-- Purchased Jump gates every request path; histories and scheduler follow the session.
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
local tycoon = dependency.TycoonService
local config = loadModule("CustomerRequests")
local manager, peer = player(), player()
tycoon.RemovePlayer(peer)
setup(tycoon.JoinSession(peer, manager, tycoon.GetRequestContext(manager)), "progression join")
local low = { Id = "Low", RequiredTags = { "Yellow" }, DisplayText = "Low", BasePayout = 25, MinJumpTier = 0 }
local high =
    { Id = "High", RequiredTags = { "Yellow" }, DisplayText = "High", BasePayout = 25, MinJumpTier = 2, NPCOnly = true }
table.clear(config.Definitions)
config.Definitions[1], config.Definitions[2] = low, high
local folder = instance("Folder")
folder.Name, folder.Parent = "CustomerNPCs", storage
local specials = instance("Folder")
specials.Name, specials.Parent = "Special", folder
local template = instance("Model")
template.Name, template.Parent = "TierSpecial", specials
template:SetAttribute("CustomerId", "session_special")
local humanoid = instance("Humanoid")
humanoid.RigType, humanoid.Parent = { Name = "R15" }, template
local root = part("HumanoidRootPart", template)
config.NPCs.session_special = { Type = "Special", RequestId = "High", Weight = 1 }
config.SpecialCustomerChance = 1
env.math = table.clone(math)
env.math.random = function(lowBound)
    return lowBound or 0
end
local timers = {}
env.task.delay = function(_, fn)
    table.insert(timers, fn)
end
workspaceFake.Gravity = 196.2
services.RunService.IsRunning = function()
    return true
end
services.RunService.IsServer = function()
    return true
end
local movement = loadModule("MovementService")
movement.Init(dependency)
movement.RefreshPlayer(manager)
studio = true
movement.SetStudioLevel(manager, "Jump", 3)
studio = false
check(
    manager:GetAttribute("JumpLevel") == 3 and tycoon.GetJumpTier(manager) == 0,
    "real Studio movement override stays personal"
)
peer:SetAttribute("JumpLevel", 3)
customer.ActivateForPlayer(manager)
local lowNpc = customer.SpawnForPlayer(peer)
flush()
check(
    lowNpc:GetAttribute("CustomerId") == nil and lowNpc:GetAttribute("RequestId") == "Low",
    "personal debug Jump cannot unlock special template"
)
customer.DeactivateForPlayer(manager)
tycoon.SetCash(manager, 20000)
for tier = 2, 3 do
    setup(tycoon.PurchaseUpgrade(peer, "Jump", tier, tycoon.GetRequestContext(peer)), "buy shared Jump")
end
customer.ActivateForPlayer(peer)
local special = customer.SpawnForPlayer(manager)
flush()
check(
    special:GetAttribute("CustomerId") == "session_special" and special:GetAttribute("RequestId") == "High",
    "shared purchased Jump unlocks fixed special for both members"
)
-- Fixed definition revalidation must also use purchased progression, not debug level 3.
high.MinJumpTier = 3
manager:SetAttribute("JumpLevel", 3)
customer:RefreshOrder(special)
check(special.Destroyed, "fixed request validation rejects difficulty above shared Jump")
high.MinJumpTier = 2
customer.DeactivateForPlayer(manager)
customer.ActivateForPlayer(manager)
local regular = customer.SpawnForPlayer(manager)
check(regular:GetAttribute("CustomerId") == nil, "special cooldown preserved through flow restart")
local sameId = tycoon.GetSessionId(manager)
tycoon.RemovePlayer(manager)
customer.RemovePlayer(manager)
check(tycoon.GetSessionId(peer) == sameId and customer.GetSnapshot(peer).Model == regular, "promotion preserves queue")
local nextNpc = customer.SpawnForPlayer(peer)
check(nextNpc:GetAttribute("CustomerId") == nil, "promotion preserves special cooldown history")
local oldTimers = timers
timers = {}
for _, fn in oldTimers do
    fn()
end
flush()
check(#customer.GetQueueSnapshot(peer) == 3, "existing scheduler continues after promotion without duplicate queue")

-- Recency is shared and survives the management handoff too.
customer.CleanupSession(sameId)
config.SpecialCustomerChance = 0
config.RegularRequestRecencyWindow = 2
config.RegularTemplateRecencyWindow = 2
local regulars = instance("Folder")
regulars.Name, regulars.Parent = "Regular", folder
table.clear(config.Definitions)
for index = 1, 3 do
    config.Definitions[index] = {
        Id = "Recent" .. index,
        RequiredTags = { "Yellow" },
        DisplayText = "Recent",
        BasePayout = 25,
        MinJumpTier = 0,
    }
    local model = instance("Model")
    model.Name, model.Parent = "Regular" .. index, regulars
    model:SetAttribute("TestTemplate", index)
    local hum = instance("Humanoid")
    hum.RigType, hum.Parent = { Name = "R15" }, model
    part("HumanoidRootPart", model)
end
setup(tycoon.JoinSession(manager, peer, tycoon.GetRequestContext(peer)), "rejoin for recency promotion")
customer.ActivateForPlayer(peer)
local previous = customer.SpawnForPlayer(peer)
local previousRequest, previousTemplate = previous:GetAttribute("RequestId"), previous:GetAttribute("TestTemplate")
previous:Destroy()
tycoon.RemovePlayer(peer)
local after = customer.SpawnForPlayer(manager)
check(
    after:GetAttribute("RequestId") ~= previousRequest and after:GetAttribute("TestTemplate") ~= previousTemplate,
    "request and template histories survive promotion"
)
