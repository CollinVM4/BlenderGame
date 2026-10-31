-- GUI/input events are doubles: these contracts do not simulate engine Tool.Activated routing.
local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local function signal()
    local entries = {}
    return {
        Connect = function(_, fn)
            local entry = { Live = true, Fn = fn }
            table.insert(entries, entry)
            return {
                Disconnect = function()
                    entry.Live = false
                end,
            }
        end,
        Fire = function(_, ...)
            for _, entry in table.clone(entries) do
                if entry.Live then
                    entry.Fn(...)
                end
            end
        end,
    }
end
local function v(x, y)
    return { X = x, Y = y }
end
local function dim(s, o)
    return { Scale = s, Offset = o }
end
local UDim = { new = dim }
local UDim2 = {
    new = function(xs, xo, ys, yo)
        return { X = dim(xs, xo), Y = dim(ys, yo) }
    end,
    fromScale = function(x, y)
        return { X = dim(x, 0), Y = dim(y, 0) }
    end,
    fromOffset = function(x, y)
        return { X = dim(0, x), Y = dim(0, y) }
    end,
}
local Vector2 = { new = v }
local Color3 = {
    new = function(...)
        return { ... }
    end,
    fromRGB = function(...)
        return { ... }
    end,
}
local Enum = setmetatable({}, {
    __index = function(self, key)
        local category = setmetatable({}, {
            __index = function(t, k)
                rawset(t, k, k)
                return k
            end,
        })
        rawset(self, key, category)
        return category
    end,
})
local pending, delayed = {}, {}
local task = {
    defer = function(fn)
        table.insert(pending, fn)
    end,
    delay = function(_, fn)
        table.insert(delayed, fn)
    end,
}
local function flush()
    local turns = 0
    while #pending > 0 do
        turns += 1
        assert(turns < 40, "event loop did not settle")
        local batch = pending
        pending = {}
        for _, fn in batch do
            fn()
        end
    end
end
local function timers()
    local batch = delayed
    delayed = {}
    for _, fn in batch do
        fn()
    end
    flush()
end
local new
local function emitAncestors(parent, event, child)
    while parent do
        parent[event]:Fire(child)
        parent = parent.Parent
    end
end
new = function(class, name, parent)
    local props = {
        Name = name or class,
        ClassName = class,
        Enabled = true,
        Visible = true,
        Image = "authored",
        Text = "preview",
        Size = UDim2.fromOffset(96, 96),
        Position = UDim2.fromOffset(0, 0),
        AnchorPoint = v(0.5, 0.5),
        ZIndex = 1,
        Padding = dim(0, 8),
        LayoutOrder = 0,
        CanvasPosition = v(0, 0),
        CanvasSize = UDim2.fromOffset(0, 0),
        Health = 100,
    }
    local children, attrs, signals = {}, {}, {}
    local object = {}
    local function sig(key)
        signals[key] = signals[key] or signal()
        return signals[key]
    end
    function object:IsA(want)
        return class == want
            or (want == "GuiButton" and (class == "TextButton" or class == "ImageButton"))
            or (
                want == "GuiObject"
                and table.find({
                        "Frame",
                        "ScrollingFrame",
                        "CanvasGroup",
                        "TextLabel",
                        "TextBox",
                        "TextButton",
                        "ImageLabel",
                        "ImageButton",
                    }, class)
                    ~= nil
            )
    end
    function object:GetChildren()
        return table.clone(children)
    end
    function object:GetDescendants()
        local result = {}
        for _, child in children do
            table.insert(result, child)
            for _, descendant in child:GetDescendants() do
                table.insert(result, descendant)
            end
        end
        return result
    end
    function object:GetFullName()
        return (if self.Parent then self.Parent:GetFullName() .. "." else "") .. self.Name
    end
    function object:IsDescendantOf(ancestor)
        local p = self.Parent
        while p do
            if p == ancestor then
                return true
            end
            p = p.Parent
        end
        return false
    end
    function object:FindFirstChildOfClass(want)
        for _, child in children do
            if child:IsA(want) then
                return child
            end
        end
        return nil
    end
    function object:FindFirstChild(want)
        for _, child in children do
            if child.Name == want then
                return child
            end
        end
        return nil
    end
    function object:GetAttribute(key)
        return attrs[key]
    end
    function object:SetAttribute(key, value)
        attrs[key] = value
        sig("attr:" .. key):Fire()
    end
    function object:GetAttributeChangedSignal(key)
        return sig("attr:" .. key)
    end
    function object:GetPropertyChangedSignal(key)
        return sig(key)
    end
    function object:Destroy()
        self.Destroying:Fire()
        for _, child in self:GetChildren() do
            child:Destroy()
        end
        self.Parent = nil
    end
    function object:Clone()
        local copy = new(class, self.Name)
        for k, value in props do
            if k ~= "Parent" then
                copy[k] = value
            end
        end
        for k, value in attrs do
            copy:SetAttribute(k, value)
        end
        for _, child in children do
            local c = child:Clone()
            c.Parent = copy
        end
        return copy
    end
    for _, event in
        {
            "AncestryChanged",
            "ChildAdded",
            "ChildRemoved",
            "DescendantAdded",
            "DescendantRemoving",
            "Equipped",
            "Unequipped",
            "Activated",
            "Destroying",
            "CharacterAdded",
            "CharacterRemoving",
        }
    do
        object[event] = signal()
    end
    setmetatable(object, {
        __index = function(_, key)
            if key == "AbsoluteSize" or key == "AbsoluteWindowSize" then
                if props.Pixels then
                    return props.Pixels
                end
                local pixels = if props.Parent then props.Parent.AbsoluteSize else v(1200, 800)
                return v(
                    pixels.X * props.Size.X.Scale + props.Size.X.Offset,
                    pixels.Y * props.Size.Y.Scale + props.Size.Y.Offset
                )
            elseif key == "AbsoluteCanvasSize" then
                return v(props.CanvasSize.X.Offset, props.CanvasSize.Y.Offset)
            elseif key == "AbsolutePosition" then
                if not props.Parent then
                    return v(0, 0)
                end
                local p = props.Parent
                local x = p.AbsolutePosition.X - p.CanvasPosition.X
                local ordered = {}
                for _, child in p:GetChildren() do
                    if child:IsA("GuiButton") and child.Visible then
                        table.insert(ordered, child)
                    end
                end
                table.sort(ordered, function(a, b)
                    return a.LayoutOrder < b.LayoutOrder
                end)
                local list = p:FindFirstChildOfClass("UIListLayout")
                local gap = if list then list.Padding.Offset else 0
                for _, child in ordered do
                    if child == object then
                        break
                    end
                    x += child.AbsoluteSize.X + gap
                end
                return v(x, 0)
            end
            return props[key]
        end,
        __newindex = function(_, key, value)
            local previous = props[key]
            if key == "Parent" and previous ~= value then
                if previous then
                    emitAncestors(previous, "DescendantRemoving", object)
                    table.remove(previous._children, table.find(previous._children, object))
                end
                props[key] = value
                if previous then
                    previous.ChildRemoved:Fire(object)
                end
                if value then
                    table.insert(value._children, object)
                    value.ChildAdded:Fire(object)
                    emitAncestors(value, "DescendantAdded", object)
                end
                object.AncestryChanged:Fire(object, value)
            else
                props[key] = value
            end
            if previous ~= value then
                sig(key):Fire()
            end
        end,
    })
    rawset(object, "_children", children)
    object.Parent = parent
    return object
end
local core = { Enabled = true, Fail = false, Calls = {} }
function core:SetCoreGuiEnabled(_, enabled)
    table.insert(self.Calls, enabled)
    if self.Fail then
        error("CoreGui unavailable")
    end
    self.Enabled = enabled
end
local cas = { Actions = {} }
function cas:BindAction(name, fn, touch, ...)
    check(touch == false, "no CAS touch button")
    self.Actions[name] = fn
end
function cas:UnbindAction(name)
    self.Actions[name] = nil
end
function cas:GetButton()
    return nil
end
local guiService = new("GuiService")
guiService.MenuIsOpen = false
local uis = {
    TouchEnabled = false,
    Focus = nil,
    GetFocusedTextBox = function(self)
        return self.Focus
    end,
}
local previews, disposed = 0, 0
local ingredientViewport = {
    Create = function(_, id)
        if id == "Missing" then
            return nil
        end
        previews += 1
        local live = true
        return function()
            if live then
                disposed += 1
                live = false
            end
        end
    end,
}
local services = {
    StarterGui = core,
    ContextActionService = cas,
    UserInputService = uis,
    GuiService = guiService,
    Players = {},
    ReplicatedStorage = { Shared = { IngredientPreviewGeometry = "Geometry" } },
}
local modules = {
    IngredientViewport = ingredientViewport,
    Geometry = {
        Clone = function()
            return nil
        end,
    },
}
local warnings = {}
local function requireModule(name)
    if modules[name] then
        return modules[name]
    end
    local script = {
        Parent = {
            UIRegistry = "UIRegistry",
            Parent = {
                UI = {
                    HotbarGui = "HotbarGui",
                    IngredientViewport = "IngredientViewport",
                    UIRegistry = "UIRegistry",
                },
            },
        },
    }
    local fn = assert(loadstring(sources[name], name))
    setfenv(
        fn,
        setmetatable({
            script = script,
            require = requireModule,
            game = {
                GetService = function(_, key)
                    assert(services[key], "unexpected service " .. key)
                    return services[key]
                end,
            },
            Instance = { new = new },
            Enum = Enum,
            UDim = UDim,
            UDim2 = UDim2,
            Vector2 = Vector2,
            Color3 = Color3,
            task = task,
            typeof = function(value)
                return type(value)
            end,
            warn = function(message)
                table.insert(warnings, message)
            end,
        }, { __index = getfenv() })
    )
    modules[name] = fn()
    return modules[name]
end
local Gui = requireModule("HotbarGui")
local Controller = requireModule("Controller")
local function fixture(valid)
    local player = new("Player", "Player")
    local playerGui = new("PlayerGui", "PlayerGui", player)
    local backpack = new("Backpack", "Backpack", player)
    local character = new("Model", "Character")
    player.Character = character
    local humanoid = new("Humanoid", "Humanoid", character)
    local equipped, unequipped = 0, 0
    function humanoid:EquipTool(tool)
        equipped += 1
        for _, child in character:GetChildren() do
            if child:IsA("Tool") then
                child.Parent = backpack
            end
        end
        tool.Parent = character
        tool.Equipped:Fire()
    end
    function humanoid:UnequipTools()
        unequipped += 1
        for _, child in character:GetChildren() do
            if child:IsA("Tool") then
                child.Parent = backpack
                child.Unequipped:Fire()
            end
        end
    end
    local root = new("ScreenGui", "Authored", playerGui)
    local desktop = new("Frame", "Be a Blender! Desktop", root)
    desktop.Pixels = v(1200, 800)
    local bar = new("Frame", "Hotbar", desktop)
    local upgrades = new("CanvasGroup", "Upgrades", desktop)
    local upgradeScroll = new("ScrollingFrame", "UpgradeScroll", upgrades)
    local upgradeList = new("Frame", "UpgradeList", upgradeScroll)
    local card = new("CanvasGroup", "BatCard", upgradeList)
    new("ImageLabel", "Isolated Wooden Baseball Bat 1", card).Image = "export-bat-art"
    for _ = 1, 9 do
        local slot = new(if valid then "ImageButton" else "Frame", "Slot1", bar)
        new("TextLabel", "Label", slot)
        if valid then
            new("ImageLabel", "SlotIcon", slot)
            new("ImageLabel", "SlotSelected", slot)
            new("ImageLabel", "SlotBackground", slot)
        end
    end
    local function tool(name, id, key)
        local t = new("Tool", name)
        if id then
            t:SetAttribute("IngredientId", id)
            t:SetAttribute("CarryItemId", key)
        end
        t.Parent = backpack
        return t
    end
    return {
        Player = player,
        PlayerGui = playerGui,
        Backpack = backpack,
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Desktop = desktop,
        Bar = bar,
        Tool = tool,
        Counts = function()
            return equipped, unequipped
        end,
    }
end
local function visible(f)
    local result = {}
    for _, child in f.Bar:GetDescendants() do
        if child:IsA("GuiButton") and child.Visible then
            table.insert(result, child)
        end
    end
    table.sort(result, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    return result
end
local function label(button)
    return button:GetChildren()[1].Text
end

-- Actual prepared export: no usable buttons, and repeated local Labels do not impersonate icons.
do
    local f = fixture(false)
    f.Root:Destroy()
    local nodes = { [0] = f.PlayerGui }
    local actualBar
    for _, row in exportNodes do
        local object = new(row[3], row[4], nodes[row[2]])
        nodes[row[1]] = object
        if object.Name == "Hotbar" then
            actualBar = object
        end
    end
    check(actualBar ~= nil, "current prepared export contains Hotbar")
    local upgrades = requireModule("UpgradesGui").Resolve(f.PlayerGui)
    check(
        upgrades
            and upgrades.Cash
            and upgrades.Rows.Bat
            and upgrades.Rows.CarryCapacity
            and upgrades.Rows.Jump
            and upgrades.Rows.MovementSpeed
            and upgrades.Rows.SprintStamina,
        "new mounted export preserves existing upgrade and cash bindings"
    )
    check(requireModule("UIRegistry").PanelId(actualBar) == nil, "persistent Hotbar is outside panel registry")
    local slots = 0
    for _, slot in actualBar:GetChildren() do
        if slot.Name == "Slot1" then
            slots += 1
            check(slot.ClassName == "Frame", "actual slot class reported")
        end
    end
    check(slots == 9 and Gui.Resolve(f.PlayerGui) == nil, "actual incompatible export fails soft")
    local before = #warnings
    Gui.Resolve(f.PlayerGui)
    check(#warnings == before, "invalid slot warning once per instance")
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(
        core.Enabled and cas.Actions.HotbarSelect == nil and not actualBar.Visible,
        "native retained without selection bindings or preview bar"
    )
    stop()
    flush()
end
do
    local f = fixture(true)
    local view = Gui.Resolve(f.PlayerGui)
    check(view and #view.Slots == 9, "duplicate slot names resolve per-slot children")
    local first = view.Slots[1]
    first.Icon:Destroy()
    view = Gui.Resolve(f.PlayerGui)
    check(view and #view.Slots == 8, "missing child skips just one slot")
    local other = new("Frame", "Be a Blender! Desktop", f.Root)
    check(Gui.Resolve(f.PlayerGui) == nil, "ambiguous active desktops fail")
    other:Destroy()
end
do
    local f = fixture(true)
    f.Player:SetAttribute("CarryCapacity", 5)
    local ingredients = {}
    for index = 8, 1, -1 do
        ingredients[index] = f.Tool("Apple", "Apple", index)
    end
    local smoothie1, smoothie2 = f.Tool("Smoothie"), f.Tool("Smoothie")
    local ice = f.Tool("ray")
    ice:SetAttribute("IceGunWeapon", true)
    local bat = f.Tool("bat")
    bat:SetAttribute("BatLevel", 2)
    f.Tool("Unsupported")
    check(core.Enabled, "native enabled before readiness")
    local before = previews
    local stop = Controller.Start(f.Player, f.PlayerGui)
    check(core.Enabled, "native remains enabled before deferred render")
    flush()
    check(not core.Enabled and cas.Actions.HotbarSelect ~= nil, "handoff after render and input wiring")
    local buttons = visible(f)
    check(#buttons == 12, "eight ingredients at capacity five plus four other Tools all display")
    check(
        label(buttons[9]) == "Smoothie"
            and label(buttons[10]) == "Smoothie"
            and label(buttons[11]) == "Bat"
            and label(buttons[12]) == "Ice Gun",
        "category order and labels"
    )
    check(buttons[11]:GetChildren()[2].Image == "export-bat-art", "bat fallback resolved from authored card")
    check(previews - before == 8, "ingredient viewports once per distinct Tool")
    for i = 1, 8 do
        buttons[i].Activated:Fire()
        flush()
        check(ingredients[i].Parent == f.Character, "CarryItemId order independent of child order")
    end
    check(previews - before == 8, "equip moves preserve bindings and renders")
    buttons[8].Activated:Fire()
    flush()
    local eq, uneq = f.Counts()
    check(eq == 8 and uneq == 1 and ingredients[8].Parent == f.Backpack, "button activation only equips/toggles")
    ingredients[3].Name = "Fresh Apple"
    flush()
    check(label(visible(f)[3]) == "Fresh Apple", "live ingredient label verbatim")
    visible(f)[9].Activated:Fire()
    flush()
    check(smoothie1.Parent == f.Character, "first smoothie selected")
    visible(f)[9].Activated:Fire()
    flush()
    visible(f)[9].Activated:Fire()
    flush()
    check(smoothie1.Parent == f.Character, "smoothie sequence retained across reparent moves")
    ingredients[1]:Destroy()
    flush()
    buttons = visible(f)
    check(#buttons == 11 and buttons[8]:GetChildren()[3].Visible, "selection follows Tool after index shift")
    local scroll = f.Bar:FindFirstChildOfClass("ScrollingFrame")
    check(scroll.CanvasSize.X.Offset >= 11 * 56 + 10 * 8, "spacing-aware overflow canvas")
    check(buttons[1].Size.X.Offset >= 56, "named minimum target width")
    guiService.SelectedObject = buttons[11]
    check(scroll.CanvasPosition.X > 0, "gamepad focused overflow slot reachable")
    local callback = cas.Actions.HotbarSelect
    uis.Focus = {}
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(smoothie1.Parent == f.Character, "focused textbox ignores keyboard")
    uis.Focus = nil
    guiService.MenuIsOpen = true
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(smoothie1.Parent == f.Character, "menu ignores keyboard")
    guiService.MenuIsOpen = false
    f.Player.GameplayPaused = true
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(smoothie1.Parent == f.Character, "paused ignores keyboard")
    f.Player.GameplayPaused = false
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Zero })
    flush()
    check(bat.Parent == f.Character, "zero selects visible index ten after shift")
    for index = 2, 8 do
        ingredients[index]:Destroy()
    end
    smoothie1:Destroy()
    smoothie2:Destroy()
    ice:Destroy()
    flush()
    check(#visible(f) == 1 and label(visible(f)[1]) == "Bat", "shrink hides unused slots without locks")
    check(disposed >= 8, "hidden ingredient renders disposed")
    f.Player.CharacterRemoving:Fire(f.Character)
    flush()
    check(#visible(f) == 0, "death clears old character and all slots")
    local nextCharacter = new("Model", "Respawn")
    local nextHumanoid = new("Humanoid", "Humanoid", nextCharacter)
    local respawnEquips = 0
    function nextHumanoid:EquipTool(tool)
        respawnEquips += 1
        tool.Parent = nextCharacter
    end
    f.Player.Character = nextCharacter
    f.Player.CharacterAdded:Fire(nextCharacter)
    flush()
    bat.Parent = nil
    f.Tool("First respawn pickup", "Apple", 99)
    flush()
    check(
        #visible(f) == 1 and label(visible(f)[1]) == "First respawn pickup",
        "first pickup after respawn has no ghosts"
    )
    visible(f)[1].Activated:Fire()
    flush()
    check(respawnEquips == 1, "respawn activation reaches the new humanoid exactly once")
    stop()
    flush()
    check(
        core.Enabled and cas.Actions.HotbarSelect == nil and #visible(f) == 0,
        "teardown restores native and releases custom UI"
    )
end
do
    local f = fixture(true)
    f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local button = visible(f)[1]
    button:GetChildren()[2]:Destroy()
    flush()
    check(core.Enabled and cas.Actions.HotbarSelect == nil, "loss of required slot content releases custom selection")
    stop()
    flush()
end
do
    local f = fixture(true)
    core.Fail = true
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(core.Enabled and cas.Actions.HotbarSelect == nil, "failed handoff releases selection")
    core.Fail = false
    timers()
    check(not core.Enabled, "CoreGui readiness retries can hand off empty inventory")
    f.Root.Enabled = false
    flush()
    check(core.Enabled and cas.Actions.HotbarSelect == nil, "loss of active root restores native")
    f.Root.Enabled = true
    flush()
    check(not core.Enabled, "root reactivation reconnects")
    stop()
    flush()
    timers()
end
do
    local f = fixture(true)
    f.Tool("Bad ingredient", "Apple", nil)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(core.Enabled and #visible(f) == 0, "missing order contract retains native")
    stop()
    flush()
end
do
    local f = fixture(true)
    f.Desktop.Pixels = v(320, 600)
    uis.TouchEnabled = true
    for i = 1, 12 do
        f.Tool("Apple", "Missing", i)
    end
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local buttons = visible(f)
    check(#buttons == 12 and buttons[1].Size.X.Offset == 56, "phone targets stay 56px with scrolling")
    buttons[12].Activated:Fire()
    flush()
    local scroll = f.Bar:FindFirstChildOfClass("ScrollingFrame")
    check(scroll.CanvasPosition.X > 0, "selected last slot scrolls fully into view")
    check(buttons[12]:GetChildren()[2].Image == "authored", "missing preview preserves authored art")
    stop()
    flush()
    uis.TouchEnabled = false
end
-- No remote service exists in the double: any attempted gameplay request errors.
check(Controller.Classify((function()
    local tool = new("Tool", "Smoothie")
    tool:SetAttribute("IngredientId", "Apple")
    tool:SetAttribute("CarryItemId", 1)
    tool:SetAttribute("BatLevel", 1)
    tool:SetAttribute("IceGunWeapon", true)
    return tool
end)()) == "Ice", "classification priority")
print("Hotbar contracts passed:", count)
