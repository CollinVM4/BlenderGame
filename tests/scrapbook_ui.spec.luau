local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, callback)
            local entry = { fn = callback, live = true }
            table.insert(callbacks, entry)
            return {
                Disconnect = function()
                    entry.live = false
                end,
            }
        end,
        Fire = function(_, ...)
            for _, callback in callbacks do
                if callback.live then
                    callback.fn(...)
                end
            end
        end,
    }
end
local function instance(class, name, parent)
    local properties = {
        Enabled = true,
        Visible = true,
        TextTransparency = 0,
        Text = "INDEX",
        AbsoluteWindowSize = { X = 800, Y = 450 },
    }
    local propertySignals = {}
    local object = {
        ClassName = class,
        Name = name,

        children = {},
        DescendantAdded = signal(),
        DescendantRemoving = signal(),
        Activated = signal(),
        Destroying = signal(),
        AncestryChanged = signal(),
        TextWrites = 0,
        attributes = {},
    }
    setmetatable(object, {
        __index = properties,
        __newindex = function(self, key, value)
            if key == "Text" or key == "Enabled" or key == "Visible" then
                local old = properties[key]
                properties[key] = value
                if key == "Text" then
                    self.TextWrites += 1
                end
                if old ~= value and propertySignals[key] then
                    propertySignals[key]:Fire()
                end
            elseif key == "Parent" then
                properties.Parent = value
                if value and not table.find(value.children, self) then
                    table.insert(value.children, self)
                end
            else
                rawset(self, key, value)
            end
        end,
    })
    function object:IsA(want)
        return self.ClassName == want
            or (want == "GuiButton" and (self.ClassName == "TextButton" or self.ClassName == "ImageButton"))
            or (
                want == "GuiObject"
                and table.find({
                        "Frame",
                        "CanvasGroup",
                        "ScrollingFrame",
                        "TextLabel",
                        "TextButton",
                        "ImageButton",
                        "ImageLabel",
                    }, self.ClassName)
                    ~= nil
            )
    end
    function object:SetAttribute(key, value)
        self.attributes[key] = value
    end
    function object:GetAttribute(key)
        return self.attributes[key]
    end
    function object:GetChildren()
        return table.clone(self.children)
    end
    function object:GetDescendants()
        local descendants = {}
        for _, c in self.children do
            table.insert(descendants, c)
            for _, d in c:GetDescendants() do
                table.insert(descendants, d)
            end
        end
        return descendants
    end
    function object:GetAttributeChangedSignal(name)
        return self:GetPropertyChangedSignal("attribute:" .. name)
    end
    function object:GetPropertyChangedSignal(name)
        propertySignals[name] = propertySignals[name] or signal()
        return propertySignals[name]
    end
    function object:FindFirstChild(want)
        for _, c in self.children do
            if c.Name == want then
                return c
            end
        end
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
    function object:WaitForChild(name)
        return self:FindFirstChild(name)
    end
    function object:FindFirstChildOfClass(class)
        for _, child in self.children do
            if child:IsA(class) then
                return child
            end
        end
    end
    function object:Clone()
        local copy = instance(self.ClassName, self.Name)
        for key, value in properties do
            if key ~= "Parent" then
                copy[key] = value
            end
        end
        copy.attributes = table.clone(self.attributes)
        for _, child in self.children do
            local cloned = child:Clone()
            cloned.Parent = copy
        end
        return copy
    end
    function object:Destroy()
        self.Destroying:Fire()
        if self.Parent then
            local index = table.find(self.Parent.children, self)
            if index then
                table.remove(self.Parent.children, index)
            end
        end
        self.Parent = nil
        self.AncestryChanged:Fire(self, nil)
    end
    object.Parent = parent
    return object
end
local playerGui = instance("PlayerGui", "PlayerGui")
local function import()
    local objects = { [0] = playerGui }
    for _, n in exportNodes do
        objects[n[1]] = instance(n[3], n[4], objects[n[2]])
    end
    return objects[1]
end
local player = instance("Player", "Player")
player.CharacterAdded = signal()
playerGui.Parent = player

local jobs, deferred = {}, {}
local shared = {
    Constants = {
        Ingredients = "Ingredients",
        CustomerRequests = "CustomerRequests",
        DiscoveryCatalog = "DiscoveryCatalog",
        ScrapbookArtwork = "ScrapbookArtwork",
    },
    MoneyFormat = "MoneyFormat",
    Types = "Types",
}
local modules = { Types = {} }
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local fn = assert(loadstring(sources[name], name))
    setfenv(
        fn,
        setmetatable({
            game = {
                GetService = function(_, name)
                    return if name == "Players" then { LocalPlayer = player } else { Shared = shared }
                end,
            },
            script = {
                Parent = {
                    UIRegistry = "UIRegistry",
                    PanelManager = "PanelManager",
                    Ingredients = "Ingredients",
                    CustomerRequests = "CustomerRequests",
                    BadCustomers = "BadCustomers",
                    Parent = {
                        UI = { ScrapbookPresentation = "ScrapbookPresentation", FramewispMenus = "FramewispMenus" },
                    },
                },
            },
            require = load,
            Color3 = {
                new = function(...)
                    return { ... }
                end,
                fromRGB = function(...)
                    return { ... }
                end,
            },
            UDim = {
                new = function(s, o)
                    return { Scale = s, Offset = o }
                end,
            },
            UDim2 = {
                fromOffset = function(x, y)
                    return { X = { Offset = x }, Y = { Offset = y } }
                end,
            },
            Instance = {
                new = function(class)
                    return instance(class, class)
                end,
            },
            Enum = {
                FillDirection = { Horizontal = "Horizontal" },
                SortOrder = { LayoutOrder = "LayoutOrder" },
                ScrollingDirection = { Y = "Y" },
                AutomaticSize = { Y = "Y" },
            },
            task = {
                spawn = function(fn)
                    table.insert(jobs, coroutine.create(fn))
                end,
                defer = function(fn)
                    table.insert(deferred, fn)
                end,
            },
            warn = function(message)
                error(message)
            end,
        }, { __index = getfenv() })
    )
    modules[name] = fn()
    return modules[name]
end
local function flush()
    while #deferred > 0 do
        local pending = deferred
        deferred = {}
        for _, fn in pending do
            fn()
        end
    end
end
local function resume(thread, ...)
    local ok, err = coroutine.resume(thread, ...)
    assert(ok, err)
end
local function descend(root, name)
    for _, child in root:GetDescendants() do
        if child.Name == name then
            return child
        end
    end
end
local presentation, controller, catalog, artwork =
    load("ScrapbookPresentation"), load("ScrapbookController"), load("DiscoveryCatalog"), load("ScrapbookArtwork")
local entries = catalog.GetIngredients()
for i, entry in entries do
    if i > 1 then
        local previous = entries[i - 1]
        check(
            catalog.RarityOrder[previous.Rarity] < catalog.RarityOrder[entry.Rarity]
                or (previous.Rarity == entry.Rarity and previous.Id < entry.Id),
            "canonical ordering"
        )
    end
end
check(artwork.GetIngredient("missing") == "", "safe missing thumbnail")
artwork.Ingredients.Strawberry = "authored-test-thumbnail"
local state = { Ingredients = {}, SpecialCustomers = {} }
check(controller.MergeDelta(state, { Kind = "Ingredient", Id = "Strawberry" }), "new discovery")
check(not controller.MergeDelta(state, { Kind = "Ingredient", Id = "Strawberry" }), "duplicate discovery")
controller.MergeSnapshot(
    state,
    { Ingredients = { Strawberry = false, Banana = true }, SpecialCustomers = { walter = true } }
)
check(state.Ingredients.Strawberry and state.Ingredients.Banana and state.SpecialCustomers.walter, "snapshot union")
for _, uiFirst in { true, false } do
    playerGui.children = {}
    jobs = {}
    local root = if uiFirst then import() else nil
    local events = instance("Folder", "Events")
    local delta = instance("RemoteEvent", "DiscoveryAdded", events)
    delta.OnClientEvent = signal()
    local snapshot = instance("RemoteFunction", "DiscoverySnapshot", events)
    snapshot.InvokeServer = function()
        delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Strawberry" })
        return coroutine.yield()
    end
    local stop = controller.Start(playerGui, events, player)
    resume(jobs[1])
    if not root then
        root = import()
        playerGui.DescendantAdded:Fire(root)
        flush()
    end
    local binding = assert(presentation.Resolve(playerGui))
    local scroll = binding.Scroll
    local function cardFor(id)
        for index, entry in entries do
            if entry.Id == id then
                return scroll:FindFirstChild("CollectionCard_" .. index)
            end
        end
    end
    local strawberry = assert(cardFor("Strawberry"))
    check(strawberry:FindFirstChild("IngredientLabel").Text == "Strawberry", "event before snapshot unlocks")
    local locked = assert(cardFor("Apple"))
    check(
        locked:FindFirstChild("IngredientLabel").Text == "???"
            and locked:FindFirstChild("RarityLabel").Text == "LOCKED"
            and locked:FindFirstChild("FruitImage").Image == ""
            and not locked:FindFirstChild("IngredientValue").Visible,
        "locked identity hidden"
    )
    check(strawberry:FindFirstChild("FruitImage").Image == "authored-test-thumbnail", "mapped thumbnail")
    resume(jobs[1], { Ingredients = { Banana = true, Strawberry = false }, SpecialCustomers = {} })
    check(strawberry:FindFirstChild("IngredientLabel").Text == "Strawberry", "late snapshot preserves event")
    local banana = cardFor("Banana")
    check(
        not banana:FindFirstChild("FruitImage").Visible
            and banana:FindFirstChild("IngredientValue").Text
                == presentation.FormatValue(load("Ingredients").Banana.Value),
        "unmapped image placeholder and catalog value"
    )
    delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
    delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
    check(locked:FindFirstChild("IngredientLabel").Text == "Apple", "live unlock")
    local grid = scroll:FindFirstChildOfClass("UIGridLayout")
    check(grid.FillDirectionMaxCells == 4 and grid.CellSize.X.Offset * 4 + 24 + 16 == 800, "four columns fit viewport")
    scroll.AbsoluteWindowSize = { X = 400, Y = 450 }
    scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Fire()
    check(grid.CellSize.X.Offset * 4 + 24 + 16 == 400, "four columns after resize")
    check(
        scroll.AutomaticCanvasSize == "Y"
            and scroll.CanvasSize.Y.Offset == 0
            and scroll.ClipsDescendants
            and scroll.ScrollingDirection == "Y",
        "vertical canvas expansion"
    )
    for _, child in scroll:GetChildren() do
        if child.Name == "IndexCard" or child.Name == "IndexCardTemplate" then
            check(not child.Visible, "examples excluded")
        end
    end
    local total = 0
    for _, child in scroll:GetChildren() do
        if child.Name:match("^CollectionCard_") then
            total += 1
        end
    end
    check(total == #entries and total > 4, "complete dynamic collection")
    check(binding.Title.Text == "INDEX 3/" .. #entries, "discovery counter")
    local menus = load("FramewispMenus").Attach(root, player)
    local nav = descend(root, "LeftMenu"):FindFirstChild("Index")
    nav.Activated:Fire()
    check(binding.Panel.Visible, "Index opens")
    descend(root, "LeftMenu"):FindFirstChild("Upgrades").Activated:Fire()
    check(not binding.Panel.Visible, "menu exclusivity")
    nav.Activated:Fire()
    player.CharacterAdded:Fire()
    check(not binding.Panel.Visible, "respawn closes Index")
    local oldPanel = binding.Panel
    local replacement = oldPanel:Clone()
    local parent = oldPanel.Parent
    oldPanel:Destroy()
    replacement.Parent = parent
    playerGui.DescendantRemoving:Fire(oldPanel)
    playerGui.DescendantAdded:Fire(replacement)
    flush()
    local rebound = assert(presentation.Resolve(playerGui))
    check(
        rebound.Panel == replacement and rebound.Title.Text == "INDEX 3/" .. #entries,
        "panel replacement retains state"
    )
    -- Cloned runtime cards from a live copy are not an authored export. Remove
    -- these before using the import to exercise a full fresh reimport.
    root:Destroy()
    playerGui.DescendantRemoving:Fire(root)
    local fresh = import()
    playerGui.DescendantAdded:Fire(fresh)
    flush()
    check(
        assert(presentation.Resolve(playerGui)).Title.Text == "INDEX 3/" .. #entries,
        "fresh reimport retains discoveries"
    )
    local active = assert(presentation.Resolve(playerGui))
    local originalField = active.Template:FindFirstChild("IngredientLabel")
    local replacementField = originalField:Clone()
    originalField:Destroy()
    replacementField.Parent = active.Template
    playerGui.DescendantRemoving:Fire(originalField)
    playerGui.DescendantAdded:Fire(replacementField)
    flush()
    check(
        assert(presentation.Resolve(playerGui)).Title.Text == "INDEX 3/" .. #entries,
        "partial template reimport preserves collection"
    )
    fresh.Enabled = false
    flush()
    check(presentation.Resolve(playerGui) == nil, "disabled root has no active view")
    fresh.Enabled = true
    flush()
    local duplicate = import()
    playerGui.DescendantAdded:Fire(duplicate)
    flush()
    check(presentation.Resolve(playerGui) == nil, "ambiguous imports pause binding")
    duplicate:Destroy()
    playerGui.DescendantRemoving:Fire(duplicate)
    flush()
    check(
        assert(presentation.Resolve(playerGui)).Title.Text == "INDEX 3/" .. #entries,
        "binding recovers after duplicate removal"
    )
    stop()
    stop()
    flush()
    local freshScroll = descend(fresh, "CardsViewport")
    for _, child in freshScroll:GetChildren() do
        check(not child.Name:match("^CollectionCard_"), "cleanup removes dynamic cards")
    end
    delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Ice" })
    playerGui.DescendantAdded:Fire(fresh)
    flush()
    check(descend(fresh, "INDEX").Text == "INDEX", "stopped controller cannot render")
    fresh:Destroy()
end
-- Cancellation while snapshot is in flight cannot update a torn-down view.
playerGui.children = {}
jobs = {}
local root = import()
local events = instance("Folder", "Events")
local delta = instance("RemoteEvent", "DiscoveryAdded", events)
delta.OnClientEvent = signal()
local snapshot = instance("RemoteFunction", "DiscoverySnapshot", events)
snapshot.InvokeServer = function()
    return coroutine.yield()
end
local stop = controller.Start(playerGui, events, player)
resume(jobs[1])
stop()
resume(jobs[1], { Ingredients = { Apple = true }, SpecialCustomers = {} })
check(descend(root, "INDEX").Text == "INDEX", "cancelled snapshot ignored")
print("PASS: Framewisp Scrapbook races, rendering, grid, replacement, lifecycle and exclusive navigation")
