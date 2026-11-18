--!strict
-- Standalone Framewisp artwork. No generated hierarchy, scripts or text scaler.
local Gui = {}
Gui.Name = "BlenderHotbar"
Gui.Art = {
    Background = "rbxassetid://131076681805409",
    Selected = "rbxassetid://98697899411894",
    Bat = "rbxassetid://130160586259095",
    Ice = "rbxassetid://114860674836321",
    Generic = "rbxassetid://136789729873472",
}
Gui.Gap, Gui.Padding = 6, 4
export type Slot = {
    Button: ImageButton,
    Label: TextLabel,
    Number: TextLabel,
    Icon: ImageLabel,
    Selected: ImageLabel,
    Background: ImageLabel,
}
export type View = {
    Root: ScreenGui,
    SafeArea: Frame,
    Bar: Frame,
    Scroll: ScrollingFrame,
    Template: ImageButton,
    SlotSize: number,
    Width: number,
    CanvasWidth: number,
}
local function image(name: string, asset: string, parent: Instance, layer: number): ImageLabel
    local object = Instance.new("ImageLabel")
    object.Name, object.Image = name, asset
    object.BackgroundTransparency, object.BorderSizePixel = 1, 0
    object.Size, object.ZIndex = UDim2.fromScale(1, 1), layer
    object.ScaleType = Enum.ScaleType.Fit
    object.Parent = parent
    return object
end
local function text(name: string, parent: Instance, size: number): TextLabel
    local object = Instance.new("TextLabel")
    object.Name, object.Text = name, ""
    object.BackgroundTransparency = 1
    object.Font = Enum.Font.FredokaOne
    object.TextSize, object.TextScaled, object.TextWrapped = size, false, false
    object.TextColor3 = Color3.new(1, 1, 1)
    object.TextTruncate = Enum.TextTruncate.AtEnd
    object.ZIndex = 5
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 1.5
    stroke.Parent = object
    object.Parent = parent
    return object
end
function Gui.Create(playerGui: PlayerGui): View
    local root = Instance.new("ScreenGui")
    root.Name, root.ResetOnSpawn = Gui.Name, false
    root.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    root.ZIndexBehavior, root.DisplayOrder = Enum.ZIndexBehavior.Sibling, 10
    local safe = Instance.new("Frame")
    safe.Name, safe.Size = "SafeArea", UDim2.fromScale(1, 1)
    safe.BackgroundTransparency = 1
    safe.Parent = root
    local bar = Instance.new("Frame")
    bar.Name, bar.BackgroundTransparency, bar.Visible = "Hotbar", 1, false
    bar.AnchorPoint = Vector2.new(0.5, 1)
    bar.Parent = safe
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "HotbarScroll", 1, 0
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.ScrollingDirection = Enum.ScrollingDirection.X
    scroll.ScrollingEnabled, scroll.ClipsDescendants = true, true
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.Parent = bar
    local template = Instance.new("ImageButton")
    template.Name, template.Image, template.BackgroundTransparency = "Slot", "", 1
    template.AutoButtonColor, template.Active, template.Selectable = false, true, true
    template.Size = UDim2.fromOffset(64, 64)
    template.AnchorPoint = Vector2.zero
    image("Background", Gui.Art.Background, template, 1)
    image("Selected", Gui.Art.Selected, template, 2).Visible = false
    local icon = image("Icon", Gui.Art.Generic, template, 3)
    icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 2)
    icon.Size = UDim2.new(1, -8, 1, -18)
    local label = text("Label", template, 11)
    label.Position, label.Size = UDim2.new(0, 4, 1, -17), UDim2.new(1, -8, 0, 14)
    local number = text("Number", template, 13)
    number.Position, number.Size = UDim2.fromOffset(2, 1), UDim2.fromOffset(18, 18)
    root.Parent = playerGui
    return {
        Root = root,
        SafeArea = safe,
        Bar = bar,
        Scroll = scroll,
        Template = template,
        SlotSize = 64,
        Width = 0,
        CanvasWidth = 0,
    }
end
function Gui.NewSlot(view: View): Slot
    local button = view.Template:Clone()
    button.Parent = view.Scroll
    return {
        Button = button,
        Label = button:FindFirstChild("Label") :: TextLabel,
        Number = button:FindFirstChild("Number") :: TextLabel,
        Icon = button:FindFirstChild("Icon") :: ImageLabel,
        Selected = button:FindFirstChild("Selected") :: ImageLabel,
        Background = button:FindFirstChild("Background") :: ImageLabel,
    }
end
-- Mounted safe bounds already include device/core insets. Obstacles use the
-- same absolute coordinate space; never subtract GetGuiInset a second time.
function Gui.Layout(view: View, count: number, touch: boolean, obstacles: { Rect }): boolean?
    local size, origin = view.SafeArea.AbsoluteSize, view.SafeArea.AbsolutePosition
    if size.X <= 0 or size.Y <= 0 then
        return nil -- retain an established layout through rotation's zero bounds
    end
    local maximum = math.min(960, size.X - 24)
    if maximum < 48 + Gui.Padding * 2 then
        return false
    end
    local slotSize = math.min(math.clamp(math.floor(size.Y * 0.08), 56, 72), maximum - Gui.Padding * 2)
    local height = slotSize + Gui.Padding * 2 + 4
    local canvas = Gui.Padding * 2 + count * slotSize + math.max(0, count - 1) * Gui.Gap
    local oneSlot = slotSize + Gui.Padding * 2
    local pitch = slotSize + Gui.Gap
    local landscape = touch and size.X > size.Y
    -- A usable landscape dock is independent of inventory size. Extra items scroll in place.
    local minimum = math.min(if landscape or count <= 1 then oneSlot else oneSlot + pitch, maximum)
    local requestedWidth = math.max(oneSlot, canvas)
    if size.Y < height + 24 then
        return false
    end
    local candidates = { 12 }
    if touch then
        for _, obstacle in obstacles do
            table.insert(candidates, math.max(12, origin.Y + size.Y - obstacle.Min.Y + 8))
        end
    end
    table.sort(candidates)
    local width, bottom, offset = 0, 12, 0
    local center = origin.X + size.X / 2
    for _, candidate in candidates do
        if candidate + height > size.Y - 8 then
            continue
        end
        local left, right = origin.X + 12, origin.X + size.X - 12
        local top, foot = origin.Y + size.Y - candidate - height, origin.Y + size.Y - candidate
        if touch then
            for _, obstacle in obstacles do
                if obstacle.Max.Y + 8 > top and obstacle.Min.Y - 8 < foot then
                    if (obstacle.Min.X + obstacle.Max.X) / 2 < center then
                        left = math.max(left, obstacle.Max.X + 8)
                    else
                        right = math.min(right, obstacle.Min.X - 8)
                    end
                end
            end
        end
        local gap = if landscape then right - left else 2 * math.min(center - left, right - center)
        local available = math.min(maximum, gap)
        if available >= minimum then
            width, bottom = math.floor(math.min(available, requestedWidth)), candidate
            if landscape then
                -- Align the resting width to a whole number of slots.
                width = oneSlot + math.floor((width - oneSlot) / pitch) * pitch
                offset = math.clamp(center, left + width / 2, right - width / 2) - center
            end
            break
        end
    end
    if width == 0 then
        return false
    end
    view.SlotSize, view.Width = slotSize, width
    view.CanvasWidth = canvas
    view.Bar.Position = UDim2.new(0.5, offset, 1, -bottom)
    view.Bar.Size = UDim2.fromOffset(width, height)
    view.Scroll.CanvasSize = UDim2.fromOffset(view.CanvasWidth, 0)
    Gui.Clamp(view)
    return true
end
function Gui.Clamp(view: View)
    local x = math.clamp(view.Scroll.CanvasPosition.X, 0, math.max(0, view.CanvasWidth - view.Width))
    if x ~= view.Scroll.CanvasPosition.X then
        view.Scroll.CanvasPosition = Vector2.new(x, 0)
    end
end
function Gui.Reveal(view: View, index: number)
    local left = Gui.Padding + (index - 1) * (view.SlotSize + Gui.Gap)
    local x = view.Scroll.CanvasPosition.X
    if left < x then
        x = left
    elseif left + view.SlotSize > x + view.Width then
        x = left + view.SlotSize - view.Width
    end
    view.Scroll.CanvasPosition = Vector2.new(math.clamp(x, 0, math.max(0, view.CanvasWidth - view.Width)), 0)
end
return Gui
