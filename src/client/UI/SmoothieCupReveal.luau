--!strict
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Geometry = require(Shared.IngredientPreviewGeometry)
local Style = require(Shared.Constants.DialogueTextStyle)

local Reveal = { Duration = 0.95 }

function Reveal.Mount(parent: Frame, tint: Color3): Frame?
    local assets = Shared:FindFirstChild("ScrapbookPreviewAssets")
    local model = Geometry.Clone(if assets then assets:FindFirstChild("SmoothieCup") else nil)
    if not model then
        return nil
    end
    local handle = model:FindFirstChild("Handle", true)
    if not handle or not handle:IsA("BasePart") then
        model:Destroy()
        return nil
    end
    handle.Color = tint

    local hero = Instance.new("Frame")
    hero.Name = "CupShowcase"
    hero.BackgroundTransparency = 1
    hero.AnchorPoint = Vector2.new(0.5, 0.5)
    hero.Position = UDim2.fromScale(0.5, 0.5)
    hero.Size = UDim2.fromScale(0.88, 0.94)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.DominantAxis = Enum.DominantAxis.Height
    aspect.Parent = hero

    local rays = Instance.new("Frame")
    rays.AnchorPoint = Vector2.new(0.5, 0.5)
    rays.Position = UDim2.fromScale(0.5, 0.5)
    rays.Size = UDim2.fromScale(1, 1)
    rays.BackgroundTransparency = 1
    rays.Parent = hero
    local light = tint:Lerp(Style.Gold, 0.63)
    for index = 1, 12 do
        local degrees = index * 30
        local angle = math.rad(degrees)
        local ray = Instance.new("Frame")
        ray.AnchorPoint = Vector2.new(0.5, 0.5)
        ray.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.25, 0.5 + math.sin(angle) * 0.25)
        ray.Size = UDim2.fromScale(if index % 2 == 0 then 0.44 else 0.36, 0.055)
        ray.Rotation = degrees
        ray.BackgroundColor3 = light
        ray.BorderSizePixel = 0
        ray.Parent = rays
        local falloff = Instance.new("UIGradient")
        falloff.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.12),
            NumberSequenceKeypoint.new(0.53, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        falloff.Parent = ray
    end

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "CupViewport"
    viewport.BackgroundTransparency = 1
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.ZIndex = 2
    viewport.Ambient = Color3.fromRGB(195, 195, 210)
    viewport.LightColor = Style.White
    viewport.LightDirection = Vector3.new(-1, -1, -1)
    viewport.Parent = hero
    local world = Instance.new("WorldModel")
    world.Parent = viewport
    model.Parent = world
    local _, authoredSize = model:GetBoundingBox()
    model:ScaleTo(model:GetScale() * 4 / math.max(authoredSize.X, authoredSize.Y, authoredSize.Z, 0.001))
    local box, size = model:GetBoundingBox()
    local pivot = model:GetPivot() - box.Position
    local camera = Instance.new("Camera")
    camera.FieldOfView = 35
    camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.15, 1).Unit * Geometry.Distance(size, 1, 35), Vector3.zero)
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    local tilt = CFrame.Angles(0, 0, math.rad(-24))
    local elapsed = 0
    local function pose()
        local progress = math.clamp(elapsed / (Reveal.Duration - 0.14), 0, 1)
        local easedTurn = 1 - (1 - progress) ^ 1.4
        model:PivotTo(tilt * CFrame.Angles(0, math.rad(-40 + 360 * easedTurn), 0) * pivot)
        rays.Rotation = -16 + progress * 31
    end
    pose()
    local animation = RunService.RenderStepped:Connect(function(delta)
        elapsed += delta
        pose()
    end)
    hero.Destroying:Once(function()
        animation:Disconnect()
    end)

    local scale = Instance.new("UIScale")
    scale.Scale = 0.42
    scale.Parent = hero
    hero.Parent = parent
    TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        :Play()
    return hero
end

return Reveal
