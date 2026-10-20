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
        ZIndex = 1,
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
                        return {
                            IsStudio = function()
                                return false
                            end,
                        }
                    end
                    return if name == "Players" then { LocalPlayer = player } else { Shared = shared }
                end,
            },
            script = {
                Parent = {
                    IngredientPickupPromptStyle = "IngredientPickupPromptStyle",
                    IngredientViewport = "IngredientViewport",
                    UIRegistry = "UIRegistry",
                    NotificationBadge = "NotificationBadge",
                    MenuNotifications = "MenuNotifications",
                    PanelManager = "PanelManager",
                    ScrapbookPreviews = "ScrapbookPreviews",
                    Ingredients = "Ingredients",
                    CustomerRequests = "CustomerRequests",
                    BadCustomers = "BadCustomers",
                    Parent = {
                        UI = {
                            ScrapbookPresentation = "ScrapbookPresentation",
                            FramewispMenus = "FramewispMenus",
                            MenuNotifications = "MenuNotifications",
                        },
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
                new = function(...)
                    return { ... }
                end,
                fromScale = function(x, y)
                    return { X = { Scale = x }, Y = { Scale = y } }
                end,
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
