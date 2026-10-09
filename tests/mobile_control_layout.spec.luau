-- This fake UI boundary exercises live modules; Device Emulator is still required.
local assertions = 0
local function check(value, message)
    assert(value, message)
    assertions += 1
end
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            table.insert(callbacks, fn)
            return {
                Disconnect = function()
                    local index = table.find(callbacks, fn)
                    if index then
                        table.remove(callbacks, index)
                    end
                end,
            }
        end,
        Fire = function(_, ...)
            for _, fn in table.clone(callbacks) do
                fn(...)
            end
        end,
    }
end
local v2 = {}
v2.__index = v2
local function vector(x, y)
    return setmetatable({ X = x, Y = y }, v2)
end
v2.__add = function(a, b)
    return vector(a.X + b.X, a.Y + b.Y)
end
v2.__sub = function(a, b)
    return vector(a.X - b.X, a.Y - b.Y)
end
v2.__mul = function(a, b)
    return vector(a.X * b, a.Y * b)
end
v2.__div = function(a, b)
    return vector(a.X / b, a.Y / b)
end
function v2:Dot(b)
    return self.X * b.X + self.Y * b.Y
end
local function rect(low, high)
    return { Min = low, Max = high }
end
local dim = {}
dim.__eq = function(a, b)
    return a.X.Scale == b.X.Scale and a.Y.Scale == b.Y.Scale and a.X.Offset == b.X.Offset and a.Y.Offset == b.Y.Offset
end
local function fromScale(x, y)
    return setmetatable({ X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }, dim)
end
local function object(class, name, parent)
    local result = {
        ClassName = class,
        Name = name,
        Parent = parent,
        children = {},
        properties = {},
        AbsolutePosition = vector(0, 0),
        AbsoluteSize = vector(0, 0),
        AnchorPoint = vector(0, 0),
        Visible = true,
        Enabled = true,
        Size = fromScale(0, 0),
        Position = fromScale(0, 0),
        AncestryChanged = signal(),
        DescendantAdded = signal(),
        DescendantRemoving = signal(),
        ChildAdded = signal(),
        ChildRemoved = signal(),
        Destroying = signal(),
    }
    function result:IsA(kind)
        return kind == self.ClassName
            or (kind == "GuiButton" and class == "ImageButton")
            or (kind == "GuiObject" and (class == "ImageButton" or class == "Frame"))
    end
    function result:IsDescendantOf(ancestor)
        local current = self.Parent
        while current do
            if current == ancestor then
                return true
            end
            current = current.Parent
        end
        return false
    end
    function result:GetPropertyChangedSignal(property)
        self.properties[property] = self.properties[property] or signal()
        return self.properties[property]
    end
    function result:FindFirstChildOfClass(kind)
        for _, child in self.children do
            if child:IsA(kind) then
                return child
            end
        end
        return nil
    end
    function result:FindFirstChild(childName)
        for _, child in self.children do
            if child.Name == childName then
                return child
            end
        end
        return nil
    end
    function result:GetDescendants()
        local descendants = {}
        local function visit(node)
            for _, child in node.children do
                table.insert(descendants, child)
                visit(child)
            end
        end
        visit(self)
        return descendants
    end
    function result:GetChildren()
        return self.children
    end
    if parent then
        table.insert(parent.children, result)
    end
    return result
end
local function change(instance, property, value)
    instance[property] = value
    instance:GetPropertyChangedSignal(property):Fire()
end
local pending = {}
local function flush()
    for _ = 1, 10 do
        if #pending == 0 then
            return
        end
        local work = pending
        pending = {}
        for _, fn in work do
            fn()
        end
    end
    error("Layout never settles")
end
local player = object("Player", "Player")
local attributes = { CarryCount = 0 }
function player:GetAttribute(name)
    return attributes[name]
end
function player:GetAttributeChangedSignal(name)
    return self:GetPropertyChangedSignal(name)
end
local camera = object("Camera", "Camera")
camera.ViewportSize = vector(800, 400)
local workspaceMock = object("Workspace", "Workspace")
workspaceMock.CurrentCamera = camera
local input = object("UserInputService", "Input")
input.TouchEnabled = true
input.InputBegan, input.InputEnded, input.WindowFocusReleased = signal(), signal(), signal()
function input:GetFocusedTextBox()
    return nil
end
local gui = object("GuiService", "GuiService")
local bounds = rect(vector(0, 0), vector(800, 400))
local insetAvailable = true
function gui:GetInsetArea()
    assert(insetAvailable, "older API")
    return bounds
end
function gui:GetGuiInset()
    return vector(0, 36), vector(0, 0)
end
local buttons, actions = {}, {}
local bindings, writes, requests = 0, 0, {}
local remote = {
    FireServer = function(_, ...)
        table.insert(requests, { ... })
    end,
}
local services = {
    Players = { LocalPlayer = player },
    UserInputService = input,
    GuiService = gui,
    ReplicatedStorage = {
        Shared = {
            Events = {
                SprintEvents = "SprintEvents",
                WaitForChild = function()
                    return remote
                end,
            },
        },
    },
    ContextActionService = {
        BindAction = function(_, name, callback, touch)
            check(
                touch == (name ~= "ThrowHeldMouse"),
                "Only the existing Sprint and Throw actions supply touch buttons"
            )
            bindings += 1
            actions[name] = callback
        end,
        SetTitle = function() end,
        GetButton = function(_, name)
            return buttons[name]
        end,
        SetPosition = function(_, name, position)
            buttons[name].Position = position
            writes += 1
        end,
    },
}
local cache = {
    SprintEvents = function()
        return remote
    end,
}
local moduleScripts = {}
local parent = { Parent = { UI = { MobileControlLayout = "MobileControlLayout" } } }
local environment
local function load(name)
    if cache[name] then
        return cache[name]
    end
    local chunk = assert(loadstring(sources[name], name))
    moduleScripts[name] = { Parent = parent, Destroying = signal() }
    setfenv(chunk, setmetatable({ script = moduleScripts[name] }, { __index = environment }))
    cache[name] = chunk()
    return cache[name]
end
environment = setmetatable({
    game = {
        GetService = function(_, name)
            return services[name]
        end,
    },
    workspace = workspaceMock,
    Vector2 = { new = vector, zero = vector(0, 0) },
    Rect = { new = rect },
    UDim2 = { fromScale = fromScale },
    require = load,
    task = {
        defer = function(fn)
            table.insert(pending, fn)
        end,
    },
    Enum = {
        ScreenInsets = { CoreUISafeInsets = "CoreUISafeInsets" },
        ContextActionResult = { Pass = "Pass", Sink = "Sink" },
        UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel" },
        UserInputType = { MouseButton1 = "MouseButton1" },
        KeyCode = { LeftShift = "LeftShift", RightShift = "RightShift", ButtonR2 = "ButtonR2" },
    },
}, { __index = getfenv() })
local root, touchGui, jump, frame
local function scene(width, height, diameter)
    bounds = rect(vector(0, 0), vector(width, height))
    player.children = {}
    root = object("PlayerGui", "PlayerGui", player)
    touchGui = object("ScreenGui", "TouchGui", root)
    -- Deliberately use an arbitrary native hierarchy under TouchGui.
    jump = object("ImageButton", "JumpButton", object("Frame", "ArbitraryNativeContainer", touchGui))
    jump.AbsoluteSize = vector(diameter, diameter)
    jump.AbsolutePosition = vector(width - diameter - 25, height - diameter - 25)
    local screen = object("ScreenGui", "ContextActionGui", root)
    frame = object("Frame", "ContextButtonFrame", screen)
    frame.AbsolutePosition, frame.AbsoluteSize = vector(width - 220, height - 200), vector(190, 170)
    for _, name in { "SprintHeld", "ThrowHeld" } do
        buttons[name] = object("ImageButton", "ContextActionButton", frame)
    end
    buttons.ThrowHeld.AnchorPoint = vector(0.5, 1)
end
local function geometry(button)
    local parentSize, position, size = button.Parent.AbsoluteSize, button.Position, button.Size
    local extent = vector(size.X.Scale * parentSize.X, size.Y.Scale * parentSize.Y)
    local anchor = button.Parent.AbsolutePosition
        + vector(position.X.Scale * parentSize.X, position.Y.Scale * parentSize.Y)
    local center = anchor + vector((0.5 - button.AnchorPoint.X) * extent.X, (0.5 - button.AnchorPoint.Y) * extent.Y)
    return center, extent
end
local function near(a, b)
    return math.abs(a - b) < 0.001
end
local function disjoint(ac, as, bc, bs)
    return math.abs(ac.X - bc.X) + 0.001 >= (as.X + bs.X) / 2 or math.abs(ac.Y - bc.Y) + 0.001 >= (as.Y + bs.Y) / 2
end
local function verify(native)
    local sc, ss = geometry(buttons.SprintHeld)
    local tc, ts = geometry(buttons.ThrowHeld)
    for _, button in buttons do
        local c, s = geometry(button)
        check(
            c.X - s.X / 2 >= bounds.Min.X + 7.999
                and c.Y - s.Y / 2 >= bounds.Min.Y + 7.999
                and c.X + s.X / 2 <= bounds.Max.X - 7.999
                and c.Y + s.Y / 2 <= bounds.Max.Y - 7.999,
            "Entire touch target is inside the safe area"
        )
    end
    check(disjoint(sc, ss, tc, ts), "Sprint and Throw hit targets do not overlap")
    if native then
        local jc, js = jump.AbsolutePosition + jump.AbsoluteSize / 2, jump.AbsoluteSize
        check(disjoint(sc, ss, jc, js) and disjoint(tc, ts, jc, js), "Native Jump has no action overlap")
        check(near(sc.X - jc.X, -1.25 * js.X) and near(sc.Y, jc.Y), "Sprint sits immediately left at Jump height")
        check(near(tc.X - jc.X, -0.95 * js.X) and near(tc.Y - jc.Y, -0.95 * js.Y), "Throw follows the 45 degree offset")
        check(tc.X > sc.X and tc.Y < sc.Y, "Throw is above and slightly right of Sprint")
        check(near(ss.X, js.X * 0.83) and near(ts.Y, js.Y * 0.83), "Action targets use 83 percent of Jump diameter")
    end
end
scene(800, 400, 70)
local initialButtons = buttons
buttons = {}
local sprint, carry, layout = load("SprintController"), load("CarryInputController"), load("MobileControlLayout")
sprint.Init()
carry.Init()
sprint.Init()
carry.Init()
flush()
check(writes == 0, "Missing CAS buttons do not block initialization")
buttons = initialButtons
for _, button in buttons do
    root.DescendantAdded:Fire(button)
end
flush()
check(bindings == 3, "Repeated startup binds two visible actions and one mouse-only action")
verify(true)
-- Phone portrait, wide/short phone, tablet landscape/portrait, and repeated recreation.
for _, dimensions in { { 375, 760, 70 }, { 932, 350, 70 }, { 1024, 720, 120 }, { 768, 980, 120 }, { 320, 480, 70 } } do
    local oldJump, oldRoot = jump, root
    local oldSize, oldPosition = jump.AbsoluteSize, jump.AbsolutePosition
    scene(table.unpack(dimensions))
    player.ChildAdded:Fire(root)
    player.ChildRemoved:Fire(oldRoot)
    flush()
    verify(true)
    check(oldJump.AbsoluteSize == oldSize and oldJump.AbsolutePosition == oldPosition, "Native Jump was never changed")
end
-- Safe area changes and parent transforms must not change screen-relative centers.
bounds = rect(vector(18, 32), vector(300, 460))
gui:GetPropertyChangedSignal("TopbarInset"):Fire()
change(frame, "AbsolutePosition", vector(-59, -58))
change(frame, "AbsoluteSize", vector(640, 320))
change(buttons.SprintHeld, "AnchorPoint", vector(1, 0.5))
flush()
verify(true)
change(jump, "AbsolutePosition", jump.AbsolutePosition - vector(12, 8))
change(jump, "AbsoluteSize", vector(80, 80))
flush()
verify(true)
-- Force clamping near safe-area edges; still no target overlap.
change(jump, "AbsolutePosition", vector(115, 65))
flush()
verify(false)
local jc = jump.AbsolutePosition + jump.AbsoluteSize / 2
for _, button in buttons do
    local c, s = geometry(button)
    check(disjoint(c, s, jc, jump.AbsoluteSize), "Clamped target keeps Jump clear")
end
-- Unavailable, hidden, and zero-sized native controls use the bounded fallback.
change(touchGui, "Enabled", false)
flush()
verify(false)
change(touchGui, "Enabled", true)
change(jump, "AbsoluteSize", vector(0, 0))
flush()
verify(false)
change(jump, "AbsoluteSize", vector(70, 70))
change(jump, "AbsolutePosition", vector(205, 365))
flush()
verify(true)
local previousJump = jump
jump.Parent.children = {}
root.DescendantRemoving:Fire(jump)
flush()
verify(false)
jump = object("ImageButton", "JumpButton", touchGui)
jump.AbsolutePosition, jump.AbsoluteSize = vector(205, 365), vector(70, 70)
root.DescendantAdded:Fire(jump)
flush()
verify(true)
local before = writes
change(previousJump, "AbsolutePosition", vector(0, 0))
flush()
check(writes == before, "Removed native control no longer drives layout")
-- CAS can return no button during recreation; additions resolve it without polling.
local previousThrow = buttons.ThrowHeld
buttons.ThrowHeld = nil
root.DescendantRemoving:Fire(previousThrow)
flush()
buttons.ThrowHeld = object("ImageButton", "NewContextActionButton", frame)
root.DescendantAdded:Fire(buttons.ThrowHeld)
flush()
verify(true)
-- Native inset API failure also has a finite fallback.
insetAvailable = false
camera.ViewportSize = vector(320, 496)
bounds = rect(vector(0, 0), vector(320, 460))
camera:GetPropertyChangedSignal("ViewportSize"):Fire()
flush()
verify(true)
-- Input semantics remain held sprint and one Throw request on press when carrying.
actions.SprintHeld("SprintHeld", "Begin")
actions.SprintHeld("SprintHeld", "Begin")
check(#requests == 1 and requests[1][1] == true, "Holding sprint requests one start")
input.InputBegan:Fire({ KeyCode = "LeftShift" }, false)
actions.SprintHeld("SprintHeld", "End")
check(#requests == 1, "Touch release retains held Shift sprint")
input.InputEnded:Fire({ KeyCode = "LeftShift" })
check(#requests == 2 and requests[2][1] == false, "Last release stops sprint")
actions.ThrowHeld("ThrowHeld", "Begin")
check(#requests == 2, "Empty inventory sends no throw request")
attributes.CarryCount = 1
actions.ThrowHeld("ThrowHeld", "Begin")
actions.ThrowHeld("ThrowHeld", "End")
check(#requests == 3 and requests[3][1] == "ThrowHeld", "Populated inventory throws only on press")
-- Touch disabled and module teardown leave pointer/console bindings intact.
change(input, "TouchEnabled", false)
flush()
before = writes
change(jump, "AbsolutePosition", vector(150, 300))
flush()
check(writes == before and bindings == 3, "Non-touch mode stops layout without rebinding input")
change(input, "TouchEnabled", true)
flush()
layout.Register("SprintHeld")
layout.Register("ThrowHeld")
flush()
check(bindings == 3, "Recreation and repeated registration never duplicate actions")
moduleScripts.MobileControlLayout.Destroying:Fire()
before = writes
change(jump, "AbsolutePosition", vector(100, 280))
gui:GetPropertyChangedSignal("TopbarInset"):Fire()
player.ChildAdded:Fire(root)
flush()
check(writes == before, "Teardown stops all layout writes")
print(string.format("PASS: %d mobile layout/input presentation contracts (mocked Roblox UI).", assertions))
