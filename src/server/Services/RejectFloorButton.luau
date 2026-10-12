--!strict
local FloorButton = {}

-- A downward ground query verifies actual support, rather than counting limb
-- touches from someone brushing past the plate or standing beside it.
local function standing(actor: Player, button: BasePart): boolean
    local character = actor.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
        return false
    end
    if root.AssemblyLinearVelocity.Y > 2 then
        return false
    end
    local leg = character and character:FindFirstChild("Left Leg")
    local legHeight = if leg and leg:IsA("BasePart") then leg.Size.Y else 0
    local distance = root.Size.Y / 2 + humanoid.HipHeight + legHeight + 0.5
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character :: Model }
    params.RespectCanCollide = true
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params)
    return hit ~= nil and hit.Instance == button
end

-- Retained support helper for LockBase. The legacy REJECT UI/action is retired.
FloorButton.IsStanding = standing

return FloorButton
