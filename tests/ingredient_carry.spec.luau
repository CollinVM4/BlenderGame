local upgrades = loadModule("Upgrades")
local function pickup(id)
    local object = ingredients.Spawn(id, translate(), nil, true)
    return inventory.CarryWorldItem(player, object), object
end
local function tools()
    local result = {}
    for _, parent in { backpack, player.Character } do
        for _, child in parent:GetChildren() do
            if child:IsA("Tool") then
                table.insert(result, child)
            end
        end
    end
    return result
end
local function fill()
    for _ = 1, inventory.GetCarryCapacity(player) do
        setup(pickup("Banana"), "fill carry capacity")
    end
end
for tier, definition in upgrades.CarryCapacity do
    if tier > 1 then
        data.SetCash(player, definition.Cost - 1)
        check(not buyTestUpgrade(data, player, "CarryCapacity", tier), "insufficient cash rejected")
        data.SetCash(player, definition.Cost)
        check(buyTestUpgrade(data, player, "CarryCapacity", tier), "capacity upgrade accepted")
        check(data.GetCash(player) == 0, "upgrade charges configured cost")
    end
    check(inventory.GetCarryCapacity(player) == definition.Value, "configured capacity preserved")
    fill()
    local accepted, rejected = pickup("Tire")
    check(not accepted and ingredients.GetRecord(rejected) ~= nil, "full carry preserves rejected world item")
    check(#tools() == definition.Value, "one slot per carried item at capacity")
    inventory.ClearHeld(player)
    check(#tools() == 0, "clear removes all ingredient slots")
end
setup(pickup("Banana"), "pickup for failed throw")
local tool = tools()[1]
local spawn = ingredients.Spawn
ingredients.Spawn = function()
    return nil
end
check(inventory.ThrowHeld(player) == nil and inventory.GetCarryCount(player) == 1, "failed throw retains reservation")
check(not tool.Destroyed, "failed throw retains slot")
ingredients.Spawn = spawn
inventory.ClearHeld(player)
for _, event in { "combat", "death", "reset", "remove" } do
    fill()
    local slots = tools()
    if event == "combat" then
        inventory.DropOne(player)
    elseif event == "death" then
        humanoid.Died:Fire()
    elseif event == "reset" then
        player.CharacterRemoving:Fire(character)
    else
        inventory.RemovePlayer(player)
    end
    check(inventory.GetCarryCount(player) == 0 and #tools() == 0, event .. " clears carry and slots")
    for _, slot in slots do
        check(slot.Destroyed, event .. " retires each slot")
    end
end
inventory.AddPlayer(player)
local nextCharacter = instance("Model")
part("HumanoidRootPart", nextCharacter, vec(2, 2, 1), translate())
part("Head", nextCharacter, vec(2, 1, 1), translate(0, 2, 0))
local nextHumanoid = instance("Humanoid")
nextHumanoid.Parent, nextHumanoid.Health, nextHumanoid.Died = nextCharacter, 100, signal()
function nextHumanoid:EquipTool(value)
    for _, current in nextCharacter:GetChildren() do
        if current:IsA("Tool") then
            current.Parent = backpack
            current.Unequipped:Fire()
        end
    end
    value.Parent = nextCharacter
    value.Equipped:Fire()
end
player.Character = nextCharacter
fill()
check(#tools() == inventory.GetCarryCapacity(player), "respawn restores usable capacity and slots")
inventory.DropHeld(player)
