-- Presentation-only: executes the actual exported action runtime, including its
-- wiring hook. Engine rendering remains a Studio smoke check.
local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            local callback = { fn = fn, live = true }
            table.insert(callbacks, callback)
            return {
                Disconnect = function()
                    callback.live = false
                end,
            }
        end,
        Fire = function(_, ...)
            for _, callback in table.clone(callbacks) do
                if callback.live then
                    callback.fn(...)
                end
            end
        end,
    }
end
local function instance(class, name, parent, attributes)
    local self = {
        ClassName = class,
        Name = name,
        Parent = parent,
        Visible = true,
        children = {},
        attributes = attributes or {},
        Activated = signal(),
        DescendantAdded = signal(),
        DescendantRemoving = signal(),
        Destroying = signal(),
        AncestryChanged = signal(),
    }
    function self:IsA(want)
        return want == class
            or (want == "GuiButton" and (class == "TextButton" or class == "ImageButton"))
            or (
                want == "GuiObject"
                and (class == "Frame" or class == "CanvasGroup" or class == "TextButton" or class == "ImageButton")
            )
    end
    function self:GetChildren()
        return table.clone(self.children)
    end
    function self:GetDescendants()
        local result = {}
        for _, child in self.children do
            table.insert(result, child)
            for _, descendant in child:GetDescendants() do
                table.insert(result, descendant)
            end
        end
        return result
    end
    function self:GetAttribute(key)
        return self.attributes[key]
    end
    function self:FindFirstChild(key)
        for _, child in self.children do
            if child.Name == key then
                return child
            end
        end
        return nil
    end
    function self:IsDescendantOf(ancestor)
        local current = self.Parent
        while current do
            if current == ancestor then
                return true
            end
            current = current.Parent
        end
        return false
    end
    if parent then
        table.insert(parent.children, self)
    end
    return self
end
function playerWait(self, name)
    return self:FindFirstChild(name)
end
local player = instance("Player", "Player")
player.CharacterAdded = signal()
player.WaitForChild = playerWait
local playerGui = instance("PlayerGui", "PlayerGui", player)
local detachedContainer = instance("Folder", "DetachedImports")
local playerScripts = instance("PlayerScripts", "PlayerScripts", player)
local client = instance("LocalScript", "Client", playerScripts)
local ui = instance("Folder", "UI", client)
playerScripts.WaitForChild, client.WaitForChild, ui.WaitForChild = playerWait, playerWait, playerWait
instance("ModuleScript", "FramewispMenus", ui)
local tweenService = {
    Create = function()
        error("Main menus must not run a second visibility tween")
    end,
}
local game = {
    GetService = function(_, service)
        return if service == "Players" then { LocalPlayer = player } else tweenService
    end,
}
local tweenInfo = {
    new = function()
        return {}
    end,
}
local enum = { EasingStyle = { Back = 1, Quad = 2 }, EasingDirection = { Out = 1, In = 2 } }
local ids = { "Settings", "Upgrades", "Shop", "Index", "Cosmetics" }
local modules = {}
local function loadModule(module)
    local name = if type(module) == "string" then module else module.Name
    if not modules[name] then
        local chunk = assert(loadstring(sources[name], name))
        setfenv(
            chunk,
            setmetatable({
                script = { Parent = { PanelManager = "PanelManager", UIRegistry = "UIRegistry" } },
                require = loadModule,
            }, { __index = getfenv() })
        )
        modules[name] = chunk()
    end
    return modules[name]
end
local manager = loadModule("PanelManager")

local function run(tagged, wrapped, semantic, detachMode)
    local mount = instance("Folder", "ImportMount", playerGui)
    local gui = instance("ScreenGui", "Framewisp", mount)
    local desktop = instance("Frame", "Be a Blender! Desktop", gui, { FW_Owned = true })
    local content = if wrapped then instance("CanvasGroup", "Be a Blender! DesktopContent", desktop) else desktop
    local top = instance("Frame", "TOP", content)
    local cash = instance("TextLabel", "{Coins}", top)
    cash.Text = "$1,234"
    local nav = instance("Frame", "LeftMenu", content)
    local rightNav = instance("CanvasGroup", "RightMenu", content)
    top.attributes.BlenderUI = "Panel:TOP" -- TOP stays excluded even with a panel tag.
    local panels, buttons, closes = {}, {}, {}
    local function panel(id)
        local p = instance(
            if semantic then "CanvasGroup" else "Frame",
            id .. (if tagged then "_panel" else ""),
            content,
            { FigmaAction = "panel" }
        )
        if semantic then
            p.attributes.BlenderUI = "Panel:" .. id
            p.Name = "Window " .. id
        end
        local header = instance("Frame", "Header", p)
        local close =
            instance("ImageButton", if tagged then "Close_close" else "Close", header, { FigmaAction = "close" })
        if semantic then
            close.attributes.BlenderUI = "Close"
            close.Name = "Dismiss"
        end
        return p, close
    end
    for _, id in ids do
        panels[id], closes[id] = panel(id)
        buttons[id] = instance(
            "TextButton",
            id .. (if tagged then "_button_open:" .. id else ""),
            nav,
            if tagged then {} else { FigmaAction = "open", FigmaActionParam = id }
        )
    end
    if semantic then
        desktop.attributes.BlenderUI = "Desktop"
        desktop.Name = "Redesigned Desktop"
        if content ~= desktop then
            content.attributes.BlenderUI = "Content"
            content.Name = "Redesigned Content"
        end
        nav.attributes.BlenderUI = "LeftMenu"
        nav.Name = "Navigation"
        for id, button in buttons do
            button.attributes.BlenderUI = "Toggle:" .. id
            button.Name = "Navigate " .. id
        end
    end
    local buy = instance("TextButton", "Buy", panels.Upgrades)
    local purchases = 0
    buy.Activated:Connect(function()
        purchases += 1
    end)
    local env = setmetatable(
        { script = { Parent = gui }, game = game, TweenInfo = tweenInfo, Enum = enum, require = loadModule },
        { __index = getfenv() }
    )
    local actions = assert(loadstring(actionSource))
    setfenv(actions, env)
    actions()
    -- Repeated initialization must not stack navigation handlers.
    loadModule("FramewispMenus").Attach(gui, player)
    local function only(id)
        for _, candidate in ids do
            check(panels[candidate].Visible == (candidate == id), candidate .. " visibility")
        end
        check(
            desktop.Visible and top.Visible and nav.Visible and rightNav.Visible and cash.Text == "$1,234",
            "HUD preserved"
        )
    end
    only(nil)
    buttons.Shop.Activated:Fire()
    only("Shop")
    buttons.Index.Activated:Fire()
    only("Index")
    buttons.Upgrades.Activated:Fire()
    only("Upgrades")
    buttons.Settings.Activated:Fire()
    only("Settings")
    buttons.Upgrades.Activated:Fire()
    only("Upgrades")
    buy.Activated:Fire()
    check(purchases == 1, "Buy functionality preserved")
    for _, id in ids do
        buttons[id].Activated:Fire()
        if id == "Upgrades" then -- The loop entered with Upgrades closed by Settings.
            only("Upgrades")
        else
            only(id)
        end
        buttons[id].Activated:Fire()
        only(nil)
        buttons[id].Activated:Fire()
        closes[id].Activated:Fire()
        only(nil)
    end
    buttons.Settings.Activated:Fire()
    -- Decorative insertion must preserve a menu the player intentionally opened.
    local decoration = instance("Frame", "Decoration", panels.Settings)
    gui.DescendantAdded:Fire(decoration)
    only("Settings")
    player.CharacterAdded:Fire()
    only(nil)
    -- Replace a panel with a complete imported subtree while retaining the HUD.
    local old = panels.Upgrades
    gui.DescendantRemoving:Fire(old)
    table.remove(content.children, table.find(content.children, old))
    old.Parent = nil
    panels.Upgrades, closes.Upgrades = panel("Upgrades")
    gui.DescendantAdded:Fire(panels.Upgrades)
    only(nil)
    gui.DescendantAdded:Fire(closes.Upgrades) -- repeated import notifications
    gui.DescendantAdded:Fire(buttons.Upgrades)
    gui.DescendantAdded:Fire(buttons.Upgrades)
    buttons.Upgrades.Activated:Fire()
    only("Upgrades")
    closes.Upgrades.Activated:Fire()
    only(nil)
    local oldButton = buttons.Settings
    gui.DescendantRemoving:Fire(oldButton)
    table.remove(nav.children, table.find(nav.children, oldButton))
    oldButton.Parent = nil
    buttons.Settings = instance("TextButton", "Settings", nav, { FigmaAction = "open", FigmaActionParam = "Settings" })
    gui.DescendantAdded:Fire(buttons.Settings)
    oldButton.Activated:Fire()
    only(nil)
    buttons.Settings.Activated:Fire()
    only("Settings")
    -- Script-generated menus share the singleton used by the imported script.
    local generatedVisible = false
    local generated = manager.Register("Generated", {
        Open = function()
            generatedVisible = true
        end,
        Close = function()
            generatedVisible = false
        end,
    })
    generated.Open()
    only(nil)
    check(generatedVisible, "generated menu closes imported menu")
    buttons.Index.Activated:Fire({ UserInputType = "Touch" })
    only("Index")
    check(not generatedVisible, "touch opening closes generated menu")
    for i = 1, 50 do
        buttons.Upgrades.Activated:Fire({ UserInputType = "Touch" })
        buttons.Index.Activated:Fire({ UserInputType = "Touch" })
        buttons.Cosmetics.Activated:Fire({ UserInputType = "Touch" })
    end
    only("Cosmetics")
    closes.Cosmetics.Activated:Fire({ UserInputType = "Touch" })
    only(nil)
    generated.Destroy()
    player.CharacterAdded:Fire()
    only(nil)
    -- Detach an OPEN root without Destroy. Check real parent relationships,
    -- including a move to a non-nil parent and removal of its ancestor.
    buttons.Upgrades.Activated:Fire()
    only("Upgrades")
    -- Moving within the owning PlayerGui must preserve the open menu.
    local nextMount = instance("Folder", "ReplacementMount", playerGui)
    table.remove(mount.children, table.find(mount.children, gui))
    gui.Parent = nextMount
    table.insert(nextMount.children, gui)
    mount = nextMount
    gui.AncestryChanged:Fire(gui, mount)
    only("Upgrades")
    if detachMode == "ancestor" or detachMode == "ancestorNil" then
        mount.Parent = if detachMode == "ancestor" then detachedContainer else nil
        if mount.Parent then
            table.insert(mount.Parent.children, mount)
        end
        table.remove(playerGui.children, table.find(playerGui.children, mount))
        gui.AncestryChanged:Fire(mount, mount.Parent)
    else
        table.remove(mount.children, table.find(mount.children, gui))
        gui.Parent = if detachMode == "reparent" then detachedContainer else nil
        if gui.Parent then
            table.insert(gui.Parent.children, gui)
        end
        gui.AncestryChanged:Fire(gui, gui.Parent)
    end
    only(nil)
    check(manager.GetActive() == nil, "detach releases active panel ownership")
    buttons.Upgrades.Activated:Fire()
    closes.Upgrades.Activated:Fire()
    only(nil)
    -- Retired roots must not participate in respawn or initialize inserted UI.
    panels.Upgrades.Visible = true
    player.CharacterAdded:Fire()
    check(panels.Upgrades.Visible, "respawn leaves detached root untouched")
    panels.Upgrades.Visible = false
    local inserted = panel("Settings")
    gui.DescendantAdded:Fire(inserted)
    check(inserted.Visible, "detached root no longer initializes UI descendants")
    local replacementVisible = true
    local replacement = manager.Register("Replacement", {
        Open = function()
            replacementVisible = true
        end,
        Close = function()
            replacementVisible = false
        end,
    })
    replacement.Open()
    buttons.Upgrades.Activated:Fire()
    player.CharacterAdded:Fire()
    check(
        replacementVisible and manager.GetActive() == "Replacement",
        "old navigation and respawn cannot close replacement menu"
    )
    -- Reattachment is explicit: bind this root again and resume its existing
    -- Framewisp delegation hook without running generated scripts a second time.
    if gui.Parent then
        table.remove(gui.Parent.children, table.find(gui.Parent.children, gui))
    end
    gui.Parent = playerGui
    table.insert(playerGui.children, gui)
    table.remove(content.children, table.find(content.children, inserted))
    inserted.Parent = nil
    loadModule("FramewispMenus").Attach(gui, player)
    loadModule("FramewispMenus").Attach(gui, player)
    only(nil)
    buttons.Upgrades.Activated:Fire()
    only("Upgrades")
    check(not replacementVisible, "reattached root shares panel ownership")
    buttons.Upgrades.Activated:Fire()
    only(nil)
    -- The retained generated hook also handles later inserted buttons once,
    -- rather than falling through to generated, independent visibility tweens.
    local newNavigation =
        instance("TextButton", "Upgrades", nav, { FigmaAction = "open", FigmaActionParam = "Upgrades" })
    gui.DescendantAdded:Fire(newNavigation)
    newNavigation.Activated:Fire()
    only("Upgrades")
    newNavigation.Activated:Fire()
    only(nil)
    buttons.Settings.Activated:Fire()
    only("Settings")
    player.CharacterAdded:Fire()
    only(nil)
    replacement.Destroy()
    gui.Destroying:Fire()
    buttons.Upgrades.Activated:Fire()
    only(nil)
    return gui
end
run(false, true)
run(true, false, false, "reparent")
-- A reconstructed GUI must start closed with fresh functioning navigation.
run(false, false)
run(false, true, true, "ancestor")
run(false, true, false, "ancestorNil")
print("Framewisp menus: " .. count .. " checks passed")
