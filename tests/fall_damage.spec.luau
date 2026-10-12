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
for _, jumpPower in { 60, 85, 95, 116 } do
    local p, h, root = subject(jumpPower)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, jumpPower, false)
    step(h, root, -jumpPower, false)
    h.Mode = "Landed"
    land(h, root)
    check(#h.Damages == 0, "normal intentional jump remains safe at every purchased tier")
    fallDamage.RemovePlayer(p)
end

for _, jumpPower in { 60, 85, 95, 116 } do
    local p, h, root = subject(jumpPower)
    h.PlatformStand = false
    for _ = 1, 3 do
        h.Mode = "Jumping"
        step(h, root, jumpPower, false)
        h.Mode = "Freefall"
        step(h, root, -jumpPower, false)
        h.Mode, h.Jump = "Jumping", true
        step(h, root, jumpPower, true) -- held Jump immediately launches the next safe arc
    end
    check(#h.Damages == 0, "repeated held-Jump normal arcs remain safe at every jump tier without a standing pause")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    land(h, root) -- entering Physics alone is neither a fall nor an impact
    step(h, root, 9, false)
    step(h, root, -9, false)
    land(h, root)
    check(#h.Damages == 0, "flat-ground Bat 3 horizontal shove and small arc are safe")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    step(h, root, 230, false)
    step(h, root, -9, false)
    land(h, root)
    check(#h.Damages == 0, "upward speed is never recorded as dangerous downward momentum")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Running", false
    step(h, root, -2, true)
    h.Mode, h.PlatformStand = "Physics", true
    step(h, root, -220, false)
    land(h, root)
    check(#h.Damages == 1, "standing gravity corrections do not suppress the next ledge fall")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    local before = rayCount
    step(h, root, -150, false)
    step(h, root, -(116 + config.HeavyImpactVelocity), false)
    check(rayCount == before and #h.Damages == 0, "fast airborne Physics fall only tracks velocity")
    land(h, root)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "Physics landing evaluates peak downward speed with current JumpPower compensation"
    )
    step(h, root, 30, false)
    step(h, root, -220, false)
    land(h, root)
    land(h, root)
    check(#h.Damages == 1, "bounce and repeated body contacts cannot damage the same fall again")
    step(h, root, 0, true, config.SettleSeconds)
    step(h, root, -230, false)
    land(h, root)
    check(#h.Damages == 2, "settled support rearms damage for a distinct later fall")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -200, false)
    h.Mode, h.PlatformStand = "Physics", true
    step(h, root, -130, false)
    h.Mode = "GettingUp"
    land(h, root)
    check(
        #h.Damages == 1 and h.Damages[1] == fallDamage.ComputeDamage(200 - 116),
        "Freefall to Physics to recovery preserves one fall and its peak"
    )
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    step(h, root, -210, false)
    h.FloorMaterial = "Concrete" -- stale while Physics, with no support beneath torso
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    groundNormal = vec(1, 0, 0)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 0, "wall contact and stale Physics FloorMaterial cannot signal a landing")
    groundNormal = vec(0, 0.8, 0.6)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 1, "upward-facing slope support counts as a Physics landing")
    fallDamage.RemovePlayer(p)
end
for _, cancellation in { "death", "removal", "respawn", "teleport", "anchored", "swimming" } do
    local p, h, root = subject(116)
    step(h, root, -220, false)
    if cancellation == "death" then
        h.Health = 0
        h.Died:Fire()
    elseif cancellation == "removal" then
        p.CharacterRemoving:Fire(p.Character)
    elseif cancellation == "respawn" then
        local replacement, nextHumanoid, nextRoot = subject(116)
        fallDamage.RemovePlayer(replacement)
        p.Character = replacement.Character
        fallDamage.ApplyCharacter(p, p.Character)
        land(nextHumanoid, nextRoot)
        check(#nextHumanoid.Damages == 0, "replacement character cannot inherit the previous life's peak")
    elseif cancellation == "teleport" then
        root.Position = vec(1000, 0, 0)
    elseif cancellation == "anchored" then
        root.Anchored = true
    else
        h.Mode = "Swimming"
    end
    land(h, root)
    check(#h.Damages == 0, cancellation .. " discards prior fall before any damage")
    fallDamage.RemovePlayer(p)
end

-- Transition contracts: no dependence on observing a particular Landed event.
for _, mode in { "Jumping", "Running", "Landed", "Physics" } do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    h.Mode = mode
    h.PlatformStand = mode == "Physics"
    h.Jump = mode == "Jumping"
    step(h, root, if mode == "Jumping" then 116 else 0, true)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "direct Freefall to " .. mode .. " retains peak and damages when support is recognized"
    )
    fallDamage.RemovePlayer(p)
end

-- Corrective contracts are part of the normal authoritative suite.
do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -116, false)
    h.Mode = "Landed"
    land(h, root) -- safe landing still enters bounce suppression
    for _ = 1, 4 do
        h.Mode, h.Jump = "Jumping", true
        step(h, root, 116, false)
        h.Mode = "Freefall"
        step(h, root, -201, false)
        h.Mode = "Landed"
        land(h, root)
    end
    check(#h.Damages == 4, "each distinct damaging fall after immediate bunny-hop takeoff must apply exactly once")
    step(h, root, 0, true, config.SettleSeconds)
    h.Mode = "Freefall"
    step(h, root, -201, false)
    h.Mode = "Landed"
    land(h, root)
    check(#h.Damages == 5, "later quiet support permits another distinct fall after bunny hops")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root, torso = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    root.Position, root.Size = vec(0, 3, 0), vec(2, 2, 1)
    torso.Position, torso.Size = vec(0, 4, 0), vec(2, 2, 1)
    step(h, root, -201, false)
    h.Mode, h.Jump = "Jumping", true
    groundHeight = 0 -- feet touch, but torso ray reaches only y=2.7
    step(h, root, 116, true)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "held Jump at independently supported feet landing must consume the recorded high fall immediately"
    )
    h.Mode, h.Jump = "Freefall", false
    for _ = 1, 60 do
        step(h, root, 0, false)
    end
    check(#h.Damages == 1, "unsupported motion after held-Jump landing cannot replay consumed impact")
    h.Mode = "Running"
    step(h, root, 0, true)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "later Running floor recognition cannot duplicate the held-Jump impact"
    )
    fallDamage.RemovePlayer(p)
end

-- Brief touchdown/takeoff signals may both occur between server Heartbeats.
for _, staleJumpVelocity in { false, true } do
    local p, h, root, torso = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    root.Size, root.Position = vec(2, 2, 1), vec(0, 3, 0)
    torso.Position = vec(0, 4, 0)
    step(h, root, -201, false)
    groundHeight, groundNormal = 0, vec(0, 1, 0)
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    transition(h, "Landed") -- no Heartbeat at the actual contact
    root.AssemblyLinearVelocity = vec(0, if staleJumpVelocity then 0 else 116, 0)
    transition(h, "Jumping")
    root.Position = vec(0, 5, 0) -- feet now beyond the support probe's padding
    transition(h, "Freefall")
    step(h, root, 116, false)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "latched world contact applies old peak despite brief Jumping and missing touchdown Heartbeat"
    )
    step(h, root, -201, false)
    root.Position = vec(0, 3, 0)
    transition(h, "Landed")
    land(h, root)
    check(#h.Damages == 2, "corroborated brief jump rearms the next distinct fall without quiet standing")
    land(h, root)
    check(#h.Damages == 2, "duplicate contacts after brief touchdown still apply damage once")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -180, false)
    root.AssemblyLinearVelocity, groundNormal = vec(0, -201, 0), vec(0, 1, 0)
    transition(h, "Landed") -- latest observed descent is between Heartbeats
    root.AssemblyLinearVelocity = vec(0, 116, 0)
    transition(h, "Jumping")
    step(h, root, 116, false)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "contact capture includes the latest server-observed downward velocity in the previous peak"
    )
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    transition(h, "Jumping")
    step(h, root, 116, false)
    check(#h.Damages == 0, "unsupported Jumping transition alone never confirms a landing")
    h.Mode = "Landed"
    land(h, root)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "unsupported jump transition preserves the old peak until genuine landing"
    )
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    h.Mode = "Running"
    land(h, root)
    step(h, root, 0, false, config.SettleSeconds + 0.01)
    transition(h, "Jumping")
    step(h, root, 116, false)
    h.Mode = "Freefall"
    step(h, root, -201, false)
    h.Mode = "Landed"
    land(h, root)
    check(#h.Damages == 1, "expired support cannot corroborate an airborne Jumping request or rearm an impact bounce")
    fallDamage.RemovePlayer(p)
end

for _, mode in { "Jumping", "Running", "Physics" } do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    h.Mode, h.PlatformStand = mode, mode == "Physics"
    h.FloorMaterial, groundNormal = "Concrete", vec(1, 0, 0)
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    h.StateChanged:Fire("Freefall", mode)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 0, "wall normal and stale FloorMaterial cannot confirm a " .. mode .. " landing")
    groundNormal = nil
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 0, "unsupported surface cannot confirm a " .. mode .. " landing")
    fallDamage.RemovePlayer(p)
end

for _, dimensions in { { vec(1, 1, 0.5), 0.7 }, { vec(4, 2.6, 3), 1.2 }, { vec(2, 2, 1), 4 } } do
    local p, h, root, torso = subject(116)
    h.Mode, h.PlatformStand, h.HipHeight = "Freefall", false, dimensions[2]
    root.Size = dimensions[1]
    local clearance = h.HipHeight + root.Size.Y * 0.5
    root.Position, torso.Position = vec(0, clearance, 0), vec(0, clearance + 3, 0)
    step(h, root, -201, false)
    groundHeight = 0
    h.Mode = "Jumping"
    step(h, root, 116, true)
    check(
        #h.Damages == 1 and h.Damages[1] == config.HeavyDamage,
        "short/wide/unusual upright avatar uses actual root dimensions and HipHeight at held-Jump touchdown"
    )
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root, torso = subject(116)
    h.Mode, h.PlatformStand, h.RigType, h.HipHeight = "Freefall", false, "R6", 0
    local leg = instance("Part")
    leg.Name, leg.Parent, leg.Size = "Left Leg", p.Character, vec(1, 2, 1)
    root.Size, root.Position, torso.Position = vec(2, 2, 1), vec(0, 3, 0), vec(0, 4, 0)
    step(h, root, -201, false)
    groundHeight, h.Mode = 0, "Landed"
    land(h, root)
    check(#h.Damages == 1, "existing R6 landing clearance includes leg height and remains supported")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    root.Position, root.AssemblyLinearVelocity = vec(1000, 0, 0), vec(0, 0, 0)
    groundNormal = vec(0, 1, 0)
    transition(h, "Landed")
    root.Position = vec(0, 0, 0)
    step(h, root, 0, false)
    check(#h.Damages == 0, "intermediate teleported contact cannot bypass Heartbeat reposition validation")
    fallDamage.RemovePlayer(p)
end

for _, cancellation in { "death", "anchored", "swimming", "climbing", "seated", "teleport", "respawn" } do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    groundNormal, root.AssemblyLinearVelocity = vec(0, 1, 0), vec(0, 0, 0)
    transition(h, "Landed")
    if cancellation == "death" then
        h.Health = 0
        h.Died:Fire()
    elseif cancellation == "anchored" then
        root.Anchored = true
    elseif cancellation == "swimming" then
        h.Mode = "Swimming"
    elseif cancellation == "climbing" then
        h.Mode = "Climbing"
    elseif cancellation == "seated" then
        h.Mode = "Seated"
    elseif cancellation == "teleport" then
        root.Position = vec(1000, 0, 0)
    else
        local replacement, nextHumanoid, nextRoot = subject(116)
        fallDamage.RemovePlayer(replacement)
        p.Character = replacement.Character
        fallDamage.ApplyCharacter(p, p.Character)
        land(nextHumanoid, nextRoot)
        check(#nextHumanoid.Damages == 0, "new character life cannot inherit a pending contact or fall peak")
    end
    land(h, root)
    check(#h.Damages == 0, cancellation .. " resets latched touchdown evidence before damage")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    step(h, root, -201, false)
    land(h, root)
    root.AssemblyLinearVelocity = vec(0, 116, 0)
    transition(h, "Jumping") -- PlatformStand still true: input cannot rearm a ragdoll bounce
    step(h, root, -201, false)
    land(h, root)
    check(#h.Damages == 1, "Jumping signal during PlatformStand cannot split a ragdoll's single impact")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    groundNormal, root.AssemblyLinearVelocity = vec(0, 1, 0), vec(0, 116, 0)
    transition(h, "Jumping")
    h.PlatformStand = true
    transition(h, "Physics")
    land(h, root)
    h.PlatformStand = false
    transition(h, "GettingUp")
    step(h, root, 116, false)
    step(h, root, -201, false)
    land(h, root)
    check(#h.Damages == 1, "ragdoll entry invalidates an old intentional-jump signal before recovery bounces")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, -201, false)
    groundNormal, root.AssemblyLinearVelocity = vec(0, 1, 0), vec(0, 0, 0)
    transition(h, "Landed")
    step(h, root, 0, false, config.SettleSeconds + 0.05)
    check(#h.Damages == 1, "fresh end-of-step contact is not aged by the entire preceding long Heartbeat")
    fallDamage.RemovePlayer(p)
end

do
    local query = workspaceFake.Raycast
    workspaceFake.Raycast = function(world, origin, direction, params)
        return if params.CollisionGroup == "Players" then query(world, origin, direction, params) else nil
    end
    local p, h, root, torso = subject(116)
    h.Mode, h.PlatformStand = "Freefall", false
    root.Size, root.Position, root.CollisionGroup = vec(2, 2, 1), vec(0, 3, 0), "Players"
    torso.Position, torso.CollisionGroup = vec(0, 4, 0), "OtherGroup"
    step(h, root, -201, false)
    groundHeight, h.Mode = 0, "Jumping"
    step(h, root, 116, true)
    check(#h.Damages == 1, "upright support uses the root's collision group for player-only platforms")
    workspaceFake.Raycast = query
    fallDamage.RemovePlayer(p)
end

for _, shape in { vec(0.8, 0.8, 0.4), vec(5, 1, 3) } do
    local p, h, root, torso = subject(116)
    torso.Size = shape
    torso.Position = vec(0, shape.Y * 0.5, 0)
    step(h, root, -201, false)
    groundHeight = 0
    land(h, root)
    check(#h.Damages == 1, "small/wide torso landing uses actual dimensions when collider reaches flat platform")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root = subject(116)
    step(h, root, -201, false)
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    groundNormal = vec(0.87, config.MinimumGroundNormalY - 0.01, 0)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 0, "steep terrain below the existing ground-normal cutoff cannot confirm a Physics landing")
    groundNormal = vec(0.86, config.MinimumGroundNormalY + 0.01, 0)
    services.RunService.Heartbeat:Fire(1 / 60)
    check(#h.Damages == 1, "terrain above the existing normal cutoff consumes the preserved fall")
    fallDamage.RemovePlayer(p)
end

do
    local p, h, root, torso = subject(116)
    step(h, root, -201, false)
    torso.Parent = nil
    local replacement = instance("Part")
    replacement.Name, replacement.Parent, replacement.CanCollide = "UpperTorso", p.Character, true
    land(h, root)
    check(#h.Damages == 1, "Physics landing after avatar torso replacement must use the current collider")
    fallDamage.RemovePlayer(p)
end

-- A late position update can exceed one Heartbeat's travel budget even though
-- its displacement represents several physics/replication steps.
do
    local p, h, root = subject(116)
    step(h, root, -201, false)
    root.Position = root.Position + vec(0, -20, 0)
    land(h, root)
    check(#h.Damages == 0, "unchanged reposition budget discards a discontinuous 20-stud sample")
    fallDamage.RemovePlayer(p)
end

-- Opt-in output contracts, with the real service and real diagnostics helper.
workspaceFake.GetServerTimeNow = os.clock
services.RunService.IsServer = function()
    return true
end
local logs = {}
env.warn = function(message)
    table.insert(logs, message)
end
local function logged(fragment)
    for _, message in logs do
        if string.find(message, fragment, 1, true) then
            return true
        end
    end
    return false
end
do
    local p, h, root = subject(116)
    step(h, root, -201, false)
    land(h, root)
    check(#logs == 0, "diagnostics are silent by default")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(116)
    check(fallDamage.EnableDiagnostics(p, 30, 30), "attached character supports explicit server diagnostics")
    h.Mode, h.PlatformStand = "Freefall", false
    h.StateChanged:Fire("Running", "Freefall")
    step(h, root, -201, false, 0.1)
    h.Mode = "Running"
    land(h, root)
    check(
        logged("event=state-change") and logged("from=Running") and logged("to=Freefall"),
        "diagnostics report actual Humanoid transition events"
    )
    check(
        logged("event=ground-transition") and logged("probes=") and logged("floor=Air"),
        "diagnostics report ground, floor and independent torso probes"
    )
    check(
        logged("source=foot-ray") and logged("impactPeak=201") and logged("compensation=116"),
        "landing diagnostics identify confirmation source and compensated peak"
    )
    check(
        logged("calculated=72") and logged("applied=72") and logged("reason=applied"),
        "calculation and actual health decrease are logged independently"
    )
    check(
        logged("scales=") and logged("networkOwner=") and logged("jumpPower="),
        "diagnostics include scale, ownership and jump settings"
    )
    local before = #logs
    fallDamage.DisableDiagnostics(p)
    h.StateChanged:Fire("Running", "Jumping")
    step(h, root, 0, true, 0.1)
    check(#logs == before, "explicit disable stops state and physics logging")
    fallDamage.RemovePlayer(p)
end
do
    logs = {}
    local p, h, root = subject(116)
    local shield = instance("ForceField")
    shield.Parent = p.Character
    fallDamage.EnableDiagnostics(p, 30, 30)
    step(h, root, -201, false)
    land(h, root)
    check(
        h.Health == 1000 and logged("calculated=72") and logged("applied=0") and logged("reason=forcefield-protected"),
        "protected damage attempt is consumed but logged as unapplied"
    )
    shield.Parent = nil
    land(h, root)
    check(#h.Damages == 0, "protection expiry does not replay an already consumed landing")
    fallDamage.RemovePlayer(p)
end
do
    logs = {}
    local p, h, root = subject(116)
    fallDamage.EnableDiagnostics(p, 30, 3)
    for _ = 1, 20 do
        h.StateChanged:Fire("Freefall", "Jumping")
    end
    check(#logs == 3 and logged("lastRecord=true"), "state-change spam cannot exceed diagnostic record budget")
    fallDamage.RemovePlayer(p)
end
do
    logs = {}
    local p, h, root = subject(116)
    fallDamage.EnableDiagnostics(p, 1, 600)
    step(h, root, 0, false, 1.1)
    h.StateChanged:Fire("Freefall", "Jumping")
    check(#logs == 1, "diagnostic duration expiry stops subsequent physics and state logs")
    fallDamage.RemovePlayer(p)
end

-- The normal displacement tolerance is 12 studs: the new 10-stud lift must have
-- an explicit teleport boundary rather than carrying an old fall/contact peak.
do
    local p, h, root = subject(60)
    step(h, root, -150, false)
    groundNormal = vec(0, 1, 0)
    h.StateChanged:Fire("Physics", "GettingUp") -- Capture an old pending landing before the teleport.
    root.Position += vec(0, 10, 0)
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    fallDamage.NotifyRecoveryTeleport(p, p.Character)
    land(h, root)
    check(#h.Damages == 0, "authorized ten-stud recovery does not consume stale lethal impact")
    step(h, root, -150, false)
    land(h, root)
    check(#h.Damages == 1, "authorized recovery grants no immunity to subsequent real falls")
    fallDamage.RemovePlayer(p)
end
do
    local p, h, root = subject(60)
    step(h, root, -150, false)
    fallDamage.NotifyRecoveryTeleport(p, instance("Model"))
    land(h, root)
    check(#h.Damages == 1, "stale-character teleport notification cannot cancel current fall")
    fallDamage.RemovePlayer(p)
end

-- Configured bat arcs keep normal compensation and single-impact consumption through recovery.
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
    h.PlatformStand = false
    transition(h, "GettingUp")
    land(h, root)
    land(h, root)
    check(
        #h.Damages == 0,
        "level " .. level .. " flat-ground arc and recovery do not create lethal or repeated fall damage"
    )
    step(h, root, 0, true, config.SettleSeconds + 0.01)
    step(h, root, -200, false)
    land(h, root)
    land(h, root)
    check(
        #h.Damages == 1 and h.Damages[1] == fallDamage.ComputeDamage(200 - 60),
        "bat recovery still permits one normal damage event for a later real fall"
    )
    fallDamage.RemovePlayer(p)
end
