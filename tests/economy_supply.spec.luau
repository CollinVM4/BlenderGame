-- Refill and producer provenance through the real server spawn boundaries.
local economy = loadModule("Economy")
local owner = player(2)
local spawned = {}
local spawnService = table.clone(ingredients)
spawnService.Spawn = function(...)
    local object = ingredients.Spawn(...)
    table.insert(spawned, object)
    return object
end
local market = loadModule("MarketService")
market.Init({ IngredientService = spawnService, InventoryService = inventory })
local function marker(id)
    local object = part("Stock", workspaceFake)
    object:SetAttribute("IngredientId", id)
    object:SetAttribute("RespawnSeconds", 9876) -- Retired ordinary marker override.
    return object
end
for _, sample in { { "Blueberry", 3 }, { "Pear", 12 }, { "Crab", 40 }, { "Melon", 90 }, { "Gummy_Bear", 300 } } do
    local pedestal = marker(sample[1])
    market.Register(pedestal)
    market.Step()
    check(ingredients.GetRecord(spawned[#spawned]).Item.Origin == "Market", "market stock opts into premium provenance")
    setup(market.Claim(owner, pedestal), "claim pedestal stock")
    inventory.ClearHeld(owner)
    now += sample[2] - 0.01
    market.Step()
    check(pedestal:GetAttribute("StockIngredientId") == nil, "pedestal cannot refill early")
    now += 0.02
    market.Step()
    check(pedestal:GetAttribute("StockIngredientId") == sample[1], "pedestal refills at shared tier or special cadence")
    market.Unregister(pedestal)
end
local drop = market.SpawnDrop(frame(), "Melon")
check(ingredients.GetRecord(drop).Item.Origin == "Market", "market world output provenance")
drop:Destroy()
-- The actual ordinary world markers use a component-owned lifecycle, separate from MarketService.
local attachments, timers = {}, {}
local world = table.clone(cache.WorldUtil)
world.BindTag = function(tag, callback)
    attachments[tag] = callback
end
local chunk = assert(loadstring(sources.IngredientSpawnComponent))
setfenv(
    chunk,
    setmetatable({
        script = { Parent = { Parent = { Services = { WorldUtil = "WorldUtil" } } } },
        require = function(name)
            return if name == "WorldUtil" then world else loadModule(name)
        end,
        task = {
            delay = function(seconds, callback)
                local timer = { Seconds = seconds, Run = callback }
                table.insert(timers, timer)
                return timer
            end,
            cancel = function(timer)
                timer.Cancelled = true
            end,
        },
    }, { __index = env })
)
local component = chunk()
component.Init({ IngredientService = spawnService })
for _, sample in { { "Blueberry", 3 }, { "Pear", 12 }, { "Crab", 40 }, { "Melon", 90 }, { "Gummy_Bear", 300 } } do
    local station = marker(sample[1])
    local cleanup = attachments.IngredientSpawn(station)
    local object = spawned[#spawned]
    check(ingredients.GetRecord(object).Item.Origin == "Market", "ordinary marker creates Market unit")
    object:Destroy()
    check(timers[#timers].Seconds == sample[2], "live world marker uses shared refill and secret exemption")
    cleanup()
end
local announces = 0
component.Bind({ IngredientService = spawnService }, "AnnouncedIngredientSpawn", function()
    announces += 1
end)
local station = marker("Dragon_Fruit")
station:SetAttribute("MinRespawnSeconds", 240)
station:SetAttribute("MaxRespawnSeconds", 360)
local cleanup = attachments.AnnouncedIngredientSpawn(station)
local event = spawned[#spawned]
check(
    ingredients.GetRecord(event).Item.Origin == "Event" and announces == 1,
    "announced output records Event provenance"
)
event:Destroy()
check(timers[#timers].Seconds >= 240 and timers[#timers].Seconds <= 360, "announced cadence retains authored range")
timers[#timers].Run()
check(announces == 2, "announced refill still publishes output callback")
cleanup()
local output = loadModule("MuncherOutput")
output.Placement = function()
    return frame(), vec(0, 0, 0)
end
local transaction = { Model = instance("Model"), At = frame(), Reward = "Melon" }
setup(output.Spawn(ingredients, transaction), "muncher output spawns")
check(
    ingredients.GetRecord(transaction.Output).Item.Origin == "Muncher",
    "real muncher producer records non-premium provenance"
)
print("PASS: economy supply and producer provenance")
