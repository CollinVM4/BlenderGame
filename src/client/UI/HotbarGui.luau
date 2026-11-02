--!strict
-- Authored hierarchy only. Repeated slot names are intentionally resolved locally.
local Registry = require(script.Parent.UIRegistry)
local Gui = {}
export type Slot = {
    Button: GuiButton,
    Label: TextLabel | TextButton | TextBox,
    Icon: ImageLabel,
    Selected: GuiObject,
    Background: GuiObject,
}
export type Metrics = {
    Ratio: number,
    IconRatio: number,
    LabelY: number,
    LabelHeight: number,
    TextMin: number,
    TextMax: number,
}
export type View = {
    Root: ScreenGui,
    Bar: GuiObject,
    Slots: { Slot },
    BatImage: string?,
    IceImage: string?,
    GenericImage: string,
}
local warned: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local measurements: { [GuiButton]: Metrics } = setmetatable({}, { __mode = "k" }) :: any
local templates: { [ImageLabel]: string } = setmetatable({}, { __mode = "k" }) :: any
function Gui.ClearTemplate(icon: ImageLabel)
    if templates[icon] == nil then
        templates[icon] = icon.Image
    end
    icon.Image = ""
end
local function issue(instance: Instance, detail: string)
    if not warned[instance] then
        warned[instance] = true
        warn("HotbarGui: " .. instance:GetFullName() .. " [" .. instance.ClassName .. "]: " .. detail)
    end
end
-- Evaluate exported scale dimensions in the export's design canvas, before any
-- slots move into the scrolling host. Runtime viewport dimensions are not ratios.
function Gui.Metrics(slot: Slot, root: ScreenGui): Metrics
    local existing = measurements[slot.Button]
    if existing then
        return existing
    end
    local designW, designH = root:GetAttribute("BB_DesignW"), root:GetAttribute("BB_DesignH")
    assert(typeof(designW) == "number" and designW > 0, "export requires numeric BB_DesignW")
    assert(typeof(designH) == "number" and designH > 0, "export requires numeric BB_DesignH")
    local function size(object: GuiObject): Vector2
        local parent = object.Parent
        local base = if parent and parent:IsA("GuiObject") then size(parent) else Vector2.new(designW, designH)
        return Vector2.new(
            base.X * object.Size.X.Scale + object.Size.X.Offset,
            base.Y * object.Size.Y.Scale + object.Size.Y.Offset
        )
    end
    local button, icon = size(slot.Button), size(slot.Icon)
    local authoredMin = slot.Label:GetAttribute("HotbarTextMin")
    local minimum = if typeof(authoredMin) == "number" then authoredMin else slot.Label.TextSize
    local fontSize = slot.Label:GetAttribute("HotbarTextMax") or slot.Label:GetAttribute("FigmaFontSize")
    local metrics = {
        Ratio = button.X / button.Y,
        IconRatio = icon.X / icon.Y,
        LabelY = slot.Label.Position.Y.Scale,
        LabelHeight = slot.Label.Size.Y.Scale,
        TextMin = minimum,
        TextMax = math.max(minimum, if typeof(fontSize) == "number" then fontSize else minimum),
    }
    measurements[slot.Button] = metrics
    return metrics
end
function Gui.Aspect(object: GuiObject, ratio: number)
    local constraint = object:FindFirstChildOfClass("UIAspectRatioConstraint")
        or Instance.new("UIAspectRatioConstraint")
    constraint.Parent = object
    constraint.AspectRatio = ratio
    constraint.DominantAxis = Enum.DominantAxis.Width
end
function Gui.Text(label: TextLabel | TextButton | TextBox, minimum: number, maximum: number)
    local text = label :: TextLabel
    -- Framewisp explicitly yields its text scaler to FW_TextOwn. Take ownership
    -- before its first apply, so a later viewport resize cannot undo readability.
    label:SetAttribute("FW_TextOwn", true)
    local spill = label:FindFirstChild("FW_Scale")
    if spill and spill:IsA("UIScale") then
        spill.Scale = 1
        local channel = spill:FindFirstChild("k_text")
        if channel and channel:IsA("NumberValue") then
            channel.Value = 1
        end
    end
    local padding = label:FindFirstChild("FW_TextPad")
    if padding then
        padding:Destroy()
    end
    text.TextScaled, text.TextWrapped = true, true
    text.TextTruncate = Enum.TextTruncate.None
    local constraint = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
    constraint.Parent = label
    constraint.MinTextSize, constraint.MaxTextSize = minimum, maximum
end
local function imported(parent: Instance?, role: string, suffix: string, class: string): Instance?
    return Registry.Child(parent, role, { role, role .. suffix }, class)
end
function Gui.Slot(instance: Instance, context: string?): Slot?
    local label = imported(instance, "Label", "_text", "GuiObject")
    local icon = imported(instance, "SlotIcon", "_image", "ImageLabel")
    local selected = imported(instance, "SlotSelected", "_image", "GuiObject")
    local background = imported(instance, "SlotBackground", "_image", "GuiObject")
    if not instance:IsA("GuiButton") then
        issue(
            instance,
            "slot must export as a GuiButton; native Backpack retained if no usable slots" .. (context or "")
        )
        return nil
    end
    if
        not label
        or not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox"))
        or not icon
        or not selected
        or not background
    then
        issue(
            instance,
            "requires compatible Label, SlotIcon (ImageLabel), SlotSelected and SlotBackground children"
                .. (context or "")
        )
        return nil
    end
    return {
        Button = instance,
        Label = label :: TextLabel | TextButton | TextBox,
        Icon = icon :: ImageLabel,
        Selected = selected :: GuiObject,
        Background = background :: GuiObject,
    }
end
local function fallback(content: Instance, ice: boolean): string?
    local panel = Registry.Child(
        content,
        if ice then "Panel:Shop" else "Panel:Upgrades",
        if ice then { "Shop", "Shop_panel" } else { "Upgrades", "Upgrades_panel" },
        "GuiObject"
    )
    local scroll = imported(panel, if ice then "ShopScroll" else "UpgradeScroll", "_scroll", "ScrollingFrame")
    local list = imported(scroll, if ice then "ShopList" else "UpgradeList", "_list", "GuiObject")
    local card = if ice
        then Registry.Child(list, "Ice Gun", { "Ice Gun" }, "GuiObject")
        else Registry.Child(list, "Upgrade:Bat", { "BatCard" }, "GuiObject")
    local image =
        imported(card, if ice then "IceGunImage" else "Isolated Wooden Baseball Bat 1", "_image", "ImageLabel")
    return if image and (image :: ImageLabel).Image ~= "" then (image :: ImageLabel).Image else nil
end
function Gui.Find(playerGui: PlayerGui): (ScreenGui?, GuiObject?)
    local desktop: Instance? = nil
    local root: ScreenGui? = nil
    for _, candidate in Registry.Desktops(playerGui) do
        local active = Registry.ActiveRoot(candidate, playerGui)
        if active then
            if desktop then
                issue(candidate, "ambiguous active desktops; native Backpack retained")
                return nil, nil
            end
            desktop, root = candidate, active
        end
    end
    if not desktop or not root then
        return nil, nil
    end
    local content = Registry.Content(desktop)
    local bar = Registry.Child(content, "Hotbar", { "Hotbar" }, "GuiObject")
    return root, bar :: GuiObject?
end
function Gui.Resolve(playerGui: PlayerGui): View?
    local root, bar = Gui.Find(playerGui)
    if not root or not bar then
        return nil
    end
    local desktop = bar.Parent
    if not desktop then
        return nil
    end
    local slots: { Slot } = {}
    for sibling, child in bar:GetChildren() do
        if Registry.Matches(child, "Slot1", { "Slot1", "Slot1_button", "Slot1_button_smooth" }) then
            local slot = Gui.Slot(child, " (direct child #" .. tostring(sibling) .. ")")
            if slot then
                table.insert(slots, slot)
            end
        end
    end
    if #slots == 0 then
        issue(bar, "no fully usable authored GuiButton slot; correct the export, do not wrap Frames")
        return nil
    end
    local upgrades = Registry.Child(desktop, "Panel:Upgrades", { "Upgrades", "Upgrades_panel" }, "GuiObject")
    local scroll = imported(upgrades, "UpgradeScroll", "_scroll", "ScrollingFrame")
    local list = imported(scroll, "UpgradeList", "_list", "GuiObject")
    local card = Registry.Child(list, "Upgrade:CarryCapacity", { "CarryCapacityCard" }, "GuiObject")
    local generic = imported(card, "Glossy Fruit Trio Sticker 1", "_image", "ImageLabel") :: ImageLabel?
    if not generic or generic.Image == "" then
        issue(bar, "missing intentional item fallback (CarryCapacityCard/Glossy Fruit Trio Sticker 1)")
        return nil
    end
    for _, slot in slots do
        if generic.Image == (templates[slot.Icon] or slot.Icon.Image) then
            issue(bar, "intentional fallback must differ from the slot template")
            return nil
        end
    end
    return {
        Root = root,
        Bar = bar :: GuiObject,
        Slots = slots,
        BatImage = fallback(desktop, false),
        IceImage = fallback(desktop, true),
        GenericImage = generic.Image,
    }
end
return Gui
