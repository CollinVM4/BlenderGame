--!strict
-- Appearance only. Callers own content, parenting, input, and lifetime.
local Style = {}

export type Settings = {
    WidthStuds: number,
    HeightStuds: number,
    MaxDistance: number,
    AlwaysOnTop: boolean?,
    ResetOnSpawn: boolean?,
}

function Style.ApplyBillboard(gui: BillboardGui, settings: Settings)
    local function positive(value: number?): boolean
        return type(value) == "number" and value > 0 and value < math.huge
    end
    if
        not positive(settings.WidthStuds)
        or not positive(settings.HeightStuds)
        or not positive(settings.MaxDistance)
    then
        local message = "[WorldBillboardStyle] WidthStuds, HeightStuds and finite MaxDistance are required"
        if game:GetService("RunService"):IsStudio() then
            error(message, 2)
        end
        warn(message)
        -- Fail closed in production; never leave an unbounded, partly styled view.
        gui.MaxDistance = 0
        gui.Enabled = false
        return
    end
    gui.Size = UDim2.fromScale(settings.WidthStuds, settings.HeightStuds)
    gui.AlwaysOnTop = settings.AlwaysOnTop ~= false
    gui.ResetOnSpawn = settings.ResetOnSpawn == true
    gui.MaxDistance = settings.MaxDistance
end

export type TextSettings = { TextSize: number?, TextScaled: boolean? }

function Style.ApplyText(object: TextLabel | TextButton, settings: TextSettings)
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
    text.TextScaled = settings.TextScaled == true
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.TextYAlignment = Enum.TextYAlignment.Center
end

return Style
