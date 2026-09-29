--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.FarmConfig)
local WorldUtil = require(script.Parent.WorldUtil)
local FarmService = {}
local deps: any
local farms: { [Instance]: any } = {}

local function live(farm: any, session: string?): boolean
    return session ~= nil
        and farms[farm.Plot] == farm
        and farm.Session == session
        and deps.TycoonService.GetSessionOwner(session) ~= nil
end

local function appearance(object: Instance): { any }
    local saved: { any } = {}
    local objects = object:GetDescendants()
    table.insert(objects, object)
    for _, item in objects do
        if item:IsA("BasePart") then
            table.insert(saved, {
                Part = item,
                Frame = item.CFrame,
                Transparency = item.Transparency,
                Collide = item.CanCollide,
                Touch = item.CanTouch,
                Query = item.CanQuery,
            })
        elseif item:IsA("Decal") or item:IsA("Texture") then
            table.insert(saved, { Decoration = item, Transparency = item.Transparency })
        elseif item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
            table.insert(saved, { Gui = item, Enabled = item.Enabled })
        end
    end
    return saved
end

local function show(saved: { any }, visible: boolean)
    for _, item in saved do
        if item.Part then
            item.Part.Transparency = if visible then item.Transparency else 1
            item.Part.CanCollide = visible and item.Collide
            item.Part.CanTouch = visible and item.Touch
            item.Part.CanQuery = visible and item.Query
        elseif item.Decoration then
            item.Decoration.Transparency = if visible then item.Transparency else 1
        else
            item.Gui.Enabled = visible and item.Enabled
        end
    end
end

local function setState(row: any, state: string)
    row.State = state
    row.Object:SetAttribute("FarmState", state)
    row.Prompt.Enabled = state == "EMPTY"
end

local function refreshPads(farm: any)
    for index, row in farm.Rows do
        local available = row.State == "LOCKED" and (index == 1 or farm.Rows[index - 1].State ~= "LOCKED")
        show(row.PadAppearance, available)
        row.Pad.CanTouch = available
    end
end

local function stopReveal(row: any)
    for _, motion in row.Motions do
        motion.Connection:Disconnect()
        motion.Tween:Cancel()
    end
    table.clear(row.Motions)
    for _, item in row.VisualAppearance do
        if item.Part then
            item.Part.CFrame = item.Frame
        end
    end
end

local function reveal(row: any)
    show(row.VisualAppearance, true)
    for _, item in row.VisualAppearance do
        if item.Part then
            item.Part.CFrame = CFrame.new(0, -Config.RevealDepth, 0) * item.Frame
            local tween = TweenService:Create(
                item.Part,
                TweenInfo.new(Config.RevealSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { CFrame = item.Frame }
            )
            local connection = tween.Completed:Connect(function()
                item.Part.CFrame = item.Frame
            end)
            table.insert(row.Motions, { Tween = tween, Connection = connection })
            tween:Play()
        end
    end
end

local function authorized(farm: any, player: Player): boolean
    return live(farm, farm.Session) and deps.TycoonService.IsMember(player, farm.Plot)
end

local function purchase(farm: any, row: any, index: number, player: Player)
    if
        not authorized(farm, player)
        or row.State ~= "LOCKED"
        or row.Busy
        or (index > 1 and farm.Rows[index - 1].State == "LOCKED")
        or not WorldUtil.Near(player, row.Pad, Config.PlantDistance)
    then
        return
    end
    row.Busy = true
    deps.TycoonService.PurchaseFarmRow(player, index, deps.TycoonService.GetRequestContext(player), function()
        setState(row, "EMPTY")
        refreshPads(farm)
        reveal(row)
    end)
    row.Busy = false
end

local function emptyWhenHarvestGone(farm: any, row: any, session: string, generation: number)
    if
        live(farm, session)
        and row.Generation == generation
        and row.State == "READY"
        and not row.Spawning
        and next(row.Products) == nil
    then
        row.IngredientId = nil
        setState(row, "EMPTY")
    end
end

local function grow(farm: any, row: any, session: string, generation: number, id: string)
    if not live(farm, session) or row.Generation ~= generation or row.State ~= "GROWING" then
        return
    end
    row.Spawning = true
    setState(row, "READY")
    for _, marker in row.Grow do
        if not live(farm, session) or row.Generation ~= generation then
            break
        end
        local product = deps.IngredientService.Spawn(id, marker.WorldCFrame, nil, true, {
            FreezeUntilPickup = true,
            BeforePublish = function(object: Instance)
                local connections: { RBXScriptConnection } = {}
                row.Products[object] = connections
                local function removed()
                    if row.Products[object] ~= connections then
                        return
                    end
                    row.Products[object] = nil
                    for _, connection in connections do
                        connection:Disconnect()
                    end
                    emptyWhenHarvestGone(farm, row, session, generation)
                end
                table.insert(connections, object.Destroying:Connect(removed))
                table.insert(
                    connections,
                    object.AncestryChanged:Connect(function()
                        if not object:IsDescendantOf(workspace) then
                            removed()
                        end
                    end)
                )
            end,
        })
        if not product then
            warn("[FarmService] Failed to spawn " .. id)
        elseif not live(farm, session) or row.Generation ~= generation then
            product:Destroy()
        end
    end
    if live(farm, session) and row.Generation == generation then
        row.Spawning = false
        emptyWhenHarvestGone(farm, row, session, generation)
    end
end

local function plant(farm: any, row: any, player: Player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if
        not authorized(farm, player)
        or row.State ~= "EMPTY"
        or row.Busy
        or not root
        or not root:IsA("BasePart")
        or (root.Position - row.Plant.WorldPosition).Magnitude > Config.PlantDistance
        or not deps.MovementService.CanPerformGameplayAction(player)
    then
        return
    end
    local id = deps.InventoryService.GetHeldIngredientId(player)
    local definition = if id then deps.IngredientService.GetDefinition(id) else nil
    if not id or not definition or definition.Farmable == false then
        return
    end
    local duration = (Config.GrowSeconds :: any)[definition.Rarity]
    if not duration then
        warn("[FarmService] Unknown rarity for " .. id .. "; using Common")
        duration = Config.GrowSeconds.Common
    end
    local token = deps.TycoonService.BeginTransaction(player, deps.TycoonService.GetRequestContext(player))
    if not token then
        return
    end
    row.Busy = true
    if deps.InventoryService.ConsumeHeldIngredient(player, id) then
        row.Generation += 1
        row.IngredientId = id
        setState(row, "GROWING")
        local generation = row.Generation
        task.delay(duration, function()
            grow(farm, row, token, generation, id)
        end)
    end
    row.Busy = false
    deps.TycoonService.EndTransaction(token)
end

local function reset(farm: any)
    farm.Session = nil -- invalidate before destruction signals or tween cancellation
    for _, row in farm.Rows do
        row.Generation += 1
        local products = row.Products
        row.Products = {}
        for product, connections in products do
            for _, connection in connections do
                connection:Disconnect()
            end
            product:Destroy()
        end
        stopReveal(row)
        row.IngredientId, row.Busy, row.Spawning = nil, false, false
        setState(row, "LOCKED")
        show(row.VisualAppearance, false)
    end
    refreshPads(farm)
end

local function activate(farm: any, player: Player)
    local session = deps.TycoonService.GetSessionId(player)
    if farm.Session == session then
        return
    end
    reset(farm)
    farm.Session = session
    local unlocked = deps.TycoonService.GetUpgrade(player, "FarmRows") - 1
    for index, row in farm.Rows do
        if index <= unlocked then
            setState(row, "EMPTY")
            show(row.VisualAppearance, true)
        end
    end
    refreshPads(farm)
end

local function bind(plot: Instance): (() -> ())?
    if farms[plot] then
        return nil
    end
    local folder = plot:FindFirstChild("Farm")
    if not folder then
        return nil
    end
    local farm: any = { Plot = plot, Rows = {}, Connections = {} }
    -- Validate the complete authored hierarchy before hiding or binding anything.
    for index = 1, #Config.RowPrices do
        local object = folder:FindFirstChild("Row" .. index)
        local pad = object and object:FindFirstChild("PurchasePoint" .. index)
        local visual = object and object:FindFirstChild("Visual")
        local markers = object and object:FindFirstChild("FarmMarkers")
        local plantPoint = markers and markers:FindFirstChild("PlantPoint")
        local growPoints = {}
        for n = 1, 3 do
            local point = markers and markers:FindFirstChild("Grow" .. n)
            if point and point:IsA("Attachment") then
                table.insert(growPoints, point)
            end
        end
        if
            not object
            or not pad
            or not pad:IsA("BasePart")
            or not visual
            or not markers
            or not markers:IsA("BasePart")
            or not plantPoint
            or not plantPoint:IsA("Attachment")
            or #growPoints ~= 3
        then
            warn("[FarmService] Invalid Row" .. index .. " hierarchy in " .. plot:GetFullName())
            return nil
        end
        table.insert(farm.Rows, {
            Object = object,
            Pad = pad,
            Markers = markers,
            Plant = plantPoint,
            Grow = growPoints,
            VisualAppearance = appearance(visual),
            PadAppearance = appearance(pad),
            Generation = 0,
            Products = {},
            Motions = {},
        })
    end
    farms[plot] = farm
    for index, row in farm.Rows do
        row.Markers.Anchored, row.Markers.Transparency = true, 1
        row.Markers.CanCollide, row.Markers.CanTouch, row.Markers.CanQuery = false, false, false
        row.Pad.Anchored = true
        for _, item in row.VisualAppearance do
            if item.Part then
                item.Part.Anchored = true
            end
        end
        local old = row.Plant:FindFirstChild("FarmPlantPrompt")
        if old then
            old:Destroy()
        end
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name, prompt.ActionText, prompt.ObjectText = "FarmPlantPrompt", "Plant ingredient", "Farm row " .. index
        prompt.MaxActivationDistance, prompt.RequiresLineOfSight = Config.PlantDistance, false
        prompt.Parent = row.Plant
        row.Prompt = prompt
        table.insert(
            farm.Connections,
            prompt.Triggered:Connect(function(player)
                plant(farm, row, player)
            end)
        )
        table.insert(
            farm.Connections,
            row.Pad.Touched:Connect(function(hit: BasePart)
                local ancestor: Instance? = hit.Parent
                while ancestor and ancestor ~= workspace do
                    local player = if ancestor:IsA("Model") then Players:GetPlayerFromCharacter(ancestor) else nil
                    if player then
                        purchase(farm, row, index, player)
                        return
                    end
                    ancestor = ancestor.Parent
                end
            end)
        )
    end
    reset(farm)
    local owner = deps.TycoonService.GetOwner(plot)
    if owner then
        activate(farm, owner)
    end
    return function()
        reset(farm)
        farms[plot] = nil
        for _, connection in farm.Connections do
            connection:Disconnect()
        end
        for _, row in farm.Rows do
            row.Prompt:Destroy()
        end
    end
end

function FarmService.StartSession(player: Player)
    local plot = deps.TycoonService.GetPlot(player)
    local farm = plot and farms[plot]
    if farm then
        activate(farm, player)
    end
end

function FarmService.CleanupSession(id: string)
    for _, farm in farms do
        if farm.Session == id then
            reset(farm)
        end
    end
end

function FarmService.Init(services: any)
    deps = services
    WorldUtil.BindTag("PlayerPlot", bind)
end

return FarmService
