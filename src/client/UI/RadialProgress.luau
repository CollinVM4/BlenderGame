--!strict
-- A circular fill built from two clipped halves of one gradient-masked disc.
local RadialProgress = {}

export type View = { Root: Frame, Right: UIGradient, Left: UIGradient }

local diameter = 22
local half = diameter / 2
local mask = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.499, 0),
    NumberSequenceKeypoint.new(0.5, 1),
    NumberSequenceKeypoint.new(1, 1),
})

local function circle(parent: Instance, name: string, size: number, color: Color3): Frame
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = UDim2.fromOffset(size, size)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromOffset(half, half)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame
    frame.Parent = parent
    return frame
end

local function fillHalf(parent: Frame, name: string, x: number, gold: Color3): UIGradient
    local clip = Instance.new("Frame")
    clip.Name = name
    clip.BackgroundTransparency = 1
    clip.ClipsDescendants = true
    clip.Position = UDim2.fromOffset(x, 0)
    clip.Size = UDim2.fromOffset(half, diameter)
    clip.Parent = parent

    local disc = circle(clip, "Fill", diameter, gold)
    disc.Position = UDim2.fromOffset(half - x, half)
    local gradient = Instance.new("UIGradient")
    gradient.Transparency = mask
    gradient.Parent = disc
    return gradient
end

function RadialProgress.Create(parent: Frame, gold: Color3, track: Color3): View
    local root = Instance.new("Frame")
    root.Name = "RadialProgress"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(diameter, diameter)
    root.Parent = parent
    circle(root, "Track", diameter, track)
    local right = fillHalf(root, "RightHalf", half, gold)
    local left = fillHalf(root, "LeftHalf", 0, gold)
    circle(root, "InnerCutout", 16, track)
    local view = { Root = root, Right = right, Left = left }
    RadialProgress.SetProgress(view, 0)
    return view
end

function RadialProgress.SetProgress(view: View, progress: number)
    local angle = math.clamp(progress, 0, 1) * 360
    view.Right.Rotation = math.min(angle, 180)
    view.Left.Rotation = math.max(angle, 180)
end

return RadialProgress
