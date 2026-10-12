local viewer = fighter("A")
services.Players.LocalPlayer = viewer
local fireRemote = env.Instance.new("RemoteEvent")
fireRemote.Name, fireRemote.Parent = "IceGunFire", replicated
local sentAim = {}
local sentRays = {}
local selections = {}
function fireRemote:FireServer(aim, origin, direction, character)
    if aim == "Select" then
        table.insert(selections, { Tool = origin, Equip = direction, Character = character })
        return
    end
    if now < (viewer:GetAttribute("IceGunCooldownEnd") or 0) then
        self.OnClientEvent:Fire(false, viewer.Character, viewer:GetAttribute("IceGunCooldownEnd"), "shot cooldown")
        return
    end
    viewer:SetAttribute("IceGunCooldownEnd", now + config.ShotCooldown)
    self.OnClientEvent:Fire(true, viewer.Character, now + config.ShotCooldown)
    table.insert(sentAim, aim)
    table.insert(sentRays, { Origin = origin, Direction = direction })
end
viewer.CharacterAdded = signal()
properties(viewer)
inputTool(viewer)
local gui = env.Instance.new("PlayerGui")
gui.Parent = viewer
local preexisting = inputTool(env.Instance.new("Tool"))
preexisting:SetAttribute("IceGunWeapon", true)
preexisting.Parent = viewer:FindFirstChildOfClass("Backpack")
local inputController = loadModule("IceGunController")
inputController.Init()
moveInputTool(preexisting, viewer.Character)
fireInput(preexisting)
check(#sentAim == 1, "Tool present before controller starts fires on first hotbar selection")
moveInputTool(preexisting, viewer:FindFirstChildOfClass("Backpack"))
advance(config.ShotCooldown)
local playable = inputTool(env.Instance.new("Tool"))
-- Reproduce late weapon-attribute replication: the first ChildAdded sees no attribute.
playable.Parent = viewer:FindFirstChildOfClass("Backpack")
playable.Parent.ChildAdded:Fire(playable)
playable.Parent = viewer.Character
viewer.Character.ChildAdded:Fire(playable)
playable:SetAttribute("IceGunWeapon", true)
fireInput(playable)
check(#sentAim == 2 and screenAim == 2, "first hotbar equip fires despite late weapon attribute replication")
check(
    sentRays[1].Origin == cameraRay.Origin and sentRays[1].Direction == cameraRay.Direction,
    "camera ray accompanies untrusted target intent"
)
fireInput(playable)
check(#sentAim == 2, "local cooldown limits input chatter")
advance(config.ShotCooldown)
setInput("Touch")
fireInput(playable)
check(#sentAim == 3 and centerAim == 1, "mobile Tool activation sends camera-center aim")
check(gui:FindFirstChild("IceGunReticle") ~= nil, "touch equip displays weapon crosshair")
advance(config.ShotCooldown)
setInput("Gamepad1")
fireInput(playable)
check(#sentAim == 4 and centerAim == 2, "controller Tool activation uses camera aim")
advance(config.ShotCooldown)
viewer:SetAttribute("Stunned", true)
fireInput(playable)
check(#sentAim == 4, "frozen/stunned local input is blocked")
viewer:SetAttribute("Stunned", false)
moveInputTool(playable, viewer:FindFirstChildOfClass("Backpack"))
check(gui:FindFirstChild("IceGunReticle") == nil, "unequip removes crosshair immediately")
fireInput(playable)
check(#sentAim == 4, "unequipped stale Tool cannot fire")
moveInputTool(playable, viewer.Character)
viewer.Character.ChildAdded:Fire(playable)
fireInput(playable)
check(#sentAim == 5, "re-equip binds one activation path")
viewer.CharacterRemoving:Fire(viewer.Character)
check(gui:FindFirstChild("IceGunReticle") == nil, "character removal removes crosshair")
advance(config.ShotCooldown)
fireInput(playable)
check(#sentAim == 5, "character removal retires firing input")

local replacement = fighter("B")
viewer.Character = replacement.Character
viewer.CharacterAdded:Fire(viewer.Character)
local respawnTool = inputTool(env.Instance.new("Tool"))
respawnTool:SetAttribute("IceGunWeapon", true)
respawnTool.Parent = viewer:FindFirstChildOfClass("Backpack")
respawnTool.Parent.ChildAdded:Fire(respawnTool)
moveInputTool(respawnTool, viewer.Character)
fireInput(respawnTool)
check(#sentAim == 6, "respawned hotbar Tool fires on first selection")
advance(config.ShotCooldown)
for _, size in { { X = 390, Y = 844 }, { X = 1920, Y = 1080 }, { X = 2340, Y = 1080 } } do
    workspaceFake.CurrentCamera.ViewportSize = size
    for _, platform in { "Touch", "Gamepad1" } do
        setInput(platform)
        cameraRay = { Origin = vec(2, 5, 20), Direction = vec(0.2, -0.1, -1).Unit }
        local before = #sentAim
        fireInput(respawnTool)
        check(
            #sentAim == before + 1 and sentRays[#sentRays].Direction == cameraRay.Direction,
            "platform uses current moving camera ray at every aspect ratio"
        )
        advance(config.ShotCooldown)
    end
end
local reticle = gui:FindFirstChild("IceGunReticle")
local cross = reticle:FindFirstChild("Crosshair")
check(
    reticle.ScreenInsets == "DeviceSafeInsets" and cross.Position.X.Scale == 0.5 and cross.Position.Y.Scale == 0.5,
    "reticle shares device-safe camera coordinates"
)
check(not cross.Active and not cross.Selectable, "reticle cannot consume touch or controller navigation")
setInput("MouseMovement")
local desktopReticle = gui:FindFirstChild("IceGunReticle")
check(
    desktopReticle ~= nil and not services.UserInputService.MouseIconEnabled,
    "desktop displays circle without duplicate mouse cursor"
)
check(services.UserInputService.MouseIcon == "previous-cursor", "cursor artwork is never overwritten")
mousePosition = { X = 320, Y = 240 }
services.UserInputService.InputChanged:Fire({ UserInputType = "MouseMovement" })
local desktopCross = desktopReticle:FindFirstChild("Crosshair")
check(
    desktopCross.Position.X.Offset == 320 and desktopCross.Position.Y.Offset == 240,
    "desktop circle follows actual mouse hotspot"
)
safeOffset = { X = 59, Y = 21 }
services.GuiService:GetPropertyChangedSignal("TopbarInset"):Fire()
check(
    desktopCross.Position.X.Offset == 261 and desktopCross.Position.Y.Offset == 219,
    "pointer uses device-safe coordinates without a top-bar offset"
)
advance(config.ShotCooldown)
fireInput(respawnTool)
services.UserInputService.MouseBehavior = "LockCenter"
services.UserInputService:GetPropertyChangedSignal("MouseBehavior"):Fire()
check(
    desktopCross.Position.X.Scale == 0.5 and desktopCross.Position.Y.Scale == 0.5,
    "locked desktop cursor uses camera center"
)
advance(config.ShotCooldown)
fireInput(respawnTool)
services.UserInputService.MouseBehavior = "Default"
services.UserInputService:GetPropertyChangedSignal("MouseBehavior"):Fire()
local button = env.Instance.new("TextBox")
gui.Hovered = { button }
services.UserInputService.InputChanged:Fire({ UserInputType = "MouseMovement" })
check(
    gui:FindFirstChild("IceGunReticle") == nil and services.UserInputService.MouseIconEnabled,
    "interactive UI hover restores desktop cursor"
)
gui.Hovered = nil
services.UserInputService.InputChanged:Fire({ UserInputType = "MouseMovement" })
focusedTextBox = {}
services.UserInputService.TextBoxFocused:Fire()
check(
    gui:FindFirstChild("IceGunReticle") == nil and services.UserInputService.MouseIconEnabled,
    "text focus hides reticle and restores cursor"
)
focusedTextBox = nil
services.UserInputService.TextBoxFocusReleased:Fire()
services.GuiService.MenuIsOpen = true
services.GuiService:GetPropertyChangedSignal("MenuIsOpen"):Fire()
check(
    gui:FindFirstChild("IceGunReticle") == nil and services.UserInputService.MouseIconEnabled,
    "Roblox menu restores cursor"
)
services.GuiService.MenuIsOpen = false
services.GuiService:GetPropertyChangedSignal("MenuIsOpen"):Fire()
services.GuiService.SelectedObject = {}
services.GuiService:GetPropertyChangedSignal("SelectedObject"):Fire()
check(gui:FindFirstChild("IceGunReticle") == nil, "controller navigation hides reticle")
services.GuiService.SelectedObject = nil
services.GuiService:GetPropertyChangedSignal("SelectedObject"):Fire()
local activeScreen = gui:FindFirstChild("IceGunReticle")
activeScreen.Enabled = false
activeScreen:GetPropertyChangedSignal("Enabled"):Fire()
check(services.UserInputService.MouseIconEnabled, "disabled gameplay reticle releases cursor")
local beforeDisabledReticle = #sentAim
advance(config.ShotCooldown)
fireInput(respawnTool)
check(#sentAim == beforeDisabledReticle + 1, "visual reticle visibility does not authorize firing")
activeScreen.Enabled = true
activeScreen:GetPropertyChangedSignal("Enabled"):Fire()
services.UserInputService.WindowFocusReleased:Fire()
check(
    gui:FindFirstChild("IceGunReticle") == nil and services.UserInputService.MouseIconEnabled,
    "window focus loss releases cursor"
)
services.UserInputService.WindowFocused:Fire()
moveInputTool(respawnTool, viewer:FindFirstChildOfClass("Backpack"))
check(
    gui:FindFirstChild("IceGunReticle") == nil and services.UserInputService.MouseIconEnabled,
    "desktop unequip restores previous cursor visibility"
)
services.UserInputService.MouseIconEnabled = false
moveInputTool(respawnTool, viewer.Character)
moveInputTool(respawnTool, viewer:FindFirstChildOfClass("Backpack"))
check(not services.UserInputService.MouseIconEnabled, "previous hidden cursor state is preserved")
services.UserInputService.MouseIconEnabled = true
moveInputTool(respawnTool, viewer.Character)
setInput("Touch")
respawnTool:Destroy()
check(gui:FindFirstChild("IceGunReticle") == nil, "Tool destruction removes reticle immediately")
local lateTool = inputTool(env.Instance.new("Tool"))
moveInputTool(lateTool, viewer.Character)
check(gui:FindFirstChild("IceGunReticle") == nil, "unmarked Tool has no weapon reticle")
lateTool:SetAttribute("IceGunWeapon", true)
check(gui:FindFirstChild("IceGunReticle") ~= nil, "late authorization attribute enables equipped reticle")
for _ = 1, 20 do
    moveInputTool(lateTool, viewer:FindFirstChildOfClass("Backpack"))
    check(gui:FindFirstChild("IceGunReticle") == nil, "repeated put-away hides reticle")
    -- Late removal/unequip notifications after the same instance is selected again.
    local backpack = lateTool.Parent
    lateTool.Parent = nil
    lateTool.AncestryChanged:Fire()
    lateTool.Parent = viewer.Character
    viewer.Character.ChildAdded:Fire(lateTool)
    backpack.ChildRemoved:Fire(lateTool)
    lateTool.Unequipped:Fire()
    lateTool.Equipped:Fire()
    flush()
    check(gui:FindFirstChild("IceGunReticle") ~= nil, "late notifications preserve current equipped reticle")
    advance(config.ShotCooldown)
    local before = #sentAim
    fireInput(lateTool)
    check(#sentAim == before + 1, "deferred transfer cleanup preserves one activation after re-equip")
end
-- A pending request is not an accepted shot. A denial releases the input lock
-- immediately, and a confirmed deadline works before attribute replication.
advance(config.ShotCooldown)
setInput("MouseMovement")
local originalSend = fireRemote.FireServer
local attempted = 0
function fireRemote:FireServer(action)
    if action ~= "Select" then
        attempted += 1
    end
end
local function feedback()
    local screen = gui:FindFirstChild("IceGunReticle")
    local cross = screen and screen:FindFirstChild("Crosshair")
    return cross and cross:FindFirstChild("IceShotgunCooldownFeedback")
end
local function rejectCooldown(deadline)
    fireRemote.OnClientEvent:Fire(false, viewer.Character, deadline, "shot cooldown")
end
fireInput(lateTool)
check(attempted == 1 and not feedback(), "pending request has no cooldown feedback")
fireRemote.OnClientEvent:Fire(false, viewer.Character, 0, "muzzle obstruction")
check(not feedback(), "other rejection reasons never display cooldown feedback")
fireInput(lateTool)
check(attempted == 2, "rejected shot can be retried immediately")
local deadline = workspaceFake:GetServerTimeNow() + config.ShotCooldown
fireRemote.OnClientEvent:Fire(true, viewer.Character, deadline)
check(not feedback(), "successful shot has no countdown or ready widget")
advance(1.3)
fireInput(lateTool)
rejectCooldown(deadline)
local message = feedback()
check(
    message.Visible and message.Text == "Cooldown... 3.2s left",
    "server deadline supplies accurate remaining time before attribute replication"
)
check(
    not message.Active and not message.Selectable and message.Position.Y.Offset == 28,
    "compact message sits below crosshair without blocking input"
)
advance(0.2)
fireInput(lateTool)
rejectCooldown(deadline)
check(
    feedback() == message and message.Text == "Cooldown... 3.0s left" and message.TextTransparency == 0,
    "repeated attempts refresh one message and restart animation"
)
advance(0.4)
check(message.TextTransparency > 0 and message.Position.Y.Offset < 28, "message fades and drifts upward")
advance(0.41)
check(not message.Visible, "feedback expires after approximately 0.8 seconds")
fireInput(lateTool)
rejectCooldown(deadline)
moveInputTool(lateTool, viewer:FindFirstChildOfClass("Backpack"))
check(weaponActions.IceShotgunFire == nil and message.Destroyed, "unequip removes feedback and dedicated action")
moveInputTool(lateTool, viewer.Character)
check(not feedback(), "re-equip has no automatic cooldown message")
fireInput(lateTool)
rejectCooldown(deadline)
check(feedback().Visible, "cooldown remains authoritative after re-equip")
advance(2.2)
check(not feedback().Visible, "cooldown completion produces no ready message")
local beforeReady = attempted
fireInput(lateTool)
check(attempted == beforeReady + 1, "input sends immediately at cooldown completion")
fireRemote.OnClientEvent:Fire(true, viewer.Character, workspaceFake:GetServerTimeNow() + config.ShotCooldown)
check(not feedback().Visible, "successful firing clears existing feedback")
local function noRadial(object)
    for _, child in object:GetChildren() do
        check(child.Name ~= "IceShotgunCooldown" and child.Name ~= "FireStatus", "no radial countdown remains")
        noRadial(child)
    end
end
noRadial(gui)
setInput("Touch")
local shotsBeforeTouch = attempted
lateTool.Activated:Fire()
check(attempted == shotsBeforeTouch, "touch-world Tool activation cannot bypass the dedicated fire button")
fireInput(lateTool)
check(attempted == shotsBeforeTouch + 1, "touch fire button uses the shared firing path")
rejectCooldown(workspaceFake:GetServerTimeNow() + 3.2)
check(feedback().Text == "Cooldown... 3.2s left", "mobile cooldown feedback uses shared path")
setInput("Gamepad1")
check(weaponButtons.IceShotgunFire.Key == "ButtonR2", "console fire action uses the right trigger")
fireInput(lateTool)
check(attempted == shotsBeforeTouch + 2, "right trigger uses the shared firing path")
rejectCooldown(workspaceFake:GetServerTimeNow() + 2.1)
check(feedback().Text == "Cooldown... 2.1s left", "console cooldown feedback uses shared path")
fireRemote.FireServer = originalSend

-- Both controllers run together: Backpack ownership must not steal carry input.
lateTool.Name = "IceGun"
local throwRemote = env.Instance.new("RemoteEvent")
throwRemote.Name, throwRemote.Parent = "GameplayRequest", shared.Events
function shared.Events:WaitForChild(name)
    return self:FindFirstChild(name)
end
local throwRequests = 0
function throwRemote:FireServer(action)
    setup(action == "ThrowHeld", "carry only sends throw intent")
    throwRequests += 1
end
viewer:SetAttribute("CarryCount", 3)
loadModule("CarryInputController").Init()
local ingredientTool = inputTool(env.Instance.new("Tool"))
ingredientTool.Name = "Banana"
ingredientTool:SetAttribute("IngredientId", "Banana")
moveInputTool(lateTool, viewer:FindFirstChildOfClass("Backpack"))
moveInputTool(ingredientTool, viewer.Character)
setInput("MouseMovement")
local oldWarn, oldDebug, oldStudio = env.warn, config.DebugLogging, services.RunService.IsStudio
local activationLogs = 0
env.warn = function(message)
    if string.find(message, "Tool.Activated fired", 1, true) then
        activationLogs += 1
    end
end
config.DebugLogging = true
services.RunService.IsStudio = function()
    return true
end
local mouse = { UserInputType = "MouseButton1" }
for _ = 1, 3 do
    advance(config.ShotCooldown)
    local beforeShots, beforeThrows = #sentAim, throwRequests
    ingredientTool.Activated:Fire()
    services.UserInputService.InputBegan:Fire(mouse, false)
    check(
        #sentAim == beforeShots and throwRequests == beforeThrows + 1,
        "ingredient click throws once while owned IceGun is in Backpack"
    )
    check(activationLogs == 0, "ingredient never enters IceGun activation handler")
    moveInputTool(ingredientTool, viewer:FindFirstChildOfClass("Backpack"))
    moveInputTool(lateTool, viewer.Character)
    services.UserInputService.InputBegan:Fire(mouse, false)
    fireInput(lateTool)
    check(
        #sentAim == beforeShots + 1 and throwRequests == beforeThrows + 1,
        "switch to IceGun fires once without a carry request"
    )
    moveInputTool(lateTool, viewer:FindFirstChildOfClass("Backpack"))
    moveInputTool(ingredientTool, viewer.Character)
    activationLogs = 0
end
local beforeUI = throwRequests
services.UserInputService.InputBegan:Fire(mouse, true)
services.UserInputService.InputBegan:Fire({ UserInputType = "Touch" }, false)
check(throwRequests == beforeUI, "processed UI and touch world gestures cannot duplicate hybrid throws")
weaponActions.ThrowHeld("ThrowHeld", "Begin", { UserInputType = "Touch" })
check(throwRequests == beforeUI + 1, "dedicated mobile Throw still works with weapon controller active")
-- A Tool which loses authorization must release native activation ownership.
moveInputTool(ingredientTool, viewer:FindFirstChildOfClass("Backpack"))
moveInputTool(lateTool, viewer.Character)
lateTool:SetAttribute("IceGunWeapon", false)
advance(config.ShotCooldown)
activationLogs = 0
lateTool.Activated:Fire()
check(
    activationLogs == 0 and weaponActions.IceShotgunFire == nil,
    "revoked weapon marker removes firing input ownership"
)
lateTool:SetAttribute("IceGunWeapon", true)
env.warn, config.DebugLogging, services.RunService.IsStudio = oldWarn, oldDebug, oldStudio
setInput("Gamepad1")
fireInput(lateTool)
rejectCooldown(workspaceFake:GetServerTimeNow() + 2.1)

local deathFeedback = feedback()
local h = viewer.Character:FindFirstChildOfClass("Humanoid")
h.Health = 0
h.Died:Fire()
check(
    gui:FindFirstChild("IceGunReticle") == nil and deathFeedback.Destroyed,
    "death removes reticle and cooldown feedback immediately"
)
local shots = #sentAim
fireInput(lateTool)
check(#sentAim == shots, "dead character cannot send weapon fire")
print("PASS: Ice Gun first-grant and platform input")
