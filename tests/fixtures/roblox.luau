-- CLI test boundary. run_state_tests.py prepends unmodified module sources.
local count = 0
local setupCount = 0
local function setup(value, message)
    assert(value, "SETUP: " .. message)
    setupCount += 1
end
local function check(value, message)
    assert(value, message)
    count += 1
end
local vector = {}
vector.__index = function(v, key)
    if key == "Magnitude" then
        return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    end
    if key == "Unit" then
        return v / v.Magnitude
    end
    return vector[key]
end
local function vec(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z }, vector)
end
vector.__add = function(a, b)
    return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vector.__sub = function(a, b)
    return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vector:Cross(b)
    return vec(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
end
function vector:Dot(b)
    return self.X * b.X + self.Y * b.Y + self.Z * b.Z
end
vector.__div = function(a, b)
    return vec(a.X / b, a.Y / b, a.Z / b)
end
vector.__mul = function(a, b)
    return vec(a.X * b, a.Y * b, a.Z * b)
end
local function color(r, g, b)
    return { R = r, G = g, B = b }
end
local deferred = {}
local function flush()
    local pending = deferred
    deferred = {}
    for _, fn in pending do
        fn()
    end
end
local allInstances = {}
local presentation = {}
local function signal()
    local listeners = {}
    return {
        Connect = function(_, fn)
            table.insert(listeners, fn)
            return {
                Disconnect = function()
                    local i = table.find(listeners, fn)
                    if i then
                        table.remove(listeners, i)
                    end
                end,
            }
        end,
        Fire = function(_, ...)
            for _, fn in table.clone(listeners) do
                fn(...)
            end
        end,
    }
end
local function frame(x, y, z)
    if type(x) == "table" then
        x, y, z = x.X, x.Y, x.Z
    end
    local cf = {
        Position = vec(x or 0, y or 0, z or 0),
        LookVector = vec(0, 0, -1),
        RightVector = vec(1, 0, 0),
        UpVector = vec(0, 1, 0),
    }
    function cf:ToObjectSpace(other)
        return frame(
            other.Position.X - self.Position.X,
            other.Position.Y - self.Position.Y,
            other.Position.Z - self.Position.Z
        )
    end
    function cf:Lerp(other, alpha)
        local v = self.Position + (other.Position - self.Position) * alpha
        local result = frame(v.X, v.Y, v.Z)
        result.LookVector, result.RightVector, result.UpVector = other.LookVector, other.RightVector, other.UpVector
        return result
    end
    return setmetatable(cf, {
        __mul = function(a, b)
            local v = a.Position
                + a.RightVector * b.Position.X
                + a.UpVector * b.Position.Y
                - a.LookVector * b.Position.Z
            local result = frame(v.X, v.Y, v.Z)
            result.RightVector, result.UpVector, result.LookVector = a.RightVector, a.UpVector, a.LookVector
            return result
        end,
    })
end
local function instance(class)
    local object = { ClassName = class, Children = {}, Attributes = {}, Archivable = true }
    table.insert(allInstances, object)
    object.Event = signal()
    function object:Fire(...)
        self.Event:Fire(...)
    end
    object.Activated = signal()
    object.Unequipped = signal()
    object.Equipped = signal()
    object.CharacterRemoving = signal()
    object.Triggered = signal()
    object.Destroying = signal()
    object.AncestryChanged = signal()
    object.CFrame = frame()
    object.Size = vec(4, 1.2, 2) -- Roblox Part default, also used by character-root doubles.
    object.Position = vec(0, 0, 0)
    function object:GetChildren()
        local found = {}
        for _, child in allInstances do
            if child.Parent == self then
                table.insert(found, child)
            end
        end
        return found
    end
    function object:GetDescendants()
        local found = {}
        for _, child in self:GetChildren() do
            table.insert(found, child)
            for _, descendant in child:GetDescendants() do
                table.insert(found, descendant)
            end
        end
        return found
    end
    function object:IsDescendantOf(target)
        local current = self.Parent
        while current do
            if current == target then
                return true
            end
            current = current.Parent
        end
        return false
    end
    function object:PivotTo(at)
        self.CFrame = at
        self.Position = at.Position
    end
    function object:GetBoundingBox()
        local part = self:FindFirstChildWhichIsA("BasePart", true)
        return self.CFrame, part and part.Size or vec(1, 1, 1)
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
    function object:CanSetNetworkOwnership()
        return true
    end
    function object:SetNetworkOwner(owner)
        self.NetworkOwner = owner
    end
    function object:Clone()
        if not self.Archivable then
            return nil
        end
        local clone = instance(self.ClassName)
        clone.Name = self.Name
        clone.Attributes = table.clone(self.Attributes)
        clone.Size = self.Size
        clone.Color = self.Color
        clone.CFrame = self.CFrame
        clone.Grip = self.Grip
        clone.RigType, clone.DisplayName = self.RigType, self.DisplayName
        clone.Enabled, clone.ManualActivationOnly = self.Enabled, self.ManualActivationOnly
        clone.Anchored = self.Anchored
        clone.CanCollide, clone.CanTouch, clone.CanQuery = self.CanCollide, self.CanTouch, self.CanQuery
        clone.Massless, clone.CustomPhysicalProperties = self.Massless, self.CustomPhysicalProperties
        if self:IsA("TextLabel") then
            for _, property in
                {
                    "Position",
                    "BackgroundTransparency",
                    "BorderSizePixel",
                    "TextStrokeColor3",
                    "TextStrokeTransparency",
                    "TextColor3",
                    "Font",
                    "TextSize",
                    "TextWrapped",
                    "Text",
                }
            do
                clone[property] = self[property]
            end
        end
        for _, child in self:GetChildren() do
            local c = child:Clone()
            if c then
                c.Parent = clone
                if child == self.PrimaryPart then
                    clone.PrimaryPart = c
                end
            end
        end
        return clone
    end
    function object:FindFirstChildOfClass(name)
        for _, child in self:GetChildren() do
            if child:IsA(name) then
                return child
            end
        end
        return self.Children[name]
    end
    function object:IsA(name)
        return name == self.ClassName
            or (name == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart"))
    end
    function object:FindFirstChild(name, recursive)
        for _, child in self:GetChildren() do
            if child.Name == name then
                return child
            end
        end
        if recursive then
            for _, child in self:GetDescendants() do
                if child.Name == name then
                    return child
                end
            end
        end
        return self.Children[name]
    end
    function object:GetFullName()
        return (if self.Parent and self.Parent.GetFullName then self.Parent:GetFullName() .. "." else "")
            .. (self.Name or self.ClassName)
    end
    function object:FindFirstChildWhichIsA(class, recursive)
        for _, child in (if recursive then self:GetDescendants() else self:GetChildren()) do
            if child:IsA(class) then
                return child
            end
        end
        return nil
    end
    function object:SetAttribute(key, value)
        self.Attributes[key] = value
    end
    function object:FireAllClients(moment, userId, payload)
        table.insert(presentation, { Moment = moment, UserId = userId, Payload = payload })
        if self.OnClientEvent then
            self.OnClientEvent:Fire(moment, userId, payload)
        end
    end
    function object:Invoke(...)
        return self.OnInvoke(...)
    end
    function object:Emit() end
    function object:GetAttribute(key)
        return self.Attributes[key]
    end
    function object:Destroy()
        if self.Destroyed then
            return
        end
        self.Destroying:Fire()
        for _, child in self:GetChildren() do
            child:Destroy()
        end
        self.Parent = nil
        self.Destroyed = true
        self.AncestryChanged:Fire()
    end
    return object
end
local shared = { Constants = {}, Types = "Types", Events = instance("Folder") }
for name in sources do
    shared.Constants[name] = name
end
local studio = false
local now = 100
local storage = instance("Folder")
local workspaceFake = {
    Blockcast = function()
        return nil
    end,
    Raycast = function()
        return nil
    end,
    GetPartsInPart = function(_, input)
        return input.Overlaps or {}
    end,
}
local tags = {}
local nextGuid = 0
local services = {
    ReplicatedStorage = { Shared = shared },
    ServerStorage = storage,
    HttpService = {
        GenerateGUID = function()
            nextGuid += 1
            return "test-id-" .. nextGuid
        end,
    },
    RunService = {
        Heartbeat = {
            Wait = function()
                return 10
            end,
        },
        IsStudio = function()
            return studio
        end,
    },
    Players = {},
    PathfindingService = {
        CreatePath = function()
            local path = { Status = "Success", Blocked = signal() }
            function path:ComputeAsync(start, finish)
                self.Points = { { Position = start }, { Position = finish } }
            end
            function path:GetWaypoints()
                return self.Points
            end
            function path:Destroy() end
            return path
        end,
    },
    Debris = { AddItem = function() end },
    CollectionService = {
        AddTag = function(_, object, tag)
            tags[tag] = tags[tag] or {}
            tags[tag][object] = true
        end,
        RemoveTag = function(_, object, tag)
            if tags[tag] then
                tags[tag][object] = nil
            end
        end,
        GetTags = function(_, object)
            local result = {}
            for tag, objects in tags do
                if objects[object] then
                    table.insert(result, tag)
                end
            end
            return result
        end,
        HasTag = function(_, object, tag)
            return tags[tag] and tags[tag][object] == true
        end,
        GetTagged = function(_, tag)
            local objects = {}
            for object in tags[tag] or {} do
                table.insert(objects, object)
            end
            return objects
        end,
    },
}
local env = setmetatable({
    game = {
        GetService = function(_, name)
            return services[name]
        end,
    },
    workspace = workspaceFake,
    Vector2 = {
        new = function(x, y)
            return { X = x, Y = y }
        end,
    },
    Vector3 = { zero = vec(0, 0, 0), yAxis = vec(0, 1, 0), new = vec },
    Color3 = {
        new = color,
        fromRGB = function(r, g, b)
            return color(r / 255, g / 255, b / 255)
        end,
    },
    Instance = { new = instance },
    CFrame = {
        new = frame,
        lookAt = function(position, target)
            local result = frame(position)
            result.LookVector = (target - position).Unit
            result.RightVector = result.LookVector:Cross(vec(0, 1, 0))
            result.UpVector = vec(0, 1, 0)
            return result
        end,
        Angles = function()
            return frame()
        end,
    },
    UDim2 = {
        fromOffset = function(x, y)
            return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
        end,
        fromScale = function(x, y)
            return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
        end,
    },
    NumberRange = {
        new = function()
            return {}
        end,
    },
    ColorSequence = {
        new = function()
            return {}
        end,
    },
    os = {
        clock = function()
            return now
        end,
    },
    RaycastParams = {
        new = function()
            return {}
        end,
    },
    Enum = {
        PositionAlignmentMode = { OneAttachment = "OneAttachment" },
        OrientationAlignmentMode = { OneAttachment = "OneAttachment" },
        PathStatus = { Success = "Success", NoPath = "NoPath" },
        PathWaypointAction = { Jump = "Jump", Walk = "Walk" },
        RaycastFilterType = { Exclude = "Exclude" },
        Font = { GothamBold = "GothamBold", FredokaOne = "FredokaOne" },
        TextXAlignment = { Center = "Center" },
        TextYAlignment = { Center = "Center" },
        ProximityPromptStyle = { Custom = "Custom", Default = "Default" },
    },
    task = {
        spawn = function(fn)
            table.insert(deferred, fn)
        end,
        wait = function()
            return 10
        end,
        delay = function() end,
        defer = function(fn)
            table.insert(deferred, fn)
        end,
    },
    warn = function() end,
}, { __index = getfenv() })
local cache = {
    WorldUtil = {
        Near = function(player, target)
            return player.Near and target ~= nil
        end,
        Part = function(object)
            if object and (object.ClassName == "Model" or object.ClassName == "Folder") then
                return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
            end
            return object
        end,
        Prompt = function(root, name)
            local prompt = instance("ProximityPrompt")
            prompt.Name = name
            prompt.Parent = root
            return prompt
        end,
    },
    AudioService = {
        CreateBlendGroup = function()
            local audio = {}
            for _, name in { "dialogueSound", "notReadySound", "customerServeSound" } do
                audio[name] = { Play = function() end, Stop = function() end }
            end
            return audio
        end,
    },
}
local parent = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
parent.Parent = { Services = parent }
local function loadModule(name)
    if cache[name] then
        return cache[name]
    end
    local chunk = assert(loadstring(sources[name], name))
    local moduleEnv = setmetatable({ script = { Parent = parent } }, { __index = env })
    setfenv(chunk, moduleEnv)
    local result = chunk()
    cache[name] = result
    return result
end
env.require = loadModule

-- Roblox adds utf8.graphemes; authored fixture dialogue uses uncombined characters.
env.utf8 = table.clone(utf8)
env.utf8.graphemes = function(message)
    local cursor = 1
    return function()
        if cursor > #message then
            return nil
        end
        local first = cursor
        cursor = utf8.offset(message, 2, cursor) or (#message + 1)
        return first, cursor - 1
    end
end
