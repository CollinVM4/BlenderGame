-- Paste into the CLIENT Command Bar during Play after discovery replication.
-- Uses real published prefabs, reports availability, and destroys every test copy.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Allowed = require(Shared.Constants.ScrapbookPreviews)
local Renderer = require(Players.LocalPlayer.PlayerScripts.Client.UI.IngredientViewport)
local assets = Shared:FindFirstChild("ScrapbookPreviewAssets")
assert(assets, "Server preview publisher has not run")
local host = Instance.new("ScreenGui")
host.Name = "ScrapbookPreviewAudit"
host.Parent = Players.LocalPlayer.PlayerGui
local card = Instance.new("Frame")
card.Size = UDim2.fromOffset(200, 200)
card.Position = UDim2.fromOffset(-1000, -1000)
card.Parent = host
local image = Instance.new("ImageLabel")
image.Size = UDim2.fromOffset(160, 160)
image.Parent = card
local available, missing = {}, {}
local ok, problem = pcall(function()
    for id in Allowed :: { [string]: boolean } do
        local previousSize, previousCamera
        local rendered = false
        for _, silhouette in { true, false } do
            local cleanup = Renderer.Create(image, id, silhouette)
            if not cleanup then
                break
            end
            rendered = true
            local viewport = card:FindFirstChild("IngredientPreview")
            local world = viewport:FindFirstChildOfClass("WorldModel")
            local model = world:FindFirstChildOfClass("Model")
            local box, size = model:GetBoundingBox()
            assert(box.Position.Magnitude < 0.001, id .. " is not centered")
            assert(math.max(size.X, size.Y, size.Z) < 4.01, id .. " was not uniformly normalized")
            for _, object in model:GetDescendants() do
                if object:IsA("BasePart") then
                    assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery)
                    if silhouette then
                        assert(object.Color == Color3.fromRGB(8, 8, 10))
                        assert(
                            object.Material == Enum.Material.SmoothPlastic
                                and object.MaterialVariant == ""
                                and object.Reflectance == 0
                        )
                        assert(object.Transparency == 0 or object.Transparency == 1)
                        if object:IsA("MeshPart") then
                            assert(object.TextureID == "")
                        end
                        if object:IsA("UnionOperation") then
                            assert(object.UsePartColor)
                        end
                    end
                end
                assert(
                    not object:IsA("LuaSourceContainer") and not object:IsA("Constraint") and not object:IsA("Sound")
                )
                if silhouette then
                    assert(
                        not object:IsA("Decal") and not object:IsA("Texture") and not object:IsA("SurfaceAppearance")
                    )
                    if object:IsA("SpecialMesh") then
                        assert(object.TextureId == "")
                    end
                end
            end
            local camera = viewport.CurrentCamera
            if previousSize then
                assert((previousSize - size).Magnitude < 0.001, id .. " silhouette changed proportions")
                assert(
                    (previousCamera.Position - camera.CFrame.Position).Magnitude < 0.001,
                    id .. " silhouette changed framing"
                )
            end
            previousSize, previousCamera = size, camera.CFrame
            -- Use the actual engine bounding-box corners, not mock geometry.
            local pixels = viewport.AbsoluteSize
            local aspect = if pixels.Y > 0 then pixels.X / pixels.Y else 1
            local tangent = math.tan(math.rad(camera.FieldOfView) / 2)
            for _, x in { -1, 1 } do
                for _, y in { -1, 1 } do
                    for _, z in { -1, 1 } do
                        local corner = box:PointToWorldSpace(Vector3.new(size.X * x, size.Y * y, size.Z * z) / 2)
                        local localPoint = camera.CFrame:PointToObjectSpace(corner)
                        assert(
                            localPoint.Z < 0
                                and math.abs(localPoint.Y / localPoint.Z) < tangent
                                and math.abs(localPoint.X / localPoint.Z) < tangent * aspect,
                            id .. " camera clips geometry"
                        )
                    end
                end
            end
            cleanup()
            assert(camera.Parent == nil and viewport.Parent == nil, id .. " cleanup failed")
        end
        table.insert(if rendered then available else missing, id)
    end
end)
host:Destroy()
assert(ok, problem)
table.sort(available)
table.sort(missing)
print("Scrapbook real prefab silhouette/color framing/cleanup checks passed: " .. table.concat(available, ", "))
print("Scrapbook missing/unrenderable prefabs: " .. table.concat(missing, ", "))
-- Passing these checks does not measure appearance, GPU cost or mobile performance.

-- Exercise lazy scrolling/close/reopen on the real bound panel, restoring its state.
local Presentation = require(Players.LocalPlayer.PlayerScripts.Client.UI.ScrapbookPresentation)
local binding = Presentation.Resolve(Players.LocalPlayer.PlayerGui)
if binding then
    local originalVisible, originalCanvas = binding.Panel.Visible, binding.Scroll.CanvasPosition
    local function checkPanel()
        local count = 0
        for _, object in binding.Scroll:GetDescendants() do
            if object:IsA("ViewportFrame") and object.Name == "IngredientPreview" then
                count += 1
                local parent = object.Parent
                assert(
                    parent.AbsolutePosition.Y < binding.Scroll.AbsolutePosition.Y + binding.Scroll.AbsoluteWindowSize.Y
                )
                assert(parent.AbsolutePosition.Y + parent.AbsoluteSize.Y > binding.Scroll.AbsolutePosition.Y)
                local label = parent:FindFirstChild("IngredientLabel")
                if label and label.Text == "???" then
                    assert(object.LightColor == Color3.new(0, 0, 0))
                    assert(not parent:FindFirstChild("IngredientValue").Visible)
                end
            end
        end
        assert(count <= 8, "preview cap exceeded")
        if not binding.Panel.Visible then
            assert(count == 0, "closed panel retained previews")
        end
    end
    local passed, reason = pcall(function()
        binding.Panel.Visible = true
        binding.Scroll.CanvasPosition = Vector2.zero
        task.wait(0.2)
        checkPanel()
        binding.Scroll.CanvasPosition =
            Vector2.new(0, math.max(0, binding.Scroll.AbsoluteCanvasSize.Y - binding.Scroll.AbsoluteWindowSize.Y))
        task.wait(0.2)
        checkPanel()
        binding.Panel.Visible = false
        task.wait(0.2)
        checkPanel()
        binding.Panel.Visible = true
        task.wait(0.2)
        checkPanel()
    end)
    binding.Scroll.CanvasPosition = originalCanvas
    binding.Panel.Visible = originalVisible
    assert(passed, reason)
    print("Scrapbook live panel scrolling, close/reopen and preview cap checks passed")
else
    warn("Scrapbook panel binding unavailable; run the audit again after Framewisp loads")
end
