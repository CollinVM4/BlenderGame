local viewer = fighter("A")
services.Players.LocalPlayer = viewer
local fireRemote = instance("RemoteEvent")
fireRemote.Name, fireRemote.Parent = "IceGunFire", replicated
local sentAim = {}
local sentRays = {}
function fireRemote:FireServer(aim, origin, direction)
    table.insert(sentAim, aim)
    table.insert(sentRays, { Origin = origin, Direction = direction })
end
viewer.CharacterAdded = signal()
properties(viewer)
local gui = env.Instance.new("PlayerGui")
gui.Parent = viewer
local preexisting = inputTool(env.Instance.new("Tool"))
preexisting:SetAttribute("IceGunWeapon", true)
preexisting.Parent = viewer:FindFirstChildOfClass("Backpack")
local inputController = loadModule("IceGunController")
inputController.Init()
moveInputTool(preexisting, viewer.Character)
preexisting.Activated:Fire()
check(#sentAim == 1, "Tool present before controller starts fires on first hotbar selection")
moveInputTool(preexisting, viewer:FindFirstChildOfClass("Backpack"))
advance(2)
local playable = inputTool(env.Instance.new("Tool"))
-- Reproduce late weapon-attribute replication: the first ChildAdded sees no attribute.
playable.Parent = viewer:FindFirstChildOfClass("Backpack")
playable.Parent.ChildAdded:Fire(playable)
playable.Parent = viewer.Character
viewer.Character.ChildAdded:Fire(playable)
playable:SetAttribute("IceGunWeapon", true)
playable.Activated:Fire()
check(#sentAim == 2 and screenAim == 2, "first hotbar equip fires despite late weapon attribute replication")
check(
    sentRays[1].Origin == cameraRay.Origin and sentRays[1].Direction == cameraRay.Direction,
    "camera ray accompanies untrusted target intent"
)
playable.Activated:Fire()
check(#sentAim == 2, "local cooldown limits input chatter")
advance(2)
setInput("Touch")
playable.Activated:Fire()
check(#sentAim == 3 and centerAim == 1, "mobile Tool activation sends camera-center aim")
check(gui:FindFirstChild("IceGunReticle") ~= nil, "touch equip displays weapon crosshair")
advance(2)
setInput("Gamepad1")
playable.Activated:Fire()
check(#sentAim == 4 and centerAim == 2, "controller Tool activation uses camera aim")
advance(2)
viewer:SetAttribute("Stunned", true)
playable.Activated:Fire()
check(#sentAim == 4, "frozen/stunned local input is blocked")
viewer:SetAttribute("Stunned", false)
moveInputTool(playable, viewer:FindFirstChildOfClass("Backpack"))
check(gui:FindFirstChild("IceGunReticle") == nil, "unequip removes crosshair immediately")
playable.Activated:Fire()
check(#sentAim == 4, "unequipped stale Tool cannot fire")
moveInputTool(playable, viewer.Character)
viewer.Character.ChildAdded:Fire(playable)
playable.Activated:Fire()
check(#sentAim == 5, "re-equip binds one activation path")
viewer.CharacterRemoving:Fire(viewer.Character)
check(gui:FindFirstChild("IceGunReticle") == nil, "character removal removes crosshair")
advance(2)
playable.Activated:Fire()
check(#sentAim == 5, "character removal retires firing input")

local replacement = fighter("B")
viewer.Character = replacement.Character
viewer.CharacterAdded:Fire(viewer.Character)
local respawnTool = inputTool(env.Instance.new("Tool"))
respawnTool:SetAttribute("IceGunWeapon", true)
respawnTool.Parent = viewer:FindFirstChildOfClass("Backpack")
respawnTool.Parent.ChildAdded:Fire(respawnTool)
respawnTool.Parent = viewer.Character
respawnTool.Activated:Fire()
check(#sentAim == 6, "respawned hotbar Tool fires on first selection")
advance(2)
for _, size in { { X = 390, Y = 844 }, { X = 1920, Y = 1080 }, { X = 2340, Y = 1080 } } do
    workspaceFake.CurrentCamera.ViewportSize = size
    for _, platform in { "Touch", "Gamepad1" } do
        setInput(platform)
        cameraRay = { Origin = vec(2, 5, 20), Direction = vec(0.2, -0.1, -1).Unit }
        local before = #sentAim
        respawnTool.Activated:Fire()
        check(
            #sentAim == before + 1 and sentRays[#sentRays].Direction == cameraRay.Direction,
            "platform uses current moving camera ray at every aspect ratio"
        )
        advance(2)
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
advance(2)
respawnTool.Activated:Fire()
services.UserInputService.MouseBehavior = "LockCenter"
services.UserInputService:GetPropertyChangedSignal("MouseBehavior"):Fire()
check(
    desktopCross.Position.X.Scale == 0.5 and desktopCross.Position.Y.Scale == 0.5,
    "locked desktop cursor uses camera center"
)
advance(2)
respawnTool.Activated:Fire()
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
local h = viewer.Character:FindFirstChildOfClass("Humanoid")
h.Health = 0
h.Died:Fire()
check(gui:FindFirstChild("IceGunReticle") == nil, "death removes reticle immediately")
local shots = #sentAim
lateTool.Activated:Fire()
check(#sentAim == shots, "dead character cannot send weapon fire")
print("PASS: Ice Gun first-grant and platform input")
