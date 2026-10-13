--!strict
local CollectionService = game:GetService("CollectionService")
local Geometry = {}

-- An allowlist of geometry classes excludes scripts, joints, constraints, audio,
-- prompts, effects and object references before the copy enters a live tree.
function Geometry.Clone(source: Instance?): Model?
    if not source or not (source:IsA("BasePart") or source:IsA("Model")) then
        return nil
    end
    local clone: Instance? = nil
    local ok = pcall(function()
        clone = source:Clone()
    end)
    if not ok or not clone then
        return nil
    end
    local copy = clone :: Instance
    local descendants = copy:GetDescendants()
    table.insert(descendants, 1, copy)
    local parts = 0
    for _, object in descendants do
        if object ~= copy and not object:IsDescendantOf(copy) then
            continue
        end
        if
            not (
                object:IsA("Model")
                or object:IsA("Folder")
                or object:IsA("BasePart")
                or object:IsA("DataModelMesh")
                or object:IsA("Decal")
                or object:IsA("Texture")
                or object:IsA("SurfaceAppearance")
                or object:IsA("Bone")
            )
        then
            object:Destroy()
            continue
        end
        for _, tag in CollectionService:GetTags(object) do
            CollectionService:RemoveTag(object, tag)
        end
        for key in object:GetAttributes() do
            object:SetAttribute(key, nil)
        end
        if object:IsA("BasePart") then
            parts += 1
            object.Anchored = true
            object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
            object.AssemblyLinearVelocity, object.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        end
    end
    if parts == 0 then
        copy:Destroy()
        return nil
    end
    local model = Instance.new("Model")
    model.Name = "PreviewGeometry"
    copy.Parent = model
    return model
end

-- Fit the bounding sphere in both camera axes with a 12% margin. A sphere
-- conservatively encloses every corner regardless of the three-quarter angle.
function Geometry.Distance(size: Vector3, aspect: number, fieldOfView: number): number
    local halfVertical = math.rad(fieldOfView) / 2
    local halfHorizontal = math.atan(math.tan(halfVertical) * math.max(aspect, 0.01))
    return math.max(0.1, size.Magnitude / 2) * 1.12 / math.sin(math.min(halfVertical, halfHorizontal))
end

return Geometry
