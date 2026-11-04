-- Passive hold sensor/controller at a mocked input boundary; real devices pending.
env.Enum.UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel" }
env.Enum.ContextActionResult = { Pass = "Pass" }
env.Enum.ContextActionPriority = { High = { Value = 3000 } }
env.Enum.KeyCode = { Space = "Space", ButtonA = "ButtonA" }
env.Enum.UserInputType = { Touch = "Touch" }
local action
services.ContextActionService = {
    BindActionAtPriority = function(_, _, callback, touch, _, ...)
        action = callback
        setup(touch == false, "sensor never creates a touch button")
    end,
    UnbindAction = function() end,
}
services.UserInputService = {
    InputEnded = signal(),
    WindowFocusReleased = signal(),
    TextBoxFocused = signal(),
    GetFocusedTextBox = function()
        return nil
    end,
}
services.GuiService = { MenuOpened = signal(), MenuIsOpen = false }
local p, h, root = subject(true)
services.Players.LocalPlayer = p
services.Players.GetPlayers = function()
    return { p }
end
local gui = instance("PlayerGui")
gui.Name, gui.Parent = "PlayerGui", p
gui.DescendantAdded, gui.DescendantRemoving = signal(), signal()
local touch = instance("ScreenGui")
touch.Name, touch.Parent = "TouchGui", gui
local button = instance("ImageButton")
button.Name, button.Parent, button.Visible = "JumpButton", touch, true
button.InputBegan, button.InputEnded = signal(), signal()
local sends = {}
local sensor = loadModule("WingsHoldSensor").Attach(gui, function(held)
    table.insert(sends, held)
    wings.SetJumpHeld(p, held)
end)
h.Mode, h.FloorMaterial = "Running", "Concrete"
wings.ApplyCharacter(p, p.Character)
local key = {}
check(action("", "Begin", key) == "Pass", "hold sensor preserves engine jump action")
action("", "Begin", key)
check(#sends == 1, "duplicate CAS Begin sends no duplicate held value")
tick(p, h, root, 0.025, 60, false)
check(state(p) == "Powered", "hold from ground engages on first airborne heartbeat")
action("", "End", key)
tick(p, h, root, 0.025, -50, false)
check(state(p) == "Falling" and #sends == 2, "CAS release immediately stops lift")
action("", "Begin", key)
fly(p, h, root, 2)
check(state(p) == "Gliding", "CAS hold eventually drives glide")
action("", "Cancel", key)
check(not wings.IsWingControlled(p), "CAS cancellation clears glide input")
check(wings.IsGraceActive(p) and state(p) == "Falling", "existing release input arms server grace while stopping lift")
action("", "Begin", key)
check(not wings.IsGraceActive(p), "existing re-engage input clears server grace")
action("", "End", key)
local finger = { UserInputType = "Touch", UserInputState = "Begin" }
button.InputBegan:Fire(finger)
check(sends[#sends] == true, "existing native mobile jump button reports press")
services.UserInputService.InputEnded:Fire(finger)
check(sends[#sends] == false, "global touch release ends hold outside button")
action("", "Begin", key)
services.UserInputService.WindowFocusReleased:Fire()
check(sends[#sends] == false, "focus loss clears held jump")
sensor.Destroy()
-- Onboarding is tied to first replicated grant and persists across respawn.
local messages = {}
cache.AnnouncementBanner = {
    Create = function()
        return {
            Show = function(message)
                table.insert(messages, message)
            end,
            Destroy = function() end,
        }
    end,
}
cache.WingsHoldSensor = {
    Attach = function()
        return { Clear = function() end }
    end,
}
services.RunService.RenderStepped = signal()
-- CFrame/mesh presentation is separately manual; exercise the real controller's
-- session grant/onboarding lifecycle without simulating engine joint transforms.
p.WaitForChild = p.FindFirstChild
replicated.WaitForChild = replicated.FindFirstChild
local controller = loadModule("WingsController")
controller.SetWingPose = function() end
controller.Init()
services.RunService.RenderStepped:Fire(1 / 60)
services.RunService.RenderStepped:Fire(1 / 60)
check(
    #messages == 1 and messages[1] == "JUMP TO FLY!\n\nHold Jump in the air to flap your wings. Keep holding to glide!",
    "first grant shows verbatim onboarding once"
)
wings.ApplyCharacter(p, p.Character)
services.RunService.RenderStepped:Fire(1 / 60)
check(#messages == 1, "respawn never repeats session onboarding")

-- Exercise the actual local RenderStepped lift independently of pose rendering.
local function renderLift(stateValue, y, dt)
    p:SetAttribute("WingState", stateValue)
    root.AssemblyLinearVelocity = vec(7, y, 9)
    services.RunService.RenderStepped:Fire(dt or 1 / 60)
    check(
        root.AssemblyLinearVelocity.X == 7 and root.AssemblyLinearVelocity.Z == 9,
        "client lift preserves horizontal velocity"
    )
    return root.AssemblyLinearVelocity.Y
end
for _, inactive in { "Falling", "Airborne", "Grounded" } do
    check(renderLift(inactive, -100) == -100, "inactive server state writes no lift")
end
check(renderLift("Powered", -100, 0) == 30, "entry burst floors falling velocity at 30")
check(renderLift("Powered", -100, 0) == -100, "entry burst fires once per Powered entry")
check(renderLift("Powered", 40, 0.1) == 45, "approach stops at configured target")
check(renderLift("Powered", 0, 0.01) == 3, "approach uses render dt")
check(renderLift("Powered", 116) == 116, "Powered preserves faster jump momentum")
check(renderLift("Gliding", -100) == -20, "dive glide caps fast descent")
check(renderLift("Gliding", 35) == 35, "glide preserves rising momentum")
check(renderLift("Gliding", -10) == -10, "glide preserves slower descent")
check(renderLift("Powered", 60, 0) == 60, "reentry burst is a floor rather than an addition")
check(renderLift("Falling", -100) == -100, "server cancellation stops lift on the next render frame")
check(renderLift("Powered", -100, 0) == 30, "a new Powered entry receives exactly one burst")
local other, oh, otherRoot = subject(true)
other:SetAttribute("WingState", "Powered")
otherRoot.AssemblyLinearVelocity = vec(1, -100, 2)
services.Players.GetPlayers = function()
    return { p, other }
end
renderLift("Grounded", -100)
check(otherRoot.AssemblyLinearVelocity.Y == -100, "local lift never drives another player")
p.Character = nil
services.RunService.RenderStepped:Fire(1 / 60)
p.Character = other.Character
otherRoot.Name = "MissingRoot"
p:SetAttribute("WingState", "Powered")
services.RunService.RenderStepped:Fire(1 / 60)
check(otherRoot.AssemblyLinearVelocity.Y == -100, "missing local character/root safely skips lift")
