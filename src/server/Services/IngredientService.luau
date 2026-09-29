--!strict
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Constants.Ingredients)
local Economy = require(Shared.Constants.Economy)
local WorldUtil = require(script.Parent.WorldUtil)
local Geometry = require(script.Parent.IngredientGeometry)
local IngredientService = {}
-- Tags/attributes are presentation metadata, never proof of ownership or validity.
local records: { [Instance]: { Id: string, Owner: Player?, Claimable: boolean } } = {}

function IngredientService.GetDefinition(id: string)
    return (Definitions :: any)[id]
end
function IngredientService.CreateVisual(id: string): Instance?
    return Geometry.CreateVisual(id, IngredientService.GetDefinition(id))
end
function IngredientService.Spawn(
    id: string,
    at: CFrame,
    owner: Player?,
    claimable: boolean?,
    options: { FreezeUntilPickup: boolean?, BeforePublish: ((Instance) -> ())? }?
): Instance?
    local object = IngredientService.CreateVisual(id)
    if not object then
        return nil
    end
    object.Name = id
    object:SetAttribute("IngredientId", id)
    object:SetAttribute("WorldItemId", HttpService:GenerateGUID(false))
    object:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
    local frozen = options ~= nil and options.FreezeUntilPickup == true
    object:SetAttribute("FrozenUntilPickup", if frozen then true else nil)
    -- Preparation has succeeded, but no world physics or pickup listeners can see it yet.
    if options and options.BeforePublish then
        options.BeforePublish(object)
    end
    local physical = object :: any
    physical:PivotTo(at)
    local root = WorldUtil.Part(object)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            part.Anchored = frozen
            part.CanQuery = true
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
-- Pickup callers set pickedUp only after inventory authorization/reservation succeeds.
-- Other removal paths (including cleanup) never release frozen physics.
function IngredientService.Consume(object: Instance, pickedUp: boolean?): string?
    local record = IngredientService.GetRecord(object)
    if not record then
        return nil
    end
    records[object] = nil
    if pickedUp and object:GetAttribute("FrozenUntilPickup") == true then
        local parts = object:GetDescendants()
        table.insert(parts, object)
        for _, part in parts do
            if part:IsA("BasePart") then
                part.Anchored = false
            end
        end
        object:SetAttribute("FrozenUntilPickup", nil)
    end
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
