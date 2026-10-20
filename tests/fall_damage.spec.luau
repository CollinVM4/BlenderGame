-- Real service with engine velocity, floor and raycast signals controlled here.
env.Enum.HumanoidStateType = {
    Freefall = "Freefall",
    Jumping = "Jumping",
    Physics = "Physics",
    GettingUp = "GettingUp",
    Landed = "Landed",
    Running = "Running",
    RunningNoPhysics = "RunningNoPhysics",
    Swimming = "Swimming",
    Climbing = "Climbing",
    Seated = "Seated",
}
env.Enum.Material = { Air = "Air", Concrete = "Concrete" }
env.Enum.HumanoidRigType = { R6 = "R6", R15 = "R15" }
services.RunService.Heartbeat = signal()
workspaceFake.Gravity = 196.2
local fallDamage = loadModule("FallDamageService")
local config = loadModule("FallDamage")

check(fallDamage.ComputeDamage(0) == 0, "no impact means no damage")
check(fallDamage.ComputeDamage(config.SafeImpactVelocity) == 0, "at SafeImpactVelocity still no damage")
check(fallDamage.ComputeDamage(config.SafeImpactVelocity - 1) == 0, "below SafeImpactVelocity no damage")

local atLight = fallDamage.ComputeDamage(config.LightImpactVelocity)
check(atLight == config.LightDamage, "at LightImpactVelocity damage equals the configured light amount")

local atHeavy = fallDamage.ComputeDamage(config.HeavyImpactVelocity)
check(atHeavy == config.HeavyDamage, "at HeavyImpactVelocity damage equals the configured heavy amount")

local atLethal = fallDamage.ComputeDamage(config.LethalImpactVelocity)
check(atLethal == config.LethalDamage, "at LethalImpactVelocity damage equals the configured lethal amount")

check(
    fallDamage.ComputeDamage(config.LethalImpactVelocity + 50) == config.LethalDamage,
    "overkill caps at lethal damage"
)

check(atLight > 0 and atLight < atHeavy, "light damage is a small, nonzero fraction of heavy damage")
check(atHeavy < atLethal, "damage increases monotonically across thresholds")

-- Curve must be smooth (monotonic), not four ugly binary steps.
local previous = 0
local monotonic = true
for velocity = 0, config.LethalImpactVelocity + 10, 5 do
    local damage = fallDamage.ComputeDamage(velocity)
    if damage < previous - 1e-6 then
        monotonic = false
    end
    previous = damage
end
check(monotonic, "damage never decreases as impact velocity increases")

-- Jump-power compensation: a normal jump-and-land on the same level must never
-- exceed the Safe threshold once the jump's own velocity is subtracted.
local maxJumpPower = 116
local normalJumpLandingSpeed = maxJumpPower
local effective = math.max(0, normalJumpLandingSpeed - maxJumpPower)
check(fallDamage.ComputeDamage(effective) == 0, "landing from one's own max-tier jump is always safe")

fallDamage.Init({
    MovementService = {
        IsInitialized = function()
            return true
        end,
        GetJumpPower = function(p)
            return p.JumpPower
        end,
    },
})
local groundNormal = nil
local groundHeight = nil
local rayCount = 0
workspaceFake.Raycast = function(_, origin, direction, params)
    rayCount += 1
    setup(
        params.RespectCanCollide and params.IgnoreWater and #params.FilterDescendantsInstances == 1,
        "support query uses collidable world geometry and excludes character"
    )
    local reachesGround = groundHeight == nil or (origin.Y >= groundHeight and origin.Y + direction.Y <= groundHeight)
    return if groundNormal and reachesGround then { Normal = groundNormal } else nil
end
local function subject(jumpPower)
    local p = instance("Player")
    p.JumpPower = jumpPower
    local character = instance("Model")
    character.Parent, p.Character = workspaceFake, character
    local h = instance("Humanoid")
    h.Parent, h.Health = character, 1000
    h.Mode, h.FloorMaterial, h.PlatformStand = "Physics", "Air", true
    h.JumpPower, h.JumpHeight, h.UseJumpPower, h.HipHeight = jumpPower, 7.2, true, 2
    h.Jump, h.RigType = false, "R15"
    h.Died = signal()
    h.StateChanged = signal()
    h.Damages = {}
    function h:GetState()
        return self.Mode
    end
    function h:TakeDamage(amount)
        if character:FindFirstChildOfClass("ForceField") then
            return
        end
        table.insert(self.Damages, amount)
        self.Health -= amount
        if self.Health <= 0 then
            self.Died:Fire()
        end
    end
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", character
    root.AssemblyLinearVelocity, root.Anchored = vec(0, 0, 0), false
    root.CollisionGroup = "Default"
    local torso = instance("Part")
    torso.Name, torso.Parent = "UpperTorso", character
    torso.CanCollide, torso.CollisionGroup = true, "Default"
    fallDamage.ApplyCharacter(p, character)
    groundNormal = nil
    groundHeight = nil
    return p, h, root, torso
end
local function step(h, root, y, grounded, seconds)
    root.AssemblyLinearVelocity = vec(38, y, 0)
    h.FloorMaterial = if grounded then "Concrete" else "Air"
    groundNormal = if grounded then vec(0, 1, 0) else nil
    services.RunService.Heartbeat:Fire(seconds or 1 / 60)
end
local function land(h, root)
    step(h, root, 0, true)
end
local function transition(h, mode)
    local old = h.Mode
    h.Mode = mode
    h.StateChanged:Fire(old, mode)
end
-- Support and velocity are scripted per Heartbeat; no engine state events are needed.
local logs = {}
env.warn = function(message)
    table.insert(logs, message)
end
workspaceFake.GetServerTimeNow = os.clock
services.RunService.IsServer = function()
    return true
end
local function events(name)
    local result = {}
    for _, message in logs do
        if string.find(message, "event=" .. name .. " ", 1, true) then
            table.insert(result, message)
        end
    end
    return result
end
local function has(message, fragment)
    return string.find(message, fragment, 1, true) ~= nil
end
local function trace(p)
    table.clear(logs)
    setup(fallDamage.EnableDiagnostics(p, 30, 240), "attached player supports diagnostics")
end
local function expected(peak, jumpPower)
    return fallDamage.ComputeDamage(math.max(0, peak - math.min(jumpPower, config.CompensationCap)))
end
-- Walk-off and jump-off from identical heights, repeated without a settling pause.
for _, jumpPower in { 60, 85, 95, 116 } do
    local p, h, root = subject(jumpPower)
    h.Mode, h.PlatformStand, h.Health = "Running", false, 10000
    land(h, root)
    for _ = 1, 5 do
        local damages = {}
        for _, jumping in { false, true } do
            h.Mode = if jumping then "Jumping" else "Freefall"
            step(h, root, if jumping then jumpPower else 0, false)
            h.Mode = "Freefall"
            local speed = math.sqrt(2 * workspaceFake.Gravity * 60 + (if jumping then jumpPower * jumpPower else 0))
            step(h, root, -speed, false)
            local before = h.Health
            h.Mode = "Landed"
            land(h, root)
            table.insert(damages, before - h.Health)
            check(
                math.abs(damages[#damages] - expected(speed, jumpPower)) < 0.0001,
                "same-ledge fall uses episode peak"
            )
        end
        check(damages[2] >= damages[1], "jump-off never damages less than walk-off from the same ledge")
    end
    fallDamage.RemovePlayer(p)
end
for _, jumpPower in { 60, 85, 95, 116 } do
    local p, h, root = subject(jumpPower)
    trace(p)
    for _ = 1, 3 do
        h.Mode, h.PlatformStand = "Jumping", false
        step(h, root, jumpPower, false)
        h.Mode = "Freefall"
        step(h, root, -jumpPower, false)
        h.Mode = "Landed"
        land(h, root)
    end
    check(#h.Damages == 0 and #events("damage") == 3, "consecutive flat-ground jumps evaluate safely at every tier")
    fallDamage.RemovePlayer(p)
end
-- High walk-off, then a supported graze with Landed/Running flicker at full speed.
do
    local p, h, root = subject(116)
    trace(p)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -150, false)
    step(h, root, -209, false)
    h.Mode = "Landed"
    step(h, root, -207, true)
    h.Mode = "Running"
    step(h, root, -209, false) -- State alone is support evidence, still not an impact.
    check(#h.Damages == 0 and #events("damage") == 0, "high-speed graze and state flicker cannot consume the peak")
    h.Mode = "Freefall"
    step(h, root, -206, false)
    h.Mode = "Landed"
    land(h, root)
    for _ = 1, 20 do
        land(h, root)
    end
    check(#h.Damages == 1 and h.Damages[1] == config.LethalDamage, "true landing evaluates the full lethal peak once")
    local evaluations = events("damage")
    check(
        #events("episode-start") == 1
            and #evaluations == 1
            and has(evaluations[1], "peak=209")
            and has(evaluations[1], "cause=impact"),
        "one episode survives the graze through its actual impact"
    )
    fallDamage.RemovePlayer(p)
end
-- Shelf impacts immediately rearm, while a small landing bounce has its own safe peak.
do
    local p, h, root = subject(60)
    trace(p)
    step(h, root, -140, false)
    step(h, root, -130, true) -- support plus an eight-stud speed drop is sufficient, even while descending.
    check(#h.Damages == 1 and h.Damages[1] == expected(140, 60), "shelf impact evaluates its own peak")
    step(h, root, -155, false)
    land(h, root)
    check(#h.Damages == 2 and h.Damages[2] == expected(155, 60), "immediate second drop is a separate damaging episode")
    step(h, root, -60, false)
    land(h, root)
    land(h, root)
    check(
        #h.Damages == 2 and #events("damage") == 3,
        "landing micro-bounce evaluates safely without replaying old peak"
    )
    fallDamage.RemovePlayer(p)
end
-- Support without sufficient deceleration must not end an episode at the boundary.
do
    local p, h, root = subject(60)
    step(h, root, -150, false)
    step(h, root, -143, true)
    check(#h.Damages == 0, "less than ImpactSpeedDrop is a graze")
    step(h, root, -142, true)
    check(#h.Damages == 1 and h.Damages[1] == expected(150, 60), "exact ImpactSpeedDrop confirms an impact")
    fallDamage.RemovePlayer(p)
end
-- Gentle slope touchdown requires continuous support for 0.1 seconds.
do
    local p, h, root = subject(60)
    trace(p)
    step(h, root, -6, false)
    step(h, root, -3, true, 0.05)
    check(#events("damage") == 0, "one short supported sample does not soft-land")
    step(h, root, -3, false, 0.05)
    step(h, root, -3, true, 0.05)
    check(#events("damage") == 0, "support loss resets soft confirmation time")
    step(h, root, -3, true, 0.05)
    for _ = 1, 10 do
        step(h, root, -3, true, 0.05)
    end
    local evaluations = events("damage")
    check(
        #evaluations == 1 and has(evaluations[1], "cause=soft") and #h.Damages == 0,
        "sustained gentle touchdown evaluates once as soft"
    )
    fallDamage.RemovePlayer(p)
end
-- No StateChanged listener captures contacts or consumes between-Heartbeat flicker.
do
    local p, h, root = subject(60)
    trace(p)
    step(h, root, -150, false)
    groundNormal, root.AssemblyLinearVelocity = vec(0, 1, 0), vec(0, 0, 0)
    transition(h, "Landed")
    transition(h, "Running")
    transition(h, "Freefall")
    step(h, root, -149, false)
    check(#h.Damages == 0 and #events("damage") == 0, "unobserved event contact cannot consume a Heartbeat episode")
    land(h, root)
    check(#h.Damages == 1, "later sampled support and deceleration evaluates the original episode")
    check(not string.find(sources.FallDamageService, "StateChanged", 1, true), "tracker has no StateChanged connection")
    fallDamage.RemovePlayer(p)
end
-- Upright support geometry retains actual rig dimensions and the root collision group.
for _, rig in { "R6", "R15" } do
    local p, h, root, torso = subject(60)
    h.Mode, h.PlatformStand, h.RigType, h.HipHeight = "Freefall", false, rig, if rig == "R6" then 0 else 2
    if rig == "R6" then
        local leg = instance("Part")
        leg.Name, leg.Parent, leg.Size = "Left Leg", p.Character, vec(1, 2, 1)
    end
    root.Size, root.Position, root.CollisionGroup = vec(2, 2, 1), vec(0, 3, 0), "Players"
    torso.Position = vec(0, 10, 0)
    local query = workspaceFake.Raycast
    workspaceFake.Raycast = function(world, origin, direction, params)
        return if params.CollisionGroup == "Players" then query(world, origin, direction, params) else nil
    end
    step(h, root, -150, false)
    groundHeight = 0
    land(h, root) -- Freefall state forces actual foot support instead of state evidence.
    check(#h.Damages == 1, rig .. " foot support includes rig clearance and correct collision group")
    workspaceFake.Raycast = query
    fallDamage.RemovePlayer(p)
end
-- Physics ignores stale floor/feet; torso normal and live replacement govern support.
do
    local p, h, root, torso = subject(60)
    step(h, root, -150, false)
    h.FloorMaterial = "Concrete"
    groundNormal, root.AssemblyLinearVelocity = vec(1, 0, 0), vec(0, 0, 0)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 0, "wall and stale Physics floor cannot support an impact")
    torso.Parent = nil
    local replacement = instance("Part")
    replacement.Name, replacement.Parent, replacement.CanCollide = "UpperTorso", p.Character, true
    groundNormal = vec(0.86, config.MinimumGroundNormalY, 0)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 1, "current ragdoll torso and slope normal confirm preserved fall")
    fallDamage.RemovePlayer(p)
end
for _, mode in { "Running", "Landed", "RunningNoPhysics", "GettingUp" } do
    local p, h, root = subject(60)
    step(h, root, -150, false)
    h.Mode = mode
    step(h, root, 0, false)
    check(#h.Damages == 1, mode .. " is sampled support evidence paired with deceleration")
    fallDamage.RemovePlayer(p)
end
for _, cancellation in { "death", "removal", "respawn", "teleport", "anchored", "Swimming", "Climbing", "Seated" } do
    local p, h, root = subject(60)
    step(h, root, -150, false)
    if cancellation == "death" then
        h.Health = 0
        h.Died:Fire()
    elseif cancellation == "removal" then
        p.CharacterRemoving:Fire(p.Character)
    elseif cancellation == "respawn" then
        local replacement, nextHumanoid, nextRoot = subject(60)
        fallDamage.RemovePlayer(replacement)
        p.Character = replacement.Character
        fallDamage.ApplyCharacter(p, p.Character)
        land(nextHumanoid, nextRoot)
        check(#nextHumanoid.Damages == 0, "new character does not inherit old peak")
    elseif cancellation == "teleport" then
        root.Position = vec(1000, 0, 0)
    elseif cancellation == "anchored" then
        root.Anchored = true
    else
        h.Mode = cancellation
    end
    land(h, root)
    check(#h.Damages == 0, cancellation .. " voids the episode without evaluation")
    fallDamage.RemovePlayer(p)
end
-- Authorized small reposition explicitly voids even within the normal travel tolerance.
do
    local p, h, root = subject(60)
    step(h, root, -150, false)
    root.Position += vec(0, 10, 0)
    fallDamage.NotifyRecoveryTeleport(p, p.Character)
    land(h, root)
    check(#h.Damages == 0, "authorized recovery discards its old fall")
    step(h, root, -150, false)
    fallDamage.NotifyRecoveryTeleport(p, instance("Model"))
    land(h, root)
    check(#h.Damages == 1, "recovery grants no immunity and stale-character notification cannot void a real fall")
    fallDamage.RemovePlayer(p)
end
-- Cap is applied at evaluation, while math.huge restores the old compensation.
do
    local p, h, root = subject(116)
    trace(p)
    step(h, root, -170, false)
    land(h, root)
    local record = events("damage")[1]
    check(
        h.Damages[1] == config.HeavyDamage
            and has(record, "compensation=85")
            and has(record, "effective=85")
            and has(record, "calculated=72")
            and has(record, "applied=72"),
        "tier-three compensation is capped at 85 with complete evaluation diagnostics"
    )
    local cap = config.CompensationCap
    config.CompensationCap = math.huge
    step(h, root, -170, false)
    land(h, root)
    check(
        #h.Damages == 1 and has(events("damage")[2], "compensation=116"),
        "infinite cap restores original jump compensation"
    )
    config.CompensationCap = cap
    fallDamage.RemovePlayer(p)
end
-- Configured bat arcs are safe on flat ground and still permit damaging roof falls.
for level = 1, 3 do
    local p, h, root = subject(60)
    local tuning = loadModule("BatConfig").Levels[level]
    root.AssemblyMass = 16
    function root:ApplyImpulse(impulse)
        self.AssemblyLinearVelocity += impulse / self.AssemblyMass
    end
    loadModule("BatKnockback").Apply(root, vec(0, 0, -1), tuning)
    step(h, root, root.AssemblyLinearVelocity.Y, false)
    step(h, root, -tuning.VerticalKnockback, false)
    h.Mode, h.PlatformStand = "GettingUp", false
    land(h, root)
    check(#h.Damages == 0, "flat-ground bat arc remains safe at level " .. level)
    h.Mode, h.PlatformStand = "Physics", true
    step(h, root, -200, false)
    land(h, root)
    check(#h.Damages == 1 and h.Damages[1] == expected(200, 60), "bat roof fall evaluates normally at level " .. level)
    fallDamage.RemovePlayer(p)
end
-- Synchronous death must not erase the evaluation peak or duplicate the episode.
do
    local p, h, root = subject(60)
    h.Health = config.LethalDamage
    trace(p)
    step(h, root, -220, false)
    land(h, root)
    land(h, root)
    local evaluations = events("damage")
    check(
        h.Health == 0
            and #evaluations == 1
            and has(evaluations[1], "peak=220")
            and has(evaluations[1], "applied=200")
            and has(evaluations[1], "cause=impact"),
        "lethal evaluation retains its peak through synchronous death reset"
    )
    fallDamage.RemovePlayer(p)
end
-- Episode diagnostics are quiet between transitions and retain protection/lifetime bounds.
do
    table.clear(logs)
    local p, h, root = subject(60)
    step(h, root, -150, false)
    land(h, root)
    check(#logs == 0, "diagnostics remain opt-in")
    trace(p)
    for _ = 1, 20 do
        step(h, root, -150, false)
    end
    check(#events("episode-start") == 1 and #logs == 2, "long airborne episode has one start and no sample spam")
    local shield = instance("ForceField")
    shield.Parent = p.Character
    local before = h.Health
    land(h, root)
    local record = events("damage")[1]
    check(
        h.Health == before and has(record, "applied=0") and has(record, "reason=forcefield-protected"),
        "protected impact records calculated and applied damage separately"
    )
    shield:Destroy()
    land(h, root)
    check(#events("damage") == 1, "ForceField expiry does not replay a consumed episode")
    local logged = #logs
    fallDamage.DisableDiagnostics(p)
    step(h, root, -150, false)
    land(h, root)
    check(#logs == logged, "explicit disable stops logging")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(60)
    table.clear(logs)
    fallDamage.EnableDiagnostics(p, 30, 3)
    for _ = 1, 5 do
        step(h, root, -150, false)
        land(h, root)
    end
    check(#logs == 3 and has(logs[3], "lastRecord=true"), "episode logging respects record budget")
    table.clear(logs)
    fallDamage.EnableDiagnostics(p, 1, 600)
    step(h, root, 0, false, 1.1)
    land(h, root)
    check(#logs == 1, "diagnostic expiry advances without per-sample output")
    fallDamage.RemovePlayer(p)
end
