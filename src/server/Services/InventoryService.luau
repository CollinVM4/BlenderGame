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
    Direction: "STORE" | "TAKE",
    LastInteraction: number,
}
local stashIntents: { [Player]: StashIntent } = {}
type HeldItem = {
    Tool: Tool,
    VisualHost: Model?,
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
local switching: { [Player]: boolean } = {}
local function selectedItem(player: Player): HeldItem?
    local stack = held[player] or {}
    for index = #stack, 1, -1 do
        if stack[index].Tool.Parent == player.Character then
            return stack[index]
        end
    end
    return nil
end
local function equipTool(player: Player, humanoid: Humanoid, tool: Tool)
    switching[player] = true
    humanoid:EquipTool(tool)
    switching[player] = nil
end
function InventoryService.GetCarryCount(player: Player): number
    return #(held[player] or {})
end
function InventoryService.GetCarryCapacity(player: Player): number
    return Upgrades.CarryCapacity[deps.PlayerDataService.GetUpgrade(player, "CarryCapacity")].Value
end
local function syncHeld(player: Player)
    local top = selectedItem(player)
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
    local successor: HeldItem? = nil
    for _, item in stack do
        if item.Tool == record.Tool then
            successor = item
            break
        end
    end
    if successor then
        if #record.Connections > 0 then
            successor.Connections = record.Connections
        end
    else
        for _, connection in record.Connections do
            connection:Disconnect()
        end
    end
    if #stack == 0 then
        held[player] = nil
    end
    for i = removedIndex, #stack do
        local item = stack[i]
        if item.Tool == record.Tool then
            if item.ShiftDown then
                item.ShiftDown(record.Height)
            end
            item.ThrowOffset = CFrame.new(0, -record.Height, 0) * item.ThrowOffset
        end
    end
    local wasEquipped = record.Tool.Parent == player.Character
    record.ClearVisual()
    if not successor then
        if record.VisualHost then
            record.VisualHost:Destroy()
        end
        if not record.Destroying then
            record.Tool:Destroy()
        end
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if wasEquipped and not successor and #stack > 0 and humanoid and humanoid.Health > 0 and not switching[player] then
        equipTool(player, humanoid, stack[#stack].Tool)
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
    if not record or record.Releasing then
        return nil
    end
    record.Releasing = true
    -- Retain the original character root for death/removal, even after Character changes.
    local at = record.Root.CFrame
    -- The held[player] reservation is exclusive only while carried. Both drop
    -- and throw release ownership so anyone can claim the loose world unit.
    local offset = if throwing then record.ThrowOffset else CFrame.new(((dropIndex or 1) - 1) * 2, 2, -3)
    local object = if record.Smoothie
        then deps.SmoothieWorldItemService.Spawn(record.Smoothie, at * offset)
        else deps.IngredientService.Spawn(record.Id :: string, at * offset, nil, true)
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
        local record = (held[player] or {})[index]
        if not record then
            break
        end
        local object = releaseHeld(player, false, count - index + 1, index)
        if not object then
            break
        end
        first = first or object
    end
    return first
end

-- Release all carried items before clearing any remaining character reservations.
function InventoryService.CleanupCharacter(player: Player)
    InventoryService.DropHeld(player)
    InventoryService.ClearHeld(player)
end

-- The equipped Tool selects its own reservation (or top ingredient); contents stay server-owned.
function InventoryService.ThrowHeld(player: Player): Instance?
    local record = selectedItem(player)
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
    return releaseHeld(player, true, nil, table.find(held[player], record))
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
    local existing: HeldItem? = nil
    if not smoothie then
        for _, item in stack do
            if item.ItemType == "Ingredient" then
                existing = item
                break
            end
        end
    end
    local tool = if smoothie then visual :: Tool elseif existing then existing.Tool else Instance.new("Tool")
    tool.Name = if smoothie then "Smoothie" else (id :: string) .. " (click to throw)"
    tool.CanBeDropped = false
    tool.RequiresHandle = smoothie ~= nil
    local height = 0
    for _, item in stack do
        if item.ItemType == "Ingredient" then
            height += item.Height
        end
    end
    local throwOffset = CFrame.new(0, 1, -3)
    local clearVisual: () -> () = function() end
    local itemHeight = 0
    local shiftDown: ((number) -> ())? = nil
    if not smoothie then
        throwOffset, clearVisual, itemHeight, shiftDown = CarryPresentation.Attach(visual, tool, root, height)
    end
    local visualHost = if smoothie then nil elseif existing then existing.VisualHost else Instance.new("Model")
    if visualHost then
        visualHost.Name = "IngredientCarryVisuals"
    end
    local reservation: HeldItem = {
        VisualHost = visualHost,
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
            equipTool(player, humanoid, tool)
        end
        return true
    end
    local function ownsTool(): boolean
        local current: { HeldItem } = held[player] or {}
        for _, item in current do
            if item.Tool == tool then
                return true
            end
        end
        return false
    end
    local function cleanupThisTool()
        if ownsTool() then
            InventoryService.CleanupCharacter(player)
        end
    end
    table.insert(
        reservation.Connections,
        tool.Equipped:Connect(function()
            if visualHost then
                for _, child in visualHost:GetChildren() do
                    child.Parent = tool
                end
                visualHost.Parent = nil
            end
            syncHeld(player)
        end)
    )
    table.insert(
        reservation.Connections,
        tool.Unequipped:Connect(function()
            if not ownsTool() then
                return
            end
            if visualHost then
                for _, child in tool:GetChildren() do
                    child.Parent = visualHost
                end
                visualHost.Parent = root.Parent
            end
            if switching[player] then
                return
            end
            -- Backpack smoothies remain selectable. Mixed inventory keeps the overhead
            -- ingredient assembly while the player switches to a smoothie Tool.
            local current: { HeldItem } = held[player] or {}
            for _, item in current do
                if item.Smoothie then
                    syncHeld(player)
                    return
                end
            end
            InventoryService.DropHeld(player)
        end)
    )
    table.insert(reservation.Connections, humanoid.Died:Connect(cleanupThisTool))
    table.insert(reservation.Connections, player.CharacterRemoving:Connect(cleanupThisTool))
    table.insert(
        reservation.Connections,
        tool.Destroying:Connect(function()
            local current = held[player] or {}
            for index = #current, 1, -1 do
                local item = current[index]
                if item.Tool == tool then
                    item.Destroying = true
                    releaseHeld(player, false, nil, index)
                end
            end
        end)
    )
    table.insert(
        reservation.Connections,
        tool.Activated:Connect(function()
            local selected = selectedItem(player)
            if ownsTool() and selected and selected.Tool == tool then
                InventoryService.ThrowHeld(player)
            end
        end)
    )
    tool.Parent = backpack
    equipTool(player, humanoid, tool)
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
    local visual = SmoothieGeometry.CreateTool(data)
    return visual ~= nil and equipVisual(player, nil, visual, data)
end

-- Separate loose smoothie path; replicated contents never enter this transaction.
function InventoryService.CarryWorldSmoothie(player: Player, object: Instance): boolean
    if not WorldUtil.Near(player, object, Economy.InteractionDistance) then
        return false
    end
    return deps.SmoothieWorldItemService.Claim(object, function(data)
        return InventoryService.GrantSmoothie(player, data)
    end)
end

-- The equipped Tool selects its server-owned reservation; attributes never authorize contents.
function InventoryService.GetHeldSmoothie(player: Player, requested: Instance?): Types.SmoothieData?
    local record = selectedItem(player)
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
    local record = selectedItem(player)
    local data = InventoryService.GetHeldSmoothie(player)
    if data and record then
        removeAt(player, table.find(held[player], record))
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
    local record = selectedItem(player)
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
    local record = selectedItem(player)
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
    removeAt(player, table.find(held[player], record))
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
    local visual = if smoothie then SmoothieGeometry.CreateTool(smoothie) else deps.IngredientService.CreateVisual(id)
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
-- Direction follows the player across slots/items; failed transfers preserve it
-- until the idle timeout after the last successful transfer.
function InventoryService.InteractStash(player: Player, index: number, owner: Player?): boolean
    local now = os.clock()
    local part = if owner then getSlotPart(owner, index) else nil
    local intent: StashIntent? = stashIntents[player]
    if intent and now - intent.LastInteraction >= STASH_BURST_TIMEOUT then
        intent = nil
        stashIntents[player] = nil
    end
    if not owner or not part then
        return false
    end
    local slot = stashes[owner] and stashes[owner][index]
    if not slot then
        return false
    end
    if not intent then
        local selected = selectedItem(player)
        local key = if selected then heldKey(selected) else slotKey(slot)
        local itemType: ("Ingredient" | "Smoothie")? = if selected then selected.ItemType else slot.ItemType
        if not key or not itemType then
            return false
        end
        intent = {
            Direction = if selected then "STORE" else "TAKE",
            LastInteraction = now,
        }
    end
    assert(intent)
    local success = false
    if intent.Direction == "STORE" then
        local selected = selectedItem(player)
        local key = if selected then heldKey(selected) else nil
        if selected and key then
            success = owner == player and depositSelected(player, selected.ItemType, key, index)
        end
    else
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
    InventoryService.DropHeld(player)
    InventoryService.ClearHeld(player)
    carried[player] = nil
    stashes[player] = nil
    stashChanged:Fire(player)
    releaseAt[player] = nil
end
return require(script.Parent.StudioServices).Wrap("InventoryService", InventoryService)
