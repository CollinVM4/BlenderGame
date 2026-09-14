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
    check(id == "GoldenTomato", "rare announcement uses explicitly configured identity")
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
local rare = marker("GoldenTomato", 300)
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
                    component.Bind(spawnDeps, tag, callback)
                end,
            }
        end,
    }, { __index = env })
)
local announced = announceChunk()
announced.Init(deps)
announced.Init(deps)
rare:SetAttribute("LocationName", "Rainbow Cloud")
emittedCallback(rare, "GoldenTomato")
local remote = shared.Events:FindFirstChild("RareIngredientSpawned")
local payload = presentation[#presentation].Moment
check(
    remote:IsA("RemoteEvent") and payload.Type == "RareIngredientSpawned",
    "rare adapter broadcasts presentation remote"
)
check(
    payload.IngredientId == "GoldenTomato"
        and payload.DisplayName == "Golden Tomato"
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
-- Exercise reconstruction from a template with no authored PrimaryPart.
template.Clone = clone
check(inventory.Withdraw(player, 3), "stash withdrawal equips authored model visual")
local heldTool = character:FindFirstChildOfClass("Tool")
local heldModel = heldTool:FindFirstChildOfClass("Model")
check(heldModel.PrimaryPart and heldModel.PrimaryPart.Name == "IngredientRoot", "stash carry resolves a physical root")
for _, name in { "Leaf", "Fruit" } do
    local child = heldModel:FindFirstChild(name)
    local weld = child:FindFirstChild("IngredientAssembly")
    check(weld and weld.Part0 == heldModel.PrimaryPart and weld.Part1 == child, "stash child welded to shared root")
    check(
        not child.Anchored and not child.CanTouch and not child.CanCollide,
        "all carried children are passive visuals"
    )
    check(not ingredients.Resolve(child), "carried child is not a registered world ingredient")
end
check(inventory.GetCarryCount(player) == 1, "multipart stash reconstruction reserves one ingredient")
local restored = inventory.ThrowHeld(player)
check(
    restored:IsA("Model") and restored:FindFirstChild("Fruit").Size.Y == 3,
    "stash withdrawal and throw restore authored model size"
)
-- The real scanner must attempt each registered object once even on rejection.
local heartbeat = signal()
local scanInput = instance("Part")
local scanModel = spawn()
local scanPart = ingredients.Spawn("Banana", frame())
scanInput.Overlaps =
    { scanModel:FindFirstChild("Leaf"), scanModel:FindFirstChild("Fruit"), scanModel.PrimaryPart, scanPart }
local attempts = {}
local inputChunk = assert(loadstring(sources.BlenderInputComponent))
setfenv(
    inputChunk,
    setmetatable({
        script = { Parent = { Parent = { Services = parent } } },
        game = {
            GetService = function()
                return { Heartbeat = heartbeat }
            end,
        },
        require = function()
            return {
                BindTag = function(_, attach)
                    attach(scanInput)
                end,
            }
        end,
    }, { __index = env })
)
inputChunk().Init({
    IngredientService = ingredients,
    TycoonService = {
        GetOwner = function()
            return player
        end,
    },
    BlendService = {
        TryInput = function(_, object)
            attempts[object] = (attempts[object] or 0) + 1
            return false
        end,
    },
})
heartbeat:Fire(0.1)
check(attempts[scanModel] == 1, "rejected multipart ingredient attempted once per scan")
check(attempts[scanPart] == 1, "single part attempted independently once")
heartbeat:Fire(0.1)
check(attempts[scanModel] == 2 and attempts[scanPart] == 2, "rejected ingredients retry on next scan")
check(ingredients.GetRecord(scanModel) ~= nil, "rejected scan preserves whole model")
local children = scanModel:GetDescendants()
check(not ingredients.Consume(scanModel:FindFirstChild("Leaf")), "child cannot independently be consumed")
check(ingredients.Consume(scanModel) == "Strawberry", "registered model consumes as one ingredient")
for _, child in children do
    check(child.Destroyed, "whole ingredient consumption leaves no child behind")
end
local singleVisual = ingredients.CreateVisual("Banana")
check(singleVisual:IsA("BasePart") and #singleVisual:GetDescendants() == 0, "single visual has no added root or weld")
-- Frozen stock uses the real spawn, authorization, carry and refill transaction.
local pickupChunk = assert(loadstring(sources.IngredientPickupComponent))
setfenv(
    pickupChunk,
    setmetatable({
        script = { Parent = { Parent = { Services = parent } } },
        require = function()
            return world
        end,
    }, { __index = env })
)
pickupChunk().Init(deps)
local appleTemplate = instance("MeshPart")
appleTemplate.Name, appleTemplate.Parent = "Apple", templates
appleTemplate.Anchored, appleTemplate.CanCollide, appleTemplate.CanTouch = false, true, false
appleTemplate.Massless, appleTemplate.CustomPhysicalProperties = false, { Density = 2 }
local function checkParts(object, anchored, message)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            check(part.Anchored == anchored, message)
        end
    end
end
for _, setting in { "missing", false, true } do
    local station = marker("Apple", 5)
    if setting ~= "missing" then
        station:SetAttribute("FreezeSpawnedItem", setting)
    end
    local clean = attachments.IngredientSpawn(station)
    local apple = spawned[#spawned]
    check(apple:IsA("MeshPart"), "single MeshPart template supported")
    checkParts(apple, setting == true, "spawner boolean controls anchoring")
    check(apple:GetAttribute("FrozenUntilPickup") == (if setting == true then true else nil), "outer freeze metadata")
    check(apple.CanCollide and not apple.CanTouch and apple.CanQuery, "freeze preserves normal collision/touch/query")
    check(
        not apple.Massless and apple.CustomPhysicalProperties == appleTemplate.CustomPhysicalProperties,
        "mass unchanged"
    )
    check(
        ingredients.GetRecord(apple).Claimable and services.CollectionService:HasTag(apple, "IngredientWorldItem"),
        "pickup eligibility retained"
    )
    clean()
end
check(
    not appleTemplate.Anchored and appleTemplate:GetAttribute("FrozenUntilPickup") == nil,
    "source MeshPart untouched"
)

for _, id in { "Apple", "Strawberry" } do
    local station = marker(id, 5)
    station:SetAttribute("FreezeSpawnedItem", true)
    local clean = attachments.IngredientSpawn(station)
    local frozen = spawned[#spawned]
    local cleanPrompt = attachments.IngredientWorldItem(frozen)
    local pickupPrompt = cache.WorldUtil.Part(frozen):FindFirstChild("CarryPrompt")
    check(
        pickupPrompt and pickupPrompt:GetAttribute("IngredientPickupPrompt") == true,
        "frozen stock retains custom pickup prompt"
    )
    checkParts(frozen, true, "all runtime parts frozen including generated pivot root")
    for _, child in frozen:GetDescendants() do
        if child:IsA("BasePart") then
            check(ingredients.Resolve(child) == frozen, "frozen child resolves registered outer object")
        end
    end
    player.Near = false
    pickupPrompt.Triggered:Fire(player)
    check(
        frozen:GetAttribute("FrozenUntilPickup") == true and inventory.GetCarryCount(player) == 0,
        "failed prompt pickup stays frozen"
    )
    check(not inventory.CarryWorldItem(player, frozen), "distant frozen pickup rejected")
    player.Near = true
    humanoid.Health = 0
    check(not inventory.CarryWorldItem(player, frozen), "dead frozen pickup rejected")
    humanoid.Health = 100
    backpack.Parent = nil
    check(not inventory.CarryWorldItem(player, frozen), "missing backpack rejected")
    backpack.Parent = player
    setup(inventory.CarryWorldItem(player, ingredients.Spawn("Banana", frame())), "fill carry capacity")
    check(not inventory.CarryWorldItem(player, frozen), "full carry rejects frozen pickup")
    inventory.ClearHeld(player)
    local addUnit = inventory.AddUnit
    inventory.AddUnit = function()
        return false
    end
    check(not inventory.CarryWorldItem(player, frozen), "failed unit reservation leaves stock")
    inventory.AddUnit = addUnit
    checkParts(frozen, true, "all failed validations preserve anchors")
    check(
        frozen:GetAttribute("FrozenUntilPickup") == true and ingredients.GetRecord(frozen) ~= nil,
        "failed claim preserves frozen identity"
    )
    blend.Reset(player)
    input.Overlaps = { cache.WorldUtil.Part(frozen) }
    check(not blend.TryInput(player, frozen, input), "incidental blender overlap rejects frozen stock")
    checkParts(frozen, true, "blender overlap leaves stock anchored")
    pickupPrompt.Triggered:Fire(player)
    check(
        inventory.GetHeldIngredientId(player) == id and ingredients.GetRecord(frozen) == nil,
        "successful prompt pickup transfers ownership without leaving world stock"
    )
    cleanPrompt()
    local tool = character:FindFirstChildOfClass("Tool")
    local visual = tool:FindFirstChild(id)
    check(visual and visual:GetAttribute("FrozenUntilPickup") == nil, "carry clone clears frozen metadata")
    checkParts(visual, false, "carry visual fully unanchored")
    check(tool:FindFirstChild("CarryAnchor"):FindFirstChild("OverheadCarry") ~= nil, "existing carry weld takes over")
    timers[#timers].Run()
    local replacement = spawned[#spawned]
    check(
        replacement ~= frozen and replacement:GetAttribute("FrozenUntilPickup") == true,
        "same station refills frozen"
    )
    checkParts(replacement, true, "replacement parts anchored")
    station:SetAttribute("FreezeSpawnedItem", false)
    replacement:Destroy()
    timers[#timers].Run()
    checkParts(spawned[#spawned], false, "refill re-reads current spawner preference")
    clean()
    local thrownFrozen = inventory.ThrowHeld(player)
    checkParts(thrownFrozen, false, "throw after frozen pickup restores physics")
    check(
        thrownFrozen:GetAttribute("FrozenUntilPickup") == nil
            and cache.WorldUtil.Part(thrownFrozen).AssemblyLinearVelocity.Y == 18,
        "normal throw velocity and metadata"
    )
    check(inventory.CarryWorldItem(player, thrownFrozen), "thrown ingredient remains pickable")
    local droppedFrozen = inventory.DropHeld(player)
    checkParts(droppedFrozen, false, "drop after frozen pickup restores physics")
    input.Overlaps = { cache.WorldUtil.Part(droppedFrozen) }
    check(blend.TryInput(player, droppedFrozen, input), "released frozen ingredient ingests normally")
    -- One frozen-origin stash flow is enough: multipart reconstruction is already
    -- exercised above, and generic transfer validation belongs to stash tests.
    if id == "Apple" then
        local stashItem = ingredients.Spawn(id, frame(), nil, true, { FreezeUntilPickup = true })
        setup(inventory.CarryWorldItem(player, stashItem), "carry frozen-origin stash fixture")
        check(inventory.Deposit(player, id, 3) and inventory.Withdraw(player, 3), "frozen-origin stash round-trip")
        inventory.ClearHeld(player)
    end
end
check(not appleTemplate.Anchored and not template.PrimaryPart, "templates never acquire runtime anchors or root")
for _, part in template:GetDescendants() do
    check(not part.Anchored, "multipart template never anchored")
end
local frozenRare = marker("GoldenTomato", 5)
frozenRare:SetAttribute("FreezeSpawnedItem", true)
local cleanFrozenRare = attachments.AnnouncedIngredientSpawn(frozenRare)
check(spawned[#spawned]:GetAttribute("FrozenUntilPickup") == true, "real announced adapter uses freeze option")
checkParts(spawned[#spawned], true, "announced stock anchored")
cleanFrozenRare()
print("PASS: " .. count .. " ingredient world assertions.")
