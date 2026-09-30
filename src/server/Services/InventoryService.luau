--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local BatConfig = require(Shared.Constants.BatConfig)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local CarryPresentation = require(script.Parent.IngredientCarryPresentation)
local IngredientThrow = require(script.Parent.IngredientThrow)
local GameplaySfx = require(script.Parent.GameplaySfxService)
local SmoothieItem = require(script.Parent.SmoothieItem)
local SmoothieGeometry = require(script.Parent.SmoothieGeometry)
local InventoryService = {}
local MovementService = require(script.Parent.MovementService)
local deps: any
local carried: { [Player]: { [string]: number? } } = {}
local stashes: { [Player]: { [number]: Types.StashSlot } } = {}
local stashChanged = Instance.new("BindableEvent")
InventoryService.StashChanged = stashChanged.Event
local releaseAt: { [Player]: number } = {}
local StashConfig = Economy.NormalStash
local StashSlots = require(script.Parent.StashSlots)
local STASH_BURST_TIMEOUT = 0.6
local raids: { [string]: { RaidEndsAt: number, ProtectionEndsAt: number } } = {}
type StashIntent = {
    Direction: "STORE" | "TAKE",
    LastInteraction: number,
    SessionId: string,
}
local stashIntents: { [Player]: StashIntent } = {}
type HeldItem = {
    Tool: Tool,
    CarryItemId: number,
    VisualHost: Model?,
    ItemType: "Ingredient" | "Smoothie",
    Id: string?,
    Smoothie: Types.SmoothieData?,
    Root: BasePart,
    ClearVisual: () -> (),
    Height: number,
    ShiftDown: ((number) -> ())?,
    Releasing: boolean,
    Destroying: boolean,
    Connections: { RBXScriptConnection },
}
local held: { [Player]: { HeldItem } } = {}
local nextCarryItemId = 0
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
-- Client IDs are preferences, never ownership proof. Only this player's live records qualify.
local function resolveActionItem(player: Player, requestedCarryItemId: any?): HeldItem?
    local stack: { HeldItem } = held[player] or {}
    local function available(item: HeldItem): boolean
        return not item.Releasing and not item.Destroying
    end
    local selected = selectedItem(player)
    -- Smoothies keep their existing exact equipped selection, independent of ingredient hints.
    if selected and selected.ItemType == "Smoothie" and available(selected) then
        return selected
    end
    local requested = requestedCarryItemId
    if requested == nil and selected and selected.ItemType == "Ingredient" then
        requested = selected.Tool:GetAttribute("CarryItemId")
    end
    if type(requested) == "number" and requested == requested and requested > 0 and requested % 1 == 0 then
        for _, item in stack do
            if item.CarryItemId == requested and item.ItemType == "Ingredient" and available(item) then
                return item
            end
        end
    end
    for index = #stack, 1, -1 do
        local item = stack[index]
        if item.ItemType == "Ingredient" and available(item) then
            return item
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
    -- These attributes describe the action target, including unequipped ingredient fallback.
    local top = resolveActionItem(player)
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
    CarryPresentation.RefreshValue(player, stack or {})
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
    for _, connection in record.Connections do
        connection:Disconnect()
    end
    if #stack == 0 then
        held[player] = nil
    end
    for i = removedIndex, #stack do
        local item = stack[i]
        if item.ShiftDown then
            item.ShiftDown(record.Height)
        end
    end
    local wasEquipped = record.Tool.Parent == player.Character
    record.ClearVisual()
    if record.VisualHost then
        record.VisualHost:Destroy()
    end
    if not record.Destroying then
        record.Tool:Destroy()
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if wasEquipped and #stack > 0 and humanoid and humanoid.Health > 0 and not switching[player] then
        local nextItem = stack[#stack]
        -- Continue the ingredient stack when removing its selected slot in mixed carry.
        if record.ItemType == "Ingredient" then
            for i = #stack, 1, -1 do
                if stack[i].ItemType == "Ingredient" then
                    nextItem = stack[i]
                    break
                end
            end
        end
        equipTool(player, humanoid, nextItem.Tool)
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
local function getLoosePickupRecord(player: Player, object: Instance): { Id: string }?
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

-- Spawn is synchronous. Keep reservations through fallible geometry preparation;
-- ingredient throws clear/reflow carry before publishing the new physical object.
local function releaseHeld(
    player: Player,
    throwing: boolean,
    dropIndex: number?,
    itemIndex: number?,
    scatter: Vector3?
): Instance?
    local record = if itemIndex then (held[player] or {})[itemIndex] else topItem(player)
    if not record or record.Releasing then
        return nil
    end
    record.Releasing = true
    if throwing and not record.Smoothie then
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not character or not root or not root:IsA("BasePart") then
            record.Releasing = false
            return nil
        end
        local at = IngredientThrow.Origin(root)
        local object = deps.IngredientService.Spawn(record.Id :: string, at, nil, true, {
            BeforePublish = function(prepared: Instance)
                removeAt(player, itemIndex)
                IngredientThrow.IgnoreCharacter(prepared, character)
            end,
        })
        if not object then
            record.Releasing = false
            return nil
        end
        local part = WorldUtil.Part(object)
        if part then
            part.AssemblyLinearVelocity = at.LookVector * 25 + Vector3.new(0, 18, 0)
        end
        return object
    end
    -- Retain the original character root for death/removal, even after Character changes.
    local at = record.Root.CFrame
    -- The held[player] reservation is exclusive only while carried. Both drop
    -- and throw release ownership so anyone can claim the loose world unit.
    local offset = if throwing then CFrame.new(0, 1, -3) else CFrame.new(((dropIndex or 1) - 1) * 2, 2, -3)
    local spawnAt = if scatter
        then CFrame.new(
            at.Position + scatter * BatConfig.Scatter.SpawnRadius + Vector3.new(0, BatConfig.Scatter.SpawnHeight, 0)
        )
        else at * offset
    local object = if record.Smoothie
        then deps.SmoothieWorldItemService.Spawn(record.Smoothie, at * offset)
        else deps.IngredientService.Spawn(record.Id :: string, spawnAt, nil, true)
    if not object then
        record.Releasing = false
        return nil
    end
    removeAt(player, itemIndex)
    local part = WorldUtil.Part(object)
    if part and throwing then
        part.AssemblyLinearVelocity = at.LookVector * 25 + Vector3.new(0, 18, 0)
    elseif part and scatter then
        local tuning = BatConfig.Scatter
        part.AssemblyLinearVelocity = scatter
                * (tuning.HorizontalMin + math.random() * (tuning.HorizontalMax - tuning.HorizontalMin))
            + Vector3.new(0, tuning.UpwardMin + math.random() * (tuning.UpwardMax - tuning.UpwardMin), 0)
        if player.Character then
            IngredientThrow.IgnoreCharacter(object, player.Character)
        end
    end
    return object
end

-- Forced drops use held records, never Backpack contents; smoothies remain reserved.
function InventoryService.DropCarriedIngredients(player: Player, reason: string?, away: Vector3?): number
    local dropped = 0
    local count = 0
    local stack: { HeldItem } = held[player] or {}
    for _, record in stack do
        if record.ItemType == "Ingredient" then
            count += 1
        end
    end
    local flat = if away then Vector3.new(away.X, 0, away.Z) else Vector3.new(0, 0, -1)
    local direction: Vector3 = if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
    for index = #(held[player] or {}), 1, -1 do
        local record = (held[player] or {})[index]
        if record and record.ItemType == "Ingredient" then
            local scatter: Vector3? = nil
            if reason == "BatStun" then
                -- Stratified random fan prevents a multi-item burst sharing one trajectory.
                local angle = ((dropped + 0.2 + math.random() * 0.6) / math.max(count, 1) - 0.5)
                    * math.rad(BatConfig.Scatter.FanAngle)
                scatter = direction * math.cos(angle) + Vector3.new(-direction.Z, 0, direction.X) * math.sin(angle)
            end
            if releaseHeld(player, false, dropped + 1, index, scatter) then
                dropped += 1
            end
        end
    end
    return dropped
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

-- Exact selected identity takes priority; unselected/invalid ingredient hints use newest-first.
function InventoryService.ThrowHeld(player: Player, requestedCarryItemId: any?): Instance?
    if not MovementService.CanPerformGameplayAction(player) then
        return nil
    end
    local record = resolveActionItem(player, requestedCarryItemId)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not record or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
        return nil
    end
    local origin = IngredientThrow.Origin(root).Position
    local object = releaseHeld(player, true, nil, table.find(held[player], record))
    if object and record.ItemType == "Ingredient" then
        GameplaySfx.Emit("IngredientThrow", origin)
    end
    return object
end

-- Private synchronous equip path shared by loose pickup and stash withdrawal.
-- onCommitted fires the instant the reservation enters the authoritative held
-- stack, before Tool parenting/EquipTool presentation work runs.
local function equipVisual(
    player: Player,
    id: string?,
    visual: Instance,
    smoothie: Types.SmoothieData?,
    onCommitted: (() -> ())?
): boolean
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
    local tool = if smoothie then visual :: Tool else Instance.new("Tool")
    nextCarryItemId += 1
    if smoothie then
        tool.Name = "Smoothie"
    else
        local definition = deps.IngredientService.GetDefinition(id)
        tool.Name = definition.DisplayName or (id :: string)
        tool:SetAttribute("IngredientId", id)
        tool:SetAttribute("CarryItemId", nextCarryItemId)
        tool:SetAttribute("ItemType", "Ingredient")
    end
    tool.CanBeDropped = false
    tool.RequiresHandle = smoothie ~= nil
    local height = 0
    for _, item in stack do
        if item.ItemType == "Ingredient" then
            height += item.Height
        end
    end
    local clearVisual: () -> () = function() end
    local itemHeight = 0
    local shiftDown: ((number) -> ())? = nil
    local visualHost = if smoothie then nil else Instance.new("Model")
    if visualHost then
        visualHost.Name = "IngredientCarryVisuals"
        visualHost:SetAttribute("CarryItemId", nextCarryItemId)
        visualHost.Parent = root.Parent
        local _visualOffset
        _visualOffset, clearVisual, itemHeight, shiftDown = CarryPresentation.Attach(visual, visualHost, root, height)
    end
    local reservation: HeldItem = {
        VisualHost = visualHost,
        Tool = tool,
        CarryItemId = nextCarryItemId,
        Id = id,
        ItemType = if smoothie then "Smoothie" else "Ingredient",
        Smoothie = if smoothie then SmoothieItem.Copy(smoothie) else nil,
        Root = root,
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
    if onCommitted then
        onCommitted()
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
            syncHeld(player)
        end)
    )
    table.insert(
        reservation.Connections,
        tool.Unequipped:Connect(function()
            if not ownsTool() then
                return
            end
            -- Selection changes never transfer ownership or remove overhead visuals.
            syncHeld(player)
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
    tool.Parent = backpack
    local equipped = pcall(equipTool, player, humanoid, tool)
    if not equipped or tool.Parent ~= player.Character then
        -- Suppress automatic re-equip while removing a failed reservation.
        switching[player] = true
        local failedIndex = table.find(held[player] or {}, reservation)
        if failedIndex then
            removeAt(player, failedIndex)
        end
        switching[player] = nil
        return false
    end
    if id and not smoothie and deps.DiscoveryService then
        deps.DiscoveryService.DiscoverIngredient(player, id)
    end
    return true
end

function InventoryService.GrantSmoothie(player: Player, data: Types.SmoothieData): boolean
    if
        not MovementService.CanPerformGameplayAction(player)
        or not carried[player]
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
    if not MovementService.CanPerformGameplayAction(player) then
        return false
    end
    if not WorldUtil.Near(player, object, Economy.InteractionDistance) then
        return false
    end
    return deps.SmoothieWorldItemService.Claim(object, function(data)
        return InventoryService.GrantSmoothie(player, data)
    end)
end

-- The equipped Tool selects its server-owned reservation; attributes never authorize contents.
function InventoryService.GetHeldSmoothie(player: Player, requested: Instance?): Types.SmoothieData?
    if not MovementService.CanPerformGameplayAction(player) then
        return nil
    end
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

-- Reserve/consume privately so failed carry equips cannot unlock a discovery.
local claimWorldItem: (Player, Instance) -> boolean

function InventoryService.CarryWorldItem(player: Player, object: Instance): boolean
    if not MovementService.CanPerformGameplayAction(player) then
        return false
    end
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
    local pickupPart = WorldUtil.Part(object)
    local pickupPosition = if pickupPart then pickupPart.Position else nil
    local visual = object:Clone()
    if not claimWorldItem(player, object) then
        visual:Destroy()
        return false
    end
    InventoryService.RemoveUnit(player, record.Id)
    local equipped = equipVisual(player, record.Id, visual, nil, function()
        if pickupPosition then
            GameplaySfx.Emit("IngredientPickup", pickupPosition)
        end
    end)
    return equipped
end

function InventoryService.Init(services)
    deps = services
end
function InventoryService.AddPlayer(player: Player)
    stashIntents[player] = nil
    carried[player] = {}
    syncHeld(player)
    stashes[player] = {}
    for index = 1, Upgrades.SecondStorage[2].Value do
        stashes[player][index] = {
            SlotIndex = index,
            Ingredients = {},
            Count = 0,
            Capacity = StashConfig.IngredientCapacity,
            Protected = index <= StashConfig.Protected,
        }
    end
    stashChanged:Fire(player)
end
function InventoryService.GetStackCap(player: Player): number
    return Upgrades.StackSize[deps.PlayerDataService.GetUpgrade(player, "StackSize")].Value
end
function InventoryService.GetStashLayout(player: Player)
    local tier = if deps.TycoonService.GetUpgrade then deps.TycoonService.GetUpgrade(player, "SecondStorage") else 1
    return { Slots = Upgrades.SecondStorage[tier].Value, Protected = StashConfig.Protected }
end
function InventoryService.GetHeldIngredientId(player: Player): string?
    local record = resolveActionItem(player)
    return if record and record.ItemType == "Ingredient" and not record.Releasing then record.Id else nil
end
-- Server-only consumption of the same selected/fallback carry record as throw.
-- Remove the reservation before destroying its Tool so reentrant actions cannot
-- consume it twice. Attributes and caller-provided ingredient IDs grant no rights.
function InventoryService.ConsumeHeldIngredient(player: Player, expectedId: string): string?
    local record = resolveActionItem(player)
    local backpack = player:FindFirstChildOfClass("Backpack")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if
        not MovementService.CanPerformGameplayAction(player)
        or not humanoid
        or humanoid.Health <= 0
        or not record
        or record.ItemType ~= "Ingredient"
        or record.Id ~= expectedId
        or not record.Tool.Parent
        or (record.Tool.Parent ~= player.Character and record.Tool.Parent ~= backpack)
        or not record.Root.Parent
    then
        return nil
    end
    record.Releasing = true
    removeAt(player, table.find(held[player], record))
    return record.Id
end
-- Deadlines are evaluated on demand; no delayed callback can reach a recycled plot.
function InventoryService.GetStashRaidState(owner: Player)
    local sessionId = deps.TycoonService.GetSessionId(owner)
    local raid = if sessionId then raids[sessionId] else nil
    local now = workspace:GetServerTimeNow()
    return {
        SessionId = sessionId,
        State = if not raid or now >= raid.ProtectionEndsAt
            then "Normal"
            elseif now < raid.RaidEndsAt then "RaidActive"
            else "Protected",
        RaidEndsAt = if raid then raid.RaidEndsAt else 0,
        ProtectionEndsAt = if raid then raid.ProtectionEndsAt else 0,
    }
end
function InventoryService.CleanupSession(sessionId: string)
    raids[sessionId] = nil
    for player, intent in stashIntents do
        if intent.SessionId == sessionId then
            stashIntents[player] = nil
            player:SetAttribute("StashDirection", nil)
            player:SetAttribute("StashDirectionExpiresAt", nil)
        end
    end
end
function InventoryService.GetSnapshot(player: Player)
    local stash = {}
    local source = stashes[player]
    if source then
        for index, stack in source do
            if index > InventoryService.GetStashLayout(player).Slots then
                continue
            end
            stash[index] = table.clone(stack)
            stash[index].Ingredients = {}
            for _, item in stack.Ingredients do
                table.insert(stash[index].Ingredients, table.clone(item))
            end
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
local function reserveUnit(player: Player, id: string): boolean
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
function InventoryService.AddUnit(player: Player, id: string): boolean
    if not reserveUnit(player, id) then
        return false
    end
    if deps.DiscoveryService then
        deps.DiscoveryService.DiscoverIngredient(player, id)
    end
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
claimWorldItem = function(player: Player, object: Instance): boolean
    if not MovementService.CanPerformGameplayAction(player) then
        return false
    end
    local record = getLoosePickupRecord(player, object)
    if not record then
        return false
    end
    if not reserveUnit(player, record.Id) then
        return false
    end
    if not deps.IngredientService.Consume(object, true) then
        InventoryService.RemoveUnit(player, record.Id)
        return false
    end
    return true
end
function InventoryService.ClaimWorldItem(player: Player, object: Instance): boolean
    local record = getLoosePickupRecord(player, object)
    if not record or not claimWorldItem(player, object) then
        return false
    end
    if deps.DiscoveryService then
        deps.DiscoveryService.DiscoverIngredient(player, record.Id)
    end
    return true
end
-- Materialize ONE reserved unit. Caller cannot supply a spawn position or contents.
function InventoryService.ReleaseUnit(player: Player, id: string): Instance?
    if not MovementService.CanPerformGameplayAction(player) then
        return nil
    end
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
    if
        type(index) ~= "number"
        or index ~= index
        or index % 1 ~= 0
        or index < 1
        or index > InventoryService.GetStashLayout(owner).Slots
    then
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
    local expansion = StashSlots.Expansion(plot)
    if index > StashConfig.Slots and (not expansion or expansion:GetAttribute("StashExpansionReady") ~= true) then
        return nil
    end
    return StashSlots.Resolve(fixtures[1], expansion)[index]
end
local function accessible(player: Player, owner: Player, index: number): boolean
    if not MovementService.CanPerformGameplayAction(player) then
        return false
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
        and humanoid.Health > 0
        and WorldUtil.Near(player, getSlotPart(owner, index), Economy.InteractionDistance)
end
local function friendly(player: Player, owner: Player): boolean
    local plot = deps.TycoonService.GetPlot(owner)
    return plot ~= nil and deps.TycoonService.GetOwner(plot) == owner and deps.TycoonService.GetPlot(player) == plot
end
function InventoryService.CanWithdraw(player: Player, owner: Player, index: number): boolean
    local slot = stashes[owner] and stashes[owner][index]
    if not slot or not getSlotPart(owner, index) or not deps.TycoonService.GetPlot(player) then
        return false
    end
    if friendly(player, owner) then
        return true
    end
    return not slot.Protected and InventoryService.GetStashRaidState(owner).State ~= "Protected"
end
local function heldKey(record: HeldItem): string?
    return if record.Smoothie then record.Smoothie.BlendId else record.Id
end
local function slotKey(slot: Types.StashSlot): string?
    return if slot.Smoothie then slot.Smoothie.BlendId else slot.IngredientId
end
local function clearSlot(slot: Types.StashSlot)
    slot.ItemType, slot.IngredientId, slot.Smoothie = nil, nil, nil
    slot.Ingredients = {}
    slot.Count, slot.Capacity = 0, StashConfig.IngredientCapacity
end
local function depositSelected(player: Player, itemType: string, key: string, index: number, owner: Player): boolean
    local record = resolveActionItem(player)
    if
        not record
        or record.Releasing
        or record.Destroying
        or record.ItemType ~= itemType
        or heldKey(record) ~= key
        or not friendly(player, owner)
        or not accessible(player, owner, index)
    then
        return false
    end
    local slot = stashes[owner] and stashes[owner][index]
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
        if slot.Count >= StashConfig.IngredientCapacity or (slot.Count > 0 and slot.ItemType ~= "Ingredient") then
            return false
        end
        slot.Smoothie = nil
        table.insert(slot.Ingredients, { IngredientId = record.Id :: string })
        slot.IngredientId = record.Id
        slot.Count += 1
        slot.Capacity = StashConfig.IngredientCapacity
    end
    slot.ItemType = record.ItemType
    removeAt(player, table.find(held[player], record))
    stashChanged:Fire(owner)
    return true
end
-- Preserve the legacy ingredient-only signature; id is a match assertion.
function InventoryService.Deposit(player: Player, id: string, index: number): boolean
    local plot = deps.TycoonService.GetPlot(player)
    local owner = if plot then deps.TycoonService.GetOwner(plot) else nil
    return owner ~= nil and depositSelected(player, "Ingredient", id, index, owner)
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
    -- Synchronous reservation; restore the exact record list on failed equip.
    local previous = table.clone(slot)
    slot.Ingredients = table.clone(slot.Ingredients)
    if not smoothie then
        table.remove(slot.Ingredients)
    end
    slot.Count -= 1
    if slot.Count == 0 then
        clearSlot(slot)
    else
        slot.IngredientId = slot.Ingredients[#slot.Ingredients].IngredientId
    end
    if not equipVisual(player, id, visual, smoothie) then
        stashes[owner][index] = previous
        return false
    end
    if not friendly(player, owner) then
        local state = InventoryService.GetStashRaidState(owner)
        if state.SessionId and state.State == "Normal" then
            local raidEnd = workspace:GetServerTimeNow() + StashConfig.RaidWindowSeconds
            raids[state.SessionId] = {
                RaidEndsAt = raidEnd,
                ProtectionEndsAt = raidEnd + StashConfig.RaidProtectionSeconds,
            }
        end
    end
    stashChanged:Fire(owner)
    return true
end
function InventoryService.Steal(player: Player, owner: Player, index: number): boolean
    return not friendly(player, owner) and InventoryService.Withdraw(player, index, owner)
end
-- Prompt direction is server-owned and survives changes caused by each transfer.
-- Direction follows the player across slots/items; failed transfers preserve it
-- until the idle timeout after the last successful transfer.
function InventoryService.InteractStash(player: Player, index: number, owner: Player?, fixture: Instance?): boolean
    if not MovementService.CanPerformGameplayAction(player) then
        return false
    end
    local now = workspace:GetServerTimeNow()
    local part = if owner then getSlotPart(owner, index) else nil
    local intent: StashIntent? = stashIntents[player]
    local sessionId = deps.TycoonService.GetSessionId(player)
    if intent and (now - intent.LastInteraction >= STASH_BURST_TIMEOUT or intent.SessionId ~= sessionId) then
        intent = nil
        stashIntents[player] = nil
    end
    if not owner or not part or not sessionId or (fixture and part ~= fixture and not part:IsDescendantOf(fixture)) then
        return false
    end
    local slot = stashes[owner] and stashes[owner][index]
    if not slot then
        return false
    end
    if not friendly(player, owner) then
        return InventoryService.Steal(player, owner, index)
    end
    if not intent then
        local selected = resolveActionItem(player)
        local key = if selected then heldKey(selected) else slotKey(slot)
        local itemType: ("Ingredient" | "Smoothie")? = if selected then selected.ItemType else slot.ItemType
        if not key or not itemType then
            return false
        end
        intent = {
            Direction = if selected then "STORE" else "TAKE",
            LastInteraction = now,
            SessionId = sessionId,
        }
    end
    assert(intent)
    local success = false
    if intent.Direction == "STORE" then
        local selected = resolveActionItem(player)
        local key = if selected then heldKey(selected) else nil
        if selected and key then
            success = depositSelected(player, selected.ItemType, key, index, owner)
        end
    else
        success = InventoryService.Withdraw(player, index, owner)
    end
    if success then
        intent.LastInteraction = now
        stashIntents[player] = intent
        player:SetAttribute("StashDirection", intent.Direction)
        player:SetAttribute("StashDirectionSessionId", sessionId)
        player:SetAttribute("StashDirectionExpiresAt", now + STASH_BURST_TIMEOUT)
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
