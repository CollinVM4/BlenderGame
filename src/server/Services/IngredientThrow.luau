--!strict
local Debris = game:GetService("Debris")
local IngredientThrow = {}
local OFFSET = CFrame.new(0, 2, -5)
local GRACE_SECONDS = 0.2

-- A conceptual attachment on HRP: independent of head, body and carry geometry.
function IngredientThrow.Origin(root: BasePart): CFrame
    return root.CFrame * OFFSET
end

-- Pairwise exclusions preserve collisions with the world, blender and other players.
-- Install before publishing the object to Workspace; no global collision groups change.
function IngredientThrow.IgnoreCharacter(object: Instance, character: Model)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            for _, body in character:GetDescendants() do
                if body:IsA("BasePart") then
                    local exclusion = Instance.new("NoCollisionConstraint")
                    exclusion.Part0 = part
                    exclusion.Part1 = body
                    exclusion.Parent = part
                    Debris:AddItem(exclusion, GRACE_SECONDS)
                end
            end
        end
    end
end

return IngredientThrow
