--!strict
-- Server-authoritative fall damage. Tracks the strongest downward velocity
-- reached during a fall and evaluates it once the character genuinely lands,
-- rather than measuring raw Y-distance fallen.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.FallDamage)
local Diagnostics = require(script.Parent.FallDamageDiagnostics)
local FallDamageService = {}
local MovementService: any = nil

type State = {
    Character: Model,
    Humanoid: Humanoid,
    Root: BasePart,
    Supports: { BasePart },
    Ray: RaycastParams,
    Airborne: boolean,
    Peak: number,
    SoftTime: number,
    LastPosition: Vector3,
    LastVelocity: Vector3,
    Connections: { RBXScriptConnection },
    Trace: Diagnostics.Trace?,
}
local states: { [Player]: State } = {}

-- Sampled locomotion states are support evidence, never landing events.
local GROUNDED_STATES: { [Enum.HumanoidStateType]: boolean } = {
    [Enum.HumanoidStateType.Landed] = true,
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.RunningNoPhysics] = true,
    [Enum.HumanoidStateType.GettingUp] = true,
}

local function reset(state: State)
    state.Airborne = false
    state.Peak = 0
    state.SoftTime = 0
    state.LastPosition = state.Root.Position
    state.LastVelocity = state.Root.AssemblyLinearVelocity
end

local function probeSupport(state: State, observations: { string }?): (boolean, string)
    local matchedSource: string? = nil
    -- Probe the actual torso colliders, including rotated rigs.
    -- Appearance loading can replace torso Instances after this service attaches.
    -- Resolve the three current parts without disturbing the active fall peak.
    table.clear(state.Supports)
    for _, name in { "UpperTorso", "LowerTorso", "Torso" } do
        local body = state.Character:FindFirstChild(name)
        if body and body:IsA("BasePart") then
            table.insert(state.Supports, body)
        end
    end
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
            if observations then
                table.insert(
                    observations,
                    string.format(
                        "%s:size=%s:length=%.3f:group=%s:velocity=%s:hit=%s:normal=%s",
                        body.Name,
                        tostring(size),
                        halfHeight + Config.ImpactProbePadding,
                        body.CollisionGroup,
                        tostring(body.AssemblyLinearVelocity),
                        if result then tostring(result.Instance) else "none",
                        if result then tostring(result.Normal) else "none"
                    )
                )
            end
            if result and result.Normal.Y >= Config.MinimumGroundNormalY then
                matchedSource = "torso-ray:" .. body.Name
                if not observations then
                    return true, "torso-ray:" .. body.Name
                end
            end
        elseif observations then
            table.insert(observations, body.Name .. ":removed-or-noncollidable")
        end
    end
    if observations then
        return matchedSource ~= nil, matchedSource or "no-support"
    end
    return false, "no-support"
end

local function footSupport(state: State): (boolean, string)
    local root = state.Root
    state.Ray.CollisionGroup = root.CollisionGroup
    local height = state.Humanoid.HipHeight + root.Size.Y * 0.5
    if state.Humanoid.RigType == Enum.HumanoidRigType.R6 then
        -- R6 HipHeight is an offset above its leg, unlike R15's absolute clearance.
        local leg = state.Character:FindFirstChild("Left Leg")
        if leg and leg:IsA("BasePart") then
            height += leg.Size.Y
        end
    end
    local length = math.max(0, height) + Config.ImpactProbePadding
    local result = workspace:Raycast(root.Position, Vector3.new(0, -length, 0), state.Ray)
    return result ~= nil and result.Normal.Y >= Config.MinimumGroundNormalY, "foot-ray"
end

local function supported(state: State, mode: Enum.HumanoidStateType): boolean
    -- Physics/ragdoll support comes from the collidable torso, not stale feet/floor.
    if not state.Humanoid.PlatformStand and mode ~= Enum.HumanoidStateType.Physics then
        if footSupport(state) then
            return true
        end
    end
    return probeSupport(state, nil) or GROUNDED_STATES[mode] == true
end

local function compensation(player: Player): number
    return if MovementService and MovementService.IsInitialized(player)
        then math.min(MovementService.GetJumpPower(player), Config.CompensationCap)
        else 0
end

local function emit(state: State, event: string, fields: { [string]: any }?)
    if state.Trace then
        state.Trace:Emit(event, fields)
    end
end

function FallDamageService.DisableDiagnostics(player: Player)
    local state = states[player]
    if state then
        if state.Trace then
            state.Trace:Stop()
        end
        state.Trace = nil
    end
end

function FallDamageService.EnableDiagnostics(player: Player, seconds: number?, maxRecords: number?): boolean
    assert(RunService:IsServer(), "Fall damage diagnostics are server-only")
    local state = states[player]
    if not state then
        return false
    end
    FallDamageService.DisableDiagnostics(player)
    state.Trace = Diagnostics.new(player, function()
        local h, root = state.Humanoid, state.Root
        local ok, owner = pcall(function()
            return root:GetNetworkOwner()
        end)
        local scales = {}
        for _, name in
            {
                "BodyHeightScale",
                "BodyWidthScale",
                "BodyDepthScale",
                "HeadScale",
                "BodyTypeScale",
                "BodyProportionScale",
            }
        do
            local value = h:FindFirstChild(name)
            table.insert(
                scales,
                name .. ":" .. if value and value:IsA("NumberValue") then tostring(value.Value) else "n/a"
            )
        end
        return {
            serverTime = workspace:GetServerTimeNow(),
            mode = tostring(h:GetState()),
            floor = tostring(h.FloorMaterial),
            jump = h.Jump,
            down = math.max(0, -root.AssemblyLinearVelocity.Y),
            velocityY = root.AssemblyLinearVelocity.Y,
            peak = state.Peak,
            airborne = state.Airborne,
            softTime = state.SoftTime,
            platformStand = h.PlatformStand,
            anchored = root.Anchored,
            health = h.Health,
            hipHeight = h.HipHeight,
            rootSize = tostring(root.Size),
            rig = tostring(h.RigType),
            scales = table.concat(scales, ","),
            networkOwner = if ok then (if owner then tostring(owner) else "server") else "unavailable",
            jumpPower = h.JumpPower,
            jumpHeight = h.JumpHeight,
            useJumpPower = h.UseJumpPower,
            compensation = compensation(player),
            forceField = state.Character:FindFirstChildOfClass("ForceField") ~= nil,
        }
    end, seconds, maxRecords)
    emit(state, "enabled")
    return true
end

local function smoothstep(t: number): number
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

-- Pure curve, exported for tests. effectiveVelocity already excludes the
-- capped jump-power allowance.
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

local function evaluateLanding(player: Player, state: State, cause: string)
    local humanoid = state.Humanoid
    local peak = state.Peak
    local compensated = compensation(player)
    local effective = math.max(0, peak - compensated)
    local damage = FallDamageService.ComputeDamage(effective)
    -- Consume before TakeDamage, which can synchronously trigger death/reset.
    state.Airborne, state.Peak, state.SoftTime = false, 0, 0
    local before = humanoid.Health
    if damage > 0 then
        humanoid:TakeDamage(damage)
    end
    local applied = math.max(0, before - humanoid.Health)
    emit(state, "damage", {
        peak = peak,
        impactPeak = peak,
        effective = effective,
        compensation = compensated,
        calculated = damage,
        applied = applied,
        cause = cause,
        healthBefore = before,
        healthAfter = humanoid.Health,
        reason = if damage <= 0
            then "safe-effective-speed"
            elseif applied > 0 then "applied"
            elseif state.Character:FindFirstChildOfClass("ForceField") then "forcefield-protected"
            else "no-health-decrease",
    })
end

function FallDamageService.RemovePlayer(player: Player)
    local state = states[player]
    if state then
        emit(state, "removed")
        FallDamageService.DisableDiagnostics(player)
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
        Airborne = false,
        Peak = 0,
        SoftTime = 0,
        LastPosition = root.Position,
        LastVelocity = root.AssemblyLinearVelocity,
        Connections = {},
    }
    state.Ray.FilterType = Enum.RaycastFilterType.Exclude
    state.Ray.FilterDescendantsInstances = { character }
    state.Ray.RespectCanCollide = true
    state.Ray.IgnoreWater = true
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
            if state.Airborne then
                emit(state, "reset", { reason = "death" })
            end
            reset(state)
        end)
    )
end

-- Explicitly separate an authorized recovery reposition from physical travel.
-- The next real descent/landing is tracked normally; this grants no damage immunity.
function FallDamageService.NotifyRecoveryTeleport(player: Player, character: Model)
    local state = states[player]
    if state and state.Character == character and player.Character == character then
        reset(state)
        emit(state, "reset", { reason = "authorized-recovery-teleport" })
    end
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
            if state.Trace then
                -- Advance the trace lifetime without emitting per-sample records.
                state.Trace:SampleDue(dt)
                if not state.Trace:Active() then
                    FallDamageService.DisableDiagnostics(player)
                end
            end
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
                if state.Airborne then
                    emit(state, "reset", {
                        reason = if humanoid.Health <= 0
                            then "dead"
                            elseif root.Anchored then "anchored"
                            elseif mode == Enum.HumanoidStateType.Swimming then "swimming"
                            elseif mode == Enum.HumanoidStateType.Climbing then "climbing"
                            elseif mode == Enum.HumanoidStateType.Seated then "seated"
                            else "reposition-budget",
                        travelBudget = travelBudget,
                        travel = (root.Position - state.LastPosition).Magnitude,
                    })
                end
                reset(state)
                continue
            end
            state.LastPosition, state.LastVelocity = root.Position, velocity
            local down = math.max(0, -velocity.Y)
            local support = supported(state, mode)
            if not state.Airborne then
                if not support then
                    state.Airborne, state.Peak, state.SoftTime = true, down, 0
                    emit(state, "episode-start")
                end
                continue
            end
            state.Peak = math.max(state.Peak, down)
            if support and down <= state.Peak - Config.ImpactSpeedDrop then
                evaluateLanding(player, state, "impact")
            elseif support and down <= Config.SettleVerticalSpeed then
                state.SoftTime += dt
                if state.SoftTime >= Config.GroundConfirmSeconds then
                    evaluateLanding(player, state, "soft")
                end
            else
                -- A graze at essentially the peak speed never consumes the episode.
                state.SoftTime = 0
            end
        end
    end)
end

return require(script.Parent.StudioServices).Wrap("FallDamageService", FallDamageService)
