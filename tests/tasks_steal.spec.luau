loadModule("FilmingUtil").Init()
local tasks = loadModule("TasksService")
local tycoon = dependency.TycoonService
tasks.Init({ TycoonService = tycoon })
dependency.TasksService = tasks
dependency.PlayerDataService.IncrementStat = dataService.IncrementStat
local owner, teammate, enemy = player(), player(), player()
tasks.AddPlayer(enemy)
tasks.AddPlayer(owner)
tasks.AddPlayer(teammate)
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owner, tycoon.GetRequestContext(owner)), "join stash team")
local function stolen()
    return dataService.GetSnapshot(enemy).Stats.IngredientsStolen
end
carry(owner, "Banana")
setup(inventory.Deposit(owner, "Banana", 1), "protected stash seed")
check(not inventory.Withdraw(enemy, 1, owner), "protected withdrawal excluded")
setup(inventory.Withdraw(teammate, 1, owner), "friendly teammate withdrawal")
check(teammate:GetAttribute("TasksStealProgress") == 0 and stolen() == 0, "friendly take does not record theft")
inventory.ClearHeld(teammate)
carry(owner, "Banana")
setup(inventory.Deposit(owner, "Banana", 3), "ingredient seed")
local locked = true
dependency.LockBaseService = {
    IsLocked = function()
        return locked
    end,
}
check(not inventory.Withdraw(enemy, 3, owner), "locked withdrawal excluded")
locked = false
local backpack = enemy:FindFirstChildOfClass("Backpack")
backpack.Parent = nil
check(not inventory.Withdraw(enemy, 3, owner) and stolen() == 0, "failed equip excluded")
backpack.Parent = enemy
setup(inventory.Steal(enemy, owner, 3), "Steal routes through successful Withdraw")
check(
    enemy:GetAttribute("TasksStealProgress") == 1 and stolen() == 1,
    "ingredient transfer counts once in both independent counters"
)
inventory.ClearHeld(enemy)
grant(owner, "task-smoothie")
setup(press(owner, "STORE", 3), "smoothie stash seed")
setup(inventory.Withdraw(enemy, 3, owner), "smoothie theft")
check(
    enemy:GetAttribute("TasksStealProgress") == 2 and stolen() == 2,
    "smoothie transfer reaches same single success hook"
)
inventory.ClearHeld(enemy)
for _ = 1, 8 do
    carry(owner, "Banana")
    setup(inventory.Deposit(owner, "Banana", 3), "repeat ingredient seed")
    setup(inventory.Withdraw(enemy, 3, owner), "repeat successful theft")
    inventory.ClearHeld(enemy)
end
check(
    enemy:GetAttribute("TasksStealProgress") == 0 and stolen() == 10 and tycoon.GetCash(enemy) == 2500,
    "real tenth transfer resets task while lifetime stat remains ten"
)
check(
    presentation[#presentation].Moment == "TaskReward" and presentation[#presentation].Payload.Payout == 2500,
    "standalone completion uses existing cash feedback remote"
)
carry(owner, "Banana")
setup(inventory.Deposit(owner, "Banana", 3), "NPC seed")
setup(inventory.RemoveThiefIngredient(owner, tycoon.GetSessionId(owner)) ~= nil, "NPC removes ingredient")
check(enemy:GetAttribute("TasksStealProgress") == 0 and stolen() == 10, "NPC path cannot advance player theft")
carry(owner, "Banana")
setup(inventory.Deposit(owner, "Banana", 3), "protection seed")
now += loadModule("Economy").NormalStash.RaidWindowSeconds
check(not inventory.Withdraw(enemy, 3, owner) and stolen() == 10, "raid-protected rejection contributes nothing")
setup(inventory.Withdraw(owner, 3), "own stash remains accessible")
check(dataService.GetSnapshot(owner).Stats.IngredientsStolen == 0, "own take does not increment stat")
