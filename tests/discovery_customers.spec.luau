local discovery = loadModule("DiscoveryService")
discovery.Init({ PlayerDataService = data })
local events = {}
shared.Events:FindFirstChild("DiscoveryAdded").FireClient = function(_, recipient, event)
    table.insert(events, { Player = recipient, Payload = event })
end
customer.Init({
    DiscoveryService = discovery,
    GameplayService = { RegisterPlotInteraction = function() end },
    PlayerDataService = data,
    TycoonService = requestAuthority(function(_, name)
        return refs[name]
    end),
}, function() end, function()
    return true
end)
local function child(class, name, parent)
    local item = instance(class)
    item.Name, item.Parent = name, parent
    if class == "Humanoid" then
        item.RigType = { Name = "R15" }
    end
    return item
end
local folder = child("Folder", "CustomerNPCs", storage)
local specials = child("Folder", "Special", folder)
local template = child("Model", "CanonicalSpecial", specials)
child("Humanoid", "Humanoid", template)
child("Part", "HumanoidRootPart", template)
template:SetAttribute("CustomerId", "caseoh")
local owner, other = player("EncounterOwner"), player("OtherSession")
data.AddPlayer(owner)
data.AddPlayer(other)
setTestJump(owner, 1)
discovery.PlayerAdded(owner)
discovery.PlayerAdded(other)
local teammate = instance("Player")
teammate.Name, teammate.UserId = "EncounterTeammate", 9090
data.AddPlayer(teammate)
discovery.PlayerAdded(teammate)
setup(
    sessionTestAuthority.JoinSession(teammate, owner, sessionTestAuthority.GetRequestContext(owner)),
    "join encounter session"
)
requestConfig.SpecialCustomerChance = 1
env.math.random = function(low)
    return low or 0
end
check(not discovery.HasSpecialCustomer(owner, "caseoh"), "template presence does not discover")
-- No encounter is awarded when the destination marker is missing.
local counter = refs.CustomerCounter
refs.CustomerCounter = nil
check(spawnFor(owner) == nil and #events == 0, "failed spawn does not discover")
refs.CustomerCounter = counter
local model = spawnFor(owner)
check(model ~= nil and discovery.HasSpecialCustomer(owner, "caseoh"), "registered special discovers before serving")
check(#events == 2 and discovery.HasSpecialCustomer(teammate, "caseoh"), "encounter reaches both session members")
for _, event in events do
    check(event.Player == owner or event.Player == teammate, "encounter sends only to session members")
end
check(not discovery.HasSpecialCustomer(other, "caseoh"), "other plot does not discover")
model:Destroy()
customer.CleanupSession(sessionTestAuthority.GetSessionId(owner))
requestConfig.SpecialCustomerChance = 0
check(spawnFor(owner) ~= nil and #events == 2, "regular fallback does not discover")
