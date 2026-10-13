--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Geometry = require(Shared.IngredientPreviewGeometry)
local Allowed = require(Shared.Constants.ScrapbookPreviews)
local Renderer = {}

function Renderer.Create(image: ImageLabel, id: string, silhouette: boolean?): (() -> ())?
    if not (Allowed :: { [string]: boolean })[id] then
        return nil
    end
    local assets = Shared:FindFirstChild("ScrapbookPreviewAssets")
    local model = Geometry.Clone(if assets then assets:FindFirstChild(id) else nil)
    if not model then
        return nil
    end
    if silhouette then
        -- Change only the private visual copy. Keep meshes, sizes, pivots and
        -- invisible helper parts, but remove every original surface/color cue.
        for _, object in model:GetDescendants() do
            if object:IsA("Decal") or object:IsA("Texture") or object:IsA("SurfaceAppearance") then
                object:Destroy()
            elseif object:IsA("BasePart") then
                object.Color = Color3.fromRGB(8, 8, 10)
                object.Material = Enum.Material.SmoothPlastic
                object.MaterialVariant = ""
                object.Reflectance = 0
                if object.Transparency < 1 then
                    object.Transparency = 0
                end
                if object:IsA("MeshPart") then
                    object.TextureID = ""
                elseif object:IsA("UnionOperation") then
                    object.UsePartColor = true
                end
            elseif object:IsA("DataModelMesh") then
                object.VertexColor = Vector3.new(1, 1, 1)
                if object:IsA("SpecialMesh") then
                    object.TextureId = ""
                end
            end
        end
    end
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "IngredientPreview"
    viewport.BackgroundTransparency = 1
    viewport.Size = image.Size
    viewport.Position = image.Position
    viewport.AnchorPoint = image.AnchorPoint
    viewport.Rotation = image.Rotation
    viewport.ZIndex = image.ZIndex
    -- Ambient-only lighting keeps silhouettes flat; full-color lighting is unchanged.
    viewport.Ambient = if silhouette then Color3.new(1, 1, 1) else Color3.fromRGB(190, 190, 190)
    viewport.LightColor = if silhouette then Color3.new(0, 0, 0) else Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -1)
    local world = Instance.new("WorldModel")
    world.Parent = viewport
    model.Parent = world
    local _, originalSize = model:GetBoundingBox()
    -- Normalize only the private copy, uniformly, to avoid camera near/far-plane
    -- problems with prefabs authored at very small or very large world scales.
    model:ScaleTo(model:GetScale() * 4 / math.max(originalSize.X, originalSize.Y, originalSize.Z, 0.001))
    local box, size = model:GetBoundingBox()
    model:PivotTo(model:GetPivot() - box.Position)
    local camera = Instance.new("Camera")
    camera.FieldOfView = 35
    camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local function frame()
        local pixels = viewport.AbsoluteSize
        local aspect = if pixels.Y > 0 then pixels.X / pixels.Y else 1
        local distance = Geometry.Distance(size, aspect, camera.FieldOfView)
        camera.CFrame = CFrame.lookAt(Vector3.new(1, 0.65, 1).Unit * distance, Vector3.zero)
    end
    viewport.Parent = image.Parent
    frame()
    local resized = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
    local disposed = false
    local destroying: RBXScriptConnection? = nil
    local function cleanup()
        if disposed then
            return
        end
        disposed = true
        resized:Disconnect()
        if destroying then
            destroying:Disconnect()
        end
        viewport:Destroy()
    end
    destroying = viewport.Destroying:Connect(cleanup)
    return cleanup
end

return Renderer
