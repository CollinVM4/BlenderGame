--!strict
-- Server-authoritative fall damage. Tracks the strongest downward velocity
-- reached during a fall and evaluates it once the character genuinely lands,
-- rather than measuring raw Y-distance fallen.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.FallDamage)
local Diagnostics = require(script.Parent.FallDamageDiagnostics)
local FallDamageService = {}
local MovementService: any = nil

type LandingContact = { Position: Vector3, Peak: number, Slowed: boolean, Source: string }
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
    ContactAge: number,
    ContactAt: number,
    ContactFresh: boolean,
    PendingLanding: LandingContact?,
    JumpTakeoff: boolean,
    JumpObserved: boolean,
    Connections: { RBXScriptConnection },
    Trace: Diagnostics.Trace?,
    TraceConnection: RBXScriptConnection?,
    TraceContact: boolean?,
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
    state.ContactAge = math.huge
    state.ContactAt = 0
    state.ContactFresh = false
    state.PendingLanding = nil
    state.JumpTakeoff = false
    state.JumpObserved = false
    state.LastPosition = state.Root.Position
    state.LastVelocity = state.Root.AssemblyLinearVelocity
end

local function probeSupport(state: State, observations: { string }?): (boolean, string)
    local matchedSource: string? = nil
    -- Gameplay calls only at possible impacts or while settling. Enabled
    -- diagnostics also sample these rays independently, including during falls.
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

local function supported(state: State): (boolean, string)
    local humanoid = state.Humanoid
    if not humanoid.PlatformStand and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
        local contact, source = footSupport(state)
        if contact then
            return true, source
        end
    end
    return probeSupport(state, nil)
end

local function recentContact(state: State): boolean
    -- Reuse the existing settling interval as a bounded evidence lifetime, not
    -- as a mandatory pause between intentional jumps. Wall time also expires it.
    return state.ContactAge <= Config.SettleSeconds and os.clock() - state.ContactAt <= Config.SettleSeconds
end

local function captureContact(state: State, source: string, velocity: Vector3, fromEvent: boolean?)
    state.ContactAge, state.ContactAt = 0, os.clock()
    if fromEvent then
        state.ContactFresh = true
    end
    if state.Falling and not state.PendingLanding then
        state.PeakDownSpeed = math.max(state.PeakDownSpeed, math.max(0, -velocity.Y))
        state.PendingLanding = {
            Position = state.Root.Position,
            Peak = state.PeakDownSpeed,
            Slowed = math.max(0, -velocity.Y) <= state.PeakDownSpeed - Config.ImpactSpeedDrop
                or math.abs(velocity.Y) <= Config.SettleVerticalSpeed,
            Source = source,
        }
    end
end

local function intentionalTakeoff(state: State, velocity: Vector3): boolean
    local humanoid = state.Humanoid
    return not humanoid.PlatformStand
        and humanoid:GetState() ~= Enum.HumanoidStateType.Physics
        and recentContact(state)
        and (
            state.JumpTakeoff
            or (
                (state.JumpObserved or humanoid:GetState() == Enum.HumanoidStateType.Jumping)
                and velocity.Y > Config.SettleVerticalSpeed
            )
        )
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
        if state.TraceConnection then
            state.TraceConnection:Disconnect()
        end
        state.Trace, state.TraceConnection, state.TraceContact = nil, nil, nil
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
            peak = state.PeakDownSpeed,
            falling = state.Falling,
            settling = state.Settling,
            supportedFor = state.SupportedFor,
            contactAge = state.ContactAge,
            pendingLanding = state.PendingLanding ~= nil,
            jumpTakeoff = state.JumpTakeoff,
            jumpObserved = state.JumpObserved,
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
            compensation = if MovementService and MovementService.IsInitialized(player)
                then MovementService.GetJumpPower(player)
                else 0,
            forceField = state.Character:FindFirstChildOfClass("ForceField") ~= nil,
        }
    end, seconds, maxRecords)
    state.TraceConnection = state.Humanoid.StateChanged:Connect(function(old, new)
        emit(state, "state-change", { from = tostring(old), to = tostring(new) })
    end)
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
        emit(state, "damage-skipped", { reason = "dead" })
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
    local impactPeak = state.PeakDownSpeed
    local before = humanoid.Health
    if damage > 0 then
        humanoid:TakeDamage(damage)
    end
    local applied = math.max(0, before - humanoid.Health)
    emit(state, "damage", {
        effective = effective,
        impactPeak = impactPeak,
        compensation = jumpPower,
        calculated = damage,
        applied = applied,
        healthBefore = before,
        healthAfter = humanoid.Health,
        reason = if damage <= 0
            then "safe-effective-speed"
            elseif applied > 0 then "applied"
            elseif state.Character:FindFirstChildOfClass("ForceField") then "forcefield-protected"
            else "no-health-decrease",
    })
end

local function consumeLanding(player: Player, state: State, source: string)
    emit(state, "landing-confirmed", { source = source })
    -- Consume before TakeDamage, which can synchronously trigger death.
    state.Falling, state.Settling, state.SupportedFor = false, true, 0
    state.PendingLanding = nil
    evaluateLanding(player, state)
    state.PeakDownSpeed = 0
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
        Falling = false,
        PeakDownSpeed = 0,
        Settling = false,
        SupportedFor = 0,
        LastPosition = root.Position,
        LastVelocity = root.AssemblyLinearVelocity,
        ContactAge = math.huge,
        ContactAt = 0,
        ContactFresh = false,
        PendingLanding = nil,
        JumpTakeoff = false,
        JumpObserved = false,
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
        humanoid.StateChanged:Connect(function(_, new)
            if states[player] ~= state or player.Character ~= character or humanoid.Health <= 0 or root.Anchored then
                return
            end
            if new == Enum.HumanoidStateType.Physics or humanoid.PlatformStand then
                state.JumpTakeoff, state.JumpObserved = false, false
            end
            if
                GROUNDED_STATES[new]
                or new == Enum.HumanoidStateType.Jumping
                or new == Enum.HumanoidStateType.Physics
                or new == Enum.HumanoidStateType.GettingUp
            then
                local velocity = root.AssemblyLinearVelocity
                local contact, source = supported(state)
                if contact then
                    captureContact(state, "state-contact:" .. source, velocity, true)
                end
                if
                    new == Enum.HumanoidStateType.Jumping
                    and not humanoid.PlatformStand
                    and recentContact(state)
                    and (state.Falling or state.Settling)
                then
                    state.JumpObserved = true
                    state.JumpTakeoff = state.JumpTakeoff or velocity.Y > Config.SettleVerticalSpeed
                end
            end
            -- Contact observation only. Heartbeat validates reposition/reset rules
            -- before any saved contact can consume a fall or rearm a new episode.
        end)
    )
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
            emit(state, "reset", { reason = "death" })
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
            -- A state event can happen at the end of a long simulation step;
            -- do not charge the entire preceding frame against fresh evidence.
            if state.ContactFresh then
                state.ContactFresh = false
            else
                state.ContactAge += dt
            end
            if not recentContact(state) then
                state.PendingLanding, state.JumpTakeoff, state.JumpObserved = nil, false, false
            end
            if state.Trace then
                if not state.Trace:Active() then
                    FallDamageService.DisableDiagnostics(player)
                elseif state.Trace:SampleDue(dt) then
                    local contact, source = supported(state)
                    local probes = {}
                    local rayContact, raySource = probeSupport(state, probes) -- Shadow observation only.
                    emit(state, if contact ~= state.TraceContact then "ground-transition" else "sample", {
                        contact = contact,
                        source = source,
                        probes = table.concat(probes, ";"),
                        dt = dt,
                        rayContact = rayContact,
                        raySource = raySource,
                        reason = if state.Settling
                            then "bounce-suppression"
                            elseif not state.Falling then "no-tracked-fall"
                            elseif not contact then "awaiting-support"
                            else "awaiting-speed-check",
                        displacementY = root.Position.Y - state.LastPosition.Y,
                        previousVelocityY = state.LastVelocity.Y,
                    })
                    state.TraceContact = contact
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
                reset(state)
                continue
            end
            -- Reject a contact captured at a discontinuous intermediate position
            -- even if a later state transition moved the root back before Heartbeat.
            if
                state.PendingLanding
                and (state.PendingLanding.Position - state.LastPosition).Magnitude > travelBudget
            then
                state.PendingLanding, state.JumpTakeoff, state.JumpObserved = nil, false, false
                state.ContactAge = math.huge
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
                and math.abs(velocity.Y) <= Config.SettleVerticalSpeed
            then
                continue
            end
            if state.Settling then
                local contact, source = supported(state)
                if contact then
                    captureContact(state, source, velocity)
                end
                if intentionalTakeoff(state, velocity) then
                    emit(state, "rearmed", { reason = "supported-jump-takeoff" })
                    reset(state)
                elseif math.abs(velocity.Y) <= Config.SettleVerticalSpeed and contact then
                    state.SupportedFor += dt
                    if state.SupportedFor >= Config.SettleSeconds then
                        emit(state, "rearmed", { reason = "quiet-supported" })
                        reset(state)
                    end
                    continue
                else
                    state.SupportedFor = 0
                    continue
                end
            end
            local pending = state.PendingLanding
            if pending and state.Falling and recentContact(state) then
                local slowed = downSpeed <= pending.Peak - Config.ImpactSpeedDrop
                    or math.abs(velocity.Y) <= Config.SettleVerticalSpeed
                if pending.Slowed or slowed then
                    -- This contact belongs to the old fall, before any subsequently
                    -- observed takeoff/descent. Never overwrite its peak with a new one.
                    state.PeakDownSpeed = pending.Peak
                    consumeLanding(player, state, pending.Source)
                    if humanoid.Health > 0 and intentionalTakeoff(state, velocity) then
                        emit(state, "rearmed", { reason = "supported-jump-takeoff" })
                        reset(state)
                    else
                        continue
                    end
                end
            end
            if downSpeed > 0 then
                state.Falling = true
                state.PeakDownSpeed = math.max(state.PeakDownSpeed, downSpeed)
            end
            local slowed = downSpeed <= state.PeakDownSpeed - Config.ImpactSpeedDrop
                or math.abs(velocity.Y) <= Config.SettleVerticalSpeed
            local contact, source = false, "not-probed"
            if state.Falling and slowed then
                contact, source = supported(state)
            end
            if state.Falling and slowed and contact then
                captureContact(state, source, velocity)
                consumeLanding(player, state, source)
                if humanoid.Health > 0 and intentionalTakeoff(state, velocity) then
                    emit(state, "rearmed", { reason = "supported-jump-takeoff" })
                    reset(state)
                end
            end
        end
    end)
end

return require(script.Parent.StudioServices).Wrap("FallDamageService", FallDamageService)
