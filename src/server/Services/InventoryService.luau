--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local CarryPresentation = require(script.Parent.IngredientCarryPresentation)
local SmoothieItem = require(script.Parent.SmoothieItem)
local SmoothieGeometry = require(script.Parent.SmoothieGeometry)
local InventoryService = {}
local deps: any
local carried: { [Player]: { [string]: number? } } = {}
local stashes: { [Player]: { [number]: Types.StashSlot } } = {}
local stashChanged = Instance.new("BindableEvent")
InventoryService.StashChanged = stashChanged.Event
local releaseAt: { [Player]: number } = {}
local STASH_BURST_TIMEOUT = 0.9
type StashIntent = {
    Owner: Player,
    Slot: BasePart,
    ItemType: "Ingredient" | "Smoothie",
    ItemKey: string,
    Direction: "STORE" | "TAKE",
    LastInteraction: number,
}
local stashIntents: { [Player]: StashIntent } = {}
type HeldItem = {
    Tool: Tool,
    ItemType: "Ingredient" | "Smoothie",
    Id: string?,
    Smoothie: Types.SmoothieData?,
    Root: BasePart,
    ThrowOffset: CFrame,
    ClearVisual: () -> (),
    Height: number,
    ShiftDown: ((number) -> ())?,
    Releasing: boolean,
    Destroying: boolean,
    Connections: { RBXScriptConnection },
}
local held: { [Player]: { HeldItem } } = {}
local function topItem(player: Player): HeldItem?
    local stack = held[player]
    return if stack then stack[#stack] else nil
end
function InventoryService.GetCarryCount(player: Player): number
    return #(held[player] or {})
end
function InventoryService.GetCarryCapacity(player: Player): number
    return Upgrades.CarryCapacity[deps.PlayerDataService.GetUpgrade(player, "CarryCapacity")].Value
end
local function syncHeld(player: Player)
    local top = topItem(player)
    if top then
        top.Tool.Name = if top.ItemType == "Smoothie" then "Smoothie" else (top.Id :: string) .. " (click to throw)"
    end
    player:SetAttribute("HeldIngredientId", if top and top.ItemType == "Ingredient" then top.Id else nil)
    player:SetAttribute("HeldItemType", if top then top.ItemType else nil)
    local hasSmoothie = false
    local stack = held[player]
    if stack then
        for _, item in stack do
            hasSmoothie = hasSmoothie or item.ItemType == "Smoothie"
        end
    end
    player:SetAttribute("HasSmoothie", hasSmoothie)
    player:SetAttribute("CarryCount", InventoryService.GetCarryCount(player))
end
local function removeAt(player: Player, index: number?)
    local stack = held[player]
    if not stack then
        return
    end
    local removedIndex = index or #stack
    local record = table.remove(stack, removedIndex)
    if not record then
        return
    end
    -- Transfer/disconnect shared handlers before presentation destruction can
    -- emit signals. Never reconnect them when the bottom reservation changes.
    if #stack > 0 and #record.Connections > 0 then
        stack[1].Connections = record.Connections
        record.Connections = {}
    elseif #stack == 0 then
        held[player] = nil
        for _, connection in record.Connections do
            connection:Disconnect()
        end
        record.Connections = {}
    end
    for i = removedIndex, #stack do
        local item = stack[i]
        if item.ShiftDown then
            item.ShiftDown(record.Height)
        end
        item.ThrowOffset = CFrame.new(0, -record.Height, 0) * item.ThrowOffset
    end
    record.ClearVisual()
    if #stack == 0 then
        if not record.Destroying then
            record.Tool:Destroy()
        end
    end
    syncHeld(player)
end
local function removeTop(player: Player)
    removeAt(player)
end

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
    while topItem(player) do
        removeTop(player)
    end
    syncHeld(player)
end

-- Spawn is synchronous. Keep the reservation until registration succeeds, and
-- block reentrant signals while restoring it. Clear before destroying the visual.
local function releaseHeld(player: Player, throwing: boolean, dropIndex: number?, itemIndex: number?): Instance?
    local record = if itemIndex then (held[player] or {})[itemIndex] else topItem(player)
    if not record or record.Releasing or record.ItemType ~= "Ingredient" then
        return nil
    end
    record.Releasing = true
    -- Retain the original character root for death/removal, even after Character changes.
    local at = record.Root.CFrame
    -- The held[player] reservation is exclusive only while carried. Both drop
    -- and throw release ownership so anyone can claim the loose world unit.
    local offset = if throwing then record.ThrowOffset else CFrame.new(((dropIndex or 1) - 1) * 2, 2, -3)
    local object = deps.IngredientService.Spawn(record.Id :: string, at * offset, nil, true)
    if not object then
        record.Releasing = false
        return nil
    end
    removeAt(player, itemIndex)
    local part = WorldUtil.Part(object)
    if part and throwing then
        part.AssemblyLinearVelocity = at.LookVector * 25 + Vector3.new(0, 18, 0)
    end
    return object
end

function InventoryService.DropHeld(player: Player): Instance?
    local first: Instance? = nil
    local count = InventoryService.GetCarryCount(player)
    for index = count, 1, -1 do
        -- Smoothie world dropping is deferred; keep its reservation intact.
        local record = (held[player] or {})[index]
        if not record then
            break
        end
        if record.ItemType == "Smoothie" then
            continue
        end
        local object = releaseHeld(player, false, count - index + 1, index)
        if not object then
            break
        end
        first = first or object
    end
    return first
end

-- End-of-character cleanup matches the old ephemeral cup lifecycle. Unequip and
-- voluntary drop do NOT call this: they retain smoothies until world support exists.
function InventoryService.CleanupCharacter(player: Player)
    InventoryService.DropHeld(player)
    InventoryService.ClearHeld(player)
end

-- One equipped Tool activates the top reservation only; attributes never authorize contents.
function InventoryService.ThrowHeld(player: Player): Instance?
    local record = topItem(player)
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
local function equipVisual(player: Player, id: string?, visual: Instance, smoothie: Types.SmoothieData?): boolean
    local backpack = player:FindFirstChildOfClass("Backpack")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if
        InventoryService.GetCarryCount(player) >= InventoryService.GetCarryCapacity(player)
        or not backpack
        or not humanoid
        or humanoid.Health <= 0
        or not root
        or not root:IsA("BasePart")
    then
        visual:Destroy()
        return false
    end
    local stack: { HeldItem } = held[player] or {}
    local existing = stack[1]
    local tool = if existing then existing.Tool else Instance.new("Tool")
    tool.Name = if smoothie then "Smoothie" else (id :: string) .. " (click to throw)"
    tool.CanBeDropped = false
    tool.RequiresHandle = false
    local height = 0
    for _, item in stack do
        height += item.Height
    end
    local throwOffset, clearVisual, itemHeight, shiftDown = CarryPresentation.Attach(visual, tool, root, height)
    local reservation: HeldItem = {
        Tool = tool,
        Id = id,
        ItemType = if smoothie then "Smoothie" else "Ingredient",
        Smoothie = if smoothie then SmoothieItem.Copy(smoothie) else nil,
        Root = root,
        ThrowOffset = throwOffset,
        ClearVisual = clearVisual,
        Height = itemHeight,
        ShiftDown = shiftDown,
        Releasing = false,
        Destroying = false,
        Connections = {},
    }
    table.insert(stack, reservation)
    held[player] = stack
    syncHeld(player)
    if existing then
        if tool.Parent ~= player.Character then
            humanoid:EquipTool(tool)
        end
        return true
    end
    local function dropThisTool()
        -- A queued signal from an old Tool must never drop a newer reservation.
        if held[player] == stack then
            InventoryService.DropHeld(player)
        end
    end
    local function cleanupThisTool()
        if held[player] == stack then
            InventoryService.CleanupCharacter(player)
        end
    end
    table.insert(reservation.Connections, tool.Unequipped:Connect(dropThisTool))
    table.insert(reservation.Connections, humanoid.Died:Connect(cleanupThisTool))
    table.insert(reservation.Connections, player.CharacterRemoving:Connect(cleanupThisTool))
    table.insert(
        reservation.Connections,
        tool.Destroying:Connect(function()
            for _, item in stack do
                item.Destroying = true
            end
            cleanupThisTool()
        end)
    )
    table.insert(
        reservation.Connections,
        tool.Activated:Connect(function()
            if held[player] == stack then
                InventoryService.ThrowHeld(player)
            end
        end)
    )
    tool.Parent = backpack
    humanoid:EquipTool(tool)
    return true
end

function InventoryService.GrantSmoothie(player: Player, data: Types.SmoothieData): boolean
    if
        not carried[player]
        or not SmoothieItem.Valid(data)
        or InventoryService.GetCarryCount(player) >= InventoryService.GetCarryCapacity(player)
    then
        return false
    end
    local visual = SmoothieGeometry.CreateVisual(data)
    return visual ~= nil and equipVisual(player, nil, visual, data)
end

-- A shared Tool is only a presentation match assertion; the top reservation
-- selects the specific smoothie. Neither names nor attributes authorize a serve.
function InventoryService.GetHeldSmoothie(player: Player, requested: Instance?): Types.SmoothieData?
    local record = topItem(player)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not record
        or record.ItemType ~= "Smoothie"
        or not record.Smoothie
        or record.Releasing
        or record.Destroying
        or record.Tool.Parent ~= player.Character
        or not humanoid
        or humanoid.Health <= 0
        or (requested ~= nil and requested ~= record.Tool)
    then
        return nil
    end
    return SmoothieItem.Copy(record.Smoothie)
end

function InventoryService.ConsumeHeldSmoothie(player: Player): Types.SmoothieData?
    local data = InventoryService.GetHeldSmoothie(player)
    if data then
        removeTop(player)
    end
    return data
end

function InventoryService.CarryWorldItem(player: Player, object: Instance): boolean
    local record = getLoosePickupRecord(player, object)
    local backpack = player:FindFirstChildOfClass("Backpack")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if
        InventoryService.GetCarryCount(player) >= InventoryService.GetCarryCapacity(player)
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
    stashIntents[player] = nil
    carried[player] = {}
    syncHeld(player)
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
    local record = topItem(player)
    return if record and record.ItemType == "Ingredient" and not record.Releasing then record.Id else nil
end
function InventoryService.GetSnapshot(player: Player)
    local stash = {}
    local source = stashes[player]
    if source then
        for index, stack in source do
            stash[index] = table.clone(stack)
            if stack.Smoothie then
                stash[index].Smoothie = SmoothieItem.Copy(stack.Smoothie)
            end
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
    if not deps.IngredientService.Consume(object, true) then
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
    if topItem(player) then
        return InventoryService.DropHeld(player)
    end
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
local function heldKey(record: HeldItem): string?
    return if record.Smoothie then record.Smoothie.BlendId else record.Id
end
local function slotKey(slot: Types.StashSlot): string?
    return if slot.Smoothie then slot.Smoothie.BlendId else slot.IngredientId
end
local function clearSlot(slot: Types.StashSlot)
    slot.ItemType, slot.IngredientId, slot.Smoothie = nil, nil, nil
    slot.Count, slot.Capacity = 0, 5
end
local function depositSelected(player: Player, itemType: string, key: string, index: number): boolean
    local record = topItem(player)
    if
        not record
        or record.Releasing
        or record.Destroying
        or record.ItemType ~= itemType
        or heldKey(record) ~= key
        or record.Tool.Parent ~= player.Character
        or not accessible(player, player, index)
    then
        return false
    end
    local slot = stashes[player] and stashes[player][index]
    if not slot then
        return false
    end
    if record.ItemType == "Smoothie" then
        if slot.Count ~= 0 or not record.Smoothie then
            return false
        end
        slot.IngredientId = nil
        slot.Smoothie = SmoothieItem.Copy(record.Smoothie)
        slot.Count, slot.Capacity = 1, 1
    else
        if
            slot.Count >= 5 or (slot.Count > 0 and (slot.ItemType ~= "Ingredient" or slot.IngredientId ~= record.Id))
        then
            return false
        end
        slot.Smoothie = nil
        slot.IngredientId = record.Id
        slot.Count += 1
        slot.Capacity = 5
    end
    slot.ItemType = record.ItemType
    removeTop(player)
    stashChanged:Fire(player)
    return true
end
-- Preserve the legacy ingredient-only signature; id is a match assertion.
function InventoryService.Deposit(player: Player, id: string, index: number): boolean
    return depositSelected(player, "Ingredient", id, index)
end
function InventoryService.Withdraw(player: Player, index: number, stashOwner: Player?): boolean
    local owner = stashOwner or player
    if
        InventoryService.GetCarryCount(player) >= InventoryService.GetCarryCapacity(player)
        or not InventoryService.CanWithdraw(player, owner, index)
        or not accessible(player, owner, index)
    then
        return false
    end
    local slot = stashes[owner][index]
    local id = slot.IngredientId
    local smoothie = if slot.Smoothie then SmoothieItem.Copy(slot.Smoothie) else nil
    if slot.Count < 1 or (not id and not smoothie) then
        return false
    end
    local visual = if smoothie then SmoothieGeometry.CreateVisual(smoothie) else deps.IngredientService.CreateVisual(id)
    if not visual then
        return false
    end
    -- No yield between reserving this unit and equipping. Failed equip restores the slot.
    slot.Count -= 1
    if slot.Count == 0 then
        clearSlot(slot)
    end
    if not equipVisual(player, id, visual, smoothie) then
        slot.Count += 1
        slot.IngredientId = id
        slot.Smoothie = if smoothie then SmoothieItem.Copy(smoothie) else nil
        slot.ItemType = if smoothie then "Smoothie" else "Ingredient"
        slot.Capacity = if smoothie then 1 else 5
        return false
    end
    stashChanged:Fire(owner)
    return true
end
function InventoryService.Steal(_player: Player, _owner: Player, _index: number): boolean
    return false
end
-- Prompt direction is server-owned and survives changes caused by each transfer.
-- Keep the final successful intent until a failed attempt consumes it, so exhausting
-- a stack/capacity cannot reverse direction on the next press of the same burst.
function InventoryService.InteractStash(player: Player, index: number, owner: Player?): boolean
    local now = os.clock()
    local part = if owner then getSlotPart(owner, index) else nil
    local intent: StashIntent? = stashIntents[player]
    if
        intent and (intent.Owner ~= owner or intent.Slot ~= part or now - intent.LastInteraction >= STASH_BURST_TIMEOUT)
    then
        intent = nil
    end
    stashIntents[player] = nil
    if not owner or not part then
        return false
    end
    local slot = stashes[owner] and stashes[owner][index]
    if not slot then
        return false
    end
    if not intent then
        local selected = topItem(player)
        local key = if selected then heldKey(selected) else slotKey(slot)
        local itemType: ("Ingredient" | "Smoothie")? = if selected then selected.ItemType else slot.ItemType
        if not key or not itemType then
            return false
        end
        intent = {
            Owner = owner,
            Slot = part,
            ItemType = itemType,
            ItemKey = key,
            Direction = if selected then "STORE" else "TAKE",
            LastInteraction = now,
        }
    end
    assert(intent)
    local success = false
    if intent.Direction == "STORE" then
        success = owner == player and depositSelected(player, intent.ItemType, intent.ItemKey, index)
    elseif slot.ItemType == intent.ItemType and slotKey(slot) == intent.ItemKey then
        success = InventoryService.Withdraw(player, index, owner)
    end
    if success then
        intent.LastInteraction = now
        stashIntents[player] = intent
    end
    return success
end
function InventoryService.RemovePlayer(player: Player)
    stashIntents[player] = nil
    for other, intent in stashIntents do
        if intent.Owner == player then
            stashIntents[other] = nil
        end
    end
    InventoryService.DropHeld(player)
    InventoryService.ClearHeld(player)
    carried[player] = nil
    stashes[player] = nil
    stashChanged:Fire(player)
    releaseAt[player] = nil
end
return require(script.Parent.StudioServices).Wrap("InventoryService", InventoryService)
