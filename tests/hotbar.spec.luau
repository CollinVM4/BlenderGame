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
local floatVectors = true
local vector2Meta = {}
vector2Meta.__add = function(a, b)
    return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, vector2Meta)
end
vector2Meta.__sub = function(a, b)
    return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, vector2Meta)
end
vector2Meta.__mul = function(a, b)
    return setmetatable(
        { X = a.X * (if type(b) == "number" then b else b.X), Y = a.Y * (if type(b) == "number" then b else b.Y) },
        vector2Meta
    )
end
vector2Meta.__div = function(a, b)
    return setmetatable({ X = a.X / b, Y = a.Y / b }, vector2Meta)
end
vector2Meta.__index = {
    Dot = function(a, b)
        return a.X * b.X + a.Y * b.Y
    end,
}
local function v(x, y)
    if floatVectors then
        x = (string.unpack("f", string.pack("f", x)))
        y = (string.unpack("f", string.pack("f", y)))
    end
    return setmetatable({ X = x, Y = y }, vector2Meta)
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
            coroutine.wrap(fn)()
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
        AnchorPoint = v(0, 0),
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
                    return if props.Parent then props.Parent.AbsoluteSize else v(1200, 800)
                end
                local pixels = if props.Parent then props.Parent.AbsoluteSize else v(1200, 800)
                if props.Parent and props.Parent:IsA("ScrollingFrame") then
                    local canvas = props.Parent.AbsoluteCanvasSize
                    pixels = v(math.max(pixels.X, canvas.X), math.max(pixels.Y, canvas.Y))
                end
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
                if props.ScreenPosition then
                    return props.ScreenPosition
                end
                if not props.Parent then
                    return v(0, 0)
                end
                local p = props.Parent
                local size, pixels, origin = object.AbsoluteSize, p.AbsoluteSize, p.AbsolutePosition
                return v(
                    origin.X
                        + pixels.X * props.Position.X.Scale
                        + props.Position.X.Offset
                        - size.X * props.AnchorPoint.X
                        - p.CanvasPosition.X,
                    origin.Y
                        + pixels.Y * props.Position.Y.Scale
                        + props.Position.Y.Offset
                        - size.Y * props.AnchorPoint.Y
                )
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
local debugSignal = signal()
local debugMessages = {}
local textChat = new("TextChatService")
local textChannels = new("Folder", "TextChannels", textChat)
local systemChannel = new("TextChannel", "RBXSystem", textChannels)
function systemChannel:DisplaySystemMessage(message)
    table.insert(debugMessages, message)
end
local services = {
    StarterGui = core,
    ContextActionService = cas,
    UserInputService = uis,
    GuiService = guiService,
    Players = {},
    ReplicatedStorage = {
        Shared = new("Folder", "Shared"),
    },
    TextChatService = textChat,
}
services.ReplicatedStorage.Shared.IngredientPreviewGeometry = "Geometry"
local debugFolder = new("Folder", "Events", services.ReplicatedStorage.Shared)
local debugRemote = new("RemoteEvent", "HotbarDebug", debugFolder)
debugRemote.OnClientEvent = debugSignal
local testWorkspace = new("Workspace")
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
        GetFullName = function()
            return "Player.PlayerScripts.Client.Controllers.HotbarController"
        end,
        Parent = {
            UIRegistry = "UIRegistry",
            Parent = {
                UI = {
                    HotbarGui = "HotbarGui",
                    IngredientViewport = "IngredientViewport",
                    UIRegistry = "UIRegistry",
                    MobileControlLayout = "MobileControlLayout",
                    HotbarDiagnostic = "HotbarDiagnostic",
                },
            },
        },
    }
    local fn = assert(loadstring(sources[name], name))
    setfenv(
        fn,
        setmetatable({
            script = script,
            workspace = testWorkspace,
            print = if name == "HotbarDiagnostic" then function() end else print,
            require = requireModule,
            game = {
                PlaceVersion = 1,
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
            Rect = {
                new = function(a, b)
                    return { Min = a, Max = b }
                end,
            },
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
local cases = 0
local function fixture(width, height, touch)
    core.Enabled, core.Fail, core.ReadFail, core.IgnoreWrite = true, false, false, false
    table.clear(core.Calls)
    table.clear(cas.Buttons)
    uis.TouchEnabled, uis.GamepadEnabled, uis.Focus = touch or false, false, nil
    guiService.MenuIsOpen, guiService.SelectedObject = false, nil
    local f = {}
    f.Player = new("Player", "Player")
    f.PlayerGui = new("PlayerGui", "PlayerGui", f.Player)
    f.PlayerGui.Pixels = v(width or 1200, height or 800)
    f.PlayerGui.CurrentScreenOrientation = if (width or 1200) < (height or 800) then "Portrait" else "LandscapeLeft"
    f.Backpack = new("Backpack", "Backpack", f.Player)
    f.Equips, f.Unequips = 0, 0
    function f.CharacterModel()
        local character = new("Model", "Character")
        local humanoid = new("Humanoid", "Humanoid", character)
        function humanoid:UnequipTools()
            f.Unequips += 1
            for _, tool in character:GetChildren() do
                if tool:IsA("Tool") then
                    tool.Parent = f.Backpack
                    tool.Unequipped:Fire()
                end
            end
        end
        function humanoid:EquipTool(tool)
            f.Equips += 1
            self:UnequipTools()
            tool.Parent = character
            tool.Equipped:Fire()
        end
        return character, humanoid
    end
    f.Character, f.Humanoid = f.CharacterModel()
    f.Player.Character = f.Character
    function f.Tool(kind, key, name)
        local tool = new("Tool", name or (if kind == "Ingredient" then "Strawberry" else kind))
        if kind == "Ice" then
            tool:SetAttribute("IceGunWeapon", true)
        elseif kind == "Bat" then
            tool:SetAttribute("BatLevel", 1)
        elseif kind == "Ingredient" then
            tool:SetAttribute("IngredientId", "Strawberry")
            tool:SetAttribute("CarryItemId", key)
        end
        tool.Parent = f.Backpack
        return tool
    end
    function f.Start()
        f.Stop = Controller.Start(f.Player, f.PlayerGui)
        f.Root = f.PlayerGui:FindFirstChild(Gui.Name)
        f.Safe = f.Root:FindFirstChild("SafeArea")
        f.Bar = f.Safe:FindFirstChild("Hotbar")
        f.Scroll = f.Bar:FindFirstChild("HotbarScroll")
        flush()
        return f
    end
    function f.Resize(w, h)
        f.PlayerGui.Pixels = v(w, h)
        f.Safe:GetPropertyChangedSignal("AbsoluteSize"):Fire()
        flush()
    end
    function f.Slots()
        local result = {}
        for _, child in f.Scroll:GetChildren() do
            if child:IsA("GuiButton") and child.Visible then
                table.insert(result, child)
            end
        end
        table.sort(result, function(a, b)
            return a.LayoutOrder < b.LayoutOrder
        end)
        return result
    end
    return f
end
local function named(button, name)
    return button:FindFirstChild(name)
end
local function selected(button)
    return named(button, "Selected").Visible
end
local function writes(value)
    local result = 0
    for _, call in core.Calls do
        if call == value then
            result += 1
        end
    end
    return result
end
local function run(group, name, fn)
    if testCase ~= "all" and testCase ~= group then
        return
    end
    fn()
    cases += 1
    print("PASS", group, name)
end
for _, dimensions in { { 390, 844 }, { 844, 390 }, { 320, 568 }, { 740, 360 }, { 1920, 1080 } } do
    for _, late in { false, true } do
        run(
            "startup",
            string.format("%dx%d %s Ice Gun", dimensions[1], dimensions[2], if late then "late" else "early"),
            function()
                local f = fixture(dimensions[1], dimensions[2], true)
                local tool = if not late then f.Tool("Ice") else nil
                f.Start()
                check(
                    f.Root.ResetOnSpawn == false and f.Root.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets,
                    "persistent dedicated safe root"
                )
                if late then
                    check(
                        core.Enabled and not f.Bar.Visible and not cas.Actions.HotbarSelect,
                        "empty join retains native access"
                    )
                    tool = f.Tool("Ice")
                    flush()
                end
                local slots = f.Slots()
                check(
                    #slots == 1 and f.Bar.Visible and not core.Enabled,
                    "standalone startup presents one Ice Gun without export or timers"
                )
                check(named(slots[1], "Icon").Image == Gui.Art.Ice, "direct Ice Gun artwork")
                check(
                    slots[1].AbsoluteSize.X >= 48 and slots[1].AbsoluteSize.X == slots[1].AbsoluteSize.Y,
                    "square touch target"
                )
                check(f.Bar.AbsoluteSize.X <= f.Safe.AbsoluteSize.X, "mounted safe width")
                slots[1].Activated:Fire()
                flush()
                check(tool.Parent == f.Character and selected(slots[1]), "pre-plot Ice Gun taps through Humanoid")
                check(writes(false) == 1, "one successful handoff")
                f.Stop()
            end
        )
    end
end
run("startup", "prepared export still mounts other screens", function()
    local sawDesktop, sawUpgrades, sawShop = false, false, false
    check(not table.find(exportNames, "Hotbar"), "shipped export has no legacy hotbar")
    for _, name in exportNames do
        sawDesktop = sawDesktop or name == "Be a Blender! Desktop"
        sawUpgrades = sawUpgrades or name == "Upgrades"
        sawShop = sawShop or name == "Shop"
    end
    check(sawDesktop and sawUpgrades and sawShop, "other Framewisp screens preserved")
end)
run("startup", "optional preview may suspend without blocking takeover", function()
    local original = ingredientViewport.Create
    local suspended
    ingredientViewport.Create = function()
        suspended = coroutine.running()
        coroutine.yield()
        return nil
    end
    local f = fixture(390, 844, true)
    f.Tool("Ingredient", 1)
    f.Start()
    check(suspended ~= nil and not core.Enabled and f.Bar.Visible, "preview suspension cannot hold handoff")
    check(named(f.Slots()[1], "Icon").Image == Gui.Art.Generic, "fallback remains available while preview loads")
    f.Slots()[1].Activated:Fire()
    flush()
    check(f.Equips == 1, "fallback slot is selectable")
    f.Stop()
    check(coroutine.resume(suspended), "stale preview may finish after teardown")
    ingredientViewport.Create = original
end)
run("input", "classification ordering and identity through equip", function()
    local f = fixture()
    local smoothie = f.Tool("Smoothie")
    local high = f.Tool("Ingredient", 9, "Very long ingredient name which must truncate")
    local ice = f.Tool("Ice")
    local low = f.Tool("Ingredient", 2)
    local bat = f.Tool("Bat")
    local unsupported = f.Tool("Unknown")
    f.Start()
    local slots = f.Slots()
    check(#slots == 5, "only supported Tools")
    check(named(slots[1], "Label").Text == "Bat" and named(slots[2], "Label").Text == "Ice Gun", "Bat then Ice")
    check(
        named(slots[3], "Label").Text == low.Name
            and named(slots[4], "Label").Text == high.Name
            and named(slots[5], "Label").Text == "Smoothie",
        "CarryItemId order then Smoothie"
    )
    check(
        named(slots[4], "Label").TextTruncate == Enum.TextTruncate.AtEnd
            and slots[4].Size.X.Offset == slots[1].Size.X.Offset,
        "long names cannot resize slots"
    )
    slots[2].Activated:Fire()
    flush()
    check(
        ice.Parent == f.Character and #f.Slots() == 5 and f.Slots()[2] == slots[2],
        "equipping moves one Tool without duplicating identity"
    )
    slots[2].Activated:Fire()
    flush()
    check(ice.Parent == f.Backpack and not selected(slots[2]), "second selection unequips")
    slots[3].Activated:Fire()
    flush()
    check(low.Parent == f.Character, "ingredient ordering maps to correct Tool")
    low:SetAttribute("CarryItemId", 12)
    flush()
    check(f.Slots()[4] == slots[3], "reordering preserves Tool button identity")
    check(writes(false) == 1, "equip and Tool changes never repeat successful disable")
    f.Stop()
end)
run("input", "keyboard guards and zero shortcut", function()
    local f = fixture()
    local tools = {}
    for i = 1, 10 do
        tools[i] = f.Tool("Ingredient", i)
    end
    f.Start()
    local function press(code, state)
        return cas.Actions.HotbarSelect(ACTION, state or Enum.UserInputState.Begin, { KeyCode = code })
    end
    check(
        press(Enum.KeyCode.Zero) == Enum.ContextActionResult.Sink and tools[10].Parent == f.Character,
        "zero selects tenth supported item"
    )
    check(
        press(Enum.KeyCode.One) == Enum.ContextActionResult.Sink and tools[1].Parent == f.Character,
        "number shortcut"
    )
    local countBefore = f.Equips
    guiService.MenuIsOpen = true
    check(press(Enum.KeyCode.Two) == Enum.ContextActionResult.Pass, "menu releases keys")
    f.Slots()[2].Activated:Fire()
    guiService.MenuIsOpen = false
    f.Player.GameplayPaused = true
    check(press(Enum.KeyCode.Two) == Enum.ContextActionResult.Pass, "pause releases keys")
    f.Slots()[2].Activated:Fire()
    f.Player.GameplayPaused = false
    uis.Focus = {}
    check(press(Enum.KeyCode.Two) == Enum.ContextActionResult.Pass, "chat releases keys")
    f.Slots()[2].Activated:Fire()
    uis.Focus = nil
    check(f.Equips == countBefore, "guards protect both keyboard and activation")
    check(
        press(Enum.KeyCode.Two, Enum.UserInputState.End) == Enum.ContextActionResult.Sink and f.Equips == countBefore,
        "only Begin equips"
    )
    f.Humanoid.Health = 0
    f.Slots()[2].Activated:Fire()
    check(f.Equips == countBefore, "dead Humanoid guard")
    f.Humanoid.Health = 100
    tools[2].Parent = nil
    f.Slots()[2].Activated:Fire()
    check(
        press(Enum.KeyCode.Two) == Enum.ContextActionResult.Pass and f.Equips == countBefore,
        "stale Tool guard before render"
    )
    flush()
    f.Stop()
end)
run("input", "controller links focus reveal and activation", function()
    local f = fixture(390, 844, true)
    for i = 1, 9 do
        f.Tool("Ingredient", i)
    end
    f.Start()
    local slots = f.Slots()
    check(
        slots[1].NextSelectionLeft == slots[1] and slots[9].NextSelectionRight == slots[9],
        "controller endpoints stay in bar"
    )
    check(
        slots[2].NextSelectionLeft == slots[1] and slots[2].NextSelectionRight == slots[3],
        "ordered controller navigation"
    )
    guiService.SelectedObject = slots[9]
    flush()
    check(f.Scroll.CanvasPosition.X > 0, "changed focus reveals ninth slot")
    slots[9].Activated:Fire()
    flush()
    check(selected(slots[9]) and f.Equips == 1, "controller activation uses Humanoid")
    f.Scroll.CanvasPosition = v(0, 0)
    guiService:GetPropertyChangedSignal("SelectedObject"):Fire()
    flush()
    check(f.Scroll.CanvasPosition.X == 0, "unchanged focus never snaps scroll")
    f.Stop()
end)
run("overflow", "nine slots remain swipeable while first equipped", function()
    local f = fixture(390, 844, true)
    local tools = {}
    for i = 1, 9 do
        tools[i] = f.Tool("Ingredient", i)
    end
    f.Start()
    local slots = f.Slots()
    slots[1].Activated:Fire()
    flush()
    check(tools[1].Parent == f.Character, "slot one equipped")
    local max = f.Scroll.CanvasSize.X.Offset - f.Bar.AbsoluteSize.X
    check(max > 0, "narrow phone uses horizontal overflow")
    f.Scroll.CanvasPosition = v(max, 0)
    tools[1].Name = "Renamed"
    flush()
    check(f.Scroll.CanvasPosition.X == max, "routine renders preserve swipe with first equipped")
    f.Resize(0, 0)
    check(
        not core.Enabled and f.Bar.Visible and f.Scroll.CanvasPosition.X == max,
        "zero bounds preserve working ownership and scroll"
    )
    f.Resize(360, 780)
    local max2 = math.max(0, f.Scroll.CanvasSize.X.Offset - f.Bar.AbsoluteSize.X)
    check(f.Scroll.CanvasPosition.X == math.min(max, max2), "rotation clamps without snapping to equipped slot")
    check(f.Slots()[1] == slots[1] and f.Slots()[9] == slots[9], "rotation retains slots")
    f.Scroll.CanvasPosition = v(max2, 0)
    local ninth = slots[9].AbsolutePosition.X + slots[9].AbsoluteSize.X
    check(
        ninth <= f.Scroll.AbsolutePosition.X + f.Scroll.AbsoluteSize.X + 0.001,
        "ninth target fully inside scroll at end"
    )
    slots[9].Activated:Fire()
    flush()
    check(tools[9].Parent == f.Character, "ninth slot tappable")
    f.Resize(844, 390)
    f.Resize(390, 844)
    check(writes(false) == 1 and selected(slots[9]), "orientation changes preserve selection and one-time handoff")
    for i = 2, 9 do
        tools[i]:Destroy()
    end
    flush()
    check(f.Scroll.CanvasPosition.X == 0, "smaller inventory clamps old scroll range")
    f.Stop()
end)
run("lifecycle", "same root across empty inventory respawn and new Backpack", function()
    local f = fixture(390, 844, true)
    local ice = f.Tool("Ice")
    f.Start()
    local root = f.Root
    ice:Destroy()
    flush()
    check(not core.Enabled and not f.Bar.Visible, "empty inventory after takeover stays custom-owned")
    local oldCharacter = f.Character
    f.Player.CharacterRemoving:Fire(f.Character)
    f.Player.Character = nil
    flush()
    f.Backpack:Destroy()
    f.Backpack = new("Backpack", "NewBackpack", f.Player)
    f.Character, f.Humanoid = f.CharacterModel()
    f.Player.Character = f.Character
    f.Player.CharacterAdded:Fire(f.Character)
    local replacement = f.Tool("Ice")
    flush()
    check(
        f.PlayerGui:FindFirstChild(Gui.Name) == root and #f.Slots() == 1,
        "respawn retains one view with actual new Tools"
    )
    f.Slots()[1].Activated:Fire()
    flush()
    check(replacement.Parent == f.Character, "new Character binding equips")
    local stale = new("Tool", "StaleIce", oldCharacter)
    stale:SetAttribute("IceGunWeapon", true)
    flush()
    check(#f.Slots() == 1 and writes(false) == 1, "old Character Tools cannot affect the replacement inventory")
    f.Stop()
    check(
        core.Enabled and not cas.Actions.HotbarSelect and f.PlayerGui:FindFirstChild(Gui.Name) == nil,
        "teardown restores native and removes custom inputs/view"
    )
end)
run("lifecycle", "Init is idempotent and follows PlayerGui replacement", function()
    local f = fixture()
    services.Players.LocalPlayer = f.Player
    f.Tool("Ice")
    Controller.Init()
    Controller.Init()
    flush()
    local first = f.PlayerGui:FindFirstChild(Gui.Name)
    check(first ~= nil and #f.PlayerGui:GetChildren() == 1, "one dedicated view after repeated Init")
    f.PlayerGui.Parent = nil
    flush()
    check(core.Enabled and first.Destroyed, "PlayerGui replacement retires old view")
    f.PlayerGui = new("PlayerGui", "ReplacementGui", f.Player)
    flush()
    check(
        not core.Enabled and f.PlayerGui:FindFirstChild(Gui.Name) ~= nil,
        "replacement PlayerGui gets one working view"
    )
    Controller.Destroy()
    flush()
    check(core.Enabled and not cas.Actions.HotbarSelect, "Destroy releases lifecycle inputs")
end)
run("fallback", "disabled detached damaged and undersized view recovers", function()
    local f = fixture(390, 844, true)
    f.Tool("Ice")
    f.Start()
    local function native()
        check(core.Enabled and not cas.Actions.HotbarSelect and not f.Bar.Visible, "native fallback usable")
    end
    local function custom()
        check(not core.Enabled and cas.Actions.HotbarSelect and f.Bar.Visible, "same view recovered")
    end
    f.Root.Enabled = false
    flush()
    native()
    f.Root.Enabled = true
    flush()
    custom()
    f.Root.Parent = nil
    flush()
    native()
    f.Root.Parent = f.PlayerGui
    flush()
    custom()
    f.Bar.Visible = false
    flush()
    native()
    f.Bar.Visible = true
    flush()
    custom()
    local icon = named(f.Slots()[1], "Icon")
    icon.Parent = nil
    flush()
    native()
    icon.Parent = f.Slots()[1]
    flush()
    custom()
    f.Resize(40, 100)
    native()
    f.Resize(390, 844)
    custom()
    f.Slots()[1].Activated:Fire()
    flush()
    check(f.Equips == 1, "recovery preserves slot input")
    f.Stop()
end)
run("fallback", "failed CoreGui call bounded retry and recovery", function()
    local f = fixture(390, 844, true)
    f.Tool("Ice")
    core.Fail = true
    f.Start()
    check(core.Enabled and not f.Bar.Visible and not cas.Actions.HotbarSelect, "failed disable leaves native active")
    core.Fail = false
    timers()
    check(not core.Enabled and f.Bar.Visible and cas.Actions.HotbarSelect, "CoreGui-only retry recovers")
    local calls = writes(false)
    for _ = 1, 10 do
        timers()
    end
    f.Resize(844, 390)
    f.Tool("Bat")
    flush()
    check(writes(false) == calls, "successful disable has no delayed reassertion")
    f.Stop()
end)
run("fallback", "CoreGui failures exhaust one budget and readiness resets it", function()
    local f = fixture()
    f.Tool("Ice")
    core.Fail = true
    f.Start()
    for _ = 1, 12 do
        timers()
    end
    check(writes(false) == 8 and core.Enabled and not cas.Actions.HotbarSelect, "eight attempts maximum")
    f.Resize(1000, 800)
    f.Tool("Bat")
    flush()
    timers()
    check(writes(false) == 8, "routine layout/Tools do not replenish API budget")
    f.Root.Enabled = false
    flush()
    core.Fail = false
    f.Root.Enabled = true
    flush()
    check(not core.Enabled and f.Bar.Visible, "new usable-view transition recovers exhausted handoff")
    f.Stop()
end)
run("fallback", "read errors do not reject successful CoreGui write", function()
    local f = fixture()
    f.Tool("Ice")
    core.ReadFail = true
    f.Start()
    check(
        not core.Enabled and f.Bar.Visible and cas.Actions.HotbarSelect,
        "successful write allows usable custom bar despite read error"
    )
    debugSignal:Fire(false)
    local message = debugMessages[#debugMessages]
    check(
        string.find(message, "place v1", 1, true)
            and string.find(message, "owner=custom", 1, true)
            and string.find(message, "CoreGui state unavailable", 1, true),
        "concise QA report includes place owner and read error"
    )
    core.ReadFail = false
    f.Stop()
end)
run("fallback", "malformed ingredient recovers on replicated attributes", function()
    local f = fixture()
    local tool = f.Tool("Ingredient", nil)
    f.Start()
    check(core.Enabled and not cas.Actions.HotbarSelect, "invalid CarryItemId retains native")
    tool:SetAttribute("CarryItemId", 1)
    flush()
    check(not core.Enabled and #f.Slots() == 1, "attribute completion triggers handoff")
    for _, invalid in { 0, -1, 1.5, math.huge, 0 / 0, "1" } do
        tool:SetAttribute("CarryItemId", invalid)
        flush()
        check(core.Enabled and not cas.Actions.HotbarSelect, "malformed CarryItemId releases custom selection")
    end
    tool:SetAttribute("CarryItemId", 2)
    flush()
    check(not core.Enabled and #f.Slots() == 1, "valid Tool recovery")
    f.Stop()
end)
run("startup", "live mobile controls have clear lane and late mounting adjusts it", function()
    for _, bounds in { { 390, 844 }, { 844, 390 } } do
        local f = fixture(bounds[1], bounds[2], true)
        f.Tool("Ice")
        f.Start()
        local original = f.Root
        local touch = new("ScreenGui", "TouchGui", f.PlayerGui)
        local function button(name, x, y, w, h)
            local object = new("ImageButton", name)
            object.ScreenPosition, object.Pixels = v(x, y), v(w, h)
            object.Parent = touch
            return object
        end
        local h, w = bounds[2], bounds[1]
        local stick = button("DynamicThumbstickFrame", 0, h - 150, 150, 150)
        local jump = button("JumpButton", w - 90, h - 90, 80, 80)
        cas.Buttons.SprintHeld = button("Sprint", w - 190, h - 90, 70, 70)
        cas.Buttons.ThrowHeld = button("Throw", w - 160, h - 180, 70, 70)
        cas.Buttons.IceShotgunFire = button("Fire", w - 100, h - 260, 70, 70)
        flush()
        local a = f.Bar.AbsolutePosition
        local b = v(a.X + f.Bar.AbsoluteSize.X, a.Y + f.Bar.AbsoluteSize.Y)
        for _, object in { stick, jump, cas.Buttons.SprintHeld, cas.Buttons.ThrowHeld, cas.Buttons.IceShotgunFire } do
            local p, s = object.AbsolutePosition, object.AbsoluteSize
            check(
                b.X <= p.X or a.X >= p.X + s.X or b.Y <= p.Y or a.Y >= p.Y + s.Y,
                "row clears native and action targets"
            )
        end
        check(f.Root == original and writes(false) == 1, "late controls adjust same bar without another disable")
        f.Stop()
    end
end)
run("startup", "zero initial safe area waits for mounted bounds", function()
    local f = fixture(0, 0, true)
    f.Tool("Ice")
    f.Start()
    check(core.Enabled and not f.Bar.Visible and not cas.Actions.HotbarSelect, "initial zero area keeps native")
    check(writes(false) == 0, "no disable before a usable slot area")
    f.Resize(390, 844)
    check(not core.Enabled and #f.Slots() == 1 and f.Bar.Visible, "bounds event alone completes takeover")
    f.Stop()
end)
run("startup", "safe-area origin and bounds apply insets once", function()
    local f = fixture(844, 390, true)
    f.Tool("Ice")
    f.Start()
    local original = guiService.GetGuiInset
    guiService.GetGuiInset = function()
        error("hotbar must use mounted safe bounds")
    end
    f.Safe.Pixels, f.Safe.ScreenPosition = v(700, 320), v(44, 24)
    f.Safe:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    flush()
    local p, safe, bar = f.Bar.AbsolutePosition, f.Safe.AbsolutePosition, f.Bar.AbsoluteSize
    check(f.Bar.Visible and not core.Enabled, "mounted bounds remain usable without GetGuiInset")
    check(
        p.X >= safe.X and p.Y >= safe.Y and p.X + bar.X <= safe.X + 700 and p.Y + bar.Y <= safe.Y + 320,
        "row stays inside actual inset container"
    )
    check(writes(false) == 1, "inset changes do not reassert CoreGui")
    guiService.GetGuiInset = original
    f.Stop()
end)
run("startup", "late ingredient preview preserves an already usable slot", function()
    local original = ingredientViewport.Create
    ingredientViewport.Create = function()
        return nil
    end
    local f = fixture(390, 844, true)
    f.Tool("Ingredient", 1)
    f.Start()
    local button = f.Slots()[1]
    check(
        named(button, "Icon").Image == Gui.Art.Generic and f.Bar.Visible,
        "missing preview presents intentional fallback"
    )
    button.Activated:Fire()
    flush()
    ingredientViewport.Create = original
    new("Folder", "ScrapbookPreviewAssets", services.ReplicatedStorage.Shared)
    flush()
    check(
        f.Slots()[1] == button and selected(button) and named(button, "Icon"):FindFirstChild("IngredientPreview"),
        "late preview does not replace identity or selection"
    )
    check(writes(false) == 1, "preview arrival does not repeat handoff")
    f.Stop()
end)
run("fallback", "failed native restoration retries without stale-session takeover", function()
    local f = fixture()
    f.Tool("Ice")
    f.Start()
    core.Fail = true
    f.Root.Enabled = false
    flush()
    check(
        not f.Bar.Visible and not cas.Actions.HotbarSelect,
        "unusable custom view releases input even during API failure"
    )
    core.Fail = false
    timers()
    check(core.Enabled, "bounded API retry restores native access")
    f.Root.Enabled = true
    flush()
    check(not core.Enabled and f.Bar.Visible, "restored custom view can reclaim ownership")
    core.Fail = true
    f.Stop()
    core.Fail = false
    local replacement = fixture()
    replacement.Tool("Ice")
    replacement.Start()
    for _ = 1, 10 do
        timers()
    end
    check(
        not core.Enabled and replacement.Bar.Visible and cas.Actions.HotbarSelect,
        "retired restoration cannot overwrite replacement owner"
    )
    replacement.Stop()
end)
run("fallback", "successful API call with unchanged readback stays native", function()
    local f = fixture()
    f.Tool("Ice")
    core.IgnoreWrite = true
    f.Start()
    check(
        core.Enabled and not f.Bar.Visible and not cas.Actions.HotbarSelect,
        "native still enabled prevents a duplicate custom bar"
    )
    core.IgnoreWrite = false
    timers()
    check(not core.Enabled and f.Bar.Visible, "confirmed disable permits recovery")
    f.Stop()
end)
run("startup", "late debug remote never gates startup", function()
    debugRemote.Parent = nil
    local f = fixture(390, 844, true)
    f.Tool("Ice")
    f.Start()
    check(not core.Enabled and f.Bar.Visible, "missing QA remote cannot block takeover")
    debugRemote.Parent = debugFolder
    flush()
    debugSignal:Fire(false)
    local message = debugMessages[#debugMessages]
    check(
        string.find(message, "owner=custom", 1, true) and string.find(message, "Portrait", 1, true),
        "late QA remote reports the existing owner"
    )
    f.Stop()
end)
run("lifecycle", "Character Tool can precede Backpack replication", function()
    local f = fixture(390, 844, true)
    local ice = f.Tool("Ice")
    ice.Parent = f.Character
    f.Backpack.Parent = nil
    f.Start()
    check(
        not core.Enabled and #f.Slots() == 1 and selected(f.Slots()[1]),
        "early Character Tool is presented without a Backpack"
    )
    f.Backpack = new("Backpack", "LateBackpack", f.Player)
    flush()
    f.Slots()[1].Activated:Fire()
    flush()
    check(
        ice.Parent == f.Backpack and #f.Slots() == 1 and writes(false) == 1,
        "late Backpack rebind preserves ownership and unequip"
    )
    f.Stop()
end)
check(cases > 0, "requested group ran")
print(string.format("Hotbar: %d cases passed, 0 failed (%d checks; Roblox UI/input doubles)", cases, count))
