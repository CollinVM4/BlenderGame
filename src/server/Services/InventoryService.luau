--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local InventoryService = {}
local deps: any
local carried: { [Player]: { [string]: number? } } = {}
local stashes: { [Player]: { [number]: Types.Stack } } = {}
local stealAt: { [Player]: number } = {}
local protectedUntil: { [Player]: number } = {}
local releaseAt: { [Player]: number } = {}

function InventoryService.Init(services)
    deps = services
end
function InventoryService.AddPlayer(player: Player)
    carried[player] = {}
    stashes[player] = {}
end
function InventoryService.GetStackCap(player: Player): number
    return Upgrades.StackSize[deps.PlayerDataService.GetUpgrade(player, "StackSize")].Value
end
function InventoryService.GetStashLayout(player: Player)
    return table.clone(
        if deps.PlayerDataService.HasEntitlement(player, "VIPStorage") then Economy.VIPStash else Economy.NormalStash
    )
end
function InventoryService.GetSnapshot(player: Player)
    local stash = {}
    local source = stashes[player]
    if source then
        for index, stack in source do
            stash[index] = table.clone(stack)
        end
    end
    return {
        Carried = table.clone(carried[player] or {}),
        Stash = stash,
        Layout = InventoryService.GetStashLayout(player),
    }
end
function InventoryService.AddUnit(player: Player, id: string): boolean
    if not carried[player] or not deps.IngredientService.GetDefinition(id) then
        return false
    end
    local count = carried[player][id] or 0
    if count >= InventoryService.GetStackCap(player) then
        return false
    end
    carried[player][id] = count + 1
    return true
end
function InventoryService.RemoveUnit(player: Player, id: string): boolean
    local count = carried[player] and carried[player][id] or 0
    if count < 1 then
        return false
    end
    carried[player][id] = if count == 1 then nil else count - 1
    return true
end
function InventoryService.ClaimWorldItem(player: Player, object: Instance): boolean
    local record = deps.IngredientService.GetRecord(object)
    if
        not record
        or not record.Claimable
        or (record.Owner and record.Owner ~= player)
        or not WorldUtil.Near(player, object, Economy.InteractionDistance)
    then
        return false
    end
    if not InventoryService.AddUnit(player, record.Id) then
        return false
    end
    deps.IngredientService.Consume(object)
    return true
end
-- Materialize ONE reserved unit. Caller cannot supply a spawn position or contents.
function InventoryService.ReleaseUnit(player: Player, id: string): Instance?
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local now = os.clock()
    if
        not root
        or not root:IsA("BasePart")
        or not humanoid
        or humanoid.Health <= 0
        or now < (releaseAt[player] or 0)
        or not InventoryService.RemoveUnit(player, id)
    then
        return nil
    end
    releaseAt[player] = now + 0.25
    local object = deps.IngredientService.Spawn(id, root.CFrame * CFrame.new(0, 2, -3), player)
    if not object then
        InventoryService.AddUnit(player, id)
    end
    local part = WorldUtil.Part(object)
    if part then
        part.AssemblyLinearVelocity = root.CFrame.LookVector * 25 + Vector3.new(0, 18, 0)
    end
    return object
end
function InventoryService.DropOne(player: Player): Instance?
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return nil
    end
    local id = next(carried[player] or {})
    if not id then
        return nil
    end
    InventoryService.RemoveUnit(player, id)
    local object = deps.IngredientService.Spawn(id, root.CFrame * CFrame.new(0, 1, -3), nil)
    if not object then
        InventoryService.AddUnit(player, id)
    end
    return object
end
local function validSlot(owner: Player, index: number): boolean
    return type(index) == "number"
        and index == math.floor(index)
        and index >= 1
        and index <= InventoryService.GetStashLayout(owner).Slots
end
local function nearStash(player: Player, owner: Player): boolean
    return WorldUtil.Near(player, deps.TycoonService.GetReference(owner, "PlayerStash"), Economy.InteractionDistance)
end
function InventoryService.Deposit(player: Player, id: string, index: number): boolean
    if not stashes[player] or not validSlot(player, index) or not nearStash(player, player) then
        return false
    end
    local stack = stashes[player][index]
    if stack and (stack.IngredientId ~= id or stack.Count >= InventoryService.GetStackCap(player)) then
        return false
    end
    if not InventoryService.RemoveUnit(player, id) then
        return false
    end
    stashes[player][index] = { IngredientId = id, Count = if stack then stack.Count + 1 else 1 }
    return true
end
local function take(owner: Player, index: number)
    local stack = stashes[owner][index]
    stack.Count -= 1
    if stack.Count == 0 then
        stashes[owner][index] = nil
    end
end
function InventoryService.Withdraw(player: Player, index: number): boolean
    if not stashes[player] or not validSlot(player, index) or not nearStash(player, player) then
        return false
    end
    local stack = stashes[player][index]
    if not stack or not InventoryService.AddUnit(player, stack.IngredientId) then
        return false
    end
    take(player, index)
    return true
end
function InventoryService.Steal(player: Player, owner: Player, index: number): boolean
    local now = os.clock()
    if
        player == owner
        or not stashes[owner]
        or not validSlot(owner, index)
        or index <= InventoryService.GetStashLayout(owner).Protected
        or not nearStash(player, owner)
        or now < (stealAt[player] or 0)
        or now < (protectedUntil[owner] or 0)
    then
        return false
    end
    local stack = stashes[owner][index]
    if not stack or not InventoryService.AddUnit(player, stack.IngredientId) then
        return false
    end
    take(owner, index)
    stealAt[player] = now + Economy.StealCooldown
    protectedUntil[owner] = now + Economy.VictimProtection
    deps.PlayerDataService.IncrementStat(player, "IngredientsStolen")
    return true
end
function InventoryService.RemovePlayer(player: Player)
    carried[player] = nil
    stashes[player] = nil
    stealAt[player] = nil
    protectedUntil[player] = nil
    releaseAt[player] = nil
end
return InventoryService
