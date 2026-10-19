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
    local properties = { Enabled = true, Visible = true, TextTransparency = 0 }
    local propertySignals = {}
    local object = {
        ClassName = class,
        Name = name,
        Parent = parent,
        children = {},
        DescendantAdded = signal(),
        DescendantRemoving = signal(),
        Activated = signal(),
        InputBegan = signal(),
        Ended = signal(),
        DidLoop = signal(),
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
    function object:GetAttribute(key)
        return self.attributes[key]
    end
    function object:SetAttribute(key, value)
        self.attributes[key] = value
        self:GetAttributeChangedSignal(key):Fire()
    end
    function object:GetAttributeChangedSignal(key)
        return self:GetPropertyChangedSignal("attr:" .. key)
    end
    function object:WaitForChild(key)
        return assert(self:FindFirstChild(key), key)
    end
    function object:Play()
        self.Playing = true
    end
    function object:Pause()
        self.Playing = false
    end
    function object:Resume()
        self.Playing = true
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
    if parent then
        table.insert(parent.children, object)
    end
    return object
end
