--!strict
-- Instance identity never changes the shared ingredient definition.
local IngredientName = {}

function IngredientName.Resolve(id: string, fallback: string, sourceUserId: any, sourceDisplayName: any): string
    if
        id == "PlayerHead"
        and typeof(sourceUserId) == "number"
        and sourceUserId > 0
        and typeof(sourceDisplayName) == "string"
        and string.find(sourceDisplayName, "%S")
    then
        return sourceDisplayName .. "'s Head"
    end
    return fallback
end

return IngredientName
