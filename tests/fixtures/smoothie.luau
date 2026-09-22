-- Real inventory, geometry, blend and customer modules; mocked Roblox engine only.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
local guid = 0
services.HttpService.GenerateGUID = function()
    guid += 1
    return "blend-" .. guid
end
local function part(name, parentObject, height)
    local object = instance("Part")
    object.Name, object.Parent = name, parentObject
    object.Size = vec(1, height or 1, 1)
    object.Transparency = 0
    return object
end
-- A multipart Tool fixture, not a claim about the authored Studio asset.
local template = instance("Tool")
template.Name, template.Parent = "Smoothie", storage
local handle = part("Handle", template, 2)
handle.Anchored = true
local nested = instance("Model")
nested.Name, nested.Parent = "Details", template
local straw = part("Straw", nested, 3)
straw.Anchored = true
local oldWeld = instance("WeldConstraint")
oldWeld.Name, oldWeld.Parent = "OldAssembly", handle
local prompt = instance("ProximityPrompt")
prompt.Parent = straw

local smoothieItem = loadModule("SmoothieItem")
local geometry = loadModule("SmoothieGeometry")
local inventory = loadModule("InventoryService")
local blend = loadModule("BlendService")
local ingredients = loadModule("IngredientService")
local dataService = loadModule("PlayerDataService")
local customer = loadModule("CustomerService")
local fixtures, references, capacities = {}, {}, {}
local dependency = {
    SmoothieWorldItemService = loadModule("SmoothieWorldItemService"),
    InventoryService = inventory,
    BlendService = blend,
    IngredientService = ingredients,
    PlayerDataService = {
        GetUpgrade = function(player, name)
            return if name == "CarryCapacity" then capacities[player] else 1
        end,
        IncrementStat = function() end,
        AddCash = dataService.AddCash,
        GetCash = dataService.GetCash,
    },
    TycoonService = {
        GetPlot = function(player)
            return fixtures[player]
        end,
        GetFixtures = function(plot)
            return { plot }
        end,
        GetOwner = function(object)
            return object.Owner
        end,
        GetReference = function(player, name)
            return references[player][name]
        end,
    },
}
inventory.Init(dependency)
blend.Init(dependency)
local completedServes = 0
customer.Init(dependency, function()
    completedServes += 1
end, function()
    return true
end)
local function player(capacity)
    local p = instance("Player")
    p.Name, p.UserId, p.Near = "SmoothieTester", #allInstances, true
    p.Character = instance("Model")
    p.CharacterRemoving = signal()
    part("HumanoidRootPart", p.Character, 2)
    local head = part("Head", p.Character, 1)
    head.CFrame = frame(0, 2, 0)
    local humanoid = instance("Humanoid")
    humanoid.Parent, humanoid.Health, humanoid.Died = p.Character, 100, signal()
    function humanoid:EquipTool(tool)
        for _, current in p.Character:GetChildren() do
            if current:IsA("Tool") and current ~= tool then
                current.Parent = p:FindFirstChildOfClass("Backpack")
                current.Unequipped:Fire()
            end
        end
        tool.Parent = p.Character
        tool.Equipped:Fire()
    end
    local backpack = instance("Backpack")
    backpack.Parent = p
    capacities[p] = capacity or 3
    fixtures[p] = instance("Model")
    fixtures[p].Owner = p
    for index = 1, 5 do
        part("Slot" .. index, fixtures[p]):SetAttribute("SlotIndex", index)
    end
    references[p] = {}
    for _, name in
        {
            "BlenderInput",
            "TurbineWheel",
            "CustomerSpawn",
            "CustomerCounter",
            "CustomerWait1",
            "CustomerWait2",
            "CustomerExit",
        }
    do
        local object = part(name)
        object.Owner = p
        references[p][name] = object
    end
    inventory.AddPlayer(p)
    dataService.AddPlayer(p)
    blend.Reset(p)
    return p, humanoid
end
local function smoothie(id, ids)
    return { BlendId = id, Ingredients = ids or { "Strawberry", "Banana", "Strawberry" } }
end
local function grant(p, id)
    setup(inventory.GrantSmoothie(p, smoothie(id)), "grant " .. id)
end
local function carry(p, id)
    setup(inventory.CarryWorldItem(p, ingredients.Spawn(id or "Banana", frame(), nil, true)), "ingredient pickup")
end
local function press(p, index, owner)
    now += 0.1
    return inventory.InteractStash(p, index or 3, owner or p)
end
local function slot(p, index)
    return inventory.GetSnapshot(p).Stash[index or 3]
end
local function tool(p)
    return p.Character:FindFirstChildOfClass("Tool")
end
local function anchors(t)
    local result = {}
    for _, child in t:GetChildren() do
        if child.Name == "CarryAnchor" then
            table.insert(result, child:FindFirstChild("OverheadCarry"))
        end
    end
    return result
end

local function complete(p)
    blend.Reset(p)
    local input = references[p].BlenderInput
    for _, id in { "Strawberry", "Banana", "Strawberry" } do
        local object = ingredients.Spawn(id, frame(), p, true)
        input.Overlaps = { object }
        setup(blend.TryInput(p, object, input), "batch accepts source ingredient")
    end
    setup(blend.AddProgress(p, references[p].TurbineWheel, loadModule("Economy").RequiredProgress), "batch completes")
    return blend.GetSnapshot(p).Result.BlendId
end
