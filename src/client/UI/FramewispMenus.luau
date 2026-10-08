--!strict
-- Embedded in FramewispActions by tools/prepare_framewisp_ui.py. Main menus
-- use that script's existing wiring path, so no second visibility owner runs.
local Menus = {}
local names: { [string]: boolean } = { Settings = true, Upgrades = true, Shop = true, Index = true }

local function contentOf(instance: Instance): Instance?
    local ancestor: Instance? = instance
    while ancestor do
        if ancestor.Name == "Be a Blender! Desktop" then
            return ancestor:FindFirstChild("Be a Blender! DesktopContent") or ancestor
        end
        ancestor = ancestor.Parent
    end
    return nil
end

local function panelId(instance: Instance): string?
    if not instance:IsA("Frame") then
        return nil
    end
    local id = instance.Name:gsub("_panel$", "")
    if names[id] and instance.Parent == contentOf(instance) then
        return id
    end
    return nil
end

function Menus.Attach(gui: Instance, player: Player)
    local initialized: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
    local wired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
    local connections: { RBXScriptConnection } = {}
    local buttons: { [Instance]: RBXScriptConnection } = {}

    local function initialize(instance: Instance)
        if panelId(instance) and not initialized[instance] then
            initialized[instance] = true
            (instance :: Frame).Visible = false
        end
    end
    local function closeAll(content: Instance, selected: Frame?)
        for _, child in content:GetChildren() do
            if panelId(child) then
                (child :: Frame).Visible = child == selected
            end
        end
    end
    local function wire(button: Instance): boolean
        if not button:IsA("GuiButton") then
            return false
        end
        local content = contentOf(button)
        if not content then
            return false
        end
        local close: Frame? = nil
        local ancestor = button.Parent
        while ancestor and ancestor ~= content do
            if panelId(ancestor) then
                close = ancestor :: Frame
                break
            end
            ancestor = ancestor.Parent
        end
        local action = button:GetAttribute("FigmaAction")
        local param = button:GetAttribute("FigmaActionParam")
        local id = if type(param) == "string" then param:gsub("_panel$", "") else button.Name:match("^(%w+)")
        local isClose = close ~= nil and (action == "close" or button.Name:match("^Close") ~= nil)
        local isMenu = close == nil and id ~= nil and names[id] == true
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
                close.Visible = false
                return
            end
            local selected: Frame? = nil
            for _, child in content:GetChildren() do
                if panelId(child) == id then
                    if selected then
                        return -- Do not guess between duplicate imported panels.
                    end
                    selected = child :: Frame
                end
            end
            if selected then
                closeAll(content, if selected.Visible then nil else selected)
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
            for _, descendant in gui:GetDescendants() do
                if panelId(descendant) then
                    (descendant :: Frame).Visible = false
                end
            end
        end)
    )
    table.insert(
        connections,
        gui.Destroying:Connect(function()
            for _, connection in buttons do
                connection:Disconnect()
            end
            table.clear(buttons)
            for _, connection in connections do
                connection:Disconnect()
            end
            table.clear(connections)
        end)
    )
    return { Wire = wire }
end

return Menus
