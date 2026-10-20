--!strict
local Registry = require(script.Parent.UIRegistry)
local Badge = {}
function Badge.Attach(button: GuiButton): ((boolean) -> (), () -> ())
    local host = Registry.Child(button, "Badge", { "Badge" }, "GuiObject") :: GuiObject?
    if host then
        host.Visible = false
    elseif game:GetService("RunService"):IsStudio() then
        warn("[MenuNotifications] Missing authored Badge on " .. button:GetFullName())
    end
    local detached = false
    return function(visible: boolean)
        if host and not detached then
            host.Visible = visible
        end
    end, function()
        detached = true
        if host then
            host.Visible = false
        end
    end
end
return Badge
