local announcements = loadModule("AnnouncementService")
dependency.AnnouncementService = announcements
announcements.Init(dependency)
local messages = {}
shared.Events:FindFirstChild("RareIngredientSpawned").FireAllClients = function(_, payload)
    table.insert(messages, payload)
end
local p, humanoid = player(3)
local thief, thiefHumanoid = player(3)
p.DisplayName, thief.DisplayName = "Collector", "New Owner"
local function stock(id)
    local object = ingredients.Spawn(id, frame(), nil, true)
    announcements.TrackSpawn(object, id)
    return object
end
local common = stock("Banana")
setup(inventory.CarryWorldItem(p, common), "common pickup")
check(#messages == 0, "common acquisition stays quiet")
inventory.ClearHeld(p)
local mystery = stock("Dragon_Fruit")
setup(inventory.CarryWorldItem(p, mystery), "Mystery pickup commits")
check(#messages == 1 and messages[1].DisplayName == p.DisplayName, "committed pickup broadcasts DisplayName once")
check(not inventory.CarryWorldItem(thief, mystery) and #messages == 1, "consumed world identity cannot announce again")
local tool = p.Character:FindFirstChildOfClass("Tool")
tool.Unequipped:Fire()
tool.Equipped:Fire()
check(#messages == 1, "equip events do not announce ownership")
setup(inventory.Deposit(p, "Dragon_Fruit", 3) and inventory.Withdraw(p, 3), "owner stash round trip")
check(#messages == 1, "owner stash retrieval does not announce again")
setup(inventory.Deposit(p, "Dragon_Fruit", 3), "stash Mystery for theft")
local thiefEquip = thiefHumanoid.EquipTool
thiefHumanoid.EquipTool = function()
    error("failed equip")
end
check(
    not inventory.Steal(thief, p, 3) and #messages == 1 and inventory.GetSnapshot(p).Stash[3].Count == 1,
    "failed theft preserves item and does not announce"
)
thiefHumanoid.EquipTool = thiefEquip
setup(inventory.Steal(thief, p, 3), "legitimate stash theft")
check(#messages == 2 and messages[2].DisplayName == thief.DisplayName, "theft announces new possessor")
local dropped = inventory.ThrowHeld(thief)
setup(dropped and inventory.CarryWorldItem(thief, dropped), "same owner repicks throw")
check(#messages == 2, "throw repick preserves last possessor")
dropped = inventory.DropHeld(thief)
setup(dropped and inventory.CarryWorldItem(p, dropped), "different owner repicks throw")
check(#messages == 3 and messages[3].DisplayName == p.DisplayName, "world transfer back announces once")
inventory.ClearHeld(p)
local failed = stock("Dragon_Fruit")
local equip = humanoid.EquipTool
humanoid.EquipTool = function()
    error("failed equip")
end
check(not inventory.CarryWorldItem(p, failed) and #messages == 3, "failed equip cannot announce an acquisition")
humanoid.EquipTool = equip
local untracked = ingredients.Spawn("Dragon_Fruit", frame(), nil, true)
setup(inventory.CarryWorldItem(p, untracked), "untracked Mystery grant pickup")
check(#messages == 3, "non-spawner Mystery stays outside acquisition announcements")
announcements.Served(p, { "Banana" }, 10)
check(#messages == 3, "ordinary smoothie does not announce")
announcements.Served(p, { "Dragon_Fruit", "Dragon_Fruit" }, 1250000)
check(#messages == 4 and messages[4].Payout == 1250000, "multiple Mystery units yield one actual-payout event")

-- Exercise the real marker adapter and spawn hook independently of legacy world tests.
local attach, spawned
local componentChunk = assert(loadstring(sources.IngredientSpawnComponent))
setfenv(
    componentChunk,
    setmetatable({
        script = { Parent = { Parent = { Services = parent } } },
        require = function()
            return {
                BindTag = function(_, callback)
                    attach = callback
                end,
            }
        end,
    }, { __index = env })
)
local component = componentChunk()
local spawnDeps = {
    AnnouncementService = announcements,
    IngredientService = {
        GetDefinition = ingredients.GetDefinition,
        Spawn = function(...)
            spawned = ingredients.Spawn(...)
            return spawned
        end,
    },
}
local adapterChunk = assert(loadstring(sources.AnnouncedIngredientSpawn))
setfenv(
    adapterChunk,
    setmetatable({
        script = { Parent = parent },
        require = function()
            return component
        end,
    }, { __index = env })
)
adapterChunk().Init(spawnDeps)
local station = instance("Part")
station.Parent, station.Size = workspaceFake, vec(8, 2, 8)
station:SetAttribute("IngredientId", "Dragon_Fruit")
station:SetAttribute("LocationName", "Cloud Garden")
local cleanup = attach(station)
check(
    #messages == 5 and messages[5].Type == "RareIngredientSpawned" and messages[5].LocationName == "Cloud Garden",
    "real announced marker broadcasts spawn location"
)
setup(spawned and inventory.CarryWorldItem(thief, spawned), "acquire real spawner output")
check(#messages == 6 and messages[6].Type == "MysteryAcquired", "spawner establishes acquisition provenance")
cleanup()
