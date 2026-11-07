--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Marketplace = game:GetService("MarketplaceService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.FarmConfig)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local Eligibility = require(game:GetService("ReplicatedStorage").Shared.Constants.FarmEligibility)
local WorldUtil = require(script.Parent.WorldUtil)
local GameplaySfx = require(script.Parent.GameplaySfxService)
local FarmService = {}
local deps: any
local farms: { [Instance]: any } = {}
local ownership: { [Player]: any } = {}
local pending: { [Player]: any } = {}
local refreshBoost: (any) -> ()

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
        elseif
            item:IsA("ParticleEmitter")
            or item:IsA("Beam")
            or item:IsA("Trail")
            or item:IsA("Light")
            or item:IsA("Sparkles")
            or item:IsA("Fire")
            or item:IsA("Smoke")
        then
            table.insert(saved, { Effect = item, Enabled = item.Enabled })
        elseif item:IsA("ProximityPrompt") then
            table.insert(saved, { Prompt = item })
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
        elseif item.Effect then
            item.Effect.Enabled = visible and item.Enabled
            if not visible and item.Effect:IsA("ParticleEmitter") then
                item.Effect:Clear()
            end
        elseif item.Prompt then
            item.Prompt.Enabled = false -- Only the explicitly managed prompt may interact.
        else
            item.Gui.Enabled = visible and item.Enabled
        end
    end
end

local function setState(row: any, state: string)
    row.State = state
    if state ~= "GROWING" then
        row.Object:SetAttribute("FarmGrowEnd", nil)
    end
    row.Object:SetAttribute("FarmState", state)
    row.Prompt.Enabled = state == "EMPTY"
end

local function refreshPads(farm: any)
    for index, row in farm.Rows do
        local available = row.State == "LOCKED" and (index == 1 or farm.Rows[index - 1].State ~= "LOCKED")
        show(row.PadAppearance, available)
        row.Pad.CanTouch = available
    end
    refreshBoost(farm)
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
        local product = deps.IngredientService.Spawn(
            id,
            CFrame.new(0, Config.HarvestVerticalOffset, 0) * marker.WorldCFrame,
            nil,
            true,
            {
                Origin = "Farm",
                FreezeUntilPickup = true,
                FarmManaged = true,
                BeforePublish = function(object: Instance)
                    object:SetAttribute("SpawnSource", "Farm")
                    object:SetAttribute("FarmSpawnTime", workspace:GetServerTimeNow())
                    local connections: { RBXScriptConnection } = {}
                    row.Products[object] = connections
                    local target = Instance.new("ObjectValue")
                    target.Name = "TutorialHarvestTarget"
                    target.Value = object
                    target.Parent = row.Object
                    local function removed()
                        if row.Products[object] ~= connections then
                            return
                        end
                        row.Products[object] = nil
                        target:Destroy()
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
                                object:Destroy()
                            end
                        end)
                    )
                end,
            }
        )
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

local function scheduleGrowth(farm: any, row: any, duration: number)
    row.Generation += 1 -- Invalidate every previous completion, including rescheduled ones.
    row.Object:SetAttribute("FarmGrowEnd", workspace:GetServerTimeNow() + duration)
    local session, generation, id = farm.Session, row.Generation, row.IngredientId
    task.delay(duration, function()
        grow(farm, row, session, generation, id)
    end)
end

local function releasePrompt(player: Player)
    local request = pending[player]
    if request then
        if request.Farm.Pending == player then
            request.Farm.Pending = nil
        end
        pending[player] = nil
    end
end

local function refreshPlayerPlot(player: Player)
    local plot = deps.TycoonService.GetPlot(player)
    local farm = plot and farms[plot]
    if farm then
        refreshBoost(farm)
    end
end

local function checkOwnership(player: Player)
    if ownership[player] or player.Parent ~= Players then
        return
    end
    local state: any = { Checking = true }
    ownership[player] = state
    task.spawn(function()
        local ok, owns = pcall(function()
            return Marketplace:UserOwnsGamePassAsync(player.UserId, Config.SpeedPassId)
        end)
        if ownership[player] ~= state or player.Parent ~= Players then
            return
        end
        state.Checking = false
        -- A matching purchase event may have confirmed ownership while this call yielded.
        if state.Owned ~= true then
            state.Owned = if ok and typeof(owns) == "boolean" then owns else nil
        end
        refreshPlayerPlot(player) -- Resolve current membership, never a captured plot.
        if state.Owned == nil then
            task.delay(Config.OwnershipRetrySeconds, function()
                if ownership[player] == state and state.Owned == nil then
                    ownership[player] = nil
                    refreshPlayerPlot(player)
                end
            end)
        end
    end)
end

refreshBoost = function(farm: any)
    local active = live(farm, farm.Session)
    if farm.Pending and (not active or not authorized(farm, farm.Pending)) then
        releasePrompt(farm.Pending)
    end
    local boosted, confirmed = false, active
    if active then
        for _, member in deps.TycoonService.GetMembers(farm.Session) do
            checkOwnership(member)
            local state = ownership[member]
            boosted = boosted or (state ~= nil and state.Owned == true)
            confirmed = confirmed and state ~= nil and state.Owned == false and not state.Checking
        end
    end
    local multiplier = if boosted then Config.SpeedMultiplier else 1
    local oldMultiplier = farm.Multiplier or 1
    farm.Multiplier = multiplier
    if multiplier ~= oldMultiplier then
        for _, row in farm.Rows do
            if row.State == "GROWING" then
                local remaining = math.max(0, row.Object:GetAttribute("FarmGrowEnd") - workspace:GetServerTimeNow())
                scheduleGrowth(farm, row, remaining * oldMultiplier / multiplier)
            end
        end
    end
    local owner = if active then deps.TycoonService.GetSessionOwner(farm.Session) else nil
    farm.BoostAvailable = confirmed
        and not boosted
        and owner ~= nil
        and deps.TycoonService.GetUpgrade(owner, "FarmRows") >= 2
    if farm.SpeedPad then
        show(farm.SpeedAppearance, farm.BoostAvailable)
        farm.SpeedPrompt.Enabled = farm.BoostAvailable and farm.Pending == nil
    end
end

local function purchaseBoost(farm: any, player: Player)
    refreshBoost(farm)
    if
        not authorized(farm, player)
        or not farm.BoostAvailable
        or farm.Pending
        or pending[player]
        or not farm.SpeedPad:IsDescendantOf(farm.Plot)
        or not WorldUtil.Near(player, farm.SpeedPad, Config.PlantDistance)
    then
        return
    end
    local request = { Farm = farm, Session = farm.Session }
    pending[player], farm.Pending = request, player
    refreshBoost(farm)
    local ok = pcall(function()
        Marketplace:PromptGamePassPurchase(player, Config.SpeedPassId)
    end)
    if not ok and pending[player] == request then
        releasePrompt(player)
        refreshBoost(farm)
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
    if not id or not definition or not Eligibility.CanPlant(definition) then
        return
    end
    local duration = Economy.RefillSeconds[definition.JumpLocation] * #row.Grow / farm.Multiplier
    local token = deps.TycoonService.BeginTransaction(player, deps.TycoonService.GetRequestContext(player))
    if not token then
        return
    end
    row.Busy = true
    if deps.InventoryService.ConsumeHeldIngredient(player, id) then
        row.IngredientId = id
        setState(row, "GROWING")
        GameplaySfx.Emit("IngredientPlant", row.Plant.WorldPosition)
        scheduleGrowth(farm, row, duration)
    end
    row.Busy = false
    deps.TycoonService.EndTransaction(token)
end

local function resetRow(row: any)
    row.Generation += 1
    local products = row.Products
    row.Products = {}
    for product, connections in products do
        for _, connection in connections do
            connection:Disconnect()
        end
        product:Destroy()
    end
    for _, reference in row.Object:GetChildren() do
        if reference.Name == "TutorialHarvestTarget" and reference:IsA("ObjectValue") then
            reference:Destroy()
        end
    end
    stopReveal(row)
    row.IngredientId, row.Busy, row.Spawning = nil, false, false
    setState(row, "LOCKED")
    show(row.VisualAppearance, false)
end

local function reset(farm: any)
    if farm.Pending then
        releasePrompt(farm.Pending)
    end
    farm.Session = nil -- invalidate before destruction signals or tween cancellation
    for _, row in farm.Rows do
        resetRow(row)
    end
    refreshPads(farm)
end

local function activate(farm: any, player: Player)
    local session = deps.TycoonService.GetSessionId(player)
    if farm.Session == session then
        refreshBoost(farm)
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
    -- The optional monetization assembly cannot invalidate otherwise valid rows.
    local speedPad = folder:FindFirstChild("FarmSpeedRobux")
    if speedPad then
        farm.SpeedAppearance = appearance(speedPad)
        show(farm.SpeedAppearance, false)
        if speedPad:IsA("BasePart") then
            farm.SpeedPad = speedPad
            speedPad.Anchored = true
            local sign = speedPad:FindFirstChild("Sign")
            if sign then
                for _, label in sign:GetDescendants() do
                    if label:IsA("TextLabel") then
                        label.Text = "2× FASTER FARM"
                    end
                end
            end
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name, prompt.ActionText, prompt.ObjectText = "FarmSpeedPrompt", "Buy Farm Boost", "2× FASTER FARM"
            prompt.MaxActivationDistance, prompt.RequiresLineOfSight = Config.PlantDistance, false
            prompt.Enabled = false
            prompt.Parent = speedPad
            farm.SpeedPrompt = prompt
            table.insert(
                farm.Connections,
                prompt.Triggered:Connect(function(player)
                    purchaseBoost(farm, player)
                end)
            )
        else
            warn("[FarmService] FarmSpeedRobux must be a BasePart in " .. plot:GetFullName())
        end
    end
    for index, row in farm.Rows do
        table.insert(
            farm.Connections,
            row.Object.AncestryChanged:Connect(function()
                if not row.Object:IsDescendantOf(plot) then
                    resetRow(row)
                    refreshPads(farm)
                end
            end)
        )
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
        prompt.Style = Enum.ProximityPromptStyle.Custom
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
        if farm.SpeedPrompt then
            farm.SpeedPrompt:Destroy()
        end
    end
end

-- Read-only tutorial boundary: authoritative state for the active plot session.
function FarmService.GetRowSnapshot(
    plot: Instance,
    index: number
): { State: string, IngredientId: string?, Products: { Instance } }?
    local farm = farms[plot]
    local row = if farm and live(farm, farm.Session) then farm.Rows[index] else nil
    if not row then
        return nil
    end
    local products: { Instance } = {}
    for object in row.Products do
        table.insert(products, object)
    end
    return { State = row.State, IngredientId = row.IngredientId, Products = products }
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
    Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
        local request = pending[player]
        if
            id ~= Config.SpeedPassId
            or not request
            or player.Parent ~= Players
            or request.Farm.Pending ~= player
            or not live(request.Farm, request.Session)
        then
            return
        end
        releasePrompt(player)
        if purchased == true then
            local state = ownership[player] or {}
            ownership[player] = state
            state.Owned, state.Checking = true, false
        end
        refreshBoost(request.Farm)
        refreshPlayerPlot(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        releasePrompt(player)
        ownership[player] = nil
    end)
    WorldUtil.BindTag("PlayerPlot", bind)
end

function FarmService.RefreshMembership()
    for _, farm in farms do
        refreshBoost(farm)
    end
end

return FarmService
