--!strict
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.LuckyBlockPresentation)
local Visual = {}

function Visual.Pose(position: Vector3): CFrame
    return CFrame.new(position + Vector3.new(0, Config.HeightOffset, 0))
        * CFrame.Angles(math.rad(Config.TiltDegrees), math.rad(Config.RevealYawDegrees), 0)
end

local function prepare(copy: Instance, model: Model, silhouette: boolean): Model?
    local descendants = copy:GetDescendants()
    table.insert(descendants, 1, copy)
    local parts = 0
    for _, object in descendants do
        if object ~= copy and not object:IsDescendantOf(copy) then
            continue
        end
        local geometry = object:IsA("Model")
            or object:IsA("Folder")
            or object:IsA("BasePart")
            or object:IsA("DataModelMesh")
            or object:IsA("Bone")
        local appearance = object:IsA("Decal") or object:IsA("Texture") or object:IsA("SurfaceAppearance")
        local effect = object:IsA("Attachment")
            or object:IsA("ParticleEmitter")
            or object:IsA("Light")
            or object:IsA("Trail")
            or object:IsA("Beam")
        if not (geometry or (not silhouette and (appearance or effect))) then
            object:Destroy()
            continue
        end
        for _, tag in CollectionService:GetTags(object) do
            CollectionService:RemoveTag(object, tag)
        end
        -- Native Clone preserves authored attributes. Never manually write/clear RBX_ attributes:
        -- imported metadata such as RBX_ReimportId requires CoreScript permission.
        if object:IsA("BasePart") then
            parts += 1
            object.Anchored = true
            object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
            object.AssemblyLinearVelocity, object.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
            if silhouette then
                object.Color = Color3.new(0, 0, 0)
                object.Material = Enum.Material.SmoothPlastic
                object.MaterialVariant = ""
                object.Transparency = 0
                object.LocalTransparencyModifier = 0
                object.Reflectance = 0
                if object:IsA("PartOperation") then
                    object.UsePartColor = true
                end
                if object:IsA("MeshPart") then
                    object.TextureID = ""
                end
            end
        elseif silhouette and object:IsA("SpecialMesh") then
            object.TextureId = ""
            object.VertexColor = Vector3.zero
        end
    end
    if parts == 0 then
        copy:Destroy()
        return nil
    end
    model.Name = "LuckyBlockRewardVisual"
    copy.Parent = model
    local _, size = model:GetBoundingBox()
    model:ScaleTo(model:GetScale() * Config.ModelSize / math.max(size.X, size.Y, size.Z, 0.001))
    local bounds = model:GetBoundingBox()
    model:PivotTo(model:GetPivot() - bounds.Position)
    return model
end

-- Clone imported art without gameplay, physics, or inherited world-item tags.
function Visual.Clone(source: Instance?, silhouette: boolean): Model?
    if not source or not (source:IsA("BasePart") or source:IsA("Model")) then
        return nil
    end
    local ok, cloned = pcall(function()
        return source:Clone()
    end)
    if not ok or not cloned then
        return nil
    end
    local copy = cloned :: Instance
    local model = Instance.new("Model")
    local prepared, result = pcall(prepare, copy, model, silhouette)
    if not prepared or not result then
        copy:Destroy()
        model:Destroy()
        return nil
    end
    return result
end

return Visual
