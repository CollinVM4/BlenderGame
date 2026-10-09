-- Client engine boundary shared by input presentation and first-grant integration.
env.Enum.UserInputType = {
    MouseButton1 = "MouseButton1",
    MouseButton2 = "MouseButton2",
    MouseButton3 = "MouseButton3",
    MouseMovement = "MouseMovement",
    MouseWheel = "MouseWheel",
    Keyboard = "Keyboard",
    Touch = "Touch",
    Gamepad1 = "Gamepad1",
}
env.Enum.ScreenInsets = { DeviceSafeInsets = "DeviceSafeInsets", None = "None" }
env.Enum.PreferredInput = { KeyboardAndMouse = "KeyboardAndMouse", Touch = "Touch", Gamepad = "Gamepad" }
env.Enum.MouseBehavior = { Default = "Default", LockCenter = "LockCenter", LockCurrentPosition = "LockCurrentPosition" }
env.UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}
local function properties(object)
    local events = {}
    function object:GetPropertyChangedSignal(name)
        events[name] = events[name] or signal()
        return events[name]
    end
    return object
end
local presentationNew = env.Instance.new
env.Instance.new = function(class)
    local object = properties(presentationNew(class))
    if class == "ScreenGui" then
        object.Enabled = true
    end
    if class == "PlayerGui" then
        function object:GetGuiObjectsAtPosition()
            return self.Hovered or {}
        end
    end
    return object
end
properties(workspaceFake)
local safeOffset = { X = 0, Y = 0 }
services.GuiService = properties({
    MenuIsOpen = false,
    GetInsetArea = function(_, insets)
        return {
            Min = if insets == "None" then { X = 0, Y = -36 } else { X = safeOffset.X, Y = safeOffset.Y - 36 },
        }
    end,
})
local focusedTextBox = nil
local mousePosition = { X = 200, Y = 100 }
local inputType = "MouseButton1"
services.UserInputService = properties({
    PreferredInput = "KeyboardAndMouse",
    MouseBehavior = "Default",
    MouseIcon = "previous-cursor",
    MouseIconEnabled = true,
    InputChanged = signal(),
    TextBoxFocused = signal(),
    TextBoxFocusReleased = signal(),
    WindowFocused = signal(),
    WindowFocusReleased = signal(),
    LastInputTypeChanged = signal(),
    GetLastInputType = function()
        return inputType
    end,
    GetFocusedTextBox = function()
        return focusedTextBox
    end,
    GetMouseLocation = function()
        return mousePosition
    end,
})
local function setInput(value)
    inputType = value
    services.UserInputService.PreferredInput = if value == "Touch"
        then "Touch"
        elseif value == "Gamepad1" then "Gamepad"
        else "KeyboardAndMouse"
    services.UserInputService:GetPropertyChangedSignal("PreferredInput"):Fire()
    services.UserInputService.LastInputTypeChanged:Fire(value)
end
local screenAim, centerAim = 0, 0
local cameraRay = { Origin = vec(0, 2, 10), Direction = vec(0, 0, -1) }
workspaceFake.CurrentCamera = properties({
    ViewportSize = { X = 1000, Y = 600 },
    ViewportPointToRay = function(self, x, y)
        if
            services.UserInputService.PreferredInput ~= "KeyboardAndMouse"
            or services.UserInputService.MouseBehavior == "LockCenter"
        then
            centerAim += 1
            setup(x == self.ViewportSize.X / 2 and y == self.ViewportSize.Y / 2, "device-safe camera-center aim")
        else
            screenAim += 1
            setup(
                x == mousePosition.X - safeOffset.X and y == mousePosition.Y - safeOffset.Y,
                "desktop pointer removes only device inset"
            )
        end
        return cameraRay
    end,
})
local function inputTool(tool)
    if tool.InputFixtureReady then
        return tool
    end
    tool.InputFixtureReady = true
    local attributes = {}
    function tool:GetAttributeChangedSignal(name)
        attributes[name] = attributes[name] or signal()
        return attributes[name]
    end
    local oldSet = tool.SetAttribute
    function tool:SetAttribute(name, value)
        oldSet(self, name, value)
        if attributes[name] then
            attributes[name]:Fire()
        end
    end
    return tool
end
local function moveInputTool(tool, parent)
    local old = tool.Parent
    tool.Parent = parent
    if old then
        old.ChildRemoved:Fire(tool)
    end
    if parent then
        parent.ChildAdded:Fire(tool)
    end
    tool.AncestryChanged:Fire()
    if parent and parent:IsA("Model") then
        tool.Equipped:Fire()
    else
        tool.Unequipped:Fire()
    end
    flush()
end
