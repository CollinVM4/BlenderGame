local handoff = loadModule("LuckyBlockPickupHandoff")
local function pendingModel(id)
    local model = instance("Model")
    model.DescendantAdded = signal()
    model:SetAttribute("PickupId", id)
    model:SetAttribute("PickupState", "Pending")
    handoff.Track(model)
    return model
end
local model = pendingModel(1)
local released = 0
handoff.Keep(1, function()
    released += 1
end, now + 60)
local visual = instance("Model")
visual.Name, visual.Parent = "RewardVisual", model
local first = instance("BasePart")
first.Parent = visual
model.DescendantAdded:Fire(first)
model:SetAttribute("VisualPartCount", 2)
model:SetAttribute("PickupState", "Available")
handoff.Step(now)
check(
    released == 0 and first.LocalTransparencyModifier == 1,
    "partial replication keeps local prize and hides public parts"
)
local second = instance("BasePart")
second.Parent = visual
model.DescendantAdded:Fire(second)
handoff.Step(now)
check(
    released == 1 and first.LocalTransparencyModifier == 0 and second.LocalTransparencyModifier == 0,
    "complete art replaces local prize in one update"
)
handoff.Step(now)
check(released == 1, "handoff cannot release twice")
handoff.Keep(1, function()
    released += 1
end, now + 60)
check(released == 2, "late reveal defers to already public reward")
local fast = pendingModel(2)
handoff.Keep(2, function()
    released += 1
end, now + 60)
fast:SetAttribute("PickupState", "Claimed")
handoff.Step(now)
check(released == 3, "claim arriving before art removes local prize")
local missing = pendingModel(3)
handoff.Keep(3, function()
    released += 1
end, now + 60)
missing:SetAttribute("VisualPartCount", 0)
missing:SetAttribute("PickupState", "Available")
handoff.Step(now)
check(handoff.Ready(3) and released == 4, "label-only public pickup completes handoff without fallback geometry")
local timeout = pendingModel(4)
handoff.Keep(4, function()
    released += 1
end, now + 60)
handoff.Step(now + 60)
check(released == 5, "lost replication cannot retain a reveal indefinitely")
handoff.Untrack(model)
handoff.Untrack(fast)
handoff.Untrack(missing)
handoff.Untrack(timeout)
local delayed = pendingModel(6)
delayed:SetAttribute("ExpiresAt", now + 90)
handoff.Keep(6, function()
    released += 1
end, now + 60)
handoff.Step(now + 60)
check(released == 5, "replicated server expiry supersedes fallback retention deadline")
handoff.Step(now + 90)
check(released == 6, "retention ends at the replicated server expiry")
handoff.Untrack(delayed)
-- Real controller keeps reward models stationary and unopened blocks animated.
local add, remove = {}, {}
services.CollectionService.GetInstanceAddedSignal = function(_, tag)
    add[tag] = add[tag] or signal()
    return add[tag]
end
services.CollectionService.GetInstanceRemovedSignal = function(_, tag)
    remove[tag] = remove[tag] or signal()
    return remove[tag]
end
services.RunService.RenderStepped = signal()
local config = loadModule("LuckyBlockConfig")
local presentation = loadModule("LuckyBlockPresentation")
local block = instance("Model")
block.Parent = workspaceFake
block:SetAttribute("LuckyBlockOrigin", frame())
block:SetAttribute("LuckyBlockSpawnTime", now - 1)
services.CollectionService:AddTag(block, config.WorldTag)
local pickup = pendingModel(5)
pickup.Parent = workspaceFake
pickup:SetAttribute("PickupState", "Available")
pickup:SetAttribute("VisualPartCount", 0)
services.CollectionService:AddTag(pickup, presentation.PickupTag)
local moved = 0
pickup.PivotTo = function()
    moved += 1
end
env.typeof = function(value)
    return if type(value) == "table" and value.Position and value.LookVector then "CFrame" else typeof(value)
end
local animation = loadModule("LuckyBlockPresentationController")
animation.Init()
services.RunService.RenderStepped:Fire()
check(moved == 0 and block.CFrame.Position.Y ~= 0, "pickup never bobs or rotates; unopened block still animates")
