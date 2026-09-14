local make = instance
instance = function(class)
    local object = make(class)
    object.Transparency = 0
    object.CFrame = env.CFrame.new()
    local properties, attributes = {}, {}
    function object:GetPropertyChangedSignal(name)
        properties[name] = properties[name] or signal()
        return properties[name]
    end
    function object:GetAttributeChangedSignal(name)
        attributes[name] = attributes[name] or signal()
        return attributes[name]
    end
    function object:GetAttributes()
        return table.clone(self.Attributes)
    end
    function object:WaitForChild(name)
        return assert(self:FindFirstChild(name))
    end
    object.Changed, object.DescendantAdded, object.DescendantRemoving = signal(), signal(), signal()
    local clone = object.Clone
    function object:Clone()
        local copy = clone(self)
        if copy then
            copy.Transparency = self.Transparency
            for _, tag in services.CollectionService:GetTags(self) do
                services.CollectionService:AddTag(copy, tag)
            end
        end
        return copy
    end
    return object
end
env.Instance.new = instance
env.Enum.Material = { Neon = "Neon" }
env._G = {}
env.require = loadModule
workspaceFake = instance("Folder")
workspaceFake.Name = "Workspace"
env.workspace = workspaceFake
storage = instance("Folder")
services.ServerStorage = storage
local run = instance("Folder")
local edit = true
function run:IsStudio()
    return studio
end
function run:IsEdit()
    return edit
end
services.RunService = run
local added, removed = {}, {}
local collection = services.CollectionService
function collection:GetInstanceAddedSignal(tag)
    added[tag] = added[tag] or signal()
    return added[tag]
end
function collection:GetInstanceRemovedSignal(tag)
    removed[tag] = removed[tag] or signal()
    return removed[tag]
end
local spawnChunk = assert(loadstring(sources.IngredientSpawn))
local attach
cache.WorldUtil.BindTag = function(_, callback)
    attach = callback
end
setfenv(spawnChunk, setmetatable({ script = { Parent = { Parent = { Services = parent } } } }, { __index = env }))
local spawn = spawnChunk()
cache.IngredientSpawn = spawn
services.ServerScriptService = {
    WaitForChild = function()
        return { Components = parent, Services = parent }
    end,
}
local utility = assert(loadstring(sources.IngredientSpawnPreview))
setfenv(utility, env)
studio = false
check(not pcall(utility), "production cannot start preview utility")
studio, edit = true, false
check(not pcall(utility), "Play cannot start preview utility")
edit = true
local warnings = {}
env.warn = function(message)
    table.insert(warnings, message)
end
local function flush()
    while #deferred > 0 do
        local work = table.clone(deferred)
        table.clear(deferred)
        for _, callback in work do
            callback()
        end
    end
end
local templates = instance("Folder")
templates.Name, templates.Parent = "Ingredients", storage
local apple = instance("MeshPart")
apple.Name, apple.Parent, apple.Size = "Apple", templates, vec(2, 3, 4)
apple:SetAttribute("WorldItemId", "authored-stale")
apple:SetAttribute("OwnerUserId", 99)
collection:AddTag(apple, "IngredientWorldItem")
for _, class in
    {
        "Script",
        "LocalScript",
        "ModuleScript",
        "ProximityPrompt",
        "ClickDetector",
        "DragDetector",
        "WeldConstraint",
        "ObjectValue",
    }
do
    instance(class).Parent = apple
end
local function marker(id, show)
    local result = instance("Part")
    result.Name, result.Parent, result.Size = "DuplicateName", workspaceFake, vec(4, 2, 4)
    result:SetAttribute("IngredientId", id)
    result:SetAttribute("ShowSpawnPreview", show)
    collection:AddTag(result, "IngredientSpawn")
    return result
end
local first, second = marker("Apple", true), marker("Apple", false)
local missing = marker("Apple", nil)
utility()
local function folder()
    return workspaceFake:FindFirstChild("_IngredientSpawnPreviews")
end
local function group(source)
    for _, child in folder():GetChildren() do
        if child:FindFirstChild("SourceMarker").Value == source then
            return child
        end
    end
    return nil
end
local function ghost(source)
    return group(source):FindFirstChild("Ghost")
end
check(
    #folder():GetChildren() == 1 and not group(second) and not group(missing),
    "missing/false preview attributes create no preview"
)
check(not folder().Archivable and folder():Clone() == nil, "preview container cannot be saved/cloned into play")
check(ghost(first):IsA("MeshPart") and ghost(first).Size.Y == 3, "authored mesh scale retained")
check(ghost(first).CFrame.Position.Y == 4, "exact top-face plus three offset")
-- Test runtime registration directly; the utility never loads this Studio bridge.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
local ingredients = loadModule("IngredientService")
check(not ingredients.GetRecord(ghost(first)), "ghost has no authoritative registration")
check(
    apple:GetAttribute("WorldItemId") == "authored-stale" and #apple:GetChildren() == 8,
    "template metadata and interactions untouched"
)
local function safe(object)
    local all = object:GetDescendants()
    table.insert(all, object)
    for _, child in all do
        check(#collection:GetTags(child) == 0, "preview carries no gameplay tags")
        check(
            child:GetAttribute("WorldItemId") == nil and child:GetAttribute("OwnerUserId") == nil,
            "preview carries no gameplay identity"
        )
        if child:IsA("BasePart") then
            check(
                child.Anchored and not child.CanCollide and not child.CanTouch and not child.CanQuery,
                "ghost physics disabled"
            )
            check(child.Transparency >= 0.5, "ghost is translucent")
        end
    end
end
safe(ghost(first))
check(#ghost(first):GetDescendants() == 0, "all scripts interactions and constraints removed")
local oldGhost = ghost(first)
first.CFrame = env.CFrame.new(10, 20, 30) * env.CFrame.Angles(math.rad(30), math.rad(90), 0)
first:GetPropertyChangedSignal("CFrame"):Fire()
local expected = spawn.GetSpawnCFrame(first)
check((ghost(first).CFrame.Position - expected.Position).Magnitude < 1e-6, "rotated marker uses local offset")
check((ghost(first).CFrame.LookVector - first.CFrame.LookVector).Magnitude < 1e-6, "preview orientation follows marker")
check(
    (group(first):FindFirstChild("ForwardMinusZ").CFrame.LookVector - first.CFrame.LookVector).Magnitude < 1e-6,
    "orientation arrow follows local forward"
)
for _, child in group(first):GetChildren() do
    if child.Name == "Arrowhead" then
        local tip = child.CFrame * env.CFrame.new(0, 0, -0.5)
        check(
            (tip.Position - (expected * env.CFrame.new(2, 0, -3)).Position).Magnitude < 0.01,
            "arrowhead converges on forward tip"
        )
    end
end
first.Size = vec(4, 8, 4)
first:GetPropertyChangedSignal("Size"):Fire()
check(ghost(first) == oldGhost, "dragging repositions without cloning again")
check(
    (ghost(first).CFrame.Position - (first.CFrame * env.CFrame.new(0, 7, 0)).Position).Magnitude < 1e-6,
    "size updates exact vertical offset"
)
local helper = spawn.GetSpawnCFrame
local helperCalls = 0
spawn.GetSpawnCFrame = function(m)
    helperCalls += 1
    return helper(m)
end
first:GetPropertyChangedSignal("CFrame"):Fire()
local runtimeAt
spawn.Init({
    IngredientService = {
        GetDefinition = ingredients.GetDefinition,
        Spawn = function(id, at)
            runtimeAt = at
            return ingredients.Spawn(id, at)
        end,
    },
})
local cleanRuntime = attach(first)
check(
    helperCalls == 2 and (runtimeAt.Position - ghost(first).CFrame.Position).Magnitude < 1e-6,
    "runtime and preview invoke same helper"
)
check(
    (runtimeAt.LookVector - ghost(first).CFrame.LookVector).Magnitude < 1e-6,
    "runtime and preview orientations match"
)
cleanRuntime()
second:SetAttribute("ShowSpawnPreview", true)
second:GetAttributeChangedSignal("ShowSpawnPreview"):Fire()
check(#folder():GetChildren() == 2 and group(first) ~= group(second), "duplicate names use marker identity")
second:SetAttribute("IngredientId", "Apple2")
second:GetAttributeChangedSignal("IngredientId"):Fire()
check(not group(second) and #warnings == 1, "invalid definition cleans old preview and warns")
second:GetPropertyChangedSignal("CFrame"):Fire()
env._G.IngredientSpawnPreview.Refresh()
check(#warnings == 1, "invalid ID warning does not spam")
second:SetAttribute("IngredientId", "Apple")
second:GetAttributeChangedSignal("IngredientId"):Fire()
local model = instance("Model")
model.Name, model.Parent, model.CFrame = "Strawberry", templates, env.CFrame.new(3, 8, 2)
for _, name in { "Fruit", "Leaf" } do
    local part = instance("Part")
    part.Name, part.Parent = name, model
    part.Transparency = if name == "Leaf" then 0.8 else 0
end
first:SetAttribute("IngredientId", "Strawberry")
first:GetAttributeChangedSignal("IngredientId"):Fire()
check(
    ghost(first):IsA("Model") and ghost(first).PrimaryPart.Name == "IngredientRoot",
    "model without PrimaryPart uses runtime generated pivot root"
)
check(
    ghost(first).PrimaryPart.Transparency == 1 and ghost(first):FindFirstChild("Leaf").Transparency == 0.8,
    "authored higher transparency preserved"
)
safe(ghost(first))
check(not model.PrimaryPart, "preview does not add template pivot root")
model.PrimaryPart = model:FindFirstChild("Fruit")
env._G.IngredientSpawnPreview.Refresh()
check(ghost(first).PrimaryPart.Name == "Fruit", "authored PrimaryPart used")
model.CFrame = env.CFrame.new(9, 9, 9)
model.Changed:Fire("WorldPivot")
flush()
check(
    ghost(first).CFrame.Position.Y == spawn.GetSpawnCFrame(first).Position.Y,
    "pivot edit rebuild uses runtime placement"
)
apple.Parent = nil
storage.DescendantRemoving:Fire(apple)
flush()
check(not group(second), "deleted template cleans preview")
apple.Parent = templates
storage.DescendantAdded:Fire(apple)
flush()
check(group(second) ~= nil, "replacement template recovers preview")
collection:RemoveTag(second, "IngredientSpawn")
removed.IngredientSpawn:Fire(second)
check(not group(second), "removed tag cleans preview")
first:SetAttribute("ShowSpawnPreview", false)
first:GetAttributeChangedSignal("ShowSpawnPreview"):Fire()
check(not group(first), "turning preview off cleans visual")
first:SetAttribute("ShowSpawnPreview", true)
first:GetAttributeChangedSignal("ShowSpawnPreview"):Fire()
first:Destroy()
check(not group(first), "marker deletion cleans visual")
local oldFolder = folder()
utility()
check(oldFolder.Destroyed, "rerun retires prior session and container")
edit = false
run:GetPropertyChangedSignal("RunState"):Fire()
check(not folder() and not env._G.IngredientSpawnPreview, "leaving Edit removes previews and disconnects session")
edit = true
utility()
folder():Destroy()
check(not env._G.IngredientSpawnPreview, "manual container deletion stops session")
print("PASS: " .. count .. " spawn preview assertions (mocked Studio boundary).")
