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
local player = { CharacterAdded = signal() }
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
local ids = { "Settings", "Upgrades", "Shop", "Index" }

local function run(tagged, wrapped)
    local gui = instance("ScreenGui", "Framewisp")
    local desktop = instance("Frame", "Be a Blender! Desktop", gui, { FW_Owned = true })
    local content = if wrapped then instance("CanvasGroup", "Be a Blender! DesktopContent", desktop) else desktop
    local top = instance("Frame", "TOP", content)
    local cash = instance("TextLabel", "{Coins}", top)
    cash.Text = "$1,234"
    local nav = instance("Frame", "LeftMenu", content)
    local panels, buttons, closes = {}, {}, {}
    local function panel(id)
        local p = instance("Frame", id .. (if tagged then "_panel" else ""), content, { FigmaAction = "panel" })
        local header = instance("Frame", "Header", p)
        local close =
            instance("ImageButton", if tagged then "Close_close" else "Close", header, { FigmaAction = "close" })
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
    local buy = instance("TextButton", "Buy", panels.Upgrades)
    local purchases = 0
    buy.Activated:Connect(function()
        purchases += 1
    end)
    local env = setmetatable(
        { script = { Parent = gui }, game = game, TweenInfo = tweenInfo, Enum = enum },
        { __index = getfenv() }
    )
    local actions = assert(loadstring(actionSource))
    setfenv(actions, env)
    actions()
    local function only(id)
        for _, candidate in ids do
            check(panels[candidate].Visible == (candidate == id), candidate .. " visibility")
        end
        check(desktop.Visible and top.Visible and nav.Visible and cash.Text == "$1,234", "HUD preserved")
    end
    only(nil)
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
    player.CharacterAdded:Fire()
    only(nil)
    gui.Destroying:Fire()
    return gui
end
run(false, true)
run(true, false)
-- A reconstructed GUI must start closed with fresh functioning navigation.
run(false, false)
print("Framewisp menus: " .. count .. " checks passed")
