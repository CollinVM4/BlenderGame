--!strict
local Registry = require(script.Parent.UIRegistry)
local Hud = {}

function Hud.Resolve(playerGui: Instance): GuiObject?
    local selected: GuiObject? = nil
    local active = 0
    for _, desktop in Registry.Desktops(playerGui) do
        if Registry.ActiveRoot(desktop, playerGui) then
            active += 1
            local content = Registry.Content(desktop)
            local top = Registry.Child(content, "TOP", { "TOP" }, "GuiObject")
            local cash = Registry.Child(top, "CashDisplay", { "CashDisplay" }, "GuiObject")
            local label = Registry.Child(cash, "Cash", { "{Coins}", "Cash" }, "TextLabel")
            if cash and label and Registry.ActiveRoot(label, playerGui) then
                local frame = cash :: GuiObject
                if frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.Y > 0 then
                    selected = frame
                end
            end
        end
    end
    return if active == 1 then selected else nil
end

-- All AbsolutePositions share the CoreUISafeInsets coordinate system, even
-- when the imported ScreenGui ignores insets. Subtract our actual canvas origin.
function Hud.Center(target: GuiObject, canvas: GuiObject): Vector2
    return target.AbsolutePosition + target.AbsoluteSize / 2 - canvas.AbsolutePosition
end

return Hud
