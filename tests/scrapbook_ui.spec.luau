local vectorMeta = {}
local function vec(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMeta)
end
vectorMeta.__index = function(v, key)
    local magnitude = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    if key == "Magnitude" then
        return magnitude
    end
    if key == "Unit" then
        return vec(v.X / magnitude, v.Y / magnitude, v.Z / magnitude)
    end
end
vectorMeta.__mul = function(v, n)
    return vec(v.X * n, v.Y * n, v.Z * n)
end
vectorMeta.__sub = function(a, b)
    return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
local frameMeta = {}
local function frame(position)
    return setmetatable({ Position = position or vec() }, frameMeta)
end
frameMeta.__sub = function(a, b)
    return frame(a.Position - b)
end
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
        AbsolutePosition = { X = 0, Y = 0 },
        AbsoluteSize = { X = 150, Y = 120 },
        Size = vec(2, 3, 4),
        CFrame = frame(),
        Transparency = 0.4,
        Reflectance = 0.8,
        Material = "Neon",
        MaterialVariant = "AuthoredMaterial",
        Color = { 220, 70, 40 },
        TextureID = "meshpart-texture",
        TextureId = "specialmesh-texture",
        VertexColor = vec(0.2, 0.5, 0.8),
        UsePartColor = false,
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
            elseif properties[key] ~= nil then
                properties[key] = value
            else
                rawset(self, key, value)
            end
        end,
    })
    function object:IsA(want)
        return self.ClassName == want
            or (want == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart" or self.ClassName == "UnionOperation"))
            or (want == "DataModelMesh" and self.ClassName == "SpecialMesh")
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
    function object:GetAttributes()
        return table.clone(self.attributes)
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
    function object:GetScale()
        return 1
    end
    function object:ScaleTo(scale)
        for _, part in self:GetDescendants() do
            if part:IsA("BasePart") then
                part.Size = part.Size * scale
            end
        end
    end
    function object:GetPivot()
        return self.CFrame
    end
    function object:PivotTo(value)
        self.CFrame = value
    end
    function object:GetBoundingBox()
        local maxSize = vec()
        local center = vec()
        for _, part in self:GetDescendants() do
            if part:IsA("BasePart") then
                maxSize = vec(
                    math.max(maxSize.X, part.Size.X),
                    math.max(maxSize.Y, part.Size.Y),
                    math.max(maxSize.Z, part.Size.Z)
                )
                center = part.CFrame.Position
            end
        end
        return frame(center), maxSize
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
        for _, child in self:GetChildren() do
            child:Destroy()
        end
        self.Destroyed = true
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
    children = {},
    DescendantAdded = signal(),
    FindFirstChild = function()
        return nil
    end,
    IngredientPreviewGeometry = "IngredientPreviewGeometry",
    Constants = {
        ScrapbookPreviews = "ScrapbookPreviews",
        Ingredients = "Ingredients",
        CustomerRequests = "CustomerRequests",
        DiscoveryCatalog = "DiscoveryCatalog",
        ScrapbookArtwork = "ScrapbookArtwork",
    },
    MoneyFormat = "MoneyFormat",
    Types = "Types",
}
local serverStorage = instance("Folder", "ServerStorage")
local collection = {
    GetTags = function(_, object)
        return object.tags or {}
    end,
    RemoveTag = function(_, object, tag)
        object.tags = {}
    end,
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
                    if name == "CollectionService" then
                        return collection
                    end
                    if name == "ServerStorage" then
                        return serverStorage
                    end
                    if name == "RunService" then
                        error("Static previews must not use RunService")
                    end
                    return if name == "Players" then { LocalPlayer = player } else { Shared = shared }
                end,
            },
            script = {
                Parent = {
                    IngredientPickupPromptStyle = "IngredientPickupPromptStyle",
                    IngredientViewport = "IngredientViewport",
                    UIRegistry = "UIRegistry",
                    PanelManager = "PanelManager",
                    ScrapbookPreviews = "ScrapbookPreviews",
                    Ingredients = "Ingredients",
                    CustomerRequests = "CustomerRequests",
                    BadCustomers = "BadCustomers",
                    Parent = {
                        UI = { ScrapbookPresentation = "ScrapbookPresentation", FramewispMenus = "FramewispMenus" },
                    },
                },
            },
            require = load,
            Vector3 = { new = vec, zero = vec() },
            CFrame = {
                lookAt = function(position, target)
                    return frame(position)
                end,
            },
            Vector2 = {
                new = function()
                    return {}
                end,
            },
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
                Material = { SmoothPlastic = "SmoothPlastic" },
                FieldOfViewMode = { Vertical = "Vertical" },
                Font = { GothamBold = "GothamBold" },
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
-- Geometry and renderer contracts use synthetic shapes, not stand-ins in production.
local geometry, renderer = load("IngredientPreviewGeometry"), load("IngredientViewport")
local source = instance("Part", "Apple")
source:SetAttribute("Gameplay", true)
instance("Script", "Unsafe", source)
instance("Sound", "Audio", source)
instance("ParticleEmitter", "Particles", source)
instance("WeldConstraint", "Joint", source)
local visual = assert(geometry.Clone(source))
local part = visual:FindFirstChild("Apple")
check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery, "noninteractive geometry")
check(#part:GetChildren() == 0 and part:GetAttribute("Gameplay") == nil, "preview strips behavior and state")
check(#source:GetChildren() == 4 and source:GetAttribute("Gameplay") == true, "original prefab preserved")
check(geometry.Clone(instance("Model", "Empty")) == nil, "empty geometry rejected")
for _, size in { vec(1, 1, 1), vec(2, 18, 45), vec(1000, 20, 600) } do
    for _, aspect in { 0.4, 1, 2.4 } do
        local distance = geometry.Distance(size, aspect, 35)
        local halfAngle = math.min(math.rad(35) / 2, math.atan(math.tan(math.rad(35) / 2) * aspect))
        check(distance * math.sin(halfAngle) > size.Magnitude / 2, "sphere fits both axes with margin")
    end
end
-- Appearance cues survive the sanitizer for color previews, but not silhouettes.
instance("Decal", "Face", source)
instance("Texture", "Pattern", source)
instance("SpecialMesh", "Shape", source)
local prefabs = instance("Folder", "Ingredients", serverStorage)
source.Parent = prefabs
local multipart = instance("Model", "Grapes", prefabs)
instance("Part", "Fruit", multipart)
local stem = instance("MeshPart", "Stem", multipart)
instance("SurfaceAppearance", "Surface", stem)
instance("UnionOperation", "Union", multipart)
local helper = instance("Part", "InvisibleRoot", multipart)
helper.Transparency = 1
instance("Script", "Unsafe", multipart)
local published
shared.FindFirstChild = function(_, name)
    return if name == "ScrapbookPreviewAssets" then published else nil
end
local publishWarnings = {}
-- Init publishes sanitized copies of only allowlisted existing prefabs.
local assetsModule = load("ScrapbookPreviewAssets")
local assetsEnv = getfenv(assetsModule.Init)
assetsEnv.warn = function(message)
    table.insert(publishWarnings, message)
end
assetsModule.Init()
-- Shared is a small mocked service table, so retrieve the published Folder explicitly.
for _, child in shared.children or {} do
    published = child
end
check(published ~= nil, "visual assets published")
check(published:FindFirstChild("Apple") and published:FindFirstChild("Grapes"), "single and multipart assets published")
check(#published:GetChildren() == 2 and #publishWarnings == 6, "allowlisted missing assets reported")
check(multipart:FindFirstChild("Unsafe") ~= nil, "publishing preserves server prefab")
local host = instance("Frame", "Card")
local image = instance("ImageLabel", "FruitImage", host)
check(
    renderer.Create(image, "Banana") == nil and renderer.Create(image, "Tire") == nil,
    "missing or nonallowlisted preview falls back"
)
published:FindFirstChild("Apple"):FindFirstChild("Apple").Size = vec(1000, 20, 600)
for _, id in { "Apple", "Grapes" } do
    local cleanup = assert(renderer.Create(image, id))
    local viewport = host:FindFirstChild("IngredientPreview")
    local camera = viewport.CurrentCamera
    local world = viewport:FindFirstChildOfClass("WorldModel")
    local model = world:FindFirstChildOfClass("Model")
    local _, bounds = model:GetBoundingBox()
    check(
        math.abs(math.max(bounds.X, bounds.Y, bounds.Z) - 4) < 0.0001,
        "large/single/multipart previews uniformly normalized"
    )
    local partCount = 0
    for _, object in model:GetDescendants() do
        if object:IsA("BasePart") then
            partCount += 1
        end
    end
    check(partCount == (if id == "Apple" then 1 else 4), "all original ingredient parts retained")
    check(
        viewport.BackgroundTransparency == 1 and viewport:FindFirstChildOfClass("WorldModel"),
        "dedicated transparent viewport world"
    )
    check(
        camera.CFrame.Position.Y > 0 and camera.CFrame.Position.X == camera.CFrame.Position.Z,
        "stationary three-quarter downward camera"
    )
    local oldDistance = camera.CFrame.Position.Magnitude
    viewport.AbsoluteSize = { X = 30, Y = 120 }
    viewport:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    check(camera.CFrame.Position.Magnitude > oldDistance, "narrow resize reframes geometry")
    local fullColorPosition = camera.CFrame.Position
    local sourcePart = descend(model, if id == "Apple" then "Apple" else "Stem")
    check(sourcePart.Color[1] == 220 and sourcePart.Material == "Neon", "full-color appearance preserved")
    cleanup()
    cleanup()
    check(host:FindFirstChild("IngredientPreview") == nil and camera.Destroyed, "cleanup releases camera and geometry")
    local silhouetteCleanup = assert(renderer.Create(image, id, true))
    local silhouette = host:FindFirstChild("IngredientPreview")
    local silhouetteModel = silhouette:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
    local _, silhouetteBounds = silhouetteModel:GetBoundingBox()
    check(
        silhouetteBounds.X == bounds.X and silhouetteBounds.Y == bounds.Y and silhouetteBounds.Z == bounds.Z,
        "silhouettes preserve geometry and proportions"
    )
    silhouette.AbsoluteSize = { X = 30, Y = 120 }
    silhouette:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    local silhouettePosition = silhouette.CurrentCamera.CFrame.Position
    check(
        silhouettePosition.X == fullColorPosition.X
            and silhouettePosition.Y == fullColorPosition.Y
            and silhouettePosition.Z == fullColorPosition.Z,
        "silhouette camera framing matches full color"
    )
    check(silhouette.Ambient[1] == 1 and silhouette.LightColor[1] == 0, "flat silhouette lighting")
    for _, object in silhouetteModel:GetDescendants() do
        check(
            not object:IsA("Decal") and not object:IsA("Texture") and not object:IsA("SurfaceAppearance"),
            "silhouette removes surface cues"
        )
        if object:IsA("BasePart") then
            check(
                object.Color[1] == 8
                    and object.Color[2] == 8
                    and object.Color[3] == 10
                    and object.Material == "SmoothPlastic"
                    and object.MaterialVariant == ""
                    and object.Reflectance == 0,
                "all silhouette parts nearly black and flat"
            )
            check(
                object.Transparency == (if object.Name == "InvisibleRoot" then 1 else 0),
                "opaque silhouette retains invisible helpers"
            )
            if object:IsA("MeshPart") then
                check(object.TextureID == "", "meshpart texture cleared")
            end
            if object:IsA("UnionOperation") then
                check(object.UsePartColor, "union original colors overridden")
            end
        elseif object:IsA("SpecialMesh") then
            check(object.TextureId == "" and object.VertexColor.X == 1, "specialmesh texture and vertex tint cleared")
        end
    end
    local silhouetteCamera = silhouette.CurrentCamera
    silhouetteCleanup()
    check(
        silhouetteCamera.Destroyed and host:FindFirstChild("IngredientPreview") == nil,
        "silhouette cleanup releases world and camera"
    )
    local normalCleanup = assert(renderer.Create(image, id, false))
    local restored =
        host:FindFirstChild("IngredientPreview"):FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
    local restoredPart = descend(restored, if id == "Apple" then "Apple" else "Stem")
    check(
        restoredPart.Color[1] == 220 and restoredPart.Material == "Neon",
        "silhouette clone never changes subsequent color previews"
    )
    check(descend(restored, if id == "Apple" then "Face" else "Surface") ~= nil, "full-color textures retained")
    normalCleanup()
end
check(
    published:FindFirstChild("Apple"):FindFirstChild("Apple").Size.X == 1000,
    "renderer never scales published source"
)
for _, tier in { "Common", "Uncommon", "Rare", "Mystery" } do
    local card = instance("Frame", "Card")
    for _, field in { "IngredientLabel", "IngredientValue", "RarityLabel" } do
        instance("TextLabel", field, card)
    end
    instance("ImageLabel", "FruitImage", card)
    presentation.RenderCard(card, false, { DisplayName = "Secret", Rarity = tier, Value = 123, Image = "secret" })
    check(card:FindFirstChild("RarityLabel").Text == string.upper(tier), "actual rarity before discovery")
    check(
        card:FindFirstChild("RarityLabel").TextColor3
            == load("IngredientPickupPromptStyle").RarityStyles[tier].TextColor,
        "existing rarity palette"
    )
    check(
        card:FindFirstChild("IngredientLabel").Text == "???"
            and not card:FindFirstChild("IngredientValue").Visible
            and not card:FindFirstChild("FruitImage").Visible,
        "all tiers hide identity"
    )
end
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
            and locked:FindFirstChild("RarityLabel").Text == "COMMON"
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
    local indexNav = descend(root, "LeftMenu"):FindFirstChild("Index")
    indexNav.Activated:Fire()
    flush()
    local lockedPreview = locked:FindFirstChild("IngredientPreview")
    check(
        lockedPreview ~= nil and lockedPreview.LightColor[1] == 0,
        "undiscovered approved card shows silhouette lazily"
    )
    check(
        locked:FindFirstChild("IngredientLabel").Text == "???" and not locked:FindFirstChild("IngredientValue").Visible,
        "silhouette does not expose visible identity or value"
    )
    check(banana:FindFirstChild("IngredientPreview") == nil, "unavailable approved prefab retains fallback")
    scroll:GetPropertyChangedSignal("CanvasPosition"):Fire()
    flush()
    check(locked:FindFirstChild("IngredientPreview") == lockedPreview, "scroll refresh reuses one silhouette viewport")
    local lockedCamera = lockedPreview.CurrentCamera
    locked.AbsolutePosition = { X = 0, Y = 1000 }
    locked:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    flush()
    check(
        lockedCamera.Destroyed and locked:FindFirstChild("IngredientPreview") == nil,
        "scrolling releases undiscovered silhouette"
    )
    locked.AbsolutePosition = { X = 0, Y = 0 }
    locked:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    flush()
    lockedPreview = locked:FindFirstChild("IngredientPreview")
    lockedCamera = lockedPreview.CurrentCamera
    delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
    flush()
    local unlockedPreview = locked:FindFirstChild("IngredientPreview")
    check(
        lockedCamera.Destroyed and unlockedPreview ~= lockedPreview and unlockedPreview.LightColor[1] == 255,
        "discovery replaces silhouette with full-color preview"
    )
    delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
    flush()
    check(
        locked:FindFirstChild("IngredientPreview") == unlockedPreview,
        "duplicate discovery retains one color preview"
    )
    indexNav.Activated:Fire()
    flush()
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
    flush()
    local preview = locked:FindFirstChild("IngredientPreview")
    check(preview ~= nil, "visible discovered card creates preview")
    delta.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
    scroll:GetPropertyChangedSignal("CanvasPosition"):Fire()
    flush()
    check(locked:FindFirstChild("IngredientPreview") == preview, "refresh reuses preview without duplicates")
    locked.AbsolutePosition = { X = 0, Y = 1000 }
    locked:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    flush()
    check(locked:FindFirstChild("IngredientPreview") == nil, "offscreen preview released")
    locked.AbsolutePosition = { X = 0, Y = 0 }
    locked:GetPropertyChangedSignal("AbsolutePosition"):Fire()
    flush()
    descend(root, "LeftMenu"):FindFirstChild("Upgrades").Activated:Fire()
    check(not binding.Panel.Visible, "menu exclusivity")
    flush()
    check(locked:FindFirstChild("IngredientPreview") == nil, "closed panel releases preview")
    nav.Activated:Fire()
    player.CharacterAdded:Fire()
    check(not binding.Panel.Visible, "respawn closes Index")
    nav.Activated:Fire()
    flush()
    local oldCamera = locked:FindFirstChild("IngredientPreview").CurrentCamera
    local oldSilhouetteCamera = cardFor("Grapes"):FindFirstChild("IngredientPreview").CurrentCamera
    local oldPanel = binding.Panel
    local replacement = oldPanel:Clone()
    local parent = oldPanel.Parent
    oldPanel:Destroy()
    replacement.Parent = parent
    playerGui.DescendantRemoving:Fire(oldPanel)
    playerGui.DescendantAdded:Fire(replacement)
    flush()
    check(oldCamera.Destroyed and oldSilhouetteCamera.Destroyed, "panel replacement releases both preview modes")
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
