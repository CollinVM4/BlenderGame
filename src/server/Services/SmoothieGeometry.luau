--!strict
-- Cosmetic geometry only. The source Tool never becomes an inventory authority.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local SmoothieItem = require(script.Parent.SmoothieItem)
local Geometry = {}

function Geometry.CreateVisual(data: Types.SmoothieData): Model?
    local template = ServerStorage:FindFirstChild("Smoothie")
    if not template or not template:IsA("Tool") or not template.Archivable then
        return nil
    end
    local clone = template:Clone()
    local handle = clone:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        clone:Destroy()
        return nil
    end
    -- Keep nested geometry, meshes and appearance, but rebuild all assembly joints.
    -- No scripts, prompts, live component tags or authored external welds escape.
    for _, child in clone:GetDescendants() do
        for _, tag in CollectionService:GetTags(child) do
            CollectionService:RemoveTag(child, tag)
        end
        if
            child:IsA("LuaSourceContainer")
            or child:IsA("ProximityPrompt")
            or child:IsA("ClickDetector")
            or child:IsA("JointInstance")
            or child:IsA("Constraint")
            or child:IsA("WeldConstraint")
        then
            child:Destroy()
        elseif child:IsA("BasePart") then
            child.Anchored = false
            child.CanCollide = false
            child.CanTouch = false
            child.CanQuery = false
            child.Massless = true
        end
    end
    local model = Instance.new("Model")
    model.Name = "SmoothieVisual"
    for _, child in clone:GetChildren() do
        child.Parent = model
    end
    clone:Destroy()
    handle.Name = "SmoothieRoot" -- avoid a competing Tool RightGrip
    handle.Color = SmoothieItem.Result(data).Color
    model.PrimaryPart = handle
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") and part ~= handle then
            local weld = Instance.new("WeldConstraint")
            weld.Name = "SmoothieAssembly"
            weld.Part0, weld.Part1 = handle, part
            weld.Parent = handle
        end
    end
    return model
end

return Geometry
