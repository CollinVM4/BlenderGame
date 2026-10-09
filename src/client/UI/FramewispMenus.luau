--!strict
-- Called by FramewispActions through tools/prepare_framewisp_ui.py. Its existing
-- wiring path delegates major menus here; generated action tweens do not compete.
local PanelManager = require(script.Parent.PanelManager)
local Menus = {}
local Registry = require(script.Parent.UIRegistry)
local names = Registry.Panels
local contentOf = Registry.ContentOf
local panelId = Registry.PanelId
local attached: { [Instance]: { Wire: (Instance) -> boolean } } = setmetatable({}, { __mode = "k" }) :: any

function Menus.Attach(gui: Instance, player: Player)
    if attached[gui] then
        return attached[gui]
    end
    local panels: { [Instance]: PanelManager.Handle } = {}
    local wired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
    local connections: { RBXScriptConnection } = {}
    local buttons: { [Instance]: RBXScriptConnection } = {}
    local stopped = false

    local function initialize(instance: Instance)
        local id = panelId(instance)
        if id and not panels[instance] then
            local panel = instance :: GuiObject
            panel.Visible = false
            panels[instance] = PanelManager.Register(id, {
                Open = function()
                    panel.Visible = true
                end,
                Close = function()
                    panel.Visible = false
                end,
            })
        end
    end
    local function wire(button: Instance): boolean
        if stopped then
            return true
        end
        if not button:IsA("GuiButton") then
            return false
        end
        local content = contentOf(button)
        if not content then
            return false
        end
        local close: GuiObject? = nil
        local ancestor = button.Parent
        while ancestor and ancestor ~= content do
            if panelId(ancestor) then
                close = ancestor :: GuiObject
                break
            end
            ancestor = ancestor.Parent
        end
        local action = button:GetAttribute("FigmaAction")
        local param = button:GetAttribute("FigmaActionParam")
        local semantic = button:GetAttribute("BlenderUI")
        local id = if type(semantic) == "string"
            then semantic:match("^Toggle:(%w+)$")
            elseif type(param) == "string" then param:gsub("_panel$", "")
            else button.Name:match("^(%w+)")
        local isClose = close ~= nil
            and (semantic == "Close" or action == "close" or button.Name:match("^Close") ~= nil)
        local navigation = false
        local container = button.Parent
        while container and container ~= content do
            if
                Registry.Matches(container, "LeftMenu", { "LeftMenu" })
                or Registry.Matches(container, "RightMenu", { "RightMenu" })
            then
                navigation = true
                break
            end
            container = container.Parent
        end
        local isMenu = close == nil
            and id ~= nil
            and names[id] == true
            and (navigation or (type(semantic) == "string" and semantic:match("^Toggle:") ~= nil))
        if not isClose and not isMenu then
            return false
        end
        if wired[button] then
            return true
        end
        wired[button] = true
        buttons[button] = button.Activated:Connect(function()
            if not button:IsDescendantOf(gui) then
                return
            end
            if isClose and close then
                local handle = panels[close]
                if handle then
                    handle.Close()
                end
                return
            end
            local selected: GuiObject? = nil
            for _, child in content:GetChildren() do
                if panelId(child) == id then
                    if selected then
                        warn("FramewispMenus: ambiguous panel target " .. tostring(id))
                        return -- Do not guess between duplicate imported panels.
                    end
                    selected = child :: GuiObject
                end
            end
            if not selected then
                warn("FramewispMenus: missing panel target " .. tostring(id))
            end
            if selected then
                local handle = panels[selected]
                if handle then
                    handle.Toggle()
                end
            end
        end)
        return true
    end
    local function added(instance: Instance)
        initialize(instance)
        wire(instance)
        -- Also handles a complete subtree inserted in one operation.
        for _, descendant in instance:GetDescendants() do
            initialize(descendant)
            wire(descendant)
        end
    end
    table.insert(connections, gui.DescendantAdded:Connect(added))
    table.insert(
        connections,
        gui.DescendantRemoving:Connect(function(instance)
            for panel, handle in panels do
                if panel == instance or panel:IsDescendantOf(instance) then
                    handle.Destroy()
                    panels[panel] = nil
                end
            end
            for button, connection in buttons do
                if button == instance or button:IsDescendantOf(instance) then
                    connection:Disconnect()
                    buttons[button] = nil
                    wired[button] = nil
                end
            end
        end)
    )
    for _, descendant in gui:GetDescendants() do
        initialize(descendant)
    end
    table.insert(
        connections,
        player.CharacterAdded:Connect(function()
            for _, handle in panels do
                handle.Close()
            end
        end)
    )
    local function stop()
        if stopped then
            return
        end
        stopped = true
        for _, handle in panels do
            handle.Destroy()
        end
        table.clear(panels)
        for _, connection in buttons do
            connection:Disconnect()
        end
        table.clear(buttons)
        table.clear(wired)
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
        attached[gui] = nil
    end
    table.insert(connections, gui.Destroying:Connect(stop))
    table.insert(
        connections,
        gui.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                stop()
            end
        end)
    )
    local binding = { Wire = wire }
    attached[gui] = binding
    return binding
end

return Menus
