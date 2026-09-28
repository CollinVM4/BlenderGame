-- Cross-system stash contracts with real plot membership and smoothie geometry.
local tycoon = dependency.TycoonService
local owner, teammate, enemy = player(), player(), player()
tycoon.Init({ SessionEnded = inventory.CleanupSession })
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owner, tycoon.GetRequestContext(owner)), "join stash team")
carry(teammate, "Milk")
check(
    press(teammate, 1, owner) and slot(owner, 1).IngredientId == "Milk",
    "actual teammate stores in owner's safe slot"
)
now += 1.2
check(press(teammate, 1, owner), "actual teammate takes from safe slot")
carry(owner, "Banana")
setup(inventory.Deposit(owner, "Banana", 1), "safe stash seed")
setup(tycoon.LeaveTeam(teammate, tycoon.GetRequestContext(teammate)), "leave stash team")
check(not press(teammate, 1, owner), "former membership cannot authorize safe slot access")

local blendId = complete(owner)
setup(blend.Dispense(owner, references[owner].TurbineWheel), "dispense smoothie for theft")
flush()
setup(press(owner, 3), "stash smoothie")
local original = slot(owner, 3).Smoothie
local backpack = enemy:FindFirstChildOfClass("Backpack")
backpack.Parent = nil
check(not press(enemy, 3, owner), "smoothie equip failure rejects theft")
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
    not press(enemy, 3, owner) and inventory.GetCarryCount(enemy) == 0,
    "thrown equip failure removes carry reservation"
)
check(
    slot(owner, 3).Smoothie.BlendId == blendId and inventory.GetStashRaidState(owner).State == "Normal",
    "thrown equip failure restores smoothie without opening raid"
)
humanoid.EquipTool = equip
check(press(enemy, 3, owner), "enemy steals smoothie through normal carry path")
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
