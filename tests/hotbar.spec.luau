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
            Vector3 = vector3,
            CFrame = {
                lookAt = function()
                    return cframe
                end,
            },
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

-- Stage A reproductions run independently against the pre-change production modules.
if testCase == "aspect" then
    local ratios = {}
    for _, width in { 320, 768, 1280, 1920 } do
        local f = fixture(true)
        f.Desktop.Pixels = v(width, 1080)
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
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    if core.Enabled then
        print("Actual-export render warnings:", table.concat(warnings, "\n"))
    end
    check(
        not core.Enabled and cas.Actions.HotbarSelect ~= nil and not actualBar.Visible,
        "actual export hands off after empty render; unused bar hidden"
    )
    local content = actualBar.Parent
    local generic = content
        :FindFirstChild("Upgrades")
        :FindFirstChild("UpgradeScroll")
        :FindFirstChild("UpgradeList")
        :FindFirstChild("CarryCapacityCard")
        :FindFirstChild("Glossy Fruit Trio Sticker 1").Image
    local batImage = content
        :FindFirstChild("Upgrades")
        :FindFirstChild("UpgradeScroll")
        :FindFirstChild("UpgradeList")
        :FindFirstChild("BatCard")
        :FindFirstChild("Isolated Wooden Baseball Bat 1").Image
    local iceImage = content
        :FindFirstChild("Shop")
        :FindFirstChild("ShopScroll")
        :FindFirstChild("ShopList")
        :FindFirstChild("Ice Gun")
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
        if index == 2 or index == 3 then
            check(icon.Image == generic, "mounted export intentional fallback resolved")
        end
    end
    check(buttons[4]:FindFirstChild("SlotIcon").Image == batImage, "mounted bat card artwork resolved")
    check(buttons[5]:FindFirstChild("SlotIcon").Image == iceImage, "mounted ice ray artwork resolved")
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
    f.Desktop.Pixels = v(320, 600)
    uis.TouchEnabled = true
    for i = 1, 12 do
        f.Tool("Apple", "Missing", i)
    end
    local stop = Controller.Start(f.Player, f.PlayerGui)
    flush()
    local buttons = visible(f)
    check(#buttons == 12 and buttons[1].AbsoluteSize.X >= 48, "phone targets keep 48px floor with scrolling")
    buttons[12].Activated:Fire()
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
    f.Desktop.Pixels = viewport
    local longestName = "WWWWWWWWWWWWWWWWWWWW's Head"
    for i = 1, 12 do
        f.Tool(if i == 1 then longestName else "Apple", "Apple", i)
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
        check(buttons[index]:FindFirstChild("SlotSelected").Visible, "1-9 and overflow 0 map to current visible order")
    end
    buttons[12].Activated:Fire()
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
    f.Desktop.Pixels = v(320, 568)
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
    f.Tool("Missing again", "Missing", 2)
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
        visible(f)[1]:FindFirstChild("SlotIcon").Image == "export-generic-art",
        "fallback is intentional distinct export artwork"
    )
    local callback = cas.Actions.HotbarSelect
    for index, key in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three } do
        callback("", Enum.UserInputState.Begin, { KeyCode = key })
        flush()
        check(visible(f)[index]:FindFirstChild("SlotSelected").Visible, "key selects Nth current visible Tool")
    end
    local eq, uneq = f.Counts()
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Nine })
    local eq2, uneq2 = f.Counts()
    check(eq == eq2 and uneq == uneq2, "absent visible index has no equip effect")
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Three })
    flush()
    check(bat.Parent == f.Backpack, "key uses exact click toggle path")
    missing1.Parent = nil
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.One })
    local eq3 = f.Counts()
    check(eq3 == eq2, "removed Tool cannot be equipped before rebuild")
    flush()
    callback("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Two })
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
print("Hotbar contracts passed:", count)
