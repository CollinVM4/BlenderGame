--!strict
local CollectionService = game:GetService("CollectionService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local SmoothieItem = require(script.Parent.SmoothieItem)
local Geometry = require(script.Parent.SmoothieGeometry)
local Service = {}
type Record = { Data: Types.SmoothieData, Claiming: boolean }
local records: { [Instance]: Record } = {}

function Service.GetData(object: Instance): Types.SmoothieData?
    local record = records[object]
    return if record
            and not record.Claiming
            and object:IsDescendantOf(workspace)
        then SmoothieItem.Copy(record.Data)
        else nil
end

function Service.Spawn(data: Types.SmoothieData, at: CFrame): Model?
    if not SmoothieItem.Valid(data) then
        return nil
    end
    local object = Geometry.CreateVisual(data)
    if not object then
        return nil
    end
    object.Name = "SmoothieWorldItem"
    object:SetAttribute("BlendId", data.BlendId)
    for index = 1, 3 do
        object:SetAttribute("IngredientId" .. index, data.Ingredients[index])
    end
    object:PivotTo(at)
    local root = object.PrimaryPart :: BasePart
    root.CanCollide, root.CanQuery, root.Massless = true, true, false
    records[object] = { Data = SmoothieItem.Copy(data), Claiming = false }
    object.Destroying:Connect(function()
        records[object] = nil
    end)
    object.Parent = workspace
    if root:CanSetNetworkOwnership() then
        root:SetNetworkOwner(nil)
    end
    CollectionService:AddTag(object, "SmoothieWorldItem")
    return object
end

-- Server-only transaction. The callback must not yield. Lock before inventory
-- signals can reenter; failure retains the same object and authoritative data.
function Service.Claim(object: Instance, receive: (Types.SmoothieData) -> boolean): boolean
    local data = Service.GetData(object)
    if not data then
        return false
    end
    local record = records[object]
    record.Claiming = true
    if not receive(data) then
        record.Claiming = false
        return false
    end
    records[object] = nil
    object:Destroy()
    return true
end
return Service
