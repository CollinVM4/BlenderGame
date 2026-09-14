--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Ingredients = require(Shared.Constants.Ingredients)
local SmoothieItem = {}

function SmoothieItem.Valid(data: Types.SmoothieData): boolean
    if
        type(data) ~= "table"
        or type(data.BlendId) ~= "string"
        or data.BlendId == ""
        or type(data.Ingredients) ~= "table"
    then
        return false
    end
    local count = 0
    for index, id in data.Ingredients do
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 3 or not Ingredients[id] then
            return false
        end
        count += 1
    end
    return count == 3
end

function SmoothieItem.Copy(data: Types.SmoothieData): Types.SmoothieData
    return { BlendId = data.BlendId, Ingredients = table.clone(data.Ingredients) }
end

-- Compatibility result for existing customer/film consumers. Inventory only stores IDs.
function SmoothieItem.Result(data: Types.SmoothieData): Types.Smoothie
    local sum = Vector3.zero
    local tags = {}
    for _, id in data.Ingredients do
        local definition = Ingredients[id]
        local color = definition.BlendColor
        sum += Vector3.new(color.R, color.G, color.B)
        for _, tag in definition.Tags do
            if not table.find(tags, tag) then
                table.insert(tags, tag)
            end
        end
    end
    sum /= 3
    return {
        BlendId = data.BlendId,
        Ingredients = table.clone(data.Ingredients),
        Tags = tags,
        Color = Color3.new(sum.X, sum.Y, sum.Z),
        Discovery = nil,
    }
end

return SmoothieItem
