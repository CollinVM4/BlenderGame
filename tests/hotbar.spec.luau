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
local Vector2 = { new = v, zero = v(0, 0) }
local vector3 = {}
local vector3Meta = {
    __mul = function(value)
        return value
    end,
    __index = function(value, key)
        return if key == "Unit" then value else nil
    end,
}
function vector3.new(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z }, vector3Meta)
end
vector3.zero = vector3.new(0, 0, 0)
local cframe = setmetatable({ Position = vector3.zero }, {
    __sub = function(value)
        return value
    end,
})
-- Deterministic font bounds for layout contracts, not Studio glyph rendering.
local function measure(text, size, _, bounds)
    local columns = math.max(1, math.floor(bounds.X / (size * 0.6)))
    local lines = math.max(1, math.ceil(#text / columns))
    return v(math.min(#text, columns) * size * 0.6, lines * size)
end
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
local failHostCreation = false
local failReparentStage = nil
local new
local function emitAncestors(parent, event, child)
    while parent do
        parent[event]:Fire(child)
        parent = parent.Parent
    end
end
new = function(class, name, parent)
    if failHostCreation and class == "Frame" and name == nil then
        error("forced host creation failure")
    end
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
        TextSize = 8,
        Font = "FredokaOne",
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
        if failReparentStage == "marker" and key == "HotbarReparented" and value == true then
            error("forced marker failure")
        end
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
        self.Destroyed = true
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
    function object:GetBoundingBox()
        return cframe, vector3.new(1, 1, 1)
    end
    function object:GetScale()
        return 1
    end
    function object:ScaleTo() end
    function object:GetPivot()
        return cframe
    end
    function object:PivotTo() end
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
                if class == "ScreenGui" or class == "PlayerGui" then
                    return v(1200, 800)
                end
                local pixels = if props.Parent then props.Parent.AbsoluteSize else v(1200, 800)
                local result = v(
                    pixels.X * props.Size.X.Scale + props.Size.X.Offset,
                    pixels.Y * props.Size.Y.Scale + props.Size.Y.Offset
                )
                local aspect = object:FindFirstChildOfClass("UIAspectRatioConstraint")
                if aspect then
                    result.Y = result.X / aspect.AspectRatio
                end
                local minimum = object:FindFirstChildOfClass("UISizeConstraint")
                if minimum then
                    result.X = math.max(result.X, minimum.MinSize.X)
                    result.Y = math.max(result.Y, minimum.MinSize.Y)
                end
                return result
            elseif key == "AbsoluteCanvasSize" then
                local size = object.AbsoluteSize
                return v(
                    props.CanvasSize.X.Scale * size.X + props.CanvasSize.X.Offset,
                    props.CanvasSize.Y.Scale * size.Y + props.CanvasSize.Y.Offset
                )
            elseif key == "AbsolutePosition" then
                if props.Name == "HotbarHost" and props.Parent then
                    return props.Parent.AbsolutePosition
                end
                if props.ScreenPosition then
                    return props.ScreenPosition
                end
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
                local gap = if list then list.Padding.Offset + list.Padding.Scale * p.AbsoluteSize.X else 0
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
            if key == "Parent" and value then
                if failReparentStage == "host parent" and props.Name == "HotbarHost" then
                    error("forced host parent failure")
                elseif failReparentStage == "bar parent" and props.Name == "Hotbar" and value.Name == "HotbarHost" then
                    error("forced bar parent failure")
                end
            end
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
local core = setmetatable({ Enabled = true, Fail = false, Calls = {} }, {
    __index = function(_, key)
        if key == "CoreGuiChangedSignal" then
            error("CoreGuiChangedSignal requires RobloxScript capability")
        end
        return nil
    end,
})
function core:GetCoreGuiEnabled()
    if self.ReadFail then
        error("CoreGui state unavailable")
    end
    return self.Enabled
end
function core:SetCoreGuiEnabled(_, enabled)
    table.insert(self.Calls, enabled)
    if self.Fail then
        error("CoreGui unavailable")
    end
    if not self.IgnoreWrite then
        self.Enabled = enabled
        if self.NativeVisible ~= nil and not self.DeferNativeUpdate then
            self.NativeVisible = enabled
        end
    end
end
local cas = { Actions = {}, Binds = 0, Live = 0 }
function cas:BindAction(name, fn, touch, ...)
    check(touch == false, "no CAS touch button")
    check(not core.Enabled, "number bindings exist only after successful native handoff")
    check(not self.Actions[name], "no duplicate number action")
    self.Binds += 1
    self.Actions[name] = fn
end
function cas:UnbindAction(name)
    self.Actions[name] = nil
end
cas.Buttons = {}
function cas:GetButton(action)
    return self.Buttons[action]
end
local guiService = new("GuiService")
guiService.MenuIsOpen = false
guiService.BottomInset = 0
function guiService:GetGuiInset()
    return v(0, 36), v(0, self.BottomInset)
end
local uis = {
    GetPropertyChangedSignal = function()
        return signal()
    end,
    TouchEnabled = false,
    GamepadEnabled = false,
    Focus = nil,
    GetFocusedTextBox = function(self)
        return self.Focus
    end,
}
local previews, disposed = 0, 0
local ingredientViewport = {
    Create = function(icon, id)
        if id == "Missing" then
            return nil
        end
        previews += 1
        local viewport = new("ViewportFrame", "IngredientPreview", icon.Parent)
        viewport.Size, viewport.Position, viewport.AnchorPoint = icon.Size, icon.Position, icon.AnchorPoint
        local live = true
        return function()
            if live then
                disposed += 1
                live = false
                viewport:Destroy()
            end
        end
    end,
}
local services = {
    StarterGui = core,
    ContextActionService = cas,
    UserInputService = uis,
    GuiService = guiService,
    TextService = {
        GetTextSize = function(_, ...)
            return measure(...)
        end,
    },
    Players = {},
    ReplicatedStorage = { Shared = { IngredientPreviewGeometry = "Geometry" } },
}
local modules = {
    IngredientViewport = ingredientViewport,
    Geometry = {
        Clone = function(child)
            return if child:IsA("Part") then new("Part", child.Name) else nil
        end,
        Distance = function()
            return 5
        end,
    },
}
local warnings = {}
local function requireModule(name)
    if modules[name] then
        return modules[name]
    end
    local script = {
        Destroying = signal(),
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
            workspace = new("Workspace"),
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
            Vector3 = vector3,
            CFrame = {
                lookAt = function()
                    return cframe
                end,
            },
            Color3 = Color3,
            task = task,
            typeof = function(value)
                if type(value) == "table" and value.X and value.Y then
                    return if type(value.X) == "table" then "UDim2" else "Vector2"
                end
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
local templateImage
for _, row in exportNodes do
    if row[4] == "SlotIcon" then
        templateImage = row[5].Image
        break
    end
end
check(templateImage and templateImage ~= "", "template asset resolved from current export")
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
    root:SetAttribute("BB_DesignW", 1920)
    root:SetAttribute("BB_DesignH", 1080)
    local desktop = new("Frame", "Be a Blender! Desktop", root)
    desktop.Size = UDim2.fromScale(1, 1)
    desktop.Pixels = v(1200, 800)
    local bar = new("Frame", "Hotbar", desktop)
    bar.Size = UDim2.new(0.483333319, 0, 0.088888891, 0)
    local upgrades = new("CanvasGroup", "Upgrades", desktop)
    local upgradeScroll = new("ScrollingFrame", "UpgradeScroll", upgrades)
    local upgradeList = new("Frame", "UpgradeList", upgradeScroll)
    local card = new("CanvasGroup", "BatCard", upgradeList)
    new("ImageLabel", "Isolated Wooden Baseball Bat 1", card).Image = "export-bat-art"
    local carryCard = new("CanvasGroup", "CarryCapacityCard", upgradeList)
    new("ImageLabel", "Glossy Fruit Trio Sticker 1", carryCard).Image = "export-generic-art"
    for _ = 1, 9 do
        local slot = new(if valid then "ImageButton" else "Frame", "Slot1", bar)
        slot.Size = UDim2.fromScale(0.103448279, 1)
        local text = new("TextLabel", "Label", slot)
        text.Size = UDim2.fromScale(1.5, 0.0729166642)
        text.Position = UDim2.fromScale(0.5, 0.801281333)
        text.TextSize = 8
        text:SetAttribute("FigmaFontSize", 15)
        if valid then
            local icon = new("ImageLabel", "SlotIcon", slot)
            icon.Image = templateImage
            icon.Size = UDim2.fromScale(0.625, 0.625)
            icon.Position = UDim2.fromScale(0.5, 0.364583343)
            new("ImageLabel", "Slot1Background", slot)
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

-- Placement regressions exercise the real resize through render, not copied math.
local function touchButton(f, name, x, y, width, height)
    local touch = f.PlayerGui:FindFirstChild("TouchGui") or new("ScreenGui", "TouchGui", f.PlayerGui)
    local button = new("ImageButton", name)
    button.Pixels, button.ScreenPosition = v(width, height), v(x, y)
    button.Parent = touch
    return button
end
local function near(actual, expected, message)
    check(
        math.abs(actual - expected) < 0.001,
        message .. ": " .. tostring(actual) .. " expected " .. tostring(expected)
    )
end
-- Screen docking uses a letterboxed desktop and a distinct full-screen root.
local function screenFixture(width, height)
    local f = fixture(true)
    f.Root.Pixels = v(width, height)
    f.Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local desktopWidth, desktopHeight = math.min(width, height * (16 / 9)), math.min(height, width / (16 / 9))
    f.Desktop.Pixels = v(desktopWidth, desktopHeight)
    f.Desktop.ScreenPosition = v((width - desktopWidth) / 2, (height - desktopHeight) / 2)
    local content = new("CanvasGroup", "DesktopContent")
    content.Size = UDim2.fromScale(1, 1)
    content.ZIndex, content.ClipsDescendants = 6, true
    for _, child in f.Desktop:GetChildren() do
        child.Parent = content
    end
    content.Parent = f.Desktop
    f.Content = content
    f.Bar.ZIndex = 538
    local shop = new("Frame", "Shop", content)
    local scroll = new("ScrollingFrame", "ShopScroll", shop)
    local list = new("Frame", "ShopList", scroll)
    local card = new("Frame", "Ice Gun", list)
    new("ImageLabel", "IceGunImage", card).Image = "export-ice-art"
    f.Tool("Apple", "Apple", 1)
    return f
end
if testCase == "all" or testCase == "reparent" then
    do
        local f = screenFixture(390, 844)
        local before = Gui.Resolve(f.PlayerGui)
        local geometry = { f.Bar.AnchorPoint, f.Bar.Position, f.Bar.Size }
        local metrics = {}
        for i, slot in before.Slots do
            metrics[i] = Gui.Metrics(slot, f.Root)
        end
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        local screenHost = f.Bar.Parent
        check(
            screenHost.Name == "HotbarHost" and screenHost.Parent == f.Root,
            "same bar docks directly under its ScreenGui"
        )
        check(
            f.Bar.ZIndex == 538 and screenHost.ZIndex == 6,
            "sibling host inherits content stacking; bar ZIndex preserved"
        )
        check(
            screenHost.Active == false and screenHost.ClipsDescendants == false and screenHost.Visible,
            "host permits input pass-through and unclipped rendering"
        )
        check(
            screenHost.BackgroundTransparency == 1 and screenHost.BorderSizePixel == 0,
            "host has no background or border"
        )
        near(screenHost.Size.X.Scale, 1, "host fills screen width")
        near(screenHost.Size.Y.Scale, 1, "host fills screen height")
        near(screenHost.Position.X.Scale, 0, "host starts at screen origin X")
        near(screenHost.Position.Y.Scale, 0, "host starts at screen origin Y")
        check(screenHost.AnchorPoint == Vector2.zero, "host anchor is zero")
        for i, slot in before.Slots do
            check(slot.Button:IsDescendantOf(f.Bar), "same slot remains below the bar through its scroll")
            check(Gui.Metrics(slot, f.Root) == metrics[i], "authored metrics cache survives reparent and resize")
        end
        local root, bar = Gui.Find(f.PlayerGui)
        check(root == f.Root and bar == before.Bar, "Find preserves render identity after setup")
        local after = Gui.Resolve(f.PlayerGui)
        check(
            after and after.Bar == before.Bar and #after.Slots == #before.Slots,
            "Resolve recognizes same live slots through HotbarScroll"
        )
        check(
            after.BatImage == before.BatImage
                and after.IceImage == before.IceImage
                and after.GenericImage == before.GenericImage,
            "Resolve retains all three panel fallbacks after setup"
        )
        f.Backpack:GetChildren()[1].Name = "Apple renamed"
        flush()
        check(
            f.Bar.Parent == screenHost and not core.Enabled,
            "next render retains custom bar instead of identity release"
        )
        stop()
        flush()
        check(
            f.Bar.Parent == f.Content and not f.Bar.Destroyed,
            "release restores original content before host destruction; bar survives"
        )
        check(
            f.Bar.AnchorPoint == geometry[1] and f.Bar.Position == geometry[2] and f.Bar.Size == geometry[3],
            "release restores authored geometry"
        )
        check(
            not f.Bar.Visible and f.Bar:GetAttribute("HotbarReparented") == nil,
            "release hides and clears reparent marker"
        )
        check(screenHost.Destroyed and screenHost.Parent == nil, "release removes owned screen host")
        for _, slot in before.Slots do
            check(slot.Button.Parent == f.Bar and not slot.Button.Destroyed, "release restores original slot instances")
        end
        print("PASS reparent identity, metrics, render continuity, panel fallback, release survival")
    end
    for _, mode in { "desktop hidden", "root disabled" } do
        local f = screenFixture(390, 844)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        if mode == "desktop hidden" then
            f.Desktop.Visible = false
        else
            f.Root.Enabled = false
        end
        local root, bar = Gui.Find(f.PlayerGui)
        check(root == nil and bar == nil, "reparented bar respects " .. mode)
        flush()
        check(
            core.Enabled and f.Bar.Parent == f.Content and not f.Bar.Visible,
            "visibility loss restores native Backpack and original bar"
        )
        stop()
        flush()
        print("PASS reparent visibility", mode)
    end
    do
        local f = screenFixture(390, 844)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        local duplicate = new("Frame", "Hotbar", f.Content)
        local countBefore = #warnings
        local root, bar = Gui.Find(f.PlayerGui)
        check(
            root == nil and bar == nil and #warnings == countBefore + 1,
            "content and hosted bar ambiguity warns and returns neither"
        )
        Gui.Find(f.PlayerGui)
        check(#warnings == countBefore + 1, "ambiguity warning deduplicated")
        local duplicateAgain = new("Frame", "Hotbar", f.Content)
        root, bar = Gui.Find(f.PlayerGui)
        check(root == nil and bar == nil, "multiple content bars cannot conceal hosted ambiguity")
        duplicate:Destroy()
        duplicateAgain:Destroy()
        flush()
        stop()
        flush()
        print("PASS reparent ambiguity")
    end
    for _, case in
        {
            { 390, 844, "touch", 93, 16 },
            { 844, 390, "touch", 64, 16 },
            { 1920, 1080, "desktop", 96, 12 },
            { 1920, 1080, "gamepad", 96, 54 },
        }
    do
        local width, height, mode = case[1], case[2], case[3]
        local f = screenFixture(width, height)
        uis.TouchEnabled, uis.GamepadEnabled = mode == "touch", mode == "gamepad"
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        local screenHost = f.Bar.Parent
        near(screenHost.AbsoluteSize.X, width, "screen host width")
        near(screenHost.AbsoluteSize.Y, height, "screen host height")
        near(f.Bar.AbsoluteSize.Y, case[4], "height measured against screen host")
        near(-f.Bar.Position.Y.Offset, case[5], "bottom rule measured against screen host")
        near(f.Bar.AbsoluteSize.X, math.min(width * 0.483333319, width * 0.9, 960), "host width and existing cap")
        near(f.Content.AbsoluteSize.Y, math.min(height, width / (16 / 9)), "desktop remains letterboxed")
        check(not core.Enabled, "docked viewport remains custom")
        if width == 390 then
            f.Root.Pixels = v(844, 390)
            screenHost:GetPropertyChangedSignal("AbsoluteSize"):Fire()
            flush()
            near(f.Bar.AbsoluteSize.Y, 64, "rotation remeasures height without inventory event")
            near(f.Bar.AbsoluteSize.X, 844 * 0.483333319, "rotation recalculates pixel-derived width")
            near(-f.Bar.Position.Y.Offset, 16, "rotation redocks bottom")
            f.Root.Pixels = v(390, 844)
            screenHost:GetPropertyChangedSignal("AbsoluteSize"):Fire()
            flush()
            near(f.Bar.AbsoluteSize.Y, 93, "rotation back restores portrait height")
            check(f.Bar.Parent == screenHost and not core.Enabled, "rotation preserves ownership and native handoff")
        end
        stop()
        flush()
        print("PASS reparent viewport", width, height, mode, "bottom", case[5], "height", case[4])
    end
    uis.TouchEnabled, uis.GamepadEnabled = false, false
    do
        local f = screenFixture(390, 844)
        f.Root.ZIndexBehavior = Enum.ZIndexBehavior.Global
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(f.Bar.Parent.ZIndex == 1 and f.Bar.ZIndex == 538, "Global leaves host default and retains bar stacking")
        stop()
        flush()
        print("PASS reparent Global stacking")
    end
    do
        local f = screenFixture(390, 844)
        local function hostWarnings()
            local count = 0
            for _, message in warnings do
                if string.find(message, "forced host creation failure", 1, true) then
                    count += 1
                end
            end
            return count
        end
        local countBefore = hostWarnings()
        failHostCreation = true
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(
            f.Bar.Parent == f.Content and not core.Enabled,
            "host creation failure retains original viewport logic and custom Backpack handoff"
        )
        near(f.Bar.AbsoluteSize.Y, 64, "failure measures letterboxed content")
        check(hostWarnings() == countBefore + 1, "reparent failure reports reason once")
        f.Backpack:GetChildren()[1].Name = "Apple renamed"
        flush()
        check(hostWarnings() == countBefore + 1, "reparent failure does not warn again on render")
        check(f.Root:FindFirstChild("HotbarHost") == nil, "failed creation leaves no host")
        stop()
        flush()
        failHostCreation = false
        print("PASS reparent failure soft fallback")
        -- A subsequent session can dock the same bar after ordinary release.
        local stopAgain = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(f.Bar.Parent.Name == "HotbarHost" and not core.Enabled, "reinit docks original restored bar")
        stopAgain()
        flush()
        print("PASS reparent reinitialization")
    end
    for _, stage in { "host parent", "bar parent", "marker" } do
        local f = screenFixture(390, 844)
        failReparentStage = stage
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(
            f.Bar.Parent == f.Content and not f.Bar.Destroyed and not core.Enabled,
            "partial reparent rolls back and keeps working custom bar: " .. stage
        )
        check(
            f.Bar:GetAttribute("HotbarReparented") == nil and f.Root:FindFirstChild("HotbarHost") == nil,
            "partial reparent clears marker and destroys only empty host: " .. stage
        )
        near(f.Bar.AbsoluteSize.Y, 64, "partial failure uses existing content resize")
        stop()
        flush()
        failReparentStage = nil
        print("PASS reparent rollback", stage)
    end
    do
        local f = screenFixture(390, 844)
        local foreignHost = new("Frame", "HotbarHost", f.Root)
        foreignHost.Size = UDim2.fromScale(1, 1)
        local anchor, position, size = f.Bar.AnchorPoint, f.Bar.Position, f.Bar.Size
        foreignHost:SetAttribute("HotbarAuthoredAnchor", anchor)
        foreignHost:SetAttribute("HotbarAuthoredPosition", position)
        foreignHost:SetAttribute("HotbarAuthoredSize", size)
        f.Bar.Parent = foreignHost
        f.Bar.Size = UDim2.fromScale(0.4, 0.1)
        f.Bar:SetAttribute("HotbarReparented", true)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(
            f.Bar.Parent == foreignHost and not core.Enabled,
            "already hosted bar continues without nesting or taking host ownership"
        )
        local hosts = 0
        for _, child in f.Root:GetChildren() do
            if child.Name == "HotbarHost" then
                hosts += 1
            end
        end
        check(hosts == 1, "already reparented bar gets no duplicate host")
        stop()
        flush()
        check(
            f.Bar.Parent == f.Content and not foreignHost.Destroyed and not f.Bar.Destroyed,
            "unowned host is preserved; recovery parent is original DesktopContent"
        )
        check(
            f.Bar.AnchorPoint == anchor and f.Bar.Position == position and f.Bar.Size == size,
            "stale host metadata restores authored geometry instead of resized geometry"
        )
        foreignHost:Destroy()
        print("PASS reparent already hosted guard")
    end
    if testCase == "reparent" then
        return
    end
end

if testCase == "all" or testCase == "docking" or testCase == "dock-portrait" or testCase == "dock-landscape" then
    for _, size in { v(390, 844), v(844, 390) } do
        if testCase == "dock-portrait" and size.X ~= 390 or testCase == "dock-landscape" and size.X ~= 844 then
            continue
        end
        local f = fixture(true)
        f.Root.Pixels = size
        -- Narrow authored fake ensures the expanded right control has zero overlap.
        f.Bar.Size = UDim2.fromScale(if size.X == 390 then 0.34 else 0.4, 0.088888891)
        uis.TouchEnabled = true
        touchButton(f, "JumpButton", size.X - 100, size.Y - 200, 100, 120)
        touchButton(f, "Thumbstick", 0, size.Y - 120, 120, 120)
        f.Tool("Apple", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        print("Dock regression", size.X, size.Y, "bottom", -f.Bar.Position.Y.Offset)
        near(-f.Bar.Position.Y.Offset, 16, "non-overlapping right-edge control must not lift")
        stop()
        flush()
        uis.TouchEnabled = false
    end
    if testCase == "dock-portrait" or testCase == "dock-landscape" then
        return
    end
end

if testCase == "all" or testCase == "docking" then
    local viewports = {
        { "phone portrait", 390, 844, "touch", 16, 93 },
        { "phone landscape", 844, 390, "touch", 16, 64 },
        { "small phone landscape", 740, 360, "touch", 16, 64 },
        { "tablet portrait", 820, 1180, "touch", 16, 96 },
        { "tablet landscape", 1180, 820, "touch", 16, 90 },
        { "narrow desktop", 1024, 768, "desktop", 12, 84 },
        { "desktop", 1920, 1080, "desktop", 12, 96 },
        { "console 1080p", 1920, 1080, "gamepad", 54, 96 },
        { "console 720p", 1280, 720, "gamepad", 36, 79 },
    }
    for _, viewport in viewports do
        local name, width, height, input, bottom, target = table.unpack(viewport)
        local f = fixture(true)
        f.Root.Pixels = v(width, height)
        uis.TouchEnabled, uis.GamepadEnabled = input == "touch", input == "gamepad"
        for i = 1, 12 do
            f.Tool("Apple", "Apple", i)
        end
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(not core.Enabled, name .. " custom bar renders")
        near(-f.Bar.Position.Y.Offset, bottom, name .. " safe bottom")
        near(f.Bar.AbsoluteSize.Y, target, name .. " adaptive height")
        near(f.Bar.AbsoluteSize.X, math.min(width * 0.483333319, width * 0.9, 960), name .. " authored width")
        check(f.Bar.AnchorPoint.X == 0.5 and f.Bar.AnchorPoint.Y == 1, name .. " bottom anchor")
        local buttons = visible(f)
        check(#buttons == 12, name .. " overfill retained")
        for _, button in buttons do
            near(button.AbsoluteSize.X / button.AbsoluteSize.Y, 1, name .. " slot ratio")
            check(button.AbsoluteSize.X >= 48 and button.AbsoluteSize.Y >= 48, name .. " hit floor")
            check(button.Selectable, name .. " selectable")
        end
        check(
            buttons[1].NextSelectionRight == buttons[2] and buttons[2].NextSelectionLeft == buttons[1],
            name .. " navigation order"
        )
        buttons[12].Activated:Fire()
        guiService.SelectedObject = buttons[12]
        flush()
        check(f.Bar:FindFirstChildOfClass("ScrollingFrame").CanvasPosition.X > 0, name .. " selected overflow revealed")
        print("PASS viewport", name, width, height, input, "bottom", bottom, "height", target)
        stop()
        flush()
    end
    uis.TouchEnabled, uis.GamepadEnabled = true, false
    -- Widened authored bar shrinks before lifting; all slots still scroll.
    for _, leftSide in { false, true } do
        local f = fixture(true)
        f.Root.Pixels = v(844, 390)
        f.Root.ScreenPosition = v(37, 55)
        f.Bar.Size = UDim2.fromScale(0.95, 0.1)
        touchButton(f, "JumpButton", 37 + (if leftSide then 0 else 744), 55 + 270, if leftSide then 120 else 100, 120)
        for i = 1, 12 do
            f.Tool("Apple", "Apple", i)
        end
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        near(
            f.Bar.AbsoluteSize.X,
            if leftSide then 588 else 628,
            "shrink clears expanded control in absolute coordinates"
        )
        near(-f.Bar.Position.Y.Offset, 16, "shrink stays docked")
        check(
            #visible(f) == 12
                and f.Bar:FindFirstChildOfClass("ScrollingFrame").AbsoluteCanvasSize.X > f.Bar.AbsoluteSize.X,
            "shrunk overflow retained"
        )
        stop()
        flush()
    end
    -- Only the overlapping control contributes to a necessary, permitted lift.
    do
        local f = fixture(true)
        f.Root.Pixels = v(240, 500)
        touchButton(f, "JumpButton", 150, 400, 90, 100)
        cas.Buttons.ThrowHeld = touchButton(f, "Throw", 0, 200, 20, 300)
        f.Tool("Apple", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        near(-f.Bar.Position.Y.Offset, 108, "lift includes overlapping Jump only")
        near(f.Bar.AbsoluteSize.X, 240 * 0.483333319, "lift preserves candidate width")
        stop()
        flush()
        cas.Buttons = {}
    end
    -- High and invisible action buttons cannot lift or shrink the bar.
    do
        local f = fixture(true)
        f.Root.Pixels = v(844, 390)
        cas.Buttons.SprintHeld = touchButton(f, "Sprint", 400, 130, 70, 70)
        cas.Buttons.IceShotgunFire = touchButton(f, "Fire", 400, 270, 70, 120)
        cas.Buttons.IceShotgunFire.Visible = false
        f.Tool("Apple", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        near(-f.Bar.Position.Y.Offset, 16, "high/invisible controls ignored")
        near(f.Bar.AbsoluteSize.X, 844 * 0.483333319, "high/invisible controls do not shrink")
        stop()
        flush()
        cas.Buttons = {}
    end
    do
        local f = fixture(true)
        f.Root.Pixels = v(240, 390)
        touchButton(f, "JumpButton", 145, 150, 95, 240)
        local tool = f.Tool("Apple", "Apple", 1)
        Gui.Resolve(f.PlayerGui)
        local before = #warnings
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        tool.Name = "Pear"
        flush()
        near(-f.Bar.Position.Y.Offset, 16, "excessive lift docks")
        near(f.Bar.AbsoluteSize.X, 96 + (240 * 0.483333319) * 8 / 928, "cap uses two hit areas plus converted gap")
        check(
            #warnings == before + 1
                and string.find(warnings[#warnings], "240x390", 1, true)
                and string.find(warnings[#warnings], "JumpButton", 1, true),
            "cap warns once per viewport with control name"
        )
        stop()
        flush()
    end
    -- Late Jump/CAS additions and removals use the existing coalesced UI watch.
    do
        local f = fixture(true)
        f.Root.Pixels = v(844, 390)
        f.Bar.Size = UDim2.fromScale(0.9, 0.1)
        local tool = f.Tool("Apple", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        local jump = touchButton(f, "JumpButton", 744, 270, 100, 120)
        flush()
        near(f.Bar.AbsoluteSize.X, 628, "late Jump triggers clearance")
        jump:Destroy()
        flush()
        near(f.Bar.AbsoluteSize.X, 844 * 0.9, "removed Jump restores width")
        local action = touchButton(f, "Throw", 744, 270, 100, 120)
        cas.Buttons.ThrowHeld = action
        flush()
        near(f.Bar.AbsoluteSize.X, 628, "late CAS triggers clearance")
        action.Visible = false
        flush()
        near(f.Bar.AbsoluteSize.X, 844 * 0.9, "observed visibility restores width")
        guiService.BottomInset = 31
        uis.GamepadEnabled = true
        tool.Name = "Pear"
        flush()
        near(-f.Bar.Position.Y.Offset, 16, "touch uses already inset host without adding device inset twice")
        uis.TouchEnabled = false
        tool.Name = "Apple"
        flush()
        near(-f.Bar.Position.Y.Offset, 20, "gamepad reclassified each resize with ceil")
        uis.GamepadEnabled = false
        tool.Name = "Pear"
        flush()
        near(-f.Bar.Position.Y.Offset, 12, "desktop ignores touch controls")
        stop()
        flush()
        cas.Buttons = {}
        guiService.BottomInset = 0
    end
    for _, size in { v(390, 80), v(47, 500) } do
        local f = fixture(true)
        f.Root.Pixels = size
        uis.TouchEnabled = true
        f.Tool("Apple", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(
            core.Enabled and cas.Actions.HotbarSelect == nil and not f.Bar.Visible,
            "size guard restores native Backpack"
        )
        stop()
        flush()
    end
    -- User-approved label accommodation at the new 64px minimum band.
    do
        local f = fixture(true)
        f.Root.Pixels = v(844, 390)
        local tool = f.Tool("WWWWWWWWWWWWWWWWWWWW's Head", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        check(not core.Enabled and #visible(f) == 1, "long label remains in custom short bar")
        local button = visible(f)[1]
        local icon, text = button:FindFirstChild("SlotIcon"), button:FindFirstChild("Label")
        local iconBottom = icon.Position.Y.Scale + icon.Size.Y.Scale * (1 - icon.AnchorPoint.Y)
        local textTop = text.Position.Y.Scale - text.Size.Y.Scale / 2
        check(iconBottom <= textTop, "reserved label band does not overlap icon")
        near(icon.AbsoluteSize.X / icon.AbsoluteSize.Y, 1, "reduced icon keeps authored aspect")
        check(icon.AbsoluteSize.Y >= 24, "short-band icon remains visible")
        local bounds = measure(text.Text, 8, text.Font, text.AbsoluteSize)
        check(
            bounds.Y <= text.AbsoluteSize.Y and text.Position.Y.Scale + text.Size.Y.Scale / 2 <= 1,
            "long label fits inside slot"
        )
        f.Root.Pixels = v(1920, 1080)
        tool.Name = "Apple"
        flush()
        near(icon.Size.Y.Scale, 0.625, "authored icon size restored when room returns")
        stop()
        flush()
    end
    uis.TouchEnabled, uis.GamepadEnabled = false, false
    print("Docking contracts passed")
    if testCase == "docking" then
        return
    end
end

-- Stage A reproductions run independently against the pre-change production modules.
if testCase == "aspect" then
    local ratios = {}
    for _, width in { 320, 768, 1280, 1920 } do
        local f = fixture(true)
        f.Root.Pixels = v(width, 1080)
        f.Tool("Apple", "Apple", 1)
        local stop = Controller.Start(f.Player, f.PlayerGui)
        flush()
        local size = visible(f)[1].AbsoluteSize
        table.insert(ratios, size.X / size.Y)
        stop()
        flush()
    end
    print("Viewport sweep slot ratios:", table.unpack(ratios))
    for _, ratio in ratios do
        check(math.abs(ratio - 1) < 0.001, "slot preserves exported 96:96 ratio across viewport widths")
    end
    return
elseif testCase == "template" then
    local f = fixture(true)
    f.Tool("Apple", "Apple", 1)
    f.Tool("No preview", "Missing", 2)
    f.Tool("Smoothie")
    f.Tool("bat"):SetAttribute("BatLevel", 1)
    f.Tool("ray"):SetAttribute("IceGunWeapon", true)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local templates = 0
    for _, button in visible(f) do
        if button:FindFirstChild("SlotIcon").Image == templateImage then
            templates += 1
        end
    end
    print("Visible template images after full rebuild:", templates)
    stop()
    flush()
    check(templates == 0, "zero visible template images after full rebuild")
    return
end

-- Required slot content stays required even when Selected is optional.
do
    for _, name in { "Label", "SlotIcon", "Slot1Background" } do
        local f = fixture(true)
        local button = assert(Gui.Resolve(f.PlayerGui)).Slots[1].Button
        button:FindFirstChild(name):Destroy()
        check(Gui.Slot(button) == nil, "slot rejects missing required " .. name)
        f.Root:Destroy()
    end
end

-- Supported authored slot locations and optional authored highlight.
do
    for _, wrapper in { "direct", "Items", "HotbarScroll" } do
        local f = fixture(true)
        local view = assert(Gui.Resolve(f.PlayerGui))
        check(#view.Slots == 9 and view.Slots[1].Selected == nil, "shipped background works without Selected")
        local button = view.Slots[1].Button
        local selected = new("ImageLabel", "SlotSelected", button)
        check(assert(Gui.Slot(button)).Selected == selected, "authored Selected still binds")
        selected:Destroy()
        if wrapper ~= "direct" then
            local parent = new(if wrapper == "Items" then "Frame" else "ScrollingFrame", wrapper, view.Bar)
            for _, slot in view.Slots do
                slot.Button.Parent = parent
            end
        end
        check(#assert(Gui.Resolve(f.PlayerGui)).Slots == 9, "supported slot location: " .. wrapper)
        f.Root:Destroy()
    end
end

do
    local f = fixture(true)
    local view = assert(Gui.Resolve(f.PlayerGui))
    local highlight = new("ImageLabel", "SlotSelected", view.Slots[1].Button)
    local tool = f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(not highlight.Visible, "authored selection starts unequipped")
    visible(f)[1].Activated:Fire()
    flush()
    check(tool.Parent == f.Character and highlight.Visible, "authored highlight still follows equipped Tool")
    stop()
    flush()
    check(not highlight.Visible, "authored highlight clears on release")
end

-- Resolve and render the actual currently mounted export, not a fabricated hierarchy.
do
    local f = fixture(false)
    f.Root:Destroy()
    local nodes = { [0] = f.PlayerGui }
    local actualBar
    for _, row in exportNodes do
        local object = new(row[3], row[4], nodes[row[2]])
        for key, value in row[5] do
            if key == "Size" or key == "Position" then
                object[key] = UDim2.new(table.unpack(value))
            elseif key == "TextSize" or key == "AspectRatio" then
                object[key] = tonumber(value)
            elseif key == "TextScaled" then
                object[key] = value == "true"
            else
                object[key] = value
            end
        end
        for key, value in row[6] do
            object:SetAttribute(key, value)
        end
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
            check(slot.ClassName == "TextButton", "actual slot class reported")
        end
    end
    check(slots == 9 and Gui.Resolve(f.PlayerGui) ~= nil, "actual newest export resolves nine authored buttons")
    local content = actualBar.Parent
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    if core.Enabled then
        print("Actual-export render warnings:", table.concat(warnings, "\n"))
    end
    check(
        not core.Enabled and cas.Actions.HotbarSelect ~= nil and not actualBar.Visible,
        "actual export hands off after empty render; unused bar hidden"
    )
    local generic = content
        :FindFirstChild("Upgrades")
        :FindFirstChild("UpgradeScroll")
        :FindFirstChild("UpgradeList")
        :FindFirstChild("CarryCapacityCard")
        :FindFirstChild("CarryCapacityCardContent")
        :FindFirstChild("Glossy Fruit Trio Sticker 1").Image
    local batImage = content
        :FindFirstChild("Upgrades")
        :FindFirstChild("UpgradeScroll")
        :FindFirstChild("UpgradeList")
        :FindFirstChild("BatCard")
        :FindFirstChild("BatCardContent")
        :FindFirstChild("Isolated Wooden Baseball Bat 1").Image
    local iceImage = content
        :FindFirstChild("Shop")
        :FindFirstChild("ShopScroll")
        :FindFirstChild("ShopList")
        :FindFirstChild("Ice Gun")
        :FindFirstChild("Ice GunContent")
        :FindFirstChild("IceGunImage").Image
    f.Tool("Apple", "Apple", 1)
    f.Tool("Missing", "Missing", 2)
    f.Tool("Smoothie")
    f.Tool("Bat"):SetAttribute("BatLevel", 1)
    f.Tool("Ray"):SetAttribute("IceGunWeapon", true)
    flush()
    local buttons = {}
    for _, button in actualBar:GetDescendants() do
        if button:IsA("GuiButton") and button.Visible then
            table.insert(buttons, button)
        end
    end
    table.sort(buttons, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    check(#buttons == 5, "mounted export rebuild contains every item category")
    for index, button in buttons do
        local icon = button:FindFirstChild("SlotIcon")
        local sources = if icon.Image ~= "" then 1 else 0
        for _, child in icon:GetChildren() do
            if child:IsA("ViewportFrame") then
                sources += 1
            end
        end
        check(
            icon.Image ~= templateImage and sources == 1,
            "actual mounted export has one non-template source per occupied slot"
        )
        if index == 4 or index == 5 then
            check(icon.Image == generic, "mounted export intentional fallback resolved")
        end
    end
    check(buttons[1]:FindFirstChild("SlotIcon").Image == batImage, "mounted bat card artwork resolved")
    check(buttons[2]:FindFirstChild("SlotIcon").Image == iceImage, "mounted ice ray artwork resolved")
    stop()
    flush()
end
do
    local f = fixture(true)
    local card = f.Desktop
        :FindFirstChild("Upgrades")
        :FindFirstChild("UpgradeScroll")
        :FindFirstChild("UpgradeList")
        :FindFirstChild("CarryCapacityCard")
    card:FindFirstChild("Glossy Fruit Trio Sticker 1").Image = templateImage
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(
        core.Enabled and cas.Actions.HotbarSelect == nil,
        "template cannot masquerade as intentional fallback after init clearing"
    )
    stop()
    flush()
    card:Destroy()
    check(Gui.Resolve(f.PlayerGui) == nil, "missing intentional fallback fails resolution")
end
do
    local f = fixture(false)
    local before = #warnings
    check(Gui.Resolve(f.PlayerGui) == nil, "incompatible hierarchy retains native")
    local warned = #warnings
    Gui.Resolve(f.PlayerGui)
    check(warned > before and #warnings == warned, "invalid slot warning once per instance")
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(core.Enabled and cas.Actions.HotbarSelect == nil, "resolution failure never binds keys")
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
        label(buttons[1]) == "Bat"
            and label(buttons[2]) == "Ice Gun"
            and label(buttons[11]) == "Smoothie"
            and label(buttons[12]) == "Smoothie",
        "category order and labels"
    )
    check(buttons[1]:GetChildren()[2].Image == "export-bat-art", "bat fallback resolved from authored card")
    check(previews - before == 8, "ingredient viewports once per distinct Tool")
    for i = 1, 8 do
        buttons[i + 2].Activated:Fire()
        flush()
        check(ingredients[i].Parent == f.Character, "CarryItemId order independent of child order")
    end
    check(previews - before == 8, "equip moves preserve bindings and renders")
    buttons[10].Activated:Fire()
    flush()
    local eq, uneq = f.Counts()
    check(eq == 8 and uneq == 1 and ingredients[8].Parent == f.Backpack, "button activation only equips/toggles")
    ingredients[3].Name = "Fresh Apple"
    flush()
    check(label(visible(f)[5]) == "Fresh Apple", "live ingredient label verbatim")
    visible(f)[11].Activated:Fire()
    flush()
    check(smoothie1.Parent == f.Character, "first smoothie selected")
    visible(f)[11].Activated:Fire()
    flush()
    visible(f)[11].Activated:Fire()
    flush()
    check(smoothie1.Parent == f.Character, "smoothie sequence retained across reparent moves")
    ingredients[1]:Destroy()
    flush()
    buttons = visible(f)
    check(
        #buttons == 11 and smoothie1.Parent == f.Character and label(buttons[10]) == "Smoothie",
        "selection follows Tool after index shift"
    )
    local scroll = f.Bar:FindFirstChildOfClass("ScrollingFrame")
    check(scroll.AbsoluteCanvasSize.X >= 11 * 48, "spacing-aware overflow canvas")
    check(buttons[1].AbsoluteSize.X >= 48, "named minimum target width")
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
    guiService.BottomInset = 0
    function guiService:GetGuiInset()
        return v(0, 36), v(0, self.BottomInset)
    end
    f.Player.GameplayPaused = true
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(smoothie1.Parent == f.Character, "paused ignores keyboard")
    f.Player.GameplayPaused = false
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Zero })
    flush()
    check(smoothie1.Parent == f.Backpack, "zero toggles the selected smoothie at visible index ten after shift")
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
    local respawnBinds = cas.Binds
    f.Player.CharacterAdded:Fire(nextCharacter)
    flush()
    check(cas.Binds == respawnBinds + 1, "respawn activates each number key once")
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
    f.Root.Pixels = v(320, 600)
    uis.TouchEnabled = true
    for i = 1, 12 do
        f.Tool("Apple", "Missing", i)
    end
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local buttons = visible(f)
    check(#buttons == 12 and buttons[1].AbsoluteSize.X >= 48, "phone targets keep 48px floor with scrolling")
    buttons[12].Activated:Fire()
    guiService.SelectedObject = buttons[12]
    flush()
    local scroll = f.Bar:FindFirstChildOfClass("ScrollingFrame")
    check(scroll.CanvasPosition.X > 0, "selected last slot scrolls fully into view")
    check(buttons[12]:GetChildren()[2].Image == "export-generic-art", "missing preview uses intentional fallback")
    stop()
    flush()
    uis.TouchEnabled = false
end
-- Aspect, label, hit-area and scrolling contracts use independent font bounds.
-- Actual glyph rasterization and safe insets remain Studio acceptance checks.
for _, viewport in { v(320, 568), v(768, 1024), v(800, 600), v(1920, 1080), v(1920, 1080) } do
    local f = fixture(true)
    f.Root.Pixels = viewport
    local longestName = "WWWWWWWWWWWWWWWWWWWW's Head"
    local tools = {}
    for i = 1, 12 do
        tools[i] = f.Tool(if i == 1 then longestName else "Apple", "Apple", i)
    end
    local before = cas.Binds
    local stop = Controller.Start(f.Player, f.PlayerGui)
    for _, slot in f.Bar:GetChildren() do
        if slot:IsA("GuiButton") then
            check(slot:FindFirstChild("SlotIcon").Image == "", "init clears every pooled template before first bind")
            check(not slot.Visible, "unbound slots are hidden before first render")
        end
    end
    check(cas.Actions.HotbarSelect == nil and core.Enabled, "before first render native keys remain untouched")
    flush()
    check(cas.Binds == before + 1, "activation binds one keyboard action")
    local scroll = f.Bar:FindFirstChildOfClass("ScrollingFrame")
    local outerWidth = f.Bar.AbsoluteSize.X
    local buttons = visible(f)
    check(#buttons == 12, "viewport sweep retains every occupied slot")
    for _, button in buttons do
        local icon, text = button:FindFirstChild("SlotIcon"), button:FindFirstChild("Label")
        local size, iconSize = button.AbsoluteSize, icon.AbsoluteSize
        check(math.abs(size.X / size.Y - 1) < 0.001, "authored slot ratio is viewport invariant")
        check(math.abs(iconSize.X / iconSize.Y - 1) < 0.001, "authored icon ratio is viewport invariant")
        check(
            button:FindFirstChildOfClass("UIAspectRatioConstraint")
                and icon:FindFirstChildOfClass("UIAspectRatioConstraint"),
            "aspect constraints cover only slot and icon"
        )
        check(
            text:FindFirstChildOfClass("UIAspectRatioConstraint") == nil,
            "labels remain flexible without aspect constraints"
        )
        check(size.X >= 48 and size.Y >= 48, "button hit area meets both floors")
        local floor = button:FindFirstChildOfClass("UISizeConstraint").MinSize
        check(floor.X == 48 and floor.Y == 48, "floor belongs to the authored button")
        check(button.Size.X.Offset == 0 and button.Size.Y.Offset == 0, "slot sizes use scale")
        check(icon.ScaleType == Enum.ScaleType.Fit, "image icons fit rather than stretch")
        local constraint = text:FindFirstChildOfClass("UITextSizeConstraint")
        check(
            text.TextScaled and text.TextWrapped and constraint.MinTextSize == 8 and constraint.MaxTextSize == 15,
            "text scales within authored bounds"
        )
        local required = measure(text.Text, constraint.MinTextSize, text.Font, text.AbsoluteSize)
        check(
            required.X <= text.AbsoluteSize.X + 0.01 and required.Y <= text.AbsoluteSize.Y + 0.01,
            "complete label fits at authored minimum"
        )
        check(
            text.Size.X.Scale <= 1 and text.Position.Y.Scale + text.Size.Y.Scale / 2 <= 1,
            "labels stay inside their slots"
        )
        check(
            icon.Image == "" and #icon:GetChildren() == 2,
            "one constrained viewport replaces template with no overlay stack"
        )
        check(
            icon:GetChildren()[2]:FindFirstChildOfClass("UIAspectRatioConstraint") ~= nil,
            "viewport inherits icon aspect"
        )
    end
    check(scroll.AbsoluteCanvasSize.X > scroll.AbsoluteWindowSize.X, "hit-area canvas overflows horizontally")
    check(
        outerWidth <= viewport.X * 0.9 and math.abs(outerWidth - viewport.X * 0.483333319) < 0.01,
        "floor leaves outer bar width bounded and unchanged"
    )
    local callback = cas.Actions.HotbarSelect
    for index, key in
        {
            Enum.KeyCode.One,
            Enum.KeyCode.Two,
            Enum.KeyCode.Three,
            Enum.KeyCode.Four,
            Enum.KeyCode.Five,
            Enum.KeyCode.Six,
            Enum.KeyCode.Seven,
            Enum.KeyCode.Eight,
            Enum.KeyCode.Nine,
            Enum.KeyCode.Zero,
        }
    do
        callback("", Enum.UserInputState.Begin, { KeyCode = key })
        flush()
        check(tools[index].Parent == f.Character, "1-9 and overflow 0 equip current visible tool without Selected")
    end
    buttons[12].Activated:Fire()
    guiService.SelectedObject = buttons[12]
    flush()
    check(scroll.CanvasPosition.X > 0, "selected overflow slot scrolls into view")
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(cas.Binds == before + 1, "rebuild never duplicates keyboard bindings")
    f.Player.CharacterRemoving:Fire(f.Character)
    flush()
    check(cas.Actions.HotbarSelect == nil, "character teardown removes keyboard actions")
    stop()
    flush()
    check(core.Enabled and cas.Actions.HotbarSelect == nil, "teardown restores native keyboard behavior")
    local authored = 0
    for _, child in f.Bar:GetChildren() do
        if child:IsA("GuiButton") then
            authored += 1
            check(
                not child.Visible and child:FindFirstChild("SlotIcon").Image == "",
                "released authored slots remain hidden and cleared"
            )
        end
    end
    check(
        authored == 9 and not f.Bar:FindFirstChildOfClass("ScrollingFrame"),
        "teardown removes all overflow clones and owned scrolling UI"
    )
end
do
    -- A non-square authored design proves the floor grows uniformly, rather
    -- than assuming all future exports are squares.
    local f = fixture(true)
    f.Root.Pixels = v(320, 568)
    for _, button in f.Bar:GetChildren() do
        if button:IsA("GuiButton") then
            button.Size = UDim2.fromScale(0.206896558, 1)
            button:FindFirstChild("SlotIcon").Size = UDim2.fromScale(0.46875, 0.625)
        end
    end
    f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local button = visible(f)[1]
    local icon = button:FindFirstChild("SlotIcon")
    check(
        math.abs(button.AbsoluteSize.X - 96) < 0.01 and math.abs(button.AbsoluteSize.Y - 48) < 0.01,
        "2:1 button uniformly grows to 96x48 floor"
    )
    check(
        math.abs(icon.AbsoluteSize.X / icon.AbsoluteSize.Y - 1.5) < 0.001,
        "non-square icon retains its own authored ratio"
    )
    stop()
    flush()
end
do
    local f = fixture(true)
    local item = f.Tool("Tool geometry", "Missing", 1)
    new("Part", "Handle", item)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local icon = visible(f)[1]:FindFirstChild("SlotIcon")
    check(
        icon.Image == "" and icon:FindFirstChild("HotbarToolPreview") ~= nil,
        "missing ingredient preview falls through to sanitized Tool geometry"
    )
    check(
        icon:FindFirstChild("HotbarToolPreview"):FindFirstChildOfClass("UIAspectRatioConstraint") ~= nil,
        "Tool render inherits host ratio"
    )
    item:FindFirstChild("Handle"):Destroy()
    item:SetAttribute("IngredientId", "OtherMissing")
    flush()
    -- OtherMissing is accepted by this preview double; the real shared pipeline
    -- separately allowlists IDs. Rebinding must dispose the Tool render first.
    check(
        icon:FindFirstChild("HotbarToolPreview") == nil and icon:FindFirstChild("IngredientPreview") ~= nil,
        "Tool render is removed before replacement ingredient render"
    )
    stop()
    flush()
end
do
    local f = fixture(true)
    -- Simulate Framewisp's responsive pass running before controller startup.
    for _, button in f.Bar:GetChildren() do
        if button:IsA("GuiButton") then
            local text = button:FindFirstChild("Label")
            text:SetAttribute("HotbarTextMin", 8)
            text:SetAttribute("HotbarTextMax", 15)
            text.TextSize = 2
        end
    end
    f.Tool("Dragon Fruit", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local text = visible(f)[1]:FindFirstChild("Label")
    check(
        text:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize == 8,
        "responsive export cannot shrink authored text minimum before init"
    )
    check(text:GetAttribute("FW_TextOwn") == true, "controller owns flexible label sizing across later export resizes")
    stop()
    flush()
end
do
    local f = fixture(true)
    local missing1 = f.Tool("Missing item", "Missing", 1)
    local missing2 = f.Tool("Missing again", "Missing", 2)
    local bat = f.Tool("bat")
    bat:SetAttribute("BatLevel", 1)
    local beforeWarnings = #warnings
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local function missingWarnings()
        local total = 0
        for i = beforeWarnings + 1, #warnings do
            if string.find(warnings[i], "missing icon for Missing", 1, true) then
                total += 1
            end
        end
        return total
    end
    check(missingWarnings() == 1, "intentional fallback reports missing id exactly once")
    check(
        visible(f)[2]:FindFirstChild("SlotIcon").Image == "export-generic-art",
        "fallback is intentional distinct export artwork"
    )
    local callback = cas.Actions.HotbarSelect
    for index, key in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three } do
        callback("", Enum.UserInputState.Begin, { KeyCode = key })
        flush()
        check(
            ({ bat, missing1, missing2 })[index].Parent == f.Character,
            "key equips Nth current visible Tool without Selected"
        )
    end
    local eq, uneq = f.Counts()
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Nine })
    local eq2, uneq2 = f.Counts()
    check(eq == eq2 and uneq == uneq2, "absent visible index has no equip effect")
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(bat.Parent == f.Character, "key one reaches pinned bat through click path")
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(bat.Parent == f.Backpack, "key uses exact click toggle path")
    local beforeRemoval = f.Counts()
    missing1.Parent = nil
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Two })
    local eq3 = f.Counts()
    check(eq3 == beforeRemoval, "removed Tool cannot be equipped before rebuild")
    flush()
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(bat.Parent == f.Character, "key remaps after current view order shifts")
    f.Tool("Another missing", "Missing", 3)
    flush()
    check(missingWarnings() == 1, "rebind does not repeat missing id report")
    -- Force reuse of a viewport slot for artwork, then reuse it for a viewport.
    for _, tool in f.Backpack:GetChildren() do
        tool:Destroy()
    end
    bat:Destroy()
    flush()
    local fresh = f.Tool("Apple", "Apple", 4)
    flush()
    local icon = visible(f)[1]:FindFirstChild("SlotIcon")
    check(icon.Image == "" and #icon:GetChildren() == 2, "artwork rebind clears source before viewport")
    fresh:SetAttribute("IngredientId", "Missing")
    flush()
    check(
        icon.Image == "export-generic-art" and #icon:GetChildren() == 1,
        "viewport rebind disposes old render before artwork"
    )
    fresh:SetAttribute("IngredientId", "Apple")
    flush()
    check(icon.Image == "" and #icon:GetChildren() == 2, "repeated rebind leaves exactly one live source")
    for _, button in visible(f) do
        check(
            button:FindFirstChild("SlotIcon").Image ~= templateImage,
            "template absent after equipment changes and full rebuild"
        )
    end
    stop()
    flush()
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
-- Startup, transient measurements, and ownership recovery use the real controller.
uis.TouchEnabled = true
for _, pixels in { v(390, 844), v(844, 390) } do
    local f = fixture(true)
    f.Root.Pixels = pixels
    f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    check(core.Enabled and not f.Bar.Visible, "cold start exposes only the native hotbar before handoff")
    flush()
    check(
        not core.Enabled and f.Bar.Visible and #visible(f) == 1 and cas.Actions.HotbarSelect,
        "cold start exposes only the usable custom hotbar without an orientation change"
    )
    stop()
    flush()
end
for _, pixels in { v(390, 844), v(844, 390) } do
    local f = fixture(true)
    f.Root.Pixels = v(0, 0)
    local tool = f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local screen = f.Bar.Parent
    local scroll = f.Bar:FindFirstChild("HotbarScroll")
    check(core.Enabled and not cas.Actions.HotbarSelect, "zero cold start leaves native access")
    -- Emulate the previous scroll measurement surviving the parent write.
    scroll.Pixels = v(1200, 800)
    f.Root.Pixels = pixels
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    local button = visible(f)[1]
    check(core.Enabled, "stale scroll measurement cannot finish the first handoff")
    local expectedWidth = f.Bar.AbsoluteSize.X
    check(button.Size.X.Scale >= 48 / expectedWidth, "slot floor derives from new bar bounds, not stale scroll")
    scroll.Pixels = nil
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    check(not core.Enabled and cas.Actions.HotbarSelect, "cold start hands off after usable geometry")
    button.Activated:Fire()
    flush()
    scroll.CanvasPosition = v(20, 0)
    local keys = cas.Actions.HotbarSelect
    f.Root.Pixels = v(0, 0)
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    check(not core.Enabled and cas.Actions.HotbarSelect == keys, "transient zero keeps custom ownership and input")
    f.Root.Pixels = pixels
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    timers()
    check(f.Bar.Parent == screen and f.Bar:FindFirstChild("HotbarScroll") == scroll, "resize retains same usable UI")
    check(visible(f)[1] == button and tool.Parent == f.Character, "resize retains selection and authored slot")
    stop()
    flush()
end
uis.TouchEnabled = false
for _, resetRequestedState in { false, true } do
    local f = fixture(true)
    uis.TouchEnabled = true
    f.Root.Pixels = v(844, 390)
    f.Tool("Apple", "Apple", 1)
    core.NativeVisible, core.DeferNativeUpdate = true, true
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(not core.Enabled and f.Bar.Visible, "mobile handoff initially verifies the requested state")
    check(core.NativeVisible, "native UI can still be visible while the request is already disabled")
    -- Late Roblox startup may leave the rendering stale or reset the request
    -- silently. Neither requires a viewport, inventory, or orientation change.
    core.Enabled = resetRequestedState
    core.DeferNativeUpdate = false
    timers()
    check(not core.Enabled and not core.NativeVisible and f.Bar.Visible, "cold start settles to custom only")
    local calls = #core.Calls
    timers()
    check(#core.Calls == calls, "successful mobile handoff verification is bounded")
    stop()
    timers()
    check(core.Enabled and core.NativeVisible and not f.Bar.Visible, "teardown restores native access")
    core.NativeVisible = nil
    uis.TouchEnabled = false
end
do
    local f = fixture(true)
    uis.TouchEnabled = true
    f.Root.Pixels = v(844, 390)
    f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    stop()
    timers()
    check(core.Enabled and not f.Bar.Visible, "pending startup reassertions cannot undo native fallback")
    uis.TouchEnabled = false
end
do
    local f = fixture(true)
    f.Tool("Apple", "Apple", 1)
    core.IgnoreWrite = true
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    for _ = 1, 10 do
        timers()
    end
    check(
        core.Enabled and not f.Bar.Visible and not cas.Actions.HotbarSelect,
        "unverified disable falls back to one native interface"
    )
    local calls = #core.Calls
    timers()
    check(#core.Calls == calls, "failed handoff has bounded retries")
    core.IgnoreWrite = false
    f.PlayerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Fire()
    flush()
    check(not core.Enabled and f.Bar.Visible, "later lifecycle retries an exhausted handoff")
    -- A public layout event can recheck ownership after a CoreGui state change.
    core.Enabled = true
    guiService:GetPropertyChangedSignal("TopbarInset"):Fire()
    flush()
    check(not core.Enabled and f.Bar.Visible, "public layout event reasserts a usable custom hotbar")
    stop()
    flush()
end
do
    local f = fixture(true)
    f.Tool("Apple", "Apple", 1)
    core.Fail = true
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local oldHost = f.Bar.Parent
    oldHost:Destroy()
    flush()
    core.Fail = false
    local replacement = fixture(true)
    replacement.Tool("Pear", "Pear", 2)
    local stopReplacement = Controller.Start(replacement.Player, replacement.PlayerGui)
    flush()
    timers()
    stop()
    timers()
    check(not core.Enabled and replacement.Bar.Visible, "old handoff and teardown cannot undo replacement ownership")
    stopReplacement()
    flush()
end
do
    local f = fixture(true)
    f.Tool("Apple", "Apple", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    core.Fail = true
    stop()
    flush()
    check(not core.Enabled, "failed native restoration remains unconfirmed")
    core.Fail = false
    timers()
    check(core.Enabled, "pending native restoration retries after teardown")
end
do
    local f = fixture(true)
    f.Root.Pixels = v(390, 844)
    for i = 1, 12 do
        f.Tool("Apple", "Apple", i)
    end
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local screen, scroll = f.Bar.Parent, f.Bar:FindFirstChild("HotbarScroll")
    local button = visible(f)[12]
    button.Activated:Fire()
    guiService.SelectedObject = button
    flush()
    local position = scroll.CanvasPosition.X
    check(position > 0, "overflow selection begins in a valid scrolled position")
    f.Root.Pixels = v(0, 0)
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    f.Root.Pixels = v(390, 844)
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    check(
        scroll.CanvasPosition.X == position and guiService.SelectedObject == button,
        "transient geometry retains scroll and gamepad selection"
    )
    screen.Visible = false
    flush()
    check(core.Enabled and not f.Bar.Visible, "hidden host restores native access")
    screen.Visible = true
    flush()
    check(not core.Enabled and #visible(f) == 12, "same healthy host regains ownership after visibility recovery")
    f.Root.Pixels = v(0, 0)
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    timers()
    check(core.Enabled and not f.Bar.Visible, "persistent pending bounds restore native after bounded recovery")
    f.Root.Pixels = v(844, 390)
    screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    check(not core.Enabled and #visible(f) == 12, "valid bounds recover all overflow tools without respawn")
    stop()
    flush()
end
do
    local f = fixture(true)
    local tool = f.Tool("Apple", "Apple", 1)
    core.ReadFail = true
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(not core.Enabled and cas.Actions.HotbarSelect, "unavailable CoreGui reads retain usable custom input")
    visible(f)[1].Activated:Fire()
    flush()
    check(tool.Parent == f.Character, "unknown CoreGui state never blocks custom tool access")
    core.ReadFail = false
    timers()
    check(not core.Enabled, "read availability verifies the handoff")
    stop()
    flush()
end
do
    local f = fixture(true)
    local first = f.Tool("Apple", "Apple", 1)
    local root = f.Root
    root.Parent = nil
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    check(core.Enabled and not cas.Actions.HotbarSelect, "late Framewisp keeps native available")
    root.Parent = f.PlayerGui
    flush()
    check(not core.Enabled and #visible(f) == 1, "late export uses normal setup without rotation")
    -- Replace the authored hierarchy in the same session during a failed handoff.
    core.Enabled = true
    core.Fail = true
    guiService:GetPropertyChangedSignal("TopbarInset"):Fire()
    flush()
    root.Parent = nil
    flush()
    local replacement = fixture(true)
    replacement.Root.Parent = f.PlayerGui
    core.Fail = false
    flush()
    timers()
    check(not core.Enabled and replacement.Bar.Visible, "same-session UI replacement completes pending ownership")
    visible(replacement)[1].Activated:Fire()
    flush()
    check(first.Parent == f.Character, "replacement binds the existing player's inventory once")
    stop()
    flush()
end
do
    local f = fixture(true)
    f.Tool("Apple", "Apple", 1)
    f.PlayerGui.Parent = nil
    services.Players.LocalPlayer = f.Player
    Controller.Init()
    flush()
    check(core.Enabled, "Init subscribes before late PlayerGui arrival")
    f.PlayerGui.Parent = f.Player
    flush()
    check(not core.Enabled and #visible(f) == 1, "late PlayerGui starts the normal session")
    f.PlayerGui.Parent = nil
    flush()
    check(core.Enabled, "removed PlayerGui releases ownership")
    local nextGui = new("PlayerGui", "ReplacementGui", f.Player)
    f.Root.Parent = nextGui
    flush()
    check(not core.Enabled and #visible(f) == 1, "replacement PlayerGui starts one healthy session")
    Controller.Destroy()
    flush()
    check(core.Enabled and not cas.Actions.HotbarSelect, "Init lifecycle teardown restores native")
end

-- Weapon pinning compacts present items; no reserved gaps.
do
    local f = fixture(true)
    local ingredient = f.Tool("Apple", "Apple", 1)
    local ice = f.Tool("Ray")
    ice:SetAttribute("IceGunWeapon", true)
    local bat = f.Tool("Bat")
    bat:SetAttribute("BatLevel", 1)
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local callback = cas.Actions.HotbarSelect
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    flush()
    check(bat.Parent == f.Character, "key one selects pinned bat")
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Two })
    flush()
    check(ice.Parent == f.Character, "key two selects pinned ice ray")
    bat:Destroy()
    flush()
    check(
        label(visible(f)[1]) == "Ice Gun" and label(visible(f)[2]) == "Apple",
        "absent bat compacts ice then ingredient"
    )
    ice:Destroy()
    flush()
    check(label(visible(f)[1]) == "Apple", "absent weapons leave no reserved gaps")
    local nextBat = f.Tool("Bat")
    nextBat:SetAttribute("BatLevel", 1)
    flush()
    check(label(visible(f)[2]) == "Apple", "absent ice places ingredients directly after bat")
    stop()
    flush()
end
print("Hotbar contracts passed:", count)
