--!strict
-- Only the editable Customer Area/Dynamic Sign Text SurfaceGui is touched.
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local Presentation = {}
local layers = { "Shadow", "Depth2", "Depth1", "Main" }
local colors = {
    Color3.fromRGB(38, 31, 43),
    Color3.fromRGB(128, 119, 150),
    Color3.fromRGB(195, 187, 211),
    Style.White,
}

function Presentation.SetStandName(signRoot: Instance, text: string)
    local gui = signRoot:FindFirstChild("SurfaceGui")
    local root = if gui and gui:IsA("SurfaceGui") then gui:FindFirstChild("TextRoot") else nil
    if not root then
        return
    end
    for _, name in layers do
        local label = root:FindFirstChild(name)
        if label and label:IsA("TextLabel") then
            label.Text = text
        end
    end
end

-- Shared with the Studio authoring helper; no letter geometry is generated.
function Presentation.Style(signRoot: Instance)
    local gui = signRoot:FindFirstChild("SurfaceGui")
    local root = if gui and gui:IsA("SurfaceGui") then gui:FindFirstChild("TextRoot") else nil
    if not root or not root:IsA("Frame") then
        return
    end
    root.BackgroundTransparency = 1
    root.Position = UDim2.fromOffset(16, 16)
    root.Size = UDim2.new(1, -38, 1, -38)
    for index, name in layers do
        local label = root:FindFirstChild(name)
        if label and label:IsA("TextLabel") then
            label.Font = Style.Font
            label.BackgroundTransparency = 1
            label.TextColor3 = colors[index]
            label.TextScaled, label.TextWrapped, label.RichText = true, true, false
            label.Size = UDim2.fromScale(1, 1)
            label.Position = UDim2.fromOffset((4 - index) * 2, (4 - index) * 2)
            label.ZIndex = index
            local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
                or Instance.new("UITextSizeConstraint")
            constraint.MinTextSize, constraint.MaxTextSize = 20, 96
            constraint.Parent = label
            local stroke = Style.Outline(label)
            stroke.Color = colors[1]
            stroke.Thickness = 3
        end
    end
end

return Presentation
