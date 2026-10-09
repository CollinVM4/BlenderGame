local function check(value, message)
    assert(value, message)
end
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            table.insert(callbacks, fn)
        end,
        Fire = function(_, ...)
            for _, fn in callbacks do
                fn(...)
            end
        end,
    }
end
local function color(r, g, b)
    return {
        R = r,
        G = g,
        B = b,
        Lerp = function(self)
            return self
        end,
    }
end
local methods = {}
local meta = {
    __index = function(self, key)
        return methods[key] or self.props[key]
    end,
    __newindex = function(self, key, value)
        if key == "Parent" and value then
            table.insert(value.children, self)
        end
        self.props[key] = value
    end,
}
local function node(class, name, parent)
    local object = setmetatable({
        props = {
            ClassName = class,
            Name = name or class,
            Visible = true,
            ImageColor3 = color(1, 1, 1),
            BackgroundColor3 = color(0.2, 0.2, 0.2),
            AbsoluteSize = { X = 600, Y = 200 },
            AbsoluteContentSize = { X = 600, Y = 200 },
            Activated = signal(),
            Destroying = signal(),
        },
        children = {},
    }, meta)
    object.Parent = parent
    return object
end
function methods:IsA(class)
    return self.ClassName == class
end
function methods:FindFirstChild(name)
    for _, child in self.children do
        if child.Name == name then
            return child
        end
    end
    return nil
end
function methods:WaitForChild(name)
    return self:FindFirstChild(name)
end
function methods:FindFirstChildOfClass(class)
    for _, child in self.children do
        if child.ClassName == class then
            return child
        end
    end
    return nil
end
function methods:GetPropertyChangedSignal()
    return signal()
end
function methods:GetFullName()
    return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
end
function methods:Clone()
    local copy = node(self.ClassName, self.Name)
    for key, value in self.props do
        if key ~= "Parent" and key ~= "Activated" then
            copy[key] = value
        end
    end
    for _, child in self.children do
        child:Clone().Parent = copy
    end
    return copy
end
local function get(root, path)
    for part in path:gmatch("[^.]+") do
        root = assert(root:FindFirstChild(part), part)
    end
    return root
end
local function hierarchy()
    local gui = node("ScreenGui", "ScrapbookGui")
    node("ImageButton", "OpenButton", gui)
    local window = node("Frame", "Window", gui)
    node("ImageButton", "CloseButton", window)
    local tabs = node("Frame", "Tabs", window)
    node("TextButton", "IngredientsButton", tabs)
    node("TextButton", "CustomersButton", tabs)
    local pages = node("Frame", "Pages", window)
    for _, config in
        { { "Ingredients", "Rarity", "Ingredient", "Artwork" }, { "Customers", "Jump", "Customer", "Portrait" } }
    do
        local page = node("Frame", config[1] .. "Page", pages)
        local scroll = node("ScrollingFrame", "Scroll", page)
        node("UIListLayout", nil, scroll)
        local section = node("Frame", config[2] .. "SectionTemplate", scroll)
        local header = node("Frame", "Header", section)
        node("TextLabel", "Title", header)
        local grid = node("Frame", "Grid", section)
        node("UIGridLayout", nil, grid)
        local card = node("Frame", config[3] .. "CardTemplate", grid)
        node("ImageLabel", config[4], card)
        node("TextLabel", "Name", card)
        if config[1] == "Ingredients" then
            node("TextLabel", "Rarity", card)
            node("TextLabel", "Value", card)
        end
    end
    return gui
end
local modules = { Types = {} }
local shared = node("Folder", "Shared")
shared.MoneyFormat = "MoneyFormat"
shared.Constants = {
    Ingredients = "Ingredients",
    CustomerRequests = "CustomerRequests",
    DiscoveryCatalog = "DiscoveryCatalog",
    ScrapbookArtwork = "ScrapbookArtwork",
}
shared.Types = "Types"
local playerGui = node("PlayerGui", "PlayerGui")
local player = node("Player", "Player")
playerGui.Parent = player
local services = { ReplicatedStorage = { Shared = shared }, Players = { LocalPlayer = player } }
local jobs, warnings = {}, {}
local function resume(thread, ...)
    local ok, err = coroutine.resume(thread, ...)
    assert(ok, err)
end
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local fn = assert(loadstring(sources[name], name))
    setfenv(
        fn,
        setmetatable({
            game = {
                GetService = function(_, service)
                    return services[service]
                end,
            },
            script = {
                Parent = {
                    BadCustomers = "BadCustomers",
                    Ingredients = "Ingredients",
                    CustomerRequests = "CustomerRequests",
                    Parent = { UI = { ScrapbookPresentation = "ScrapbookPresentation", PanelManager = "PanelManager" } },
                },
            },
            require = load,
            Color3 = { new = color, fromRGB = color },
            UDim = {
                new = function(...)
                    return { ... }
                end,
            },
            UDim2 = {
                new = function(...)
                    return { ... }
                end,
                fromOffset = function(...)
                    return { ... }
                end,
            },
            Enum = {
                AutomaticSize = { Y = "Y", None = "None" },
                FillDirection = { Vertical = "Vertical", Horizontal = "Horizontal" },
                SortOrder = { LayoutOrder = "LayoutOrder" },
                ScrollingDirection = { Y = "Y" },
                ScaleType = { Fit = "Fit" },
            },
            Instance = { new = node },
            task = {
                spawn = function(fn)
                    table.insert(jobs, coroutine.create(fn))
                end,
            },
            warn = function(message)
                table.insert(warnings, message)
            end,
        }, { __index = getfenv() })
    )
    modules[name] = fn()
    return modules[name]
end
local presentation = load("ScrapbookPresentation")
local controller = load("ScrapbookController")
local catalog = load("DiscoveryCatalog")
local artwork = load("ScrapbookArtwork")
for value, expected in
    {
        [250] = "$250",
        [500] = "$500",
        [1000] = "$1K",
        [1500] = "$1.5K",
        [12000] = "$12K",
        [165000] = "$165K",
        [1e6] = "$1M",
        [1.2e6] = "$1.2M",
    }
do
    check(presentation.FormatValue(value) == expected, "compact value formatting")
end
check(artwork.GetIngredient("unknown") == "" and artwork.GetSpecialCustomer("walter") == "", "empty artwork fallback")
local ingredients = catalog.GetIngredients()
local groups = presentation.Group(ingredients, function(entry)
    return entry.Rarity
end)
local flattened = {}
for _, group in groups do
    for _, entry in group.Entries do
        table.insert(flattened, entry.Id)
    end
end
for index, entry in ingredients do
    check(flattened[index] == entry.Id, "grouping preserves canonical order")
end
check(groups[1].Key == "Common" and groups[#groups].Key == "Mystery", "rarity sections")
local state = { Ingredients = {}, SpecialCustomers = {} }
check(controller.MergeDelta(state, { Kind = "Ingredient", Id = "Strawberry" }), "first delta")
check(not controller.MergeDelta(state, { Kind = "Ingredient", Id = "Strawberry" }), "duplicate delta is idempotent")
controller.MergeSnapshot(
    state,
    { Ingredients = { Banana = true, Strawberry = false }, SpecialCustomers = { walter = true } }
)
check(
    state.Ingredients.Strawberry and state.Ingredients.Banana and state.SpecialCustomers.walter,
    "snapshot union never erases delta"
)
local gui = hierarchy()
local view = presentation.Create(
    gui,
    { Ingredients = {}, SpecialCustomers = {} },
    { Open = function() end, Close = function() end, SelectTab = function() end }
)
local scroll = get(gui, "Window.Pages.IngredientsPage.Scroll")
local strawberryEntry
for _, entry in ingredients do
    if entry.Id == "Strawberry" then
        strawberryEntry = entry
    end
end
local card = get(scroll, "Section_" .. string.upper(strawberryEntry.Rarity) .. ".Grid.Ingredient_Strawberry")
check(get(card, "Name").Text == "???" and get(card, "Value").Text == "$???", "locked card masks name/value")
check(
    get(card, "Artwork").Image == "" and get(card, "Artwork").ImageColor3.R == 0,
    "missing artwork still creates locked card"
)
view.UpdateDiscovery({ Kind = "Ingredient", Id = "Strawberry" })
check(
    get(card, "Name").Text == strawberryEntry.DisplayName
        and get(card, "Value").Text == presentation.FormatValue(strawberryEntry.Value),
    "live unlock reveals existing card"
)
check(
    get(card, "Artwork").ImageColor3.R == 1 and get(card, "Rarity").Text == strawberryEntry.Rarity,
    "restores tint and retains rarity"
)
check(
    get(scroll, "Section_" .. string.upper(strawberryEntry.Rarity) .. ".Grid.Ingredient_Strawberry") == card,
    "unlock keeps card instance"
)
local customersScroll = get(gui, "Window.Pages.CustomersPage.Scroll")
for _, group in
    presentation.Group(catalog.GetSpecialCustomers(), function(entry)
        return tostring(entry.MinJumpTier)
    end)
do
    for index, entry in group.Entries do
        local customer = get(customersScroll, "Section_JUMP " .. group.Key .. ".Grid.Customer_" .. index)
        check(get(customer, "Name").Text == "???", "customer identity hidden")
        if entry.Id == "walter" then
            view.UpdateDiscovery({ Kind = "SpecialCustomer", Id = "WalterWhite" })
            check(get(customer, "Name").Text == "???", "display name is not an unlock key")
            view.UpdateDiscovery({ Kind = "SpecialCustomer", Id = "walter" })
            check(
                get(customer, "Name").Text == entry.DisplayName and get(customer, "Portrait").ImageColor3.R == 1,
                "canonical customer ID reveals portrait/name"
            )
        end
    end
end
local bad = hierarchy()
get(bad, "Window.Pages.IngredientsPage.Scroll.RaritySectionTemplate.Grid.IngredientCardTemplate.Name").Name =
    "Misspelled"
local ok, err = pcall(presentation.Create, bad, state, {})
check(
    not ok
        and string.find(
            err,
            "ScrapbookGui.Window.Pages.IngredientsPage.Scroll.RaritySectionTemplate.Grid.IngredientCardTemplate.Name missing",
            1,
            true
        ),
    "missing hierarchy reports exact path"
)
-- Execute the real controller while InvokeServer is suspended. Exercise UI ready
-- both before and after snapshot completion, without mocking the presentation.
for _, uiFirst in { true, false } do
    jobs, warnings = {}, {}
    playerGui.children = {}
    local live = hierarchy()
    live.Parent = playerGui
    shared.children = {}
    local events = node("Folder", "Events", shared)
    local added = node("RemoteEvent", "DiscoveryAdded", events)
    added.OnClientEvent = signal()
    local snapshot = node("RemoteFunction", "DiscoverySnapshot", events)
    snapshot.InvokeServer = function()
        added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Strawberry" })
        return coroutine.yield()
    end
    modules.ScrapbookController = nil
    load("ScrapbookController").Init()
    resume(jobs[1])
    if uiFirst then
        resume(jobs[2])
    end
    added.OnClientEvent:Fire({ Kind = "SpecialCustomer", Id = "walter" })
    resume(jobs[1], { Ingredients = { Banana = true }, SpecialCustomers = {} })
    if not uiFirst then
        resume(jobs[2])
    end
    local liveCard = get(
        live,
        "Window.Pages.IngredientsPage.Scroll.Section_"
            .. string.upper(strawberryEntry.Rarity)
            .. ".Grid.Ingredient_Strawberry"
    )
    check(get(liveCard, "Name").Text == strawberryEntry.DisplayName, "late snapshot cannot overwrite in-flight delta")
    for _, entry in ingredients do
        if entry.Id == "Banana" or entry.Id == "Apple" then
            local other = get(
                live,
                "Window.Pages.IngredientsPage.Scroll.Section_"
                    .. string.upper(entry.Rarity)
                    .. ".Grid.Ingredient_"
                    .. entry.Id
            )
            if entry.Id == "Banana" then
                check(get(other, "Name").Text == entry.DisplayName, "snapshot-only discovery renders")
            else
                check(get(other, "Name").Text == "???", "unrelated card stays locked")
                added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
                check(
                    get(other, "Name").Text == entry.DisplayName,
                    "post-initialization discovery updates existing card"
                )
            end
        end
    end
    for _, group in
        presentation.Group(catalog.GetSpecialCustomers(), function(entry)
            return tostring(entry.MinJumpTier)
        end)
    do
        for index, entry in group.Entries do
            if entry.Id == "walter" then
                local customer = get(
                    live,
                    "Window.Pages.CustomersPage.Scroll.Section_JUMP " .. group.Key .. ".Grid.Customer_" .. index
                )
                check(
                    get(customer, "Name").Text == entry.DisplayName,
                    "customer delta survives snapshot and delayed GUI creation"
                )
            end
        end
    end
    added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Strawberry" })
    check(get(liveCard, "Name").Text == strawberryEntry.DisplayName, "duplicate event retains reveal")
    get(live, "OpenButton").Activated:Fire()
    check(
        get(live, "Window").Visible and get(live, "Window.Pages.IngredientsPage").Visible,
        "first open selects ingredients"
    )
    get(live, "Window.Tabs.CustomersButton").Activated:Fire()
    get(live, "Window.CloseButton").Activated:Fire()
    check(not get(live, "Window").Visible, "close hides window")
    get(live, "OpenButton").Activated:Fire()
    check(
        get(live, "Window.Pages.CustomersPage").Visible and not get(live, "Window.Pages.IngredientsPage").Visible,
        "reopen retains selected tab"
    )
    local otherVisible = false
    local other = load("PanelManager").Register("Upgrades", {
        Open = function()
            otherVisible = true
        end,
        Close = function()
            otherVisible = false
        end,
    })
    other.Open()
    check(not get(live, "Window").Visible and otherVisible, "another major menu closes Scrapbook")
    get(live, "Window.Tabs.IngredientsButton").Activated:Fire()
    check(not get(live, "Window").Visible, "tab refresh cannot reopen an externally closed Scrapbook")
    get(live, "OpenButton").Activated:Fire({ UserInputType = "Touch" })
    check(get(live, "Window").Visible and not otherVisible, "touch reopens Scrapbook exclusively")
    get(live, "Window.CloseButton").Activated:Fire({ UserInputType = "Touch" })
    check(not get(live, "Window").Visible, "touch X closes Scrapbook")
    other.Destroy()
    check(#warnings == 0, "valid UI startup has no warnings")
end
print(
    "PASS: Scrapbook merge/races, catalog grouping, formatting, card rendering, canonical IDs, artwork fallback, hierarchy diagnostics, and controls"
)
