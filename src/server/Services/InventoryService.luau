--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local CarryPresentation = require(script.Parent.IngredientCarryPresentation)
local InventoryService = {}
local deps: any
local carried: { [Player]: { [string]: number? } } = {}
local stashes: { [Player]: { [number]: Types.StashSlot } } = {}
local stashChanged = Instance.new("BindableEvent")
InventoryService.StashChanged = stashChanged.Event
local releaseAt: { [Player]: number } = {}
type HeldItem = {
    Tool: Tool,
    Id: string,
    Root: BasePart,
    ThrowOffset: CFrame,
    ClearPose: () -> (),
    Releasing: boolean,
    Destroying: boolean,
    Connections: { RBXScriptConnection },
}
local held: { [Player]: HeldItem } = {}

-- Authorization for the loose-world pickup context only. Never use this owner rule
-- as a global inventory-transfer policy: stash acquisition must separately validate
-- its server-owned slot/protection state before granting a unit or held reservation.
-- No caller-supplied owner, slot attributes, or "allow stealing" flag grants rights here.
local function getLoosePickupRecord(player: Player, object: Instance)
    local record = deps.IngredientService.GetRecord(object)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not record
        or not record.Claimable
        or (record.Owner ~= nil and record.Owner ~= player)
        or not humanoid
        or humanoid.Health <= 0
        or not WorldUtil.Near(player, object, Economy.InteractionDistance)
    then
        return nil
    end
    return record
end

function InventoryService.ClearHeld(player: Player)
    local record = held[player]
    held[player] = nil
    player:SetAttribute("HeldIngredientId", nil)
    if record then
        record.ClearPose()
        for _, connection in record.Connections do
            connection:Disconnect()
        end
        if not record.Destroying then
            record.Tool:Destroy()
        end
    end
end

-- Spawn is synchronous. Keep the reservation until registration succeeds, and
-- block reentrant signals while restoring it. Clear before destroying the visual.
local function releaseHeld(player: Player, throwing: boolean): Instance?
    local record = held[player]
    if not record or record.Releasing then
        return nil
    end
    record.Releasing = true
    -- Retain the original character root for death/removal, even after Character changes.
    local at = record.Root.CFrame
    -- The held[player] reservation is exclusive only while carried. Both drop
    -- and throw release ownership so anyone can claim the loose world unit.
    local offset = if throwing then record.ThrowOffset else CFrame.new(0, 2, -3)
    local object = deps.IngredientService.Spawn(record.Id, at * offset, nil, true)
    if not object then
        record.Releasing = false
        return nil
    end
    InventoryService.ClearHeld(player)
    local part = WorldUtil.Part(object)
    if part and throwing then
        part.AssemblyLinearVelocity = at.LookVector * 25 + Vector3.new(0, 18, 0)
    end
    return object
end

function InventoryService.DropHeld(player: Player): Instance?
    return releaseHeld(player, false)
end

-- The equipped Tool is a reserved inventory unit. Its attributes are never read for contents.
function InventoryService.ThrowHeld(player: Player): Instance?
    local record = held[player]
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not record
        or record.Tool.Parent ~= player.Character
        or not root
        or not root:IsA("BasePart")
        or not humanoid
        or humanoid.Health <= 0
    then
        return nil
    end
    return releaseHeld(player, true)
end

-- Private synchronous equip path shared by loose pickup and stash withdrawal.
local function equipVisual(player: Player, id: string, visual: Instance): boolean
    local backpack = player:FindFirstChildOfClass("Backpack")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if held[player] or not backpack or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
        visual:Destroy()
        return false
    end
    local tool = Instance.new("Tool")
    tool.Name = id .. " (click to throw)"
    tool.CanBeDropped = false
    tool.RequiresHandle = false
    local throwOffset, clearPose = CarryPresentation.Attach(visual, tool, root)
    local reservation: HeldItem = {
        Tool = tool,
        Id = id,
        Root = root,
        ThrowOffset = throwOffset,
        ClearPose = clearPose,
        Releasing = false,
        Destroying = false,
        Connections = {},
    }
    held[player] = reservation
    player:SetAttribute("HeldIngredientId", id)
    local function dropThisTool()
        -- A queued signal from an old Tool must never drop a newer reservation.
        if held[player] == reservation then
            InventoryService.DropHeld(player)
        end
    end
    table.insert(reservation.Connections, tool.Unequipped:Connect(dropThisTool))
    table.insert(reservation.Connections, humanoid.Died:Connect(dropThisTool))
    table.insert(reservation.Connections, player.CharacterRemoving:Connect(dropThisTool))
    table.insert(
        reservation.Connections,
        tool.Destroying:Connect(function()
            reservation.Destroying = true
            dropThisTool()
        end)
    )
    table.insert(
        reservation.Connections,
        tool.Activated:Connect(function()
            if held[player] == reservation then
                InventoryService.ThrowHeld(player)
            end
        end)
    )
    tool.Parent = backpack
    humanoid:EquipTool(tool)
    return true
end

function InventoryService.CarryWorldItem(player: Player, object: Instance): boolean
    local record = getLoosePickupRecord(player, object)
    local backpack = player:FindFirstChildOfClass("Backpack")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if
        held[player]
        or not record
        or not backpack
        or not humanoid
        or humanoid.Health <= 0
        or not root
        or not root:IsA("BasePart")
    then
        return false
    end
    -- This claim-to-reservation transaction must not yield. Consume removes the server
    -- identity before another request can claim it; only the visual is cloned for carry.
    local visual = object:Clone()
    if not InventoryService.ClaimWorldItem(player, object) then
        visual:Destroy()
        return false
    end
    InventoryService.RemoveUnit(player, record.Id)
    return equipVisual(player, record.Id, visual)
end

function InventoryService.Init(services)
    deps = services
end
function InventoryService.AddPlayer(player: Player)
    carried[player] = {}
    stashes[player] = {}
    for index = 1, 5 do
        stashes[player][index] =
            { SlotIndex = index, IngredientId = nil, Count = 0, Capacity = 5, Protected = index <= 2 }
    end
    stashChanged:Fire(player)
end
function InventoryService.GetStackCap(player: Player): number
    return Upgrades.StackSize[deps.PlayerDataService.GetUpgrade(player, "StackSize")].Value
end
function InventoryService.GetStashLayout(_player: Player)
    return { Slots = 5, Protected = 2 }
end
function InventoryService.GetHeldIngredientId(player: Player): string?
    local record = held[player]
    return if record and not record.Releasing then record.Id else nil
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
    local record = getLoosePickupRecord(player, object)
    if not record then
        return false
    end
    if not InventoryService.AddUnit(player, record.Id) then
        return false
    end
    if not deps.IngredientService.Consume(object) then
        InventoryService.RemoveUnit(player, record.Id)
        return false
    end
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
-- Resolve the unique server-tagged fixture and actual slot, never a client position.
local function getSlotPart(owner: Player, index: number): BasePart?
    if type(index) ~= "number" or index ~= index or index % 1 ~= 0 or index < 1 or index > 5 then
        return nil
    end
    local plot = deps.TycoonService.GetPlot(owner)
    if not plot then
        return nil
    end
    local fixtures = deps.TycoonService.GetFixtures(plot, "PlayerStash")
    if #fixtures ~= 1 or deps.TycoonService.GetOwner(fixtures[1]) ~= owner then
        return nil
    end
    local found: BasePart? = nil
    for _, part in fixtures[1]:GetDescendants() do
        if part:IsA("BasePart") and part:GetAttribute("SlotIndex") == index then
            if found then
                return nil
            end
            found = part
        end
    end
    return found
end
local function accessible(player: Player, owner: Player, index: number): boolean
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
        and humanoid.Health > 0
        and WorldUtil.Near(player, getSlotPart(owner, index), Economy.InteractionDistance)
end
-- Authorization seam for future stealing. Protection lives in server state even when empty.
function InventoryService.CanWithdraw(player: Player, owner: Player, index: number): boolean
    local slot = stashes[owner] and stashes[owner][index]
    if not slot then
        return false
    end
    if player == owner then
        return true
    end
    if slot.Protected then
        return false
    end
    return false -- Unprotected theft is deliberately disabled in V1.
end
-- Preserve the legacy signature; id is only a match assertion, never a grant of contents.
function InventoryService.Deposit(player: Player, id: string, index: number): boolean
    local record = held[player]
    if
        not record
        or record.Releasing
        or record.Destroying
        or record.Id ~= id
        or record.Tool.Parent ~= player.Character
        or not accessible(player, player, index)
    then
        return false
    end
    local slot = stashes[player] and stashes[player][index]
    if not slot or slot.Count >= slot.Capacity or (slot.Count > 0 and slot.IngredientId ~= record.Id) then
        return false
    end
    slot.IngredientId = record.Id
    slot.Count += 1
    InventoryService.ClearHeld(player)
    stashChanged:Fire(player)
    return true
end
function InventoryService.Withdraw(player: Player, index: number, stashOwner: Player?): boolean
    local owner = stashOwner or player
    if
        held[player]
        or not InventoryService.CanWithdraw(player, owner, index)
        or not accessible(player, owner, index)
    then
        return false
    end
    local slot = stashes[owner][index]
    local id = slot.IngredientId
    if slot.Count < 1 or not id then
        return false
    end
    local visual = deps.IngredientService.CreateVisual(id)
    if not visual then
        return false
    end
    -- No yield between reserving this unit and equipping. Failed equip restores the slot.
    slot.Count -= 1
    if slot.Count == 0 then
        slot.IngredientId = nil
    end
    if not equipVisual(player, id, visual) then
        slot.Count += 1
        slot.IngredientId = id
        return false
    end
    stashChanged:Fire(owner)
    return true
end
function InventoryService.Steal(_player: Player, _owner: Player, _index: number): boolean
    return false
end
function InventoryService.RemovePlayer(player: Player)
    InventoryService.DropHeld(player)
    InventoryService.ClearHeld(player)
    carried[player] = nil
    stashes[player] = nil
    stashChanged:Fire(player)
    releaseAt[player] = nil
end
return require(script.Parent.StudioServices).Wrap("InventoryService", InventoryService)
