-- Real inventory/stash/blender transitions around the shared cleanup clock.
local announcements = loadModule("AnnouncementService")
dependency.AnnouncementService = announcements
announcements.Init(dependency)
local messages, scheduled = {}, {}
shared.Events:FindFirstChild("RareIngredientSpawned").FireAllClients = function(_, payload)
    table.insert(messages, { At = now, Payload = payload })
end
env.task.delay = function(seconds, callback)
    table.insert(scheduled, { At = now + seconds, Callback = callback })
end
-- Model Debris deadlines too: an accidentally restored item timer must be observable.
services.Debris.AddItem = function(_, object, seconds)
    env.task.delay(seconds, function()
        object:Destroy()
    end)
end
local function advance(target)
    while true do
        table.sort(scheduled, function(a, b)
            return a.At < b.At
        end)
        if not scheduled[1] or scheduled[1].At > target then
            break
        end
        local entry = table.remove(scheduled, 1)
        now = entry.At
        entry.Callback()
    end
    now = target
end
local p = player(3)
carry(p, "Banana")
setup(inventory.Deposit(p, "Banana", 1), "protected stash ingredient")
carry(p, "Strawberry")
setup(inventory.Deposit(p, "Strawberry", 3), "ordinary stash ingredient")
grant(p, "stored-smoothie")
setup(press(p, 2), "stash smoothie")
local input = references[p].BlenderInput
local accepted = ingredients.Spawn("Milk", frame(), nil, true)
input.Overlaps = { accepted }
setup(blend.TryInput(p, accepted, input), "active blender ingredient")
carry(p, "Banana")
local dropped = inventory.DropHeld(p)
carry(p, "Strawberry")
local thrown = inventory.ThrowHeld(p)
thrown:PivotTo(frame(10000, 20, -10000))
carry(p, "Milk")
local carriedTool = tool(p)
local overhead = p.Character:FindFirstChild("IngredientCarryVisuals")
setup(overhead ~= nil, "carried ingredient has overhead visual")
local oldLoose = ingredients.Spawn("Banana", frame(), nil, true)
-- Without the global clock, a loose item survives beyond the former per-item TTL.
advance(now + 241)
check(ingredients.GetRecord(oldLoose) ~= nil, "no independent four-minute expiration")
local start = now
ingredients.Init(dependency)
ingredients.Init(dependency)
advance(start + 179)
check(#messages == 0 and ingredients.GetRecord(oldLoose) ~= nil, "no early warning or cleanup")
advance(start + 180)
check(#messages == 1 and messages[1].At == start + 180, "one warning sixty seconds before sweep")
check(
    messages[1].Payload.Type == "ServerAnnouncement"
        and messages[1].Payload.Text == "LOOSE INGREDIENTS CLEAR IN 1 MINUTE!"
        and messages[1].Payload.Immediate == true,
    "warning uses existing time-sensitive server announcement pipeline"
)
advance(start + 220)
local late = ingredients.Spawn("Dragon_Fruit", frame(), nil, true)
advance(start + 239.9)
check(ingredients.GetRecord(late) and ingredients.GetRecord(thrown), "loose items remain until shared deadline")
local rescued = ingredients.Spawn("Banana", frame(), nil, true)
setup(inventory.CarryWorldItem(p, rescued), "pickup immediately before sweep")
advance(start + 240)
for _, object in { oldLoose, dropped, thrown, late } do
    check(object.Parent == nil and ingredients.GetRecord(object) == nil, "sweep removes registered loose ingredient")
end
check(
    inventory.GetCarryCount(p) == 2 and carriedTool.Parent ~= nil and overhead.Parent ~= nil,
    "carried Tool and overhead ingredient survive sweep"
)
check(slot(p, 1).Count == 1 and slot(p, 3).Count == 1, "protected and ordinary stash contents survive")
check(slot(p, 2).Smoothie.BlendId == "stored-smoothie", "stashed smoothie survives")
check(
    blend.GetSnapshot(p).Ingredients[1] == "Milk" and blend.GetSnapshot(p).State == "LOADING",
    "active blender batch survives"
)
local nextLoose = ingredients.Spawn("Banana", frame(), nil, true)
advance(start + 420)
check(#messages == 2 and messages[2].At == start + 420, "warning repeats on original cadence")
check(ingredients.GetRecord(nextLoose) ~= nil, "new cycle keeps loose item until sweep")
advance(start + 480)
check(nextLoose.Parent == nil, "next cycle sweeps newly registered ingredients")

-- Market regeneration continues through the normal registry/removal boundary.
local market = loadModule("MarketService")
market.Init(dependency)
local pedestal = part("Market", workspaceFake)
pedestal:SetAttribute("IngredientId", "Banana")
pedestal:SetAttribute("RespawnSeconds", 12)
market.Register(pedestal)
market.Step()
setup(pedestal:GetAttribute("StockIngredientId") == "Banana", "market has stock")
advance(start + 720)
market.Step()
check(pedestal:GetAttribute("StockIngredientId") == nil, "sweep releases market stock")
advance(now + 12)
market.Step()
check(pedestal:GetAttribute("StockIngredientId") == "Banana", "market replenishes on its existing cooldown")

-- The real marker component observes Consume destruction and schedules its refill.
local attach, stationItem
local chunk = assert(loadstring(sources.IngredientSpawnComponent))
setfenv(
    chunk,
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
chunk().Init({
    IngredientService = {
        GetDefinition = ingredients.GetDefinition,
        Spawn = function(...)
            stationItem = ingredients.Spawn(...)
            return stationItem
        end,
    },
})
local marker = part("Station", workspaceFake)
marker:SetAttribute("IngredientId", "Dragon_Fruit")
marker:SetAttribute("RespawnSeconds", 5)
marker:SetAttribute("FreezeSpawnedItem", true)
attach(marker)
local previous = stationItem
advance(start + 960)
check(previous.Parent == nil, "frozen untouched station stock participates in sweep")
advance(start + 965)
check(
    stationItem ~= previous and ingredients.GetRecord(stationItem),
    "station respawns registered stock on existing cooldown"
)
