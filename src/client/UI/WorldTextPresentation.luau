--!strict
local Style = require(script.Parent.WorldBillboardStyle)
local Presentation = {}

export type Settings = Style.Settings & {
    Origin: Instance?,
    Text: string?,
    StudsOffset: Vector3?,
}

export type Handle = {
    SetText: (self: Handle, text: string) -> (),
    SetVisible: (self: Handle, visible: boolean) -> (),
    Destroy: (self: Handle) -> (),
}

-- Call from client code. One handle owns one GUI; updates never allocate views.
-- Invalid/missing origins return nil and a reason without creating any instances.
function Presentation.Create(settings: Settings?): (Handle?, string?)
    local origin = if settings then settings.Origin else nil
    if typeof(origin) ~= "Instance" or not origin:IsA("Attachment") then
        return nil, "WorldTextPresentation requires an Attachment Origin"
    end
    if not origin:IsDescendantOf(workspace) then
        return nil, "WorldTextPresentation Origin must be in Workspace"
    end
    local config = settings :: Settings
    local gui = Instance.new("BillboardGui")
    gui.Name = "WorldTextDisplay"
    gui.Adornee = origin
    Style.ApplyBillboard(gui, config)
    gui.StudsOffset = config.StudsOffset or Vector3.zero
    gui.Active = false
    gui.Enabled = true

    local text = Instance.new("TextLabel")
    text.Name = "Text"
    Style.ApplyText(text, config)
    text.Active = false
    text.Selectable = false
    text.Text = config.Text or ""
    text.Parent = gui
    -- Client-created child: no server replication; origin destruction owns cleanup.
    gui.Parent = origin

    local destroyed = false
    local destroying: RBXScriptConnection? = nil
    local function disconnect()
        if destroying then
            destroying:Disconnect()
            destroying = nil
        end
    end
    destroying = gui.Destroying:Connect(function()
        destroyed = true
        disconnect()
    end)
    local handle: Handle = {
        SetText = function(_self: Handle, value: string)
            if not destroyed then
                text.Text = value
            end
        end,
        SetVisible = function(_self: Handle, visible: boolean)
            if not destroyed then
                gui.Enabled = visible
            end
        end,
        Destroy = function(_self: Handle)
            if destroyed then
                return
            end
            destroyed = true
            disconnect()
            gui:Destroy()
        end,
    }
    return handle, nil
end

return Presentation
