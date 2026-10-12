-- Own assigned plot fallback uses the real respawn resolver with authoritative memberships.
local owner, ownerH, ownerC = subject(30)
local teammate, teamH, teamC = subject(40)
local plot = instance("Model")
plot.Parent = workspaceFake
local identity = instance("Folder")
identity.Name, identity.Parent = "PlotIdentity", plot
local marker = instance("Attachment")
marker.Name, marker.Parent, marker.WorldCFrame = "PlayerSpawnOrigin", identity, frame(100, 4, 300)
assignments[owner], assignments[teammate], owners[plot] = plot, plot, owner
contexts[owner], contexts[teammate] = {}, {}
local function arm(p, character)
    changed:Fire(character, true)
    changed:Fire(character, false)
    tick(0.4)
    tick(3)
    event.OnServerEvent:Fire(p, true)
end
local inventory = { "Apple", "Banana" }
ownerC.Inventory, teamC.Inventory = inventory, { "Ice" }
local carry = instance("Tool")
carry.Name, carry.Parent = "CarriedIngredients", ownerC
local apple = instance("Part")
apple.Name, apple.Parent = "Apple", carry
local banana = instance("Part")
banana.Name, banana.Parent = "Banana", carry
local carriedCount = #carry:GetChildren()
destination = nil
arm(owner, ownerC)
local before = ownerH.Health
check(service.Request(owner), "blocked vertical lift falls back to owner's assigned plot")
check(
    ownerC.Teleported.Position.X == 100 and ownerC.Teleported.Position.Y == 7 and ownerC.Teleported.Position.Z == 300,
    "owner fallback uses PlayerSpawnOrigin plus existing three-stud vertical offset"
)
check(
    event.Replies[owner] == "Returned to your plot!" and fallNotified[owner] == ownerC,
    "fallback success feedback and authorized fall reset issued"
)
check(
    ownerH.Health == before and ownerC.Inventory == inventory and #inventory == 2 and assignments[owner] == plot,
    "fallback preserves health, inventory identity and assigned plot"
)
check(
    carry.Parent == ownerC and apple.Parent == carry and banana.Parent == carry and #carry:GetChildren() == carriedCount,
    "whole-model teleport preserves carried instances without duplication or loss"
)
arm(teammate, teamC)
check(
    service.Request(teammate) and teamC.Teleported.Position.X == 104 and teamC.Teleported.Position.Y == 7,
    "teammate fallback uses same plot and existing four-stud offset"
)
check(
    assignments[teammate] == plot and owners[plot] == owner and #teamC.Inventory == 1,
    "teammate recovery never changes ownership, membership, or carried ingredients"
)
local released, releasedH, releasedC = subject(50)
assignments[released], contexts[released] = plot, {}
arm(released, releasedC)
assignments[released], contexts[released] = nil, nil
check(
    not service.Request(released) and not releasedC.Teleported,
    "plot release invalidates already eligible history rather than using another plot"
)
local blocked, blockedH, blockedC = subject(60)
assignments[blocked], contexts[blocked] = plot, {}
spawnUsable = false
arm(blocked, blockedC)
check(
    not service.Request(blocked)
        and not blockedC.Teleported
        and event.Replies[blocked] == "Unable to find a safe recovery position.",
    "unsafe plot spawn fails without mutation"
)
spawnUsable = true
marker:Destroy()
tick(1.1)
event.OnServerEvent:Fire(blocked, true)
check(not service.Request(blocked), "missing assigned spawn marker cannot route to an arbitrary plot")
