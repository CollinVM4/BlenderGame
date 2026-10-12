-- Input contracts are independent of the separately tested touch layout.
cache.MobileControlLayout = { Register = function() end }
env.UDim2.new = function(xScale, xOffset, yScale, yOffset)
    return { X = { Scale = xScale, Offset = xOffset }, Y = { Scale = yScale, Offset = yOffset } }
end
-- One input action reaches the server-owned throw path, including rate limiting.
local newInstance = env.Instance.new
env.Instance.new = function(class)
    local object = newInstance(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
        function object:FireServer(...)
            self.OnServerEvent:Fire(player, ...)
        end
    end
    return object
end
services.GuiService = { MenuIsOpen = false }
local gameplay = loadModule("GameplayService")
local issuedGun = nil
local gameplayDependencies = {
    InventoryService = inventory,
    CombatService = loadModule("CombatService"),
    IceGunService = {
        IsEquipped = function(p)
            return issuedGun ~= nil and issuedGun.Parent == p.Character
        end,
    },
}
gameplay.Init(gameplayDependencies)
local remote = shared.Events:FindFirstChild("GameplayRequest")
local requestedIds = {}
local lastAttempt = nil
local send = remote.FireServer
function remote:FireServer(actionName, id, slot, context)
    lastAttempt = context
    table.insert(requestedIds, id or false)
    send(self, actionName, id, slot, context)
end
function shared.Events:WaitForChild(name)
    return self:FindFirstChild(name)
end
local action, touchEnabled = nil, false
local inputBegan = signal()
services.Players.LocalPlayer = player
local textFocused = false
services.UserInputService = {
    InputBegan = inputBegan,
    TouchEnabled = true,
    MouseEnabled = true,
    KeyboardEnabled = true,
    PreferredInput = "KeyboardAndMouse",
    GetFocusedTextBox = function()
        return if textFocused then {} else nil
    end,
}
services.ContextActionService = {
    BindAction = function(_, name, callback, createTouchButton)
        if name == "ThrowHeld" then
            action = callback
            touchEnabled = createTouchButton
        end
    end,
    SetTitle = function() end,
    SetPosition = function() end,
}
env.Enum.ContextActionResult = { Pass = "Pass", Sink = "Sink" }
env.Enum.UserInputState = { Begin = "Begin", End = "End" }
env.Enum.UserInputType = { MouseButton1 = "MouseButton1" }
env.Enum.KeyCode = { ButtonR2 = "ButtonR2" }
local controller = loadModule("CarryInputController")
controller.Init()
controller.Init()
check(action ~= nil and touchEnabled, "mobile/gamepad throw action available after repeated initialization")
for _, id in { "Banana", "Ice", "Cherries" } do
    setup(inventory.CarryWorldItem(player, ingredients.Spawn(id, translate(), nil, true)), "input fixture pickup")
end
local selectedTool
for _, t in player:FindFirstChildOfClass("Backpack"):GetChildren() do
    if t:GetAttribute("IngredientId") == "Ice" then
        selectedTool = t
    end
end
humanoid:EquipTool(selectedTool)
textFocused = true
action("ThrowHeld", "Begin")
check(inventory.GetCarryCount(player) == 3, "typing does not throw")
textFocused = false
player:SetAttribute("Stunned", true)
local beforeStun = #requestedIds
action("ThrowHeld", "Begin")
check(#requestedIds == beforeStun and inventory.GetCarryCount(player) == 3, "client stun suppresses throw request")
player:SetAttribute("Stunned", false)
action("ThrowHeld", "End")
check(inventory.GetCarryCount(player) == 3, "release edge does not throw")
action("ThrowHeld", "Begin")
check(
    inventory.GetCarryCount(player) == 2 and not selectedTool.Destroyed,
    "input throws newest even with older ingredient equipped"
)
check(requestedIds[1] == false, "client sends no gameplay selection or position")
action("ThrowHeld", "Begin")
check(inventory.GetCarryCount(player) == 2, "server throttles repeated requests")
now += 0.2
local equipped = character:FindFirstChildOfClass("Tool")
equipped.Parent = player:FindFirstChildOfClass("Backpack")
equipped.Unequipped:Fire()
local bat = instance("Tool")
bat.Name = "RenamedBat"
bat:SetAttribute("BatLevel", 1)
bat.Parent = character
local beforeBat = #requestedIds
check(touchEnabled, "mobile Throw button shares the primary action callback")
for _, edge in { "Begin", "End" } do
    check(action("ThrowHeld", edge) == "Pass", "equipped Bat leaves primary input available to Tool activation")
end
check(
    #requestedIds == beforeBat and inventory.GetCarryCount(player) == 2,
    "Bat suppresses mouse/touch throw without changing carry"
)
bat.Parent = player:FindFirstChildOfClass("Backpack")
action("ThrowHeld", "Begin")
check(requestedIds[#requestedIds] == false, "deselect sends no carry identity")
check(
    inventory.GetCarryCount(player) == 1 and inventory.GetHeldIngredientId(player) == "Banana",
    "unselected input throws newest held ingredient"
)
now += 0.2
humanoid.Health = 0
remote.OnServerEvent:Fire(player, "ThrowHeld")
check(inventory.GetCarryCount(player) == 1, "server rejects dead player throw")
humanoid.Health = 100
inventory.ClearHeld(player)
local forged = instance("Tool")
forged.Parent = character
forged:SetAttribute("IngredientId", "Banana")
now += 0.2
remote.OnServerEvent:Fire(player, "ThrowHeld")
check(inventory.GetCarryCount(player) == 0, "forged Tool cannot create authoritative inventory")

-- Physical mouse is accepted on hybrid PC hardware; GUI/CAS processed input is not.
humanoid.Health = 100
inventory.ClearHeld(player)
for _, id in { "Banana", "Ice", "Cherries" } do
    setup(inventory.CarryWorldItem(player, ingredients.Spawn(id, translate(), nil, true)), "mouse fixture pickup")
end
local mouse = { UserInputType = "MouseButton1" }
local beforeMouse = #requestedIds
inputBegan:Fire(mouse, true)
inputBegan:Fire({ UserInputType = "Touch" }, false)
check(
    #requestedIds == beforeMouse and inventory.GetCarryCount(player) == 3,
    "GUI, consumed actions and touch gestures never throw"
)
now += 0.2
inputBegan:Fire(mouse, false)
check(
    #requestedIds == beforeMouse + 1 and inventory.GetCarryCount(player) == 2,
    "hybrid PC left click throws exactly once without a world target"
)
local gun = instance("Tool")
gun.Name = "IceGun"
gun:SetAttribute("IceGunWeapon", true)
gun.Parent = character
now += 0.2
inputBegan:Fire(mouse, false)
check(#requestedIds == beforeMouse + 1, "Ice Gun owns primary mouse input")
gun.Parent = backpack
bat.Parent = character
inputBegan:Fire(mouse, false)
check(#requestedIds == beforeMouse + 1, "Bat owns primary mouse input")
bat.Parent = backpack
now += 0.2
action("ThrowHeld", "Begin")
check(inventory.GetCarryCount(player) == 1, "mobile/gamepad action remains available alongside desktop mouse")

now += 0.2
services.UserInputService.MouseEnabled = false
local beforeTouch = #requestedIds
inputBegan:Fire(mouse, false)
check(#requestedIds == beforeTouch, "touch-only synthesized mouse cannot throw")
services.UserInputService.MouseEnabled = true
services.UserInputService.TouchEnabled = false
inputBegan:Fire(mouse, false)
check(
    inventory.GetCarryCount(player) == 0 and #requestedIds == beforeTouch + 1,
    "standard desktop mouse throws newest remaining ingredient"
)

-- Correlation and rate bounds cover the opt-in pipeline without authorizing state.
now += 0.2
setup(inventory.CarryWorldItem(player, ingredients.Spawn("Banana", translate(), nil, true)), "debug pickup")
local diagnosticMessages = {}
local originalPrint = env.print
env.print = function(message)
    table.insert(diagnosticMessages, message)
end
player:SetAttribute("ThrowDebug", true)
inputBegan:Fire(mouse, false)
check(type(lastAttempt) == "number", "debug request carries numeric correlation metadata only")
local clientFound, serverFound = false, false
for _, message in diagnosticMessages do
    if string.find(message, "attempt=" .. tostring(lastAttempt) .. " ", 1, true) then
        clientFound = clientFound or string.find(message, "[ThrowInput]", 1, true) ~= nil
        serverFound = serverFound or string.find(message, "[ThrowServer]", 1, true) ~= nil
    end
end
check(clientFound and serverFound, "client attempt correlates with authoritative server outcome")
check(
    string.find(table.concat(diagnosticMessages, "\n"), "keyboard=true", 1, true) ~= nil,
    "diagnostics report hybrid capability alongside received input"
)
local beforeFlood = #diagnosticMessages
for _ = 1, 100 do
    inputBegan:Fire(mouse, true)
end
check(#diagnosticMessages - beforeFlood <= 40, "client diagnostics stay bounded under repeated input")
local trace = loadModule("IngredientThrow")
local beforeServerFlood = #diagnosticMessages
for _ = 1, 100 do
    trace.Trace(player, "test repeated rejection")
end
check(#diagnosticMessages - beforeServerFlood <= 40, "server diagnostics stay bounded under repeated rejection")
player:SetAttribute("ThrowDebug", false)
env.print = originalPrint

-- Bypass client gating to exercise the server-owned weapon decision.
now += 0.2
setup(inventory.CarryWorldItem(player, ingredients.Spawn("Ice", translate(), nil, true)), "weapon gate pickup")
issuedGun = gun
gun.Parent = character
remote.OnServerEvent:Fire(player, "ThrowHeld")
check(inventory.GetCarryCount(player) == 1, "issued equipped IceGun rejects direct ingredient throw intent")
gun.Parent = backpack
now += 0.2
remote.OnServerEvent:Fire(player, "ThrowHeld")
check(inventory.GetCarryCount(player) == 0, "Backpack IceGun does not reject server throw intent")

now += 0.2
setup(inventory.CarryWorldItem(player, ingredients.Spawn("Ice", translate(), nil, true)), "UI gate pickup")
services.GuiService.MenuIsOpen = true
local beforeMenu = #requestedIds
inputBegan:Fire(mouse, false)
check(#requestedIds == beforeMenu, "open Roblox menu blocks even unprocessed input")
services.GuiService.MenuIsOpen = false
player.GameplayPaused = true
inputBegan:Fire(mouse, false)
check(#requestedIds == beforeMenu, "paused gameplay does not initiate throws")
player.GameplayPaused = false
inputBegan:Fire(mouse, false)
check(inventory.GetCarryCount(player) == 0, "closing UI restores ingredient input")
