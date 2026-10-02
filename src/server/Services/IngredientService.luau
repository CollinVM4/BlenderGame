--!strict
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Constants.Ingredients)
local Economy = require(Shared.Constants.Economy)
local WorldUtil = require(script.Parent.WorldUtil)
local Geometry = require(script.Parent.IngredientGeometry)
local Item = require(Shared.IngredientItem)
local Types = require(Shared.Types)
local IngredientService = {}
-- Tags/attributes are presentation metadata, never proof of ownership or validity.
local records: { [Instance]: { Id: string, Owner: Player?, Claimable: boolean, Item: Types.IngredientItem } } = {}

function IngredientService.GetDefinition(id: string)
    return (Definitions :: any)[id]
end
function IngredientService.CreateVisual(id: string, item: Types.IngredientItem?): Instance?
    return Geometry.CreateVisual(id, IngredientService.GetDefinition(id), item and item.VisualKey)
end
function IngredientService.Spawn(
    id: string,
    at: CFrame,
    owner: Player?,
    claimable: boolean?,
    options: {
        Item: Types.IngredientItem?,
        VisualTemplate: Instance?,
        FreezeUntilPickup: boolean?,
        BeforePublish: ((Instance) -> ())?,
    }?
): Instance?
    local item: Types.IngredientItem = if options and options.Item
        then table.clone(options.Item)
        else Item.New(id, HttpService:GenerateGUID(false))
    if id == "PlayerHead" and options and options.VisualTemplate then
        item.VisualKey = Geometry.CapturePlayerHead(options.VisualTemplate)
    end
    local object = IngredientService.CreateVisual(id, item)
    if not object then
        return nil
    end
    object.Name = id
    object:SetAttribute("IngredientId", id)
    object:SetAttribute("WorldItemId", item.ItemId)
    Item.ApplySourceMetadata(object, item)
    object:SetAttribute("EffectiveIngredientValue", Item.GetIngredientValue(item, workspace:GetServerTimeNow()))
    object:SetAttribute("IsRipe", item.IsRipe)
    object:SetAttribute("RipenessStoredSeconds", item.RipenessStoredSeconds)
    object:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
    local frozen = options ~= nil and options.FreezeUntilPickup == true
    object:SetAttribute("FrozenUntilPickup", if frozen then true else nil)
    -- Preparation has succeeded, but no world physics or pickup listeners can see it yet.
    if options and options.BeforePublish then
        options.BeforePublish(object)
    end
    local physical = object :: any
    physical:PivotTo(at)
    local root = WorldUtil.Part(object)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            part.Anchored = frozen
            part.CanQuery = true
        end
    end
    object.Parent = workspace
    if root and root:CanSetNetworkOwnership() then
        root:SetNetworkOwner(nil)
    end
    records[object] = { Id = id, Owner = owner, Claimable = claimable ~= false, Item = item }
    object.Destroying:Connect(function()
        records[object] = nil
    end)
    CollectionService:AddTag(object, "IngredientWorldItem")
    return object
end
function IngredientService.Resolve(hit: Instance): Instance?
    local current: Instance? = hit
    while current and current ~= workspace do
        if records[current] then
            return current
        end
        current = current.Parent
    end
    return nil
end
function IngredientService.GetRecord(
    object: Instance
): { Id: string, Owner: Player?, Claimable: boolean, Item: Types.IngredientItem }?
    local record = records[object]
    if not record or not object:IsDescendantOf(workspace) then
        return nil
    end
    local copy = table.clone(record)
    copy.Item = table.clone(record.Item)
    return copy
end
-- Pickup callers set pickedUp only after inventory authorization/reservation succeeds.
-- Other removal paths (including cleanup) never release frozen physics.
function IngredientService.Consume(object: Instance, pickedUp: boolean?): string?
    local record = IngredientService.GetRecord(object)
    if not record then
        return nil
    end
    records[object] = nil
    if pickedUp and object:GetAttribute("FrozenUntilPickup") == true then
        local parts = object:GetDescendants()
        table.insert(parts, object)
        for _, part in parts do
            if part:IsA("BasePart") then
                part.Anchored = false
            end
        end
        object:SetAttribute("FrozenUntilPickup", nil)
    end
    object:Destroy()
    return record.Id
end
-- Snapshot the registry: removal callbacks may replenish spawn systems.
-- Carry, stash and accepted blender contents have already left this registry.
function IngredientService.ClearLooseIngredients()
    local remove = {}
    for object in records do
        table.insert(remove, object)
    end
    for _, object in remove do
        IngredientService.Consume(object)
    end
end

local started = false
function IngredientService.Init(services: any)
    if started then
        return
    end
    started = true
    local interval = Economy.WorldIngredientCleanupInterval
    local warningSeconds = Economy.WorldIngredientCleanupWarningSeconds
    local nextCleanup = os.clock() + interval
    local function scheduleCycle()
        task.delay(math.max(0, nextCleanup - warningSeconds - os.clock()), function()
            services.AnnouncementService.Publish({
                Type = "ServerAnnouncement",
                Text = "LOOSE INGREDIENTS CLEAR IN 1 MINUTE!",
                Duration = 5,
                Priority = 100,
                Immediate = true,
            })
            task.delay(math.max(0, nextCleanup - os.clock()), function()
                IngredientService.ClearLooseIngredients()
                -- Keep the original cadence without replaying missed cycles after a stall.
                repeat
                    nextCleanup += interval
                until nextCleanup - warningSeconds > os.clock()
                scheduleCycle()
            end)
        end)
    end
    scheduleCycle()
end

function IngredientService.RemovePlayer(player: Player)
    local remove = {}
    for object, record in records do
        if record.Owner == player then
            table.insert(remove, object)
        end
    end
    for _, object in remove do
        IngredientService.Consume(object)
    end
end
return require(script.Parent.StudioServices).Wrap("IngredientService", IngredientService)
