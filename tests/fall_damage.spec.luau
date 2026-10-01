-- Real service with engine velocity, floor and raycast signals controlled here.
env.Enum.HumanoidStateType = {
    Freefall = "Freefall",
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
local rayCount = 0
workspaceFake.Raycast = function(_, _, _, params)
    rayCount += 1
    setup(
        params.RespectCanCollide and params.IgnoreWater and #params.FilterDescendantsInstances == 1,
        "support query uses collidable world geometry and excludes character"
    )
    return if groundNormal then { Normal = groundNormal } else nil
end
local function subject(jumpPower)
    local p = instance("Player")
    p.JumpPower = jumpPower
    local character = instance("Model")
    character.Parent, p.Character = workspaceFake, character
    local h = instance("Humanoid")
    h.Parent, h.Health = character, 1000
    h.Mode, h.FloorMaterial, h.PlatformStand = "Physics", "Air", true
    h.Died = signal()
    h.Damages = {}
    function h:GetState()
        return self.Mode
    end
    function h:TakeDamage(amount)
        table.insert(self.Damages, amount)
        self.Health -= amount
        if self.Health <= 0 then
            self.Died:Fire()
        end
    end
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", character
    root.AssemblyLinearVelocity, root.Anchored = vec(0, 0, 0), false
    local torso = instance("Part")
    torso.Name, torso.Parent = "UpperTorso", character
    torso.CanCollide, torso.CollisionGroup = true, "Default"
    fallDamage.ApplyCharacter(p, character)
    groundNormal = nil
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
for _, jumpPower in { 85, 95, 116 } do
    local p, h, root = subject(jumpPower)
    h.Mode, h.PlatformStand = "Freefall", false
    step(h, root, jumpPower, false)
    step(h, root, -jumpPower, false)
    h.Mode = "Landed"
    land(h, root)
    check(#h.Damages == 0, "normal intentional jump remains safe at every purchased tier")
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
