--!strict
-- Server-authoritative fall damage. Tracks the strongest downward velocity
-- reached during a fall and evaluates it once the character genuinely lands,
-- rather than measuring raw Y-distance fallen.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.FallDamage)
local FallDamageService = {}
local MovementService: any = nil

type State = {
    Character: Model,
    Humanoid: Humanoid,
    Root: BasePart,
    Supports: { BasePart },
    Ray: RaycastParams,
    Falling: boolean,
    PeakDownSpeed: number,
    Settling: boolean,
    SupportedFor: number,
    LastPosition: Vector3,
    LastVelocity: Vector3,
    Connections: { RBXScriptConnection },
}
local states: { [Player]: State } = {}

-- FloorMaterial is useful for standing locomotion, but is not the ragdoll
-- landing signal. Physics can retain stale floor information.
local GROUNDED_STATES: { [Enum.HumanoidStateType]: boolean } = {
    [Enum.HumanoidStateType.Landed] = true,
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local function reset(state: State)
    state.Falling = false
    state.PeakDownSpeed = 0
    state.Settling = false
    state.SupportedFor = 0
    state.LastPosition = state.Root.Position
    state.LastVelocity = state.Root.AssemblyLinearVelocity
end

local function supported(state: State): boolean
    local humanoid = state.Humanoid
    if not humanoid.PlatformStand and GROUNDED_STATES[humanoid:GetState()] then
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            return true
        end
    end
    -- Only called at a possible impact or while settling, never throughout a
    -- fast free fall. Probe the actual torso colliders, including rotated rigs.
    for _, body in state.Supports do
        if body:IsDescendantOf(state.Character) and body.CanCollide then
            local cf, size = body.CFrame, body.Size
            local halfHeight = (
                math.abs(cf.RightVector.Y) * size.X
                + math.abs(cf.UpVector.Y) * size.Y
                + math.abs(cf.LookVector.Y) * size.Z
            ) * 0.5
            state.Ray.CollisionGroup = body.CollisionGroup
            local result =
                workspace:Raycast(body.Position, Vector3.new(0, -halfHeight - Config.ImpactProbePadding, 0), state.Ray)
            if result and result.Normal.Y >= Config.MinimumGroundNormalY then
                return true
            end
        end
    end
    return false
end

local function smoothstep(t: number): number
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

-- Pure curve, exported for tests. effectiveVelocity already excludes the
-- character's own jump impulse.
function FallDamageService.ComputeDamage(effectiveVelocity: number): number
    if effectiveVelocity <= Config.SafeImpactVelocity then
        return 0
    elseif effectiveVelocity <= Config.LightImpactVelocity then
        local t = (effectiveVelocity - Config.SafeImpactVelocity)
            / (Config.LightImpactVelocity - Config.SafeImpactVelocity)
        return lerp(0, Config.LightDamage, smoothstep(t))
    elseif effectiveVelocity <= Config.HeavyImpactVelocity then
        local t = (effectiveVelocity - Config.LightImpactVelocity)
            / (Config.HeavyImpactVelocity - Config.LightImpactVelocity)
        return lerp(Config.LightDamage, Config.HeavyDamage, smoothstep(t))
    elseif effectiveVelocity <= Config.LethalImpactVelocity then
        local t = (effectiveVelocity - Config.HeavyImpactVelocity)
            / (Config.LethalImpactVelocity - Config.HeavyImpactVelocity)
        return lerp(Config.HeavyDamage, Config.LethalDamage, smoothstep(t))
    else
        return Config.LethalDamage
    end
end

local function evaluateLanding(player: Player, state: State)
    local humanoid = state.Humanoid
    if humanoid.Health <= 0 then
        return
    end
    -- Subtract the player's own jump power so a normal jump-and-land at any
    -- unlocked tier nets ~0 excess velocity; only genuine extra fall height
    -- (clouds, knockback, voids) produces damage.
    local jumpPower = if MovementService and MovementService.IsInitialized(player)
        then MovementService.GetJumpPower(player)
        else 0
    local effective = math.max(0, state.PeakDownSpeed - jumpPower)
    local damage = FallDamageService.ComputeDamage(effective)
    if damage > 0 then
        humanoid:TakeDamage(damage)
    end
end

function FallDamageService.RemovePlayer(player: Player)
    local state = states[player]
    if state then
        for _, connection in state.Connections do
            connection:Disconnect()
        end
        states[player] = nil
    end
end

function FallDamageService.ApplyCharacter(player: Player, character: Model)
    FallDamageService.RemovePlayer(player)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or not root:IsA("BasePart") then
        return
    end
    local state: State = {
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Supports = {},
        Ray = RaycastParams.new(),
        Falling = false,
        PeakDownSpeed = 0,
        Settling = false,
        SupportedFor = 0,
        LastPosition = root.Position,
        LastVelocity = root.AssemblyLinearVelocity,
        Connections = {},
    }
    state.Ray.FilterType = Enum.RaycastFilterType.Exclude
    state.Ray.FilterDescendantsInstances = { character }
    state.Ray.RespectCanCollide = true
    state.Ray.IgnoreWater = true
    for _, name in { "UpperTorso", "LowerTorso", "Torso" } do
        local body = character:FindFirstChild(name)
        if body and body:IsA("BasePart") then
            table.insert(state.Supports, body)
        end
    end
    states[player] = state
    table.insert(
        state.Connections,
        player.CharacterRemoving:Connect(function(removing)
            if removing == character and states[player] == state then
                FallDamageService.RemovePlayer(player)
            end
        end)
    )
    table.insert(
        state.Connections,
        humanoid.Died:Connect(function()
            reset(state)
        end)
    )
end

function FallDamageService.Init(dependencies)
    MovementService = dependencies.MovementService
    RunService.Heartbeat:Connect(function(dt)
        for player, state in states do
            local root, humanoid = state.Root, state.Humanoid
            if player.Character ~= state.Character or not root:IsDescendantOf(workspace) then
                FallDamageService.RemovePlayer(player)
                continue
            end
            local velocity = root.AssemblyLinearVelocity
            local mode = humanoid:GetState()
            -- Discontinuous repositioning is not a physical landing. Allow
            -- ordinary integration/replication error without carrying a peak
            -- through a teleport. Anchoring also cancels the current fall.
            local travelBudget = math.max(state.LastVelocity.Magnitude, velocity.Magnitude) * dt
                + workspace.Gravity * dt * dt * 0.5
                + Config.RepositionTolerance
            if
                humanoid.Health <= 0
                or root.Anchored
                or mode == Enum.HumanoidStateType.Swimming
                or mode == Enum.HumanoidStateType.Climbing
                or mode == Enum.HumanoidStateType.Seated
                or (root.Position - state.LastPosition).Magnitude > travelBudget
            then
                reset(state)
                continue
            end
            state.LastPosition, state.LastVelocity = root.Position, velocity
            local downSpeed = math.max(0, -velocity.Y)
            -- Standing gravity/step corrections are not new airborne events.
            if
                not state.Falling
                and not state.Settling
                and not humanoid.PlatformStand
                and GROUNDED_STATES[mode]
                and humanoid.FloorMaterial ~= Enum.Material.Air
            then
                continue
            end
            if state.Settling then
                -- A bounce remains part of the consumed fall. Rearm only once
                -- supported and vertically quiet for a short continuous period.
                if math.abs(velocity.Y) <= Config.SettleVerticalSpeed and supported(state) then
                    state.SupportedFor += dt
                    if state.SupportedFor >= Config.SettleSeconds then
                        reset(state)
                    end
                else
                    state.SupportedFor = 0
                end
                continue
            end
            if downSpeed > 0 then
                state.Falling = true
                state.PeakDownSpeed = math.max(state.PeakDownSpeed, downSpeed)
            end
            local slowed = downSpeed <= state.PeakDownSpeed - Config.ImpactSpeedDrop
                or math.abs(velocity.Y) <= Config.SettleVerticalSpeed
            if state.Falling and slowed and supported(state) then
                -- Consume before TakeDamage, which can synchronously trigger death.
                state.Falling = false
                state.Settling = true
                state.SupportedFor = 0
                evaluateLanding(player, state)
                state.PeakDownSpeed = 0
            end
        end
    end)
end

return require(script.Parent.StudioServices).Wrap("FallDamageService", FallDamageService)
