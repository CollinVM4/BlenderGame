-- Authoritative eligibility and request lifecycle; physics is a controlled boundary.
local config = loadModule("UnstuckConfig")
local policy = loadModule("UnstuckPolicy")
local observation = {
    Recent = true,
    Alive = true,
    Locked = false,
    Cooldown = false,
    StationarySeconds = 3,
    RecoverySeconds = 6,
    Intent = true,
    Obstructed = true,
    Abnormal = false,
}
check(policy.Eligible(observation), "recent obstructed failed movement qualifies")
for _, field in { "Recent", "Alive", "Intent", "Obstructed" } do
    local o = table.clone(observation)
    o[field] = false
    check(not policy.Eligible(o), field .. " is necessary for failed movement recovery")
end
for _, field in { "Locked", "Cooldown" } do
    local o = table.clone(observation)
    o[field] = true
    check(not policy.Eligible(o), field .. " prevents recovery")
end
local idle = table.clone(observation)
idle.Intent, idle.Obstructed = false, false
check(not policy.Eligible(idle), "healthy idle after ragdoll never qualifies")
idle.Abnormal = true
check(policy.Eligible(idle), "prolonged abnormal recovery qualifies without input")
idle.RecoverySeconds = config.AbnormalSeconds - 0.01
check(not policy.Eligible(idle), "abnormal recovery grace is enforced")
local moving = table.clone(observation)
moving.StationarySeconds = 0
check(not policy.Eligible(moving), "recent movement invalidates eligibility")

local p, h, c, root = subject(10)
local other, otherH, otherC, otherRoot = subject(20)
check(not service.Request(p), "unwatched arbitrary request rejected")
event.OnServerEvent:Fire(p, { Destination = env.CFrame.new(500, 500, 500) })
check(not c.Teleported, "arbitrary client destinations and malformed actions ignored")
changed:Fire(c, true)
changed:Fire(c, false)
tick(0.4)
tick(3)
check(p:GetAttribute("UnstuckEligible") == false, "idle with overlap alone does not show button")
event.OnServerEvent:Fire(p, true)
tick(0.4)
check(p:GetAttribute("UnstuckEligible") == true, "intent plus server-observed immobility/overlap shows button")
check(other:GetAttribute("UnstuckEligible") ~= true, "unrelated multiplayer character unaffected")
root.Position += vec(1, 0, 0)
check(
    not service.Request(p) and not c.Teleported,
    "activation rechecks movement rather than trusting published eligibility"
)
root.Position -= vec(1, 0, 0)
tick(0.4)
tick(3)
event.OnServerEvent:Fire(p, true)
tick(0.4)
destination = nil
check(
    not service.Request(p) and not c.Teleported and not recovered,
    "failed placement preserves character and ragdoll state"
)
check(
    event.Replies[p] == "Unable to find a safe recovery position.",
    "failure reported only after local and assigned fallback are unavailable"
)
destination = env.CFrame.new(10, 12, 10)
tick(1.1)
event.OnServerEvent:Fire(p, true)
locked[p] = true
check(not service.Request(p) and not c.Teleported, "new stun/freeze cannot be bypassed by stale button")
locked[p] = false
tick(1.1)
event.OnServerEvent:Fire(p, true)
h.PlatformStand, h.AutoRotate, h.WalkSpeed, h.JumpPower = true, false, 0, 0
root.AssemblyLinearVelocity = vec(0.2, 0, 0)
root.AssemblyAngularVelocity = vec(2, 2, 2)
local health = h.Health
check(service.Request(p), "eligible safe recovery succeeds")
check(
    c.Teleported and recoveries[c] == 1 and h.Health == health,
    "whole character moved through ragdoll authority without healing"
)
check(
    not h.PlatformStand and h.AutoRotate and h.WalkSpeed == 16 and h.JumpPower == 50,
    "valid movement restored from authoritative movement services"
)
check(
    root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0,
    "residual velocities cleared"
)
check(
    event.Replies[p] == "Unstuck!" and fallNotified[p] == c,
    "local success feedback and authorized fall reset issued"
)
check(p:GetAttribute("UnstuckEligible") == false and not service.Request(p), "success hides button and rejects replay")
check(not otherC.Teleported and otherH.Health == health, "recovery does not mutate other players")
changed:Fire(c, true)
changed:Fire(c, false)
tick(0.4)
tick(3)
event.OnServerEvent:Fire(p, true)
tick(0.4)
check(not service.Request(p), "new ragdoll does not reset cooldown")
tick(config.CooldownSeconds)
event.OnServerEvent:Fire(p, true)
h.Health = 0
check(not service.Request(p), "death cannot be avoided")
h.Health = health
p.Character = instance("Model")
check(not service.Request(p), "respawn invalidates old-character history")
tick(0.4)
check(p:GetAttribute("UnstuckEligible") == false, "respawn clears button state")
changed:Fire(otherC, true)
changed:Fire(otherC, false)
otherRoot.Overlaps = {}
otherH.State = "GettingUp"
tick(0.4)
tick(6)
check(other:GetAttribute("UnstuckEligible") == false, "stale recovery state alone cannot interrupt healthy idle")
otherH.PlatformStand = true
tick(0.4)
check(other:GetAttribute("UnstuckEligible") == true, "prolonged physical immobilization qualifies without intent")
otherC.RejectRecovery = true
check(
    not service.Request(other) and not otherC.Teleported and otherRoot:GetNetworkOwnershipAuto(),
    "failed native restoration releases ownership without teleport"
)
otherC.RejectRecovery = false
tick(1.1)
check(service.Request(other), "abnormal recovery can succeed without movement input")
changed:Fire(otherC, true)
changed:Fire(otherC, false)
tick(config.RecentSeconds + 1)
check(not service.Request(other), "recent history expires")
service.RemovePlayer(p)
check(not service.Request(p), "disconnect removes recovery authority")
