-- Shared feedback timing stays separate from authority tests.
local tycoon = dependency.TycoonService
local owner, peer = player(), player()
tycoon.RemovePlayer(peer)
tycoon.Init({
    MemberChanged = blend.BindPlayer,
    MemberRemoved = blend.RemovePlayer,
    SessionEnded = blend.CleanupSession,
})
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Run = callback })
end
local wheel = references[owner].TurbineWheel
check(not blend.AddProgress(owner, wheel, 1), "empty batch cannot progress")
check(owner:GetAttribute("BlendNeedsItems") == true, "underfilled spin shows feedback")
setup(tycoon.JoinSession(peer, owner, tycoon.GetRequestContext(owner)), "join during feedback")
check(peer:GetAttribute("BlendNeedsItems") == true, "joining inherits active feedback")
now += 0.5
blend.AddProgress(peer, wheel, 1)
tycoon.RemovePlayer(owner)
now = timers[1].At
timers[1].Run()
check(
    peer:GetAttribute("BlendNeedsItems") == false,
    "original feedback expires after promotion without heartbeat extension"
)
check(
    not blend.AddProgress(peer, wheel, 1) and peer:GetAttribute("BlendNeedsItems") == false,
    "cooldown remains separate from feedback duration"
)
now += 1
blend.AddProgress(peer, wheel, 1)
local oldTimer = timers[#timers]
blend.Reset(peer)
now += 0.1
blend.AddProgress(peer, wheel, 1)
local newTimer = timers[#timers]
now = oldTimer.At
oldTimer.Run()
check(peer:GetAttribute("BlendNeedsItems") == true, "old batch timer cannot clear replacement batch feedback")
now = newTimer.At
newTimer.Run()
check(peer:GetAttribute("BlendNeedsItems") == false, "replacement feedback expires on its own timer")
now += 1
blend.AddProgress(peer, wheel, 1)
local input = references[owner].BlenderInput
for _ = 1, 3 do
    local item = ingredients.Spawn("Banana", frame(), peer, true)
    input.Overlaps = { item }
    setup(blend.TryInput(peer, item, input), "fill promoted batch")
end
check(peer:GetAttribute("BlendNeedsItems") == false, "full batch clears needs-items feedback immediately")
tycoon.RemovePlayer(peer)
for _, timer in timers do
    timer.Run()
end
check(
    peer:GetAttribute("BlendNeedsItems") == false and blend.GetSnapshot(peer) == nil,
    "teardown timers cannot resurrect feedback or batch"
)
