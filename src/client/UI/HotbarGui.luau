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
export type View = { Root: ScreenGui, Bar: GuiObject, Slots: { Slot }, BatImage: string?, IceImage: string? }
local warned: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function issue(instance: Instance, detail: string)
    if not warned[instance] then
        warned[instance] = true
        warn("HotbarGui: " .. instance:GetFullName() .. " [" .. instance.ClassName .. "]: " .. detail)
    end
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
    return {
        Root = root,
        Bar = bar :: GuiObject,
        Slots = slots,
        BatImage = fallback(desktop, false),
        IceImage = fallback(desktop, true),
    }
end
return Gui
