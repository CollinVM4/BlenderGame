--!strict
-- Appearance only, shared by NPC lettering and plot/world presentation.
local Style = {
    Font = Enum.Font.FredokaOne,
    White = Color3.new(1, 1, 1),
    Dark = Color3.fromRGB(18, 22, 30),
    Gold = Color3.fromRGB(255, 222, 115),
    Green = Color3.new(0.45, 1, 0.55),
}

function Style.Outline(object: TextLabel | TextButton): UIStroke
    local text = object :: TextLabel
    text.TextStrokeColor3 = Style.Dark
    text.TextStrokeTransparency = 1 -- UIStroke supplies the thicker, opaque text outline.
    local existing = text:FindFirstChild("DialogueOutline")
    local stroke = if existing and existing:IsA("UIStroke") then existing else Instance.new("UIStroke")
    stroke.Name = "DialogueOutline"
    stroke.Color = Style.Dark
    stroke.Thickness = 2.5
    stroke.Transparency = 0
    stroke.Parent = text
    return stroke
end

function Style.Apply(object: TextLabel | TextButton, size: number)
    local text = object :: TextLabel
    text.Font = Style.Font
    text.TextSize = size
    text.TextScaled = false
    text.TextWrapped = false
    text.TextColor3 = Style.White
    Style.Outline(object)
end

return Style
