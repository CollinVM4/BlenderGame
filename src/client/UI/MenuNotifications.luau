--!strict
-- Session state survives imported views. FramewispMenus owns instance bindings.
local Badge = require(script.Parent.NotificationBadge)
local Notifications = {}
type Channel = {
    Visible: boolean,
    Open: boolean,
    Views: { [GuiButton]: (boolean) -> () },
    Listeners: { [() -> ()]: boolean },
}
local channels: { [string]: Channel } = {}
local function channel(id: string): Channel
    if not channels[id] then
        channels[id] = { Visible = false, Open = false, Views = {}, Listeners = {} }
    end
    return channels[id]
end
local function render(state: Channel)
    for _, setVisible in state.Views do
        setVisible(state.Visible)
    end
end
function Notifications.Set(id: string, visible: boolean)
    local state = channel(id)
    state.Visible = visible
    render(state)
end
function Notifications.IsOpen(id: string): boolean
    return channel(id).Open
end
function Notifications.PanelChanged(id: string, open: boolean)
    local state = channel(id)
    state.Open = open
    -- Hide before callbacks or panel animations begin.
    render(state)
    if open then
        for listener in state.Listeners do
            listener()
        end
    end
end
function Notifications.OnOpened(id: string, callback: () -> ()): () -> ()
    local state = channel(id)
    state.Listeners[callback] = true
    return function()
        state.Listeners[callback] = nil
    end
end
function Notifications.Attach(id: string, button: GuiButton): () -> ()
    if id ~= "Upgrades" and id ~= "Index" then
        return function() end
    end
    local state = channel(id)
    local setVisible, detach = Badge.Attach(button)
    state.Views[button] = setVisible
    render(state)
    return function()
        if state.Views[button] == setVisible then
            state.Views[button] = nil
        end
        detach()
    end
end
return Notifications
