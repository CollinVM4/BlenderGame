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
    gui:SetAttribute("WorldHeightStuds", settings.HeightStuds)
    gui.Size = UDim2.fromScale(settings.WidthStuds, settings.HeightStuds)
    gui.AlwaysOnTop = settings.AlwaysOnTop ~= false
    gui.ResetOnSpawn = settings.ResetOnSpawn == true
    gui.MaxDistance = settings.MaxDistance
end

export type StrokeSettings = {
    ThicknessStuds: number?,
    Color: Color3?,
    Transparency: number?,
    Name: string?,
}
local bindings: { [UIStroke]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

-- Local views keep this binding until cleanup/destruction. Server views publish
-- stud metadata; WorldStrokeController binds their replicated strokes per client.
function Style.ApplyWorldStroke(label: GuiObject, billboard: BillboardGui, settings: StrokeSettings?): () -> ()
    local config: StrokeSettings = settings or {}
    local name = config.Name or "WorldOutline"
    local existing = label:FindFirstChild(name)
    local stroke = if existing and existing:IsA("UIStroke") then existing else Instance.new("UIStroke")
    local previous = bindings[stroke]
    if previous then
        previous()
    end
    stroke.Name = name
    stroke.Color = config.Color or Color3.new(0, 0, 0)
    stroke.Transparency = config.Transparency or 0
    stroke:SetAttribute("WorldThicknessStuds", config.ThicknessStuds or 0.05)
    stroke.Parent = label
    local function update()
        local height = billboard:GetAttribute("WorldHeightStuds")
        local thickness = stroke:GetAttribute("WorldThicknessStuds")
        if typeof(height) == "number" and height > 0 and typeof(thickness) == "number" then
            stroke.Thickness = math.max(1, math.round(thickness * billboard.AbsoluteSize.Y / height))
        end
    end
    local connections = {
        billboard:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
        billboard:GetAttributeChangedSignal("WorldHeightStuds"):Connect(update),
    }
    local alive = true
    local function cleanup()
        if not alive then
            return
        end
        alive = false
        for _, connection in connections do
            connection:Disconnect()
        end
        bindings[stroke] = nil
    end
    table.insert(connections, stroke.Destroying:Connect(cleanup))
    table.insert(connections, billboard.Destroying:Connect(cleanup))
    bindings[stroke] = cleanup
    update()
    return cleanup
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
