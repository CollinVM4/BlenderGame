--!strict
local Registry = require(script.Parent.UIRegistry)
local Hud = {}

local function resolveWithin(root: Instance?, playerGui: Instance): GuiObject?
    local cash = Registry.Child(root, "CashDisplay", { "CashDisplay" }, "GuiObject")
    local label = Registry.Child(cash, "Cash", { "{Coins}", "Cash" }, "TextLabel")
    local target = if cash and label then cash else Registry.Child(root, "Cash", { "{Coins}", "Cash" }, "TextLabel")
    local activeLabel = label or target
    if label and label:GetAttribute("CashTickerActive") == true then
        activeLabel = label.Parent
    end
    if target and target:IsA("GuiObject") and activeLabel and Registry.ActiveRoot(activeLabel, playerGui) then
        if target.AbsoluteSize.X > 0 and target.AbsoluteSize.Y > 0 then
            return target
        end
    end
    return nil
end

function Hud.Resolve(playerGui: Instance): GuiObject?
    local selected: GuiObject? = nil
    for _, desktop in Registry.Desktops(playerGui) do
        if Registry.ActiveRoot(desktop, playerGui) then
            local content = Registry.Content(desktop)
            local top = Registry.Child(content, "TOP", { "TOP" }, "GuiObject")
            local target = resolveWithin(top, playerGui) or resolveWithin(content, playerGui)
            if not target and content ~= desktop then
                local desktopTop = Registry.Child(desktop, "TOP", { "TOP" }, "GuiObject")
                target = resolveWithin(desktopTop, playerGui) or resolveWithin(desktop, playerGui)
            end
            if target then
                if selected and selected ~= target then
                    return nil
                end
                selected = target
            end
        end
    end
    return selected
end

-- All AbsolutePositions share the CoreUISafeInsets coordinate system, even
-- when the imported ScreenGui ignores insets. Subtract our actual canvas origin.
function Hud.Center(target: GuiObject, canvas: GuiObject): Vector2
    return target.AbsolutePosition + target.AbsoluteSize / 2 - canvas.AbsolutePosition
end

return Hud
