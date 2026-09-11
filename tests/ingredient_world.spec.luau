-- Runs after the shared fake-engine boundary, before unrelated gameplay tests.
local ingredients = loadModule("IngredientService")
local templates = instance("Folder")
templates.Name, templates.Parent = "Ingredients", storage
local template = instance("Model")
template.Name, template.Parent = "Strawberry", templates
for _, name in { "Leaf", "Fruit" } do
    local part = instance("Part")
    part.Name, part.Parent, part.Size = name, template, vec(2, 3, 4)
end
local function spawn()
    return ingredients.Spawn("Strawberry", frame(10, 20, 30), nil, true)
end
local item = spawn()
check(item:IsA("Model") and item.PrimaryPart.Name == "IngredientRoot", "no PrimaryPart gets a pivot root")
check(
    item.PrimaryPart.Transparency == 1 and not item.PrimaryPart.CanCollide,
    "generated root is invisible and noncolliding"
)
check(item:GetPivot().Position.Y == 20, "world pivot uses requested frame")
check(services.CollectionService:HasTag(item, "IngredientWorldItem"), "top-level model is tagged")
for _, name in { "Leaf", "Fruit" } do
    local part = item:FindFirstChild(name)
    check(part.Size.Y == 3 and not part.Anchored and part.CanQuery, "authored size retained, physical query enabled")
    local weld = part:FindFirstChild("IngredientAssembly")
    check(weld.Part0 == item.PrimaryPart and weld.Part1 == part, "every authored part welded to root")
    check(ingredients.Resolve(part) == item, "descendant resolves authoritative model identity")
end
local clone = template.Clone
function template:Clone()
    local result = clone(self)
    result.PrimaryPart = result:FindFirstChild("Fruit")
    return result
end
local primaryItem = spawn()
check(
    primaryItem.PrimaryPart.Name == "Fruit" and not primaryItem:FindFirstChild("IngredientRoot"),
    "authored PrimaryPart wins"
)
check(ingredients.Consume(item) == "Strawberry" and not ingredients.Resolve(item), "consume unregisters entire model")
check(not ingredients.Spawn("Invalid", frame()), "unknown ingredients rejected")
check(ingredients.Spawn("Banana", frame()):IsA("BasePart"), "missing template preserves part fallback")

-- Real inventory service exercises model carry, exclusive hands, drop and throw.
local inventory = loadModule("InventoryService")
local player = instance("Player")
player.UserId, player.Near = 1, true
local character = instance("Model")
player.Character = character
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", character
local humanoid = instance("Humanoid")
humanoid.Health, humanoid.Parent, humanoid.Died = 100, character, signal()
function humanoid:EquipTool(tool)
    tool.Parent = character
end
local backpack = instance("Backpack")
backpack.Parent = player
local deps = {
    IngredientService = ingredients,
    InventoryService = inventory,
    PlayerDataService = {
        GetUpgrade = function()
            return 1
        end,
    },
}
inventory.Init(deps)
inventory.AddPlayer(player)
check(inventory.CarryWorldItem(player, primaryItem), "multipart item physically equips")
local otherItem = spawn()
check(not inventory.CarryWorldItem(player, otherItem), "second ingredient cannot equip")
local thrown = inventory.ThrowHeld(player)
check(thrown and thrown.PrimaryPart.AssemblyLinearVelocity.Y == 18, "throw applies velocity to assembled model root")
check(ingredients.GetRecord(thrown).Owner == nil, "throw remains publicly claimable")
check(inventory.CarryWorldItem(player, thrown), "thrown model can be picked up again")
check(
    inventory.DropHeld(player) ~= nil and inventory.GetHeldIngredientId(player) == nil,
    "drop restores one physical unit"
)
local input = instance("Part")
deps.TycoonService = {
    GetOwner = function()
        return player
    end,
    GetReference = function()
        return input
    end,
}
local blend = loadModule("BlendService")
blend.Init(deps)
blend.Reset(player)
local toBlend = spawn()
input.Overlaps = { toBlend:FindFirstChild("Leaf"), toBlend:FindFirstChild("Fruit") }
check(blend.TryInput(player, toBlend, input), "blender accepts overlap from model leaf")
check(
    not blend.TryInput(player, toBlend, input) and #blend.GetSnapshot(player).Ingredients == 1,
    "overlapping multiple model parts consumes only one ingredient"
)

-- Real component lifecycle with controlled tag attachment and timers.
local attachments, timers, spawned = {}, {}, {}
local world = table.clone(cache.WorldUtil)
function world.BindTag(tag, attach)
    attachments[tag] = attach
end
local componentChunk = assert(loadstring(sources.IngredientSpawnComponent))
setfenv(
    componentChunk,
    setmetatable({
        script = { Parent = { Parent = { Services = parent } } },
        require = function(name)
            assert(name == "WorldUtil")
            return world
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
local component = componentChunk()
local spawnDeps = {
    IngredientService = {
        GetDefinition = ingredients.GetDefinition,
        Spawn = function(...)
            local result = ingredients.Spawn(...)
            table.insert(spawned, result)
            return result
        end,
    },
}
local function marker(id, seconds)
    local station = instance("Part")
    station.Parent, station.Size = workspaceFake, vec(8, 2, 8)
    station:SetAttribute("IngredientId", id)
    station:SetAttribute("RespawnSeconds", seconds)
    return station
end
local announcements = 0
component.Init(spawnDeps)
component.Bind(spawnDeps, "AnnouncedIngredientSpawn", function(_, id)
    check(id == "GoldenApple", "rare announcement uses explicitly configured identity")
    announcements += 1
end)
local normal = marker("Strawberry", 10)
local cleanup = attachments.IngredientSpawn(normal)
check(#spawned == 1 and announcements == 0, "normal spawn is silent")
check(not attachments.IngredientSpawn(normal) and #spawned == 1, "duplicate attach cannot duplicate stock")
ingredients.Consume(spawned[1])
check(#timers == 1 and timers[1].Seconds == 10, "individual normal cooldown begins on removal")
timers[1].Run()
check(#spawned == 2 and announcements == 0, "normal respawn stays silent")
cleanup()
check(spawned[2].Destroyed and #timers == 1, "cleanup destroys stock without scheduling a refill")
local rare = marker("GoldenApple", 300)
rare:SetAttribute("MinRespawnSeconds", 240)
rare:SetAttribute("MaxRespawnSeconds", 360)
local cleanRare = attachments.AnnouncedIngredientSpawn(rare)
check(announcements == 1 and #spawned == 3, "rare spawn announces exactly once")
check(not attachments.IngredientSpawn(rare), "second marker tag cannot duplicate rare stock")
ingredients.Consume(spawned[3])
check(#timers == 2 and timers[2].Seconds >= 240 and timers[2].Seconds <= 360, "rare delay stays in authored range")
timers[2].Run()
check(announcements == 2 and #spawned == 4, "rare refill creates and announces one replacement")
spawned[4].Parent = storage
spawned[4].AncestryChanged:Fire()
check(spawned[4].Destroyed and #timers == 3, "reparented stock retires once")
cleanRare()
check(timers[3].Cancelled, "marker cleanup cancels pending rare refill")
check(not attachments.IngredientSpawn(marker("Invalid", 10)), "invalid marker cannot spawn")

-- Compare the working marker with Grapes using the real definition and model lookup.
local grapeTemplate = instance("Model")
grapeTemplate.Name, grapeTemplate.Parent = "Grapes", templates
local fruit = instance("Part")
fruit.Name, fruit.Parent = "GrapeFruit", grapeTemplate
local beforeGrapes = #spawned
local cleanGrapes = attachments.IngredientSpawn(marker("Grapes", 5))
check(cleanGrapes and #spawned == beforeGrapes + 1, "Grapes marker passes definition validation")
local grapes = spawned[#spawned]
check(grapes:IsA("Model") and grapes:FindFirstChild("GrapeFruit"), "Grapes station clones authored template")
check(ingredients.GetRecord(grapes).Id == "Grapes", "Grapes stock is registered")
grapes:Destroy()
check(timers[#timers].Seconds == 5, "Grapes uses its configured five-second cooldown")
timers[#timers].Run()
check(#spawned == beforeGrapes + 2 and spawned[#spawned].Name == "Grapes", "Grapes refills once")
cleanGrapes()
check(spawned[#spawned].Destroyed, "Grapes cleanup removes stock")

local announceChunk = assert(loadstring(sources.AnnouncedIngredientSpawn))
local emittedCallback
setfenv(
    announceChunk,
    setmetatable({
        script = { Parent = parent },
        require = function(name)
            assert(name == "IngredientSpawn")
            return {
                Bind = function(_, tag, callback)
                    check(tag == "AnnouncedIngredientSpawn", "rare adapter binds only rare tag")
                    emittedCallback = callback
                end,
            }
        end,
    }, { __index = env })
)
local announced = announceChunk()
announced.Init(deps)
announced.Init(deps)
rare:SetAttribute("LocationName", "Rainbow Cloud")
emittedCallback(rare, "GoldenApple")
local remote = shared.Events:FindFirstChild("RareIngredientSpawned")
local payload = presentation[#presentation].Moment
check(
    remote:IsA("RemoteEvent") and payload.Type == "RareIngredientSpawned",
    "rare adapter broadcasts presentation remote"
)
check(
    payload.IngredientId == "GoldenApple"
        and payload.DisplayName == "Golden Apple"
        and payload.LocationName == "Rainbow Cloud",
    "rare payload uses server definition and authored location"
)

local market = loadModule("MarketService")
market.Init(deps)
local pedestal = marker("Strawberry", 17)
market.Register(pedestal)
market.Step()
check(pedestal:GetAttribute("StockIngredientId") == "Strawberry", "market uses explicit ingredient")
check(
    market.Claim(player, pedestal) and inventory.GetHeldIngredientId(player) == "Strawberry",
    "market claim visibly carries"
)
check(not market.Claim(player, pedestal), "duplicate market claim rejected")
now += 16
market.Step()
check(pedestal:GetAttribute("StockIngredientId") == nil, "market respects individual cooldown")
now += 1
market.Step()
check(pedestal:GetAttribute("StockIngredientId") == "Strawberry", "market refills same explicit ingredient")
market.Unregister(pedestal)
check(not market.Claim(player, pedestal), "unregistered market cannot claim")
local plot = instance("Model")
plot.Parent = workspaceFake
local stash = instance("Model")
stash.Parent = plot
local slot = instance("Part")
slot.Parent = stash
slot:SetAttribute("SlotIndex", 3)
deps.TycoonService.GetPlot = function()
    return plot
end
deps.TycoonService.GetFixtures = function()
    return { stash }
end
check(inventory.Deposit(player, "Strawberry", 3), "held multipart fruit deposits into stash")
check(
    inventory.GetHeldIngredientId(player) == nil and inventory.GetSnapshot(player).Stash[3].Count == 1,
    "stash stores one ID/count and clears hands"
)
check(inventory.Withdraw(player, 3), "stash withdrawal equips authored model visual")
local restored = inventory.ThrowHeld(player)
check(
    restored:IsA("Model") and restored:FindFirstChild("Fruit").Size.Y == 3,
    "stash withdrawal and throw restore authored model size"
)
print("PASS: " .. count .. " ingredient world assertions.")
