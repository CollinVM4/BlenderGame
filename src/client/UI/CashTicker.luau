--!strict
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Model = require(script.Parent.CashTickerModel)
local Ticker = {}
type Wheel = { Clip: Frame, Strip: Frame }
type View = {
    Label: TextLabel,
    Row: Frame,
    Visible: boolean,
    Wheels: { Wheel },
    Connections: { RBXScriptConnection },
    State: Model.State,
}
local view: View? = nil
local render: RBXScriptConnection? = nil
local pending: RBXScriptConnection? = nil
local pendingValue = 0

local function stop()
    if render then
        render:Disconnect()
        render = nil
    end
end

function Ticker.Clear()
    stop()
    if pending then
        pending:Disconnect()
        pending = nil
    end
    local old = view
    view = nil
    if old then
        for _, connection in old.Connections do
            connection:Disconnect()
        end
        old.Label:SetAttribute("CashTickerActive", nil)
        old.Label.Visible = old.Visible
        old.Row:Destroy()
    end
end

local function draw(current: View, rolling: boolean)
    local label, row = current.Label, current.Row
    local height = label.AbsoluteSize.Y
    if height <= 0 then
        return
    end
    -- AbsoluteSize includes ancestor UIScales (including the arrival punch).
    -- Convert back to local pixels so the overlay inherits that scale once.
    local ancestor: Instance? = label.Parent
    while ancestor do
        local scale = ancestor:FindFirstChildOfClass("UIScale")
        if scale and scale.Scale > 0 then
            height /= scale.Scale
        end
        ancestor = ancestor.Parent
    end
    row.Size, row.Position, row.AnchorPoint = label.Size, label.Position, label.AnchorPoint
    row.LayoutOrder, row.Rotation, row.ZIndex = label.LayoutOrder, label.Rotation, label.ZIndex
    local width = math.max(1, TextService:GetTextSize("0", height, label.Font, Vector2.new(10000, height)).X)
    local count = Model.Wheels(current.State, rolling)
    if rolling then
        count = math.max(count, #current.Wheels)
    end
    while #current.Wheels > count do
        local removed = table.remove(current.Wheels)
        if removed then
            removed.Clip:Destroy()
        end
    end
    for place = 0, count - 1 do
        local wheel = current.Wheels[place + 1]
        if not wheel then
            local clip = Instance.new("Frame")
            clip.Name, clip.BackgroundTransparency, clip.Active = "Wheel", 1, false
            clip.BorderSizePixel = 0
            clip.ClipsDescendants = true
            clip.Parent = row
            local strip = Instance.new("Frame")
            strip.Name, strip.BackgroundTransparency, strip.Active = "Strip", 1, false
            strip.BorderSizePixel = 0
            strip.Size = UDim2.fromScale(1, 11)
            strip.Parent = clip
            for digit = 0, 10 do
                local cell = Instance.new("TextLabel")
                cell.Name, cell.Text = "Digit", tostring(digit % 10)
                cell.BackgroundTransparency, cell.Active = 1, false
                cell.BorderSizePixel = 0
                cell.FontFace = label.FontFace
                cell.TextColor3, cell.TextTransparency = label.TextColor3, label.TextTransparency
                cell.TextStrokeColor3, cell.TextStrokeTransparency =
                    label.TextStrokeColor3, label.TextStrokeTransparency
                cell.TextSize = height
                cell.Size = UDim2.fromScale(1, 1 / 11)
                cell.Position = UDim2.fromScale(0, digit / 11)
                cell.ZIndex = label.ZIndex
                local stroke = label:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke:Clone().Parent = cell
                end
                cell.Parent = strip
            end
            wheel = { Clip = clip, Strip = strip }
            current.Wheels[place + 1] = wheel
        end
        wheel.Clip.ZIndex, wheel.Strip.ZIndex = label.ZIndex, label.ZIndex
        wheel.Clip.Size = UDim2.fromOffset(width, height)
        wheel.Clip.LayoutOrder = -place
        local digit = Model.Digit(current.State.Value, place)
        -- At rest, seat each wheel on a whole digit so the balance is readable.
        wheel.Strip.Position = UDim2.fromOffset(0, -(if rolling then digit else math.floor(digit)) * height)
        for _, cell in wheel.Strip:GetChildren() do
            if cell:IsA("TextLabel") then
                cell.FontFace, cell.TextSize = label.FontFace, height
                cell.TextColor3, cell.TextTransparency = label.TextColor3, label.TextTransparency
                cell.TextStrokeColor3, cell.TextStrokeTransparency =
                    label.TextStrokeColor3, label.TextStrokeTransparency
            end
        end
    end
end

local function safeDraw(current: View, rolling: boolean): boolean
    local ok = pcall(draw, current, rolling)
    if not ok then
        Ticker.Clear()
    end
    return ok
end

function Ticker.Bind(label: TextLabel?, value: number)
    if view and view.Label == label then
        return
    end
    Ticker.Clear()
    if not label or not label.Parent or not label.Parent:IsA("GuiObject") or not label.Visible then
        return
    end
    if label.AbsoluteSize.Y <= 0 then
        pendingValue = value
        pending = label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if label.AbsoluteSize.Y > 0 then
                Ticker.Bind(label, pendingValue)
            end
        end)
        return
    end
    local row = Instance.new("Frame")
    local current: View =
        { Label = label, Row = row, Visible = label.Visible, Wheels = {}, Connections = {}, State = Model.New(value) }
    view = current
    local ok = pcall(function()
        row.Name, row.BackgroundTransparency, row.Active = "CashTicker", 1, false
        row.BorderSizePixel = 0
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = row
        row.Parent = label.Parent
        draw(current, false)
        label:SetAttribute("CashTickerActive", true)
        label.Visible = false
        table.insert(
            current.Connections,
            label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                safeDraw(current, render ~= nil)
            end)
        )
        for _, property in
            {
                "Position",
                "Size",
                "AnchorPoint",
                "Rotation",
                "FontFace",
                "TextColor3",
                "TextTransparency",
                "TextStrokeColor3",
                "TextStrokeTransparency",
            }
        do
            table.insert(
                current.Connections,
                label:GetPropertyChangedSignal(property):Connect(function()
                    safeDraw(current, render ~= nil)
                end)
            )
        end
        table.insert(
            current.Connections,
            label.AncestryChanged:Connect(function()
                Ticker.Clear()
            end)
        )
    end)
    if not ok then
        Ticker.Clear()
    end
end

function Ticker.SetTarget(value: number)
    if pending then
        pendingValue = value
    end
    local current = view
    if not current or value ~= value or value < 0 or value == math.huge then
        return
    end
    stop()
    Model.Retarget(current.State, math.floor(value), os.clock())
    if not safeDraw(current, current.State.Duration > 0) or current.State.Duration == 0 then
        return
    end
    render = RunService.RenderStepped:Connect(function()
        local rolling = Model.Sample(current.State, os.clock())
        if not safeDraw(current, rolling) or not rolling then
            stop()
        end
    end)
end

function Ticker.Snap(value: number)
    stop()
    pendingValue = value
    if view then
        view.State = Model.New(value)
        safeDraw(view, false)
    end
end

return Ticker
