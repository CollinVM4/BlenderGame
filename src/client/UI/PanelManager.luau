--!strict
-- One visibility owner for major menus, independent of GUI/import identities.
-- Open/Close callbacks may yield for animations, but must finish their transition
-- before returning. Requests during a transition coalesce to the latest intent.
local PanelManager = {}

export type Callbacks = {
    Open: () -> (),
    Close: () -> (),
}
export type Handle = {
    Open: () -> (),
    Close: () -> (),
    Toggle: () -> (),
    Destroy: () -> (),
}
type Entry = { Id: string, Callbacks: Callbacks }
local registered: { [string]: Entry } = {}
local active: Entry? = nil
local requested: Entry? = nil
local transitioning = false

local function reconcile()
    if transitioning then
        return
    end
    transitioning = true
    local ok, message = xpcall(function()
        while active ~= requested do
            local previous = active
            if previous then
                previous.Callbacks.Close()
                active = nil
            end
            -- Read again after Close: it may yield while newer requests arrive.
            local nextPanel = requested
            if nextPanel then
                active = nextPanel
                nextPanel.Callbacks.Open()
            end
        end
    end, debug.traceback)
    transitioning = false
    if not ok then
        -- A failed close must never let another panel overlap the current one.
        requested = active
        warn("[PanelManager] " .. tostring(message))
    end
end

function PanelManager.Register(id: string, callbacks: Callbacks): Handle
    callbacks.Close() -- Registered views always start hidden, including replacements.
    local previous = registered[id]
    if previous and requested == previous then
        requested = nil
    end
    local entry: Entry = { Id = id, Callbacks = callbacks }
    registered[id] = entry
    reconcile()

    local function isRegistered(): boolean
        return registered[id] == entry
    end
    local function open()
        if isRegistered() then
            requested = entry
            reconcile()
        end
    end
    local function close()
        if requested == entry then
            requested = nil
            reconcile()
        end
    end
    return {
        Open = open,
        Close = close,
        Toggle = function()
            if requested == entry then
                close()
            else
                open()
            end
        end,
        Destroy = function()
            if isRegistered() then
                registered[id] = nil
            end
            close()
        end,
    }
end

function PanelManager.CloseAll()
    requested = nil
    reconcile()
end

function PanelManager.GetActive(): string?
    return if active then active.Id else nil
end

return PanelManager
