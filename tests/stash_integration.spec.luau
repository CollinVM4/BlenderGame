-- Cross-system stash contracts with real plot membership and smoothie geometry.
local tycoon = dependency.TycoonService
local owner, teammate, enemy = player(), player(), player()
tycoon.Init({ SessionEnded = inventory.CleanupSession })
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owner, tycoon.GetRequestContext(owner)), "join stash team")
carry(teammate, "Milk")
check(
    press(teammate, "STORE", 1, owner) and slot(owner, 1).IngredientId == "Milk",
    "actual teammate stores in owner's safe slot"
)
now += 1.2
check(press(teammate, "TAKE", 1, owner), "actual teammate takes from safe slot")
carry(owner, "Banana")
setup(inventory.Deposit(owner, "Banana", 1), "safe stash seed")
setup(tycoon.LeaveTeam(teammate, tycoon.GetRequestContext(teammate)), "leave stash team")
check(not press(teammate, "TAKE", 1, owner), "former membership cannot authorize safe slot access")

local blendId = complete(owner)
setup(blend.Dispense(owner, references[owner].TurbineWheel), "dispense smoothie for theft")
flush()
setup(press(owner, "STORE", 2), "protected slot accepts smoothie")
check(slot(owner, 2).Count == 1 and slot(owner, 2).Capacity == 1, "protected smoothie capacity remains one")
grant(owner, "extra-smoothie")
check(
    not press(owner, "STORE", 2)
        and slot(owner, 2).Smoothie.BlendId == blendId
        and inventory.GetHeldSmoothie(owner).BlendId == "extra-smoothie",
    "second smoothie rejected without changing either identity"
)
inventory.ConsumeHeldSmoothie(owner)
carry(owner, "Milk")
check(
    not press(owner, "STORE", 2) and inventory.GetCarryCount(owner) == 1,
    "ingredient cannot enter an occupied smoothie slot"
)
inventory.ClearHeld(owner)
setup(press(owner, "TAKE", 2), "take smoothie from protected slot")
check(slot(owner, 2).Count == 0 and slot(owner, 2).Capacity == 3, "cleared smoothie restores ingredient capacity")
setup(press(owner, "STORE", 3), "stash smoothie")
local original = slot(owner, 3).Smoothie
local backpack = enemy:FindFirstChildOfClass("Backpack")
backpack.Parent = nil
check(not press(enemy, "TAKE", 3, owner), "smoothie equip failure rejects theft")
check(
    slot(owner, 3).Smoothie.BlendId == blendId and inventory.GetCarryCount(enemy) == 0,
    "failed smoothie transfer preserves exclusive identity"
)
backpack.Parent = enemy
local humanoid = enemy.Character:FindFirstChildOfClass("Humanoid")
local equip = humanoid.EquipTool
humanoid.EquipTool = function()
    error("injected equip failure")
end
check(
    not press(enemy, "TAKE", 3, owner) and inventory.GetCarryCount(enemy) == 0,
    "thrown equip failure removes carry reservation"
)
check(
    slot(owner, 3).Smoothie.BlendId == blendId and inventory.GetStashRaidState(owner).State == "Normal",
    "thrown equip failure restores smoothie without opening raid"
)
humanoid.EquipTool = equip
check(press(enemy, "TAKE", 3, owner), "enemy steals smoothie through normal carry path")
local stolen = inventory.GetHeldSmoothie(enemy)
check(
    stolen.BlendId == blendId and table.concat(stolen.Ingredients, ",") == table.concat(original.Ingredients, ","),
    "stolen smoothie preserves blend and ingredient order"
)
check(slot(owner, 3).Count == 0 and inventory.GetCarryCount(enemy) == 1, "successful transfer has one carried owner")
local sessionId = tycoon.GetSessionId(owner)
local plot = tycoon.GetPlot(owner)
tycoon.RemovePlayer(owner)
check(inventory.GetStashRaidState(owner).State == "Normal", "ending real plot session clears raid state")
setup(tycoon.AssignPlot(owner, plot) ~= nil, "reassign same plot")
check(
    tycoon.GetSessionId(owner) ~= sessionId and inventory.GetStashRaidState(owner).State == "Normal",
    "recycled plot gets clean raid state"
)
