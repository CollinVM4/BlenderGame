--!strict
-- Appearance only. Callers own content, parenting, input, and lifetime.
local Style = {}

export type Settings = {
    Width: number?,
    Height: number?,
    TextSize: number?,
    MaxDistance: number?,
}

function Style.ApplyBillboard(gui: BillboardGui, settings: Settings)
    gui.Size = UDim2.fromOffset(settings.Width or 300, settings.Height or 56)
    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false
    gui.MaxDistance = settings.MaxDistance or math.huge
end

function Style.ApplyText(object: TextLabel | TextButton, settings: Settings)
    -- Luau cannot assign shared properties through this engine-class union.
    -- Both accepted classes expose every text/GuiObject property used below.
    local text = object :: TextLabel
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.BorderSizePixel = 0
    text.TextColor3 = Color3.new(1, 1, 1)
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextStrokeTransparency = 0.2
    text.Font = Enum.Font.GothamBold
    text.TextSize = settings.TextSize or 24
    text.TextScaled = false
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.TextYAlignment = Enum.TextYAlignment.Center
end

return Style
