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
local gameplay = loadModule("GameplayService")
gameplay.Init({ InventoryService = inventory, CombatService = loadModule("CombatService") })
local remote = shared.Events:FindFirstChild("GameplayRequest")
local requestedIds = {}
local send = remote.FireServer
function remote:FireServer(actionName, id)
    table.insert(requestedIds, id or false)
    send(self, actionName, id)
end
function shared.Events:WaitForChild(name)
    return self:FindFirstChild(name)
end
local action, mouseAction, bindings, touchEnabled = nil, nil, 0, false
services.Players.LocalPlayer = player
local textFocused = false
services.UserInputService = {
    GetFocusedTextBox = function()
        return if textFocused then {} else nil
    end,
}
services.ContextActionService = {
    BindAction = function(_, name, callback, createTouchButton)
        if name == "ThrowHeld" then
            action = callback
            touchEnabled = createTouchButton
        elseif name == "ThrowHeldMouse" then
            mouseAction = callback
            setup(not createTouchButton, "mouse action does not create mobile UI")
        end
        bindings += 1
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
check(bindings == 2, "controller startup cannot duplicate throw bindings")
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
check(inventory.GetCarryCount(player) == 2 and selectedTool.Destroyed, "one central input throws selected ingredient")
check(requestedIds[1] == selectedTool:GetAttribute("CarryItemId"), "client sends exact equipped carry identity")
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
