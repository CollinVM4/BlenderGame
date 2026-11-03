local p, h, root = subject(true)
check(state(p) == "Airborne", "midair spawn awaits jump hold rather than automatically powering")
wings.SetJumpHeld(p, "true")
check(state(p) == "Airborne", "nonboolean input never engages wings")
wings.SetJumpHeld(p, true)
fly(p, h, root, 1.725)
check(state(p) == "Powered", "powered budget remains before 1.75s")
fly(p, h, root, 0.025)
check(state(p) == "Gliding", "held budget reaches glide at 1.75s")
fly(p, h, root, 1.25)
check(state(p) == "Gliding", "three seconds held never replenishes powered energy")
check(root.AssemblyLinearVelocity.X == 7 and root.AssemblyLinearVelocity.Z == 9, "lift preserves horizontal velocity")
wings.SetJumpHeld(p, false)
tick(p, h, root, 0.025, -100, false)
check(state(p) == "Falling" and root.AssemblyLinearVelocity.Y == -100, "release stops glide without resetting velocity")
wings.SetJumpHeld(p, true)
tick(p, h, root, 0.025, -30, false)
check(
    state(p) == "Gliding" and root.AssemblyLinearVelocity.Y == -30,
    "exhausted rehold authorizes glide without server velocity writes"
)

local function remainingAfterPause(taps)
    local q, hum, r = subject(true)
    wings.SetJumpHeld(q, true)
    fly(q, hum, r, 0.875)
    for _ = 1, taps do
        wings.SetJumpHeld(q, false)
        wings.SetJumpHeld(q, true)
    end
    wings.SetJumpHeld(q, false)
    fly(q, hum, r, 1)
    wings.SetJumpHeld(q, true)
    fly(q, hum, r, 0.85)
    check(state(q) == "Powered", "release/resume preserves remaining half budget")
    fly(q, hum, r, 0.05)
    check(state(q) == "Gliding", "rapid taps never add powered duration")
    return q, hum, r
end
remainingAfterPause(0)
local q, hum, r = remainingAfterPause(10)
tick(q, hum, r, 0.025, -100, true)
tick(q, hum, r, 0.025, -100, true)
tick(q, hum, r, 0.025, 0, false)
check(state(q) == "Gliding", "one-two support ticks cannot recharge an exhausted episode")
tick(q, hum, r, 0.1, 0, true)
tick(q, hum, r, 0.025, 0, false)
check(state(q) == "Gliding", "0.1s touchdown is not sustained recharge")
for _ = 1, 9 do
    tick(q, hum, r, 0.025, 0, true)
end
tick(q, hum, r, 0.025, 0, false)
check(state(q) == "Powered", "0.2s sustained ground refills next airborne episode")

local s, sh, sr = subject(true)
wings.SetJumpHeld(s, true)
fly(s, sh, sr, 0.5)
s.Locked = true
tick(s, sh, sr, 0.25, -70, false)
check(state(s) == "Falling" and sr.AssemblyLinearVelocity.Y == -70, "stun cancels lift without changing velocity")
s.Locked = false
fly(s, sh, sr, 0.25)
check(state(s) == "Powered", "held jump resumes after lock clears")
tick(s, sh, sr, 0.025, 160, false)
check(
    sr.AssemblyLinearVelocity.Y == 160 and state(s) == "Powered",
    "external rising impulse is preserved, never punished by total altitude"
)
fly(s, sh, sr, 1.025)
check(state(s) == "Gliding", "external impulses do not replenish powered time")
for _ = 1, 12 do
    tick(s, sh, sr, 0.025, -70, false)
end
check(state(s) == "Gliding" and wings.IsGliding(s), "persistent fast descent never latches glide off")

local n, nh, nr = subject(false)
wings.SetJumpHeld(n, true)
tick(n, nh, nr, 0.5, -100, false)
check(
    nr.AssemblyLinearVelocity.Y == -100 and not wings.IsGliding(n) and not n.Character:FindFirstChild("AngelWings"),
    "unowned input grants no lift, glide or accessory"
)
n:SetAttribute("WingState", "Gliding")
n:SetAttribute("WingsOwnership", "Owned")
tick(n, nh, nr, 0.025, -180, false)
local unownedHealth = nh.Health
tick(n, nh, nr, 0.025, 0, true)
check(nh.Health < unownedHealth and not wings.IsGliding(n), "spoofed display attributes confer no landing exemption")
for _, power in { 60, 85, 95, 116 } do
    local t, th, tr = subject(true, power)
    wings.SetJumpHeld(t, true)
    tick(t, th, tr, 0.025, power, false)
    check(
        th.JumpPower == power and movement.GetJumpPower(t) == power and tr.AssemblyLinearVelocity.Y == power,
        "wings preserve jump power and fresh jump momentum at every tier"
    )
end

-- Real fall tracker, high episode peak, then gliding at the genuine boundary.
local function fastGlide()
    local f, fh, fr = subject(true)
    tick(f, fh, fr, 0.025, -180, false)
    wings.SetJumpHeld(f, true)
    fly(f, fh, fr, 1.8)
    return f, fh, fr
end
local f, fh, fr = fastGlide()
local before = fh.Health
tick(f, fh, fr, 0.025, 0, true)
check(fh.Health == before, "high peak glided landing is exempt and consumes the episode")
wings.SetJumpHeld(f, false)
tick(f, fh, fr, 0.025, -180, false)
tick(f, fh, fr, 0.025, 0, true)
check(fh.Health < before, "next fall has no stale glide immunity")
for _, gap in { 0.025, 1 } do
    local a, ah, ar = fastGlide()
    wings.SetJumpHeld(a, false)
    tick(a, ah, ar, gap, -180, false)
    local health = ah.Health
    tick(a, ah, ar, 0.025, 0, true)
    check(
        ah.Health == health - fall.ComputeDamage(120),
        "release before touchdown uses full peak even on last prelanding tick"
    )
end
-- Either Heartbeat order: wings can confirm Grounded before fall evaluates.
local a, ah, ar = fastGlide()
local health = ah.Health
ah.Mode, ah.FloorMaterial, ar.AssemblyLinearVelocity = "Running", "Concrete", vec(7, 0, 9)
heartbeats[2](0.25)
check(state(a) == "Grounded", "wings confirms recharge before delayed fall evaluation")
heartbeats[1](0.25)
check(ah.Health == health, "episode landing latch survives reverse heartbeat order and confirmation mismatch")
check(not wings.ConsumeGlideLandingProtection(a, a.Character), "fall evaluation consumes latch once")
-- Reset/teleport and another episode cannot carry protection forward.
wings.ResetFallEpisode(a, a.Character, true)
wings.ObserveFallLanding(a, a.Character, true)
wings.SetJumpHeld(a, false)
check(not wings.ConsumeGlideLandingProtection(a, a.Character), "release invalidates pending landing evidence")

-- Publish only real transitions, including the first airborne initialization.
local pub, ph, pr = subject(true)
check(state(pub) == "Airborne", "first airborne state is published")
local originalSet = pub.SetAttribute
local publishes = 0
pub.SetAttribute = function(self, key, value)
    if key == "WingState" then
        publishes += 1
    end
    originalSet(self, key, value)
end
wings.SetJumpHeld(pub, true)
tick(pub, ph, pr, 0.025, -100, false)
tick(pub, ph, pr, 0.025, -100, false)
check(publishes == 1 and state(pub) == "Powered", "unchanged Powered publishes exactly once")
check(
    pr.AssemblyLinearVelocity.Y == -100 and pr.Automatic ~= false,
    "server neither writes lift nor borrows network ownership"
)
wings.SetJumpHeld(pub, false)
wings.SetJumpHeld(pub, true)
tick(pub, ph, pr, 0.025, -100, false)
check(state(pub) == "Powered", "reholding during a fast dive resumes remaining energy")
tick(pub, ph, pr, 0.025, 0, true)
check(state(pub) == "Airborne", "provisional support immediately revokes client lift before recharge")

for _ = 1, 10 do
    tick(pub, ph, pr, 0.025, 0, true)
end
local afterGrounded = publishes
for _ = 1, 10 do
    tick(pub, ph, pr, 0.025, 0, true)
end
check(
    state(pub) == "Grounded" and publishes == afterGrounded,
    "sustained grounded state does not republish during recharge"
)
