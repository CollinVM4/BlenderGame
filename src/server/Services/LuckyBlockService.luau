--!strict
-- Instant world rewards are not inventory items. Only this service owns these clones.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.LuckyBlockConfig)
local Presentation = require(Shared.Constants.LuckyBlockPresentation)
local WorldUtil = require(script.Parent.WorldUtil)
local Service = {}
type Record = { Marker: BasePart, Origin: CFrame, Connections: { RBXScriptConnection } }
local markers: { [BasePart]: boolean } = {}
local records: { [Model]: Record } = {}
local pending: { number } = {}
local lastClaim: { [Player]: number } = {}
local folder: Folder
local remote: RemoteEvent
local nearbyRemote: RemoteEvent
local pickupId = 0
local started = false
local assetWarning = false

local function retire(model: Model, alreadyDestroying: boolean?)
    local record = records[model]
    if not record then
        return
    end
    -- Commit before Destroy/events: another player or reentrant callback cannot claim.
    records[model] = nil
    for _, connection in record.Connections do
        connection:Disconnect()
    end
    table.insert(
        pending,
        os.clock() + Config.Respawn.MinSeconds + math.random() * (Config.Respawn.MaxSeconds - Config.Respawn.MinSeconds)
    )
    if not alreadyDestroying then
        model:Destroy()
    end
end

function Service.TryClaim(player: Player, model: Model): boolean
    local record = records[model]
    local now = os.clock()
    if not record or player.Parent ~= Players or not model:IsDescendantOf(folder) then
        return false
    end
    if lastClaim[player] and now - lastClaim[player] < Config.Pickup.PlayerCooldownSeconds then
        return false
    end
    if not WorldUtil.Near(player, model, Config.Pickup.Radius) then
        return false
    end
    lastClaim[player] = now
    -- Config is shared for presentation, but selection uses only the server's copy.
    local total = 0
    for _, reward in Config.Rewards do
        total += reward.Weight
    end
    local roll = math.random() * total
    local selected = Config.Rewards[#Config.Rewards]
    for _, reward in Config.Rewards do
        roll -= reward.Weight
        if roll < 0 then
            selected = reward
            break
        end
    end
    local position = record.Origin.Position
    local character = player.Character
    local pickedUpAt = workspace:GetServerTimeNow()
    pickupId += 1
    retire(model)
    remote:FireClient(player, {
        RewardId = selected.Id,
        DurationSeconds = selected.DurationSeconds, -- Metadata only; no buff clock starts in Pass 1.
        Position = position,
        Character = character,
        PickedUpAt = pickedUpAt,
        PickupId = pickupId,
    })
    -- Output only; observers receive one committed reward, never silhouette ticks.
    for _, observer in Players:GetPlayers() do
        local root = observer.Character and observer.Character:FindFirstChild("HumanoidRootPart")
        if
            observer ~= player
            and root
            and root:IsA("BasePart")
            and (root.Position - position).Magnitude <= Presentation.NearbyDistance
        then
            nearbyRemote:FireClient(observer, {
                Position = position,
                UserId = player.UserId,
                Character = character,
                RewardId = selected.Id,
                DurationSeconds = selected.DurationSeconds,
                PickedUpAt = pickedUpAt,
                PickupId = pickupId,
            })
        end
    end
    return true
end

local function spawnAt(marker: BasePart): boolean
    local templates = ServerStorage:FindFirstChild(Config.TemplateFolderName)
    local template = templates and templates:FindFirstChild(Config.ModelName)
    if not template or not template:IsA("Model") or not template.PrimaryPart or not template.Archivable then
        if not assetWarning then
            warn(
                "[LuckyBlock] Add an archivable Model with PrimaryPart at ServerStorage."
                    .. Config.TemplateFolderName
                    .. "."
                    .. Config.ModelName
            )
            assetWarning = true
        end
        return false
    end
    assetWarning = false
    local model = template:Clone()
    -- Authored templates are visual assets, never executable gameplay or inventory.
    local descendants = model:GetDescendants()
    table.insert(descendants, model)
    for _, child in descendants do
        for _, tag in CollectionService:GetTags(child) do
            CollectionService:RemoveTag(child, tag)
        end
        if child:IsA("BaseScript") or child:IsA("ModuleScript") or child:IsA("ProximityPrompt") then
            child:Destroy()
        elseif child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            child.CanTouch = false
            child.CanQuery = false
        end
    end
    local origin = marker.CFrame * CFrame.new(0, marker.Size.Y / 2 + Config.Spawn.HeightOffset, 0)
    model:PivotTo(origin)
    model:SetAttribute("LuckyBlockOrigin", origin)
    model:SetAttribute("LuckyBlockSpawnTime", workspace:GetServerTimeNow())
    records[model] = { Marker = marker, Origin = origin, Connections = {} }
    model.Parent = folder
    local connections = records[model].Connections
    table.insert(
        connections,
        model.Destroying:Connect(function()
            retire(model, true)
        end)
    )
    table.insert(
        connections,
        model.AncestryChanged:Connect(function()
            if not model:IsDescendantOf(folder) then
                retire(model)
            end
        end)
    )
    CollectionService:AddTag(model, Config.WorldTag)
    return true
end

local function tick()
    local available: { BasePart } = {}
    local occupied: { [BasePart]: boolean } = {}
    for model, record in records do
        occupied[record.Marker] = true
        for _, player in Players:GetPlayers() do
            if Service.TryClaim(player, model) then
                break
            end
        end
    end
    for marker in markers do
        if marker:IsDescendantOf(workspace) and not occupied[marker] then
            table.insert(available, marker)
        end
    end
    for index = #pending, 1, -1 do
        if pending[index] <= os.clock() and #available > 0 then
            local choice = math.random(1, #available)
            local marker = assert(table.remove(available, choice))
            if spawnAt(marker) then
                table.remove(pending, index)
            end
        end
    end
    task.delay(Config.Pickup.PollSeconds, tick)
end

function Service.RemovePlayer(player: Player)
    lastClaim[player] = nil
end

function Service.Init()
    if started then
        return
    end
    started = true
    local existing = workspace:FindFirstChild(Config.WorldFolderName)
    assert(not existing or existing:IsA("Folder"), "LuckyBlocks must be a Folder")
    folder = if existing then existing :: Folder else Instance.new("Folder")
    folder.Name = Config.WorldFolderName
    folder.Parent = workspace
    local event = Shared.Events:FindFirstChild(Config.RewardEventName)
    assert(not event or event:IsA("RemoteEvent"), "LuckyBlockPickedUp must be a RemoteEvent")
    remote = if event then event :: RemoteEvent else Instance.new("RemoteEvent")
    remote.Name = Config.RewardEventName
    remote.Parent = Shared.Events
    local nearby = Shared.Events:FindFirstChild(Presentation.NearbyEventName)
    assert(not nearby or nearby:IsA("RemoteEvent"), "LuckyBlockRevealed must be a RemoteEvent")
    nearbyRemote = if nearby then nearby :: RemoteEvent else Instance.new("RemoteEvent")
    nearbyRemote.Name = Presentation.NearbyEventName
    nearbyRemote.Parent = Shared.Events
    -- Output only: there is deliberately no OnServerEvent pickup endpoint.
    WorldUtil.BindTag(Config.MarkerTag, function(object: Instance): (() -> ())?
        if not object:IsA("BasePart") then
            warn("[LuckyBlock] Tag a BasePart spawn marker")
            return nil
        end
        markers[object] = true
        return function()
            markers[object] = nil
            for model, record in records do
                if record.Marker == object then
                    retire(model)
                end
            end
        end
    end)
    for _ = 1, Config.Spawn.ActiveLimit do
        table.insert(pending, 0)
    end
    Players.PlayerRemoving:Connect(Service.RemovePlayer)
    tick()
end

return Service
