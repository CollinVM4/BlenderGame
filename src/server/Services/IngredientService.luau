--!strict
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Constants.Ingredients)
local Economy = require(Shared.Constants.Economy)
local WorldUtil = require(script.Parent.WorldUtil)
local IngredientService = {}
-- Tags/attributes are presentation metadata, never proof of ownership or validity.
local records: { [Instance]: { Id: string, Owner: Player?, Claimable: boolean } } = {}

function IngredientService.GetDefinition(id: string)
    return (Definitions :: any)[id]
end
function IngredientService.CreateVisual(id: string): Instance?
    local definition = IngredientService.GetDefinition(id)
    if not definition then
        return nil
    end
    local templates = ServerStorage:FindFirstChild("Ingredients")
    local template = templates and templates:FindFirstChild(id)
    local object: Instance
    if template and (template:IsA("Model") or template:IsA("BasePart")) and WorldUtil.Part(template) then
        object = template:Clone()
    else
        local part = Instance.new("Part")
        part.Size = Vector3.new(1.5, 1.5, 1.5)
        part.Color = definition.BlendColor
        object = part
    end
    -- Templates are geometry, not live components. Register only the new world
    -- root after its private record exists; cloned tags must not bind early.
    local descendants = object:GetDescendants()
    table.insert(descendants, object)
    for _, child in descendants do
        for _, tag in CollectionService:GetTags(child) do
            CollectionService:RemoveTag(child, tag)
        end
        if child:IsA("ProximityPrompt") or child:IsA("ClickDetector") or child:IsA("LuaSourceContainer") then
            child:Destroy()
        end
    end
    return object
end
function IngredientService.Spawn(id: string, at: CFrame, owner: Player?, claimable: boolean?): Instance?
    local object = IngredientService.CreateVisual(id)
    if not object then
        return nil
    end
    object.Name = id
    object:SetAttribute("IngredientId", id)
    object:SetAttribute("WorldItemId", HttpService:GenerateGUID(false))
    object:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
    -- An explicit pivot root avoids choosing an arbitrary leaf/stem/mesh. It also
    -- keeps a no-PrimaryPart model's authored pivot unchanged when made physical.
    if object:IsA("Model") and not object.PrimaryPart then
        local root = Instance.new("Part")
        root.Name = "IngredientRoot"
        root.Size = Vector3.new(0.1, 0.1, 0.1)
        root.Transparency = 1
        root.CanCollide = false
        root.CanTouch = false
        root.Massless = true
        root.CFrame = object:GetPivot()
        root.Parent = object
        object.PrimaryPart = root
    end
    local physical = object :: any
    physical:PivotTo(at)
    local root = WorldUtil.Part(object)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanQuery = true
            if root and part ~= root then
                local weld = Instance.new("WeldConstraint")
                weld.Name = "IngredientAssembly"
                weld.Part0 = root
                weld.Part1 = part
                weld.Parent = part
            end
        end
    end
    object.Parent = workspace
    if root and root:CanSetNetworkOwnership() then
        root:SetNetworkOwner(nil)
    end
    records[object] = { Id = id, Owner = owner, Claimable = claimable ~= false }
    object.Destroying:Connect(function()
        records[object] = nil
    end)
    CollectionService:AddTag(object, "IngredientWorldItem")
    Debris:AddItem(object, Economy.WorldItemLifetime)
    return object
end
function IngredientService.Resolve(hit: Instance): Instance?
    local current: Instance? = hit
    while current and current ~= workspace do
        if records[current] then
            return current
        end
        current = current.Parent
    end
    return nil
end
function IngredientService.GetRecord(object: Instance): { Id: string, Owner: Player?, Claimable: boolean }?
    local record = records[object]
    if not record or not object:IsDescendantOf(workspace) then
        return nil
    end
    return table.clone(record)
end
function IngredientService.Consume(object: Instance): string?
    local record = IngredientService.GetRecord(object)
    if not record then
        return nil
    end
    records[object] = nil
    object:Destroy()
    return record.Id
end
function IngredientService.RemovePlayer(player: Player)
    local remove = {}
    for object, record in records do
        if record.Owner == player then
            table.insert(remove, object)
        end
    end
    for _, object in remove do
        IngredientService.Consume(object)
    end
end
return require(script.Parent.StudioServices).Wrap("IngredientService", IngredientService)
