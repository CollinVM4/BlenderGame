--!strict
-- Geometry only: safe to require from the Edit-mode Command Bar; no registration.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local WorldUtil = require(script.Parent.WorldUtil)
local Geometry = {}
-- Item copies share an opaque key. When the final item/snapshot releases it,
-- this weak-key entry releases its detached, behavior-free template as well.
local headTemplates = setmetatable({} :: { [{}]: BasePart }, { __mode = "k" })

function Geometry.CapturePlayerHead(template: Instance?): {}?
    if not template or not template:IsA("BasePart") then
        return nil
    end
    local clone: BasePart? = nil
    local success = pcall(function()
        clone = template:Clone()
        local head = clone
        if not head then
            return
        end
        -- Keep rendered head data, including dynamic-head bones/FaceControls,
        -- but no rig joints, character references, scripts, sounds or effects.
        for _, child in head:GetDescendants() do
            if
                not (
                    child:IsA("DataModelMesh")
                    or child:IsA("Decal")
                    or child:IsA("Texture")
                    or child:IsA("SurfaceAppearance")
                    or child:IsA("Attachment")
                    or child:IsA("FaceControls")
                    or child:IsA("BaseWrap")
                    or child:IsA("Folder")
                )
            then
                child:Destroy()
            end
        end
        local descendants = head:GetDescendants()
        table.insert(descendants, head)
        for _, child in descendants do
            for _, tag in CollectionService:GetTags(child) do
                CollectionService:RemoveTag(child, tag)
            end
            for name in child:GetAttributes() do
                child:SetAttribute(name, nil)
            end
        end
        head.Anchored = false
        head.CanCollide, head.CanTouch, head.CanQuery = true, true, true
        head.Massless = false
        head.CollisionGroup = "Default"
        -- Roblox accepts nil to restore material defaults; the installed API typings do not.
        head.CustomPhysicalProperties = nil :: any
        head.AssemblyLinearVelocity, head.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end)
    if not success or not clone then
        if clone then
            clone:Destroy()
        end
        return nil
    end
    local key = table.freeze({})
    headTemplates[key] = clone
    return key
end

-- Shared by world spawns and stash/carry visuals; registration stays in Spawn.
local function prepareAssembly(object: Instance)
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
    local root = WorldUtil.Part(object)
    for _, part in object:GetDescendants() do
        if root and part:IsA("BasePart") and part ~= root then
            local weld = Instance.new("WeldConstraint")
            weld.Name = "IngredientAssembly"
            weld.Part0 = root
            weld.Part1 = part
            weld.Parent = part
        end
    end
end

function Geometry.CreateVisual(id: string, definition: any, visualKey: {}?): Instance?
    if not definition then
        return nil
    end
    local templates = ServerStorage:FindFirstChild("Ingredients")
    local appearance = if id == "PlayerHead" and visualKey then headTemplates[visualKey] else nil
    local template = appearance or (templates and templates:FindFirstChild(id))
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
    prepareAssembly(object)
    return object
end

return Geometry
