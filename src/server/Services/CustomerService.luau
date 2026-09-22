--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Customers = require(Shared.Constants.Customers)
local CustomerRequests = require(Shared.Constants.CustomerRequests)
local Ingredients = require(Shared.Constants.Ingredients)
local RunService = game:GetService("RunService")
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local Placement = require(script.Parent.CustomerPlacement)
local Walk = require(script.Parent.CustomerWalk)
local Presentation = require(script.Parent.CustomerPresentation)
local AudioService = require(script.Parent.AudioService)
local Film = require(script.Parent.FilmingUtil)
local CustomerService = {}
local deps: any
local onServed: (Player, Types.Grade) -> ()
local queues: { [Player]: any } = {}
local queueMarkers = { "CustomerCounter", "CustomerWait1", "CustomerWait2" }
local function front(player: Player): any
    local queue = queues[player]
    return if queue then queue.Customers[1] else nil
end
local function current(player: Player, queue: any): boolean
    return queues[player] == queue
        and deps.TycoonService.GetPlot(player) == queue.Plot
        and deps.TycoonService.GetOwner(queue.Plot) == player
end
local ownedModels: { [Player]: { [Model]: boolean } } = {}
local lastSpecialSpawn: { [Player]: number } = {}
local lastTemplates: { [Player]: Model } = {}
-- Runtime-only regular selections survive flow restarts.
local recentTemplates: { [Player]: { Model } } = {}
local recentRequests: { [Player]: { string } } = {}

local function remember<T>(histories: { [Player]: { T } }, player: Player, value: T, window: number)
    local history = histories[player] or {}
    table.insert(history, value)
    while #history > math.max(0, window) do
        table.remove(history, 1)
    end
    histories[player] = history
end
local warnedTemplates = setmetatable({} :: { [Instance]: boolean }, { __mode = "k" })
local activeTypingTasks = setmetatable({}, { __mode = "k" })
local CustomerNameHeight = 28
local CUSTOMER_ORDER_MAX_DISTANCE = 30
local CUSTOMER_ORDER_WIDTH = 270
local CUSTOMER_ORDER_TEXT_HEIGHT = 56
local CUSTOMER_ORDER_TEXT_SIZE = 21
local CUSTOMER_ORDER_HEIGHT_OFFSET = 3

local function diagnostic(message: string)
    if RunService:IsStudio() then
        print("[CustomerService] " .. message)
    end
end

-- Pure request decision, separate from legacy grading and cosmetic reactions.
-- Read definitions from actual ingredient IDs, never cup attributes or supplied result.Tags.
-- Only tag comparisons ignore case; ingredient IDs and CustomerIds keep their existing semantics.
function CustomerService.ValidateRequestDefinition(request: CustomerRequests.Request): { string }
    local diagnostics: { string } = {}
    local requiredIngredients: { string } = request.RequiredIngredients or {}
    for _, id in requiredIngredients do
        local definition = Ingredients[id]
        if not definition then
            table.insert(diagnostics, "Unknown required ingredient: " .. id)
        elseif definition.JumpLocation > request.MinJumpTier then
            table.insert(
                diagnostics,
                string.format(
                    "Required ingredient %s needs JumpLocation %d, above MinJumpTier %d",
                    id,
                    definition.JumpLocation,
                    request.MinJumpTier
                )
            )
        end
    end
    local forbiddenIngredients: { string } = request.ForbiddenIngredients or {}
    for _, id in forbiddenIngredients do
        if not Ingredients[id] then
            table.insert(diagnostics, "Unknown forbidden ingredient: " .. id)
        end
    end
    if request.ExactIngredients and #requiredIngredients == 0 then
        table.insert(diagnostics, "ExactIngredients requires at least one RequiredIngredient")
    end
    return diagnostics
end

function CustomerService.ValidateRequest(result: Types.Smoothie, request: CustomerRequests.Request): (boolean, string)
    local requiredIngredients: { string } = request.RequiredIngredients or {}
    if #result.Ingredients == 0 then
        return false, "Empty smoothie"
    end
    if #request.RequiredTags == 0 and #requiredIngredients == 0 then
        return false, "Empty request"
    end
    if request.ExactIngredients and #requiredIngredients == 0 then
        return false, "ExactIngredients requires at least one RequiredIngredient"
    end
    local tags: { [string]: boolean } = {}
    local ingredientCounts: { [string]: number } = {}
    for _, id in result.Ingredients do
        local definition = Ingredients[id]
        if not definition then
            return false, "Unknown ingredient: " .. id
        end
        ingredientCounts[id] = (ingredientCounts[id] or 0) + 1
        for _, tag in definition.Tags do
            tags[string.lower(tag)] = true
        end
    end
    for _, tag in request.RequiredTags do
        local normalizedTag = string.lower(tag)
        local matches = tags[normalizedTag] == true
        local group = CustomerRequests.TagGroups[normalizedTag]
        if group then
            for member in group do
                if tags[member] then
                    matches = true
                    break
                end
            end
        end
        if not matches then
            return false, "Missing required tag: " .. tag
        end
    end
    local forbiddenTags: { string } = request.ForbiddenTags or {}
    for _, tag in forbiddenTags do
        if tags[string.lower(tag)] then
            return false, "Contains forbidden tag: " .. tag
        end
    end
    local requiredCounts: { [string]: number } = {}
    for _, id in requiredIngredients do
        requiredCounts[id] = (requiredCounts[id] or 0) + 1
    end
    for id, count in requiredCounts do
        if (ingredientCounts[id] or 0) < count then
            return false, "Missing required ingredient: " .. id
        end
    end
    local forbiddenIngredients: { string } = request.ForbiddenIngredients or {}
    for _, id in forbiddenIngredients do
        if ingredientCounts[id] then
            return false, "Contains forbidden ingredient: " .. id
        end
    end
    if request.ExactIngredients then
        for id, count in ingredientCounts do
            if requiredCounts[id] ~= count then
                return false, "Exact ingredient mismatch"
            end
        end
    end
    return true, "Request requirements matched"
end

local function eligibleRequests(player: Player): { CustomerRequests.Request }
    -- Server-owned effective tier, published by PlayerDataService/MovementService (0-3).
    local playerJumpTier = player:GetAttribute("JumpLevel") or 0
    local eligible: { CustomerRequests.Request } = {}
    for _, request in CustomerRequests.Definitions do
        if not request.NPCOnly and playerJumpTier >= request.MinJumpTier then
            table.insert(eligible, request)
        end
    end
    if #eligible == 0 then
        warn(
            string.format(
                "[CustomerService] No eligible requests for %s at jump tier %s",
                player.Name,
                tostring(playerJumpTier)
            )
        )
    end
    return eligible
end

local function assignRequest(player: Player, record: any): boolean
    local selectedRequest = record.FixedRequest
    local forced = selectedRequest ~= nil
    local recentFiltered, recentFallback = false, false
    if selectedRequest and (player:GetAttribute("JumpLevel") or 0) < selectedRequest.MinJumpTier then
        diagnostic("special became ineligible before assignment; removing customer owner=" .. player.Name)
        record.Model:Destroy()
        return false
    end
    if not selectedRequest then
        local eligible = eligibleRequests(player)
        if #eligible == 0 then
            record.Model:Destroy()
            return false
        end
        local pool = eligible
        if record.CustomerType == "Regular" then
            local fresh: { CustomerRequests.Request } = {}
            for _, request in eligible do
                if not table.find(recentRequests[player] or {}, request.Id) then
                    table.insert(fresh, request)
                end
            end
            recentFiltered = #fresh < #eligible
            recentFallback = #fresh == 0
            if #fresh > 0 then
                pool = fresh
            end
        end
        selectedRequest = pool[math.random(1, #pool)]
    end
    local request = selectedRequest :: CustomerRequests.Request
    record.Request = request
    record.RequestId = request.Id
    record.Preference = request.RequiredTags[1] or "Surprise Me"
    record.Model:SetAttribute("Preference", record.Preference)
    record.Model:SetAttribute("RequestId", request.Id)
    if not forced and record.CustomerType == "Regular" then
        remember(recentRequests, player, request.Id, CustomerRequests.RegularRequestRecencyWindow)
    end
    diagnostic(
        string.format(
            "selected type=%s template=%s customerId=%s displayName=%s request=%s jumpTier=%s forced=%s requestRecencyFiltered=%s requestRecencyFallback=%s",
            record.CustomerType,
            record.TemplateName,
            record.CustomerId or "<absent>",
            record.DisplayName or "<absent>",
            request.Id,
            tostring(player:GetAttribute("JumpLevel") or 0),
            tostring(forced),
            tostring(recentFiltered),
            tostring(recentFallback)
        )
    )
    return true
end

local function npcRoot(model: Model): BasePart?
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return WorldUtil.Part(model)
end

local function rejectTemplate(template: Instance, reason: string)
    if RunService:IsStudio() and not warnedTemplates[template] then
        warnedTemplates[template] = true
        warn("[CustomerService] Skipping " .. template:GetFullName() .. ": " .. reason)
    end
end

local function cleanClone(model: Model)
    -- This flow owns customer world-space presentation, including on cloned templates.
    for _, object in model:GetDescendants() do
        if
            object:IsA("Script")
            or object:IsA("LocalScript")
            or object:IsA("ModuleScript")
            or object:IsA("Tool")
            or object:IsA("ProximityPrompt")
            or object:IsA("BillboardGui")
            or object:IsA("SurfaceGui")
        then
            object:Destroy()
        end
    end
end

type Candidate = {
    Template: Model,
    CustomerId: string?,
    DisplayName: string?,
    CustomerType: string,
    Request: CustomerRequests.Request?,
    Weight: number,
}

local function candidateFor(player: Player, template: Model): Candidate?
    local id = CustomerRequests.NormalizeCustomerId(template:GetAttribute("CustomerId"))
    local config = if id then CustomerRequests.NPCs[id] else nil
    -- Existing RequestId-only mappings remain special; an explicit Regular ignores overrides.
    local kind = if config and (config.Type == "Special" or (not config.Type and config.RequestId))
        then "Special"
        else "Regular"
    local request, reason = CustomerRequests.GetForNPC(id)
    if kind == "Special" then
        if reason then
            rejectTemplate(template, reason)
            return nil
        end
        if request and (player:GetAttribute("JumpLevel") or 0) < request.MinJumpTier then
            diagnostic(
                string.format(
                    "special ineligible customerId=%s request=%s requiredJumpTier=%d playerJumpTier=%s",
                    id or "<absent>",
                    request.Id,
                    request.MinJumpTier,
                    tostring(player:GetAttribute("JumpLevel") or 0)
                )
            )
            return nil
        end
    else
        request = nil
    end
    local weight = if config and config.Weight then config.Weight else 1
    if weight ~= weight or weight <= 0 or weight == math.huge then
        rejectTemplate(template, "Weight must be positive and finite")
        return nil
    end
    return {
        Template = template,
        CustomerId = id,
        DisplayName = Presentation.DisplayName(
            template,
            kind == "Special",
            if config then config.DisplayName else nil,
            id
        ),
        CustomerType = kind,
        Request = request,
        Weight = weight,
    }
end

local function cloneNPC(player: Player): (Model?, Candidate?)
    local folder = ServerStorage:FindFirstChild("CustomerNPCs")
    local regular: { Candidate } = {}
    local special: { Candidate } = {}
    if folder and folder:IsA("Folder") then
        for _, kind in { "Regular", "Special" } do
            local source = folder:FindFirstChild(kind)
            if source and source:IsA("Folder") then
                for _, template in source:GetChildren() do
                    if not template:IsA("Model") then
                        rejectTemplate(template, "expected a Model")
                    elseif not template:FindFirstChildOfClass("Humanoid") or not npcRoot(template) then
                        rejectTemplate(template, "requires Humanoid and a BasePart root")
                    elseif not template.Archivable then
                        rejectTemplate(template, "enable Archivable to allow cloning")
                    else
                        local candidate = candidateFor(player, template)
                        if candidate and candidate.CustomerType == kind then
                            table.insert(if kind == "Special" then special else regular, candidate)
                        elseif candidate then
                            rejectTemplate(template, "CustomerId mapping does not match source folder " .. kind)
                        end
                    end
                end
            elseif source then
                rejectTemplate(source, kind .. " must be a Folder")
            end
        end
    elseif folder then
        rejectTemplate(folder, "CustomerNPCs must be a Folder")
    end
    if #regular > 0 then
        for index = #special, 1, -1 do
            if special[index].Template == lastTemplates[player] then
                table.remove(special, index)
            end
        end
    end
    local useSpecial = #special > 0
        and (lastSpecialSpawn[player] == nil or os.clock() - lastSpecialSpawn[player] >= Economy.SpecialCustomerCooldownSeconds)
        and math.random() < CustomerRequests.SpecialCustomerChance
    local candidates = if useSpecial then special else regular
    -- Regulars use rolling recency; specials retain their existing immediate-repeat rule.
    -- Never increase special frequency to avoid a regular repeat.
    local function take(pool: { Candidate }): (Candidate, boolean, boolean)
        local alternatives: { number } = {}
        for index, candidate in pool do
            local recent = if candidate.CustomerType == "Regular"
                then table.find(recentTemplates[player] or {}, candidate.Template) ~= nil
                else candidate.Template == lastTemplates[player]
            if not recent then
                table.insert(alternatives, index)
            end
        end
        local filtered, fallback = #alternatives < #pool, #alternatives == 0
        if fallback then
            for index in pool do
                table.insert(alternatives, index)
            end
        end
        local total = 0
        for _, index in alternatives do
            total += pool[index].Weight
        end
        local roll = math.random() * total
        local chosen = alternatives[#alternatives]
        for _, index in alternatives do
            roll -= pool[index].Weight
            if roll < 0 then
                chosen = index
                break
            end
        end
        return table.remove(pool, chosen) :: Candidate, filtered, fallback
    end
    while #candidates > 0 do
        local candidate, filtered, fallback = take(candidates)
        local template = candidate.Template
        local ok, clone = pcall(function()
            return template:Clone()
        end)
        if ok and clone then
            cleanClone(clone)
        end
        if ok and clone and clone:FindFirstChildOfClass("Humanoid") and npcRoot(clone) then
            lastTemplates[player] = template
            if candidate.CustomerType == "Regular" then
                remember(recentTemplates, player, template, CustomerRequests.RegularCustomerRecencyWindow)
                diagnostic(
                    string.format(
                        "regular template=%s customerRecencyFiltered=%s customerRecencyFallback=%s owner=%s",
                        template:GetFullName(),
                        tostring(filtered),
                        tostring(fallback),
                        player.Name
                    )
                )
            end
            return clone, candidate
        end
        if ok and clone then
            clone:Destroy()
        end
        rejectTemplate(template, "clone failed or required descendants are not Archivable")
        if #candidates == 0 and useSpecial then
            candidates = regular
            useSpecial = false
        end
    end
    return nil, nil
end

-- Legacy compatibility: day boundaries no longer reset special eligibility.
function CustomerService.BeginDay(_player: Player) end

local function ensureCustomerCounterGlow(customerModel: Model): ParticleEmitter?
    local existingGlow = customerModel:FindFirstChild("CustomerCounterGlow")
    if existingGlow and existingGlow:IsA("ParticleEmitter") then
        return existingGlow
    end

    local rootPart = customerModel.PrimaryPart
        or customerModel:FindFirstChild("HumanoidRootPart")
        or customerModel:FindFirstChild("Head")
        or customerModel:FindFirstChild("Torso")

    if not rootPart then
        return nil
    end

    local counterGlow = Instance.new("ParticleEmitter")
    counterGlow.Name = "CustomerCounterGlow"
    counterGlow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    counterGlow.Rate = 0
    counterGlow.Speed = NumberRange.new(0.5, 1)
    counterGlow.Lifetime = NumberRange.new(0.4, 0.7)
    counterGlow.Color = ColorSequence.new(Color3.fromRGB(255, 224, 100))
    counterGlow.Parent = rootPart

    return counterGlow
end

local function typewriterText(textLabel: TextLabel, message: string, dialogueSound: Sound?)
    local currentToken = {}
    activeTypingTasks[textLabel] = currentToken
    local dialogueStep = 3

    if dialogueSound and dialogueSound.Parent then
        dialogueSound:Stop()
    end

    textLabel.Text = ""

    task.spawn(function()
        for index = 1, #message do
            if not textLabel.Parent or activeTypingTasks[textLabel] ~= currentToken then
                return
            end

            local character = string.sub(message, index, index)
            textLabel.Text = string.sub(message, 1, index)

            local shouldPlayDialogueSound = dialogueSound
                and dialogueSound.Parent
                and character ~= " "
                and (index % dialogueStep == 0 or index == #message)

            if shouldPlayDialogueSound and dialogueSound then
                dialogueSound.TimePosition = 0
                dialogueSound.PlaybackSpeed = math.random(90, 120) / 100

                local pitchShift: PitchShiftSoundEffect? = dialogueSound:FindFirstChildOfClass("PitchShiftSoundEffect")
                if not pitchShift then
                    local created = Instance.new("PitchShiftSoundEffect")
                    created.Parent = dialogueSound
                    pitchShift = created
                end

                (pitchShift :: PitchShiftSoundEffect).Octave = math.random(92, 108) / 100
                dialogueSound:Play()
            end

            task.wait(0.04)
        end

        if activeTypingTasks[textLabel] == currentToken then
            activeTypingTasks[textLabel] = nil
        end
    end)
end

function CustomerService.Init(services, servedCallback, _servingCallback)
    deps = services
    onServed = servedCallback
    if RunService:IsStudio() then
        for _, request in CustomerRequests.Definitions do
            for _, message in CustomerService.ValidateRequestDefinition(request) do
                warn("[CustomerService] Request " .. request.Id .. ": " .. message)
            end
        end
    end
end

-- Grade and reaction are deliberately independent, pure decision functions.
function CustomerService.CalculateGrade(result: Types.Smoothie, preference: string): Types.Grade
    if preference == "Surprise Me" then
        local unique = {}
        for _, id in result.Ingredients do
            unique[id] = true
        end
        local count = 0
        for _ in unique do
            count += 1
        end
        return if count >= 3 then "A" elseif count == 2 then "B" else "C"
    end
    local matching = 0
    for _, id in result.Ingredients do
        if table.find(deps.IngredientService.GetDefinition(id).Tags, preference) then
            matching += 1
        end
    end
    local ratio = matching / math.max(1, #result.Ingredients)
    return if ratio >= 2 / 3 then "A" elseif ratio >= 1 / 3 then "B" elseif matching > 0 then "C" else "D"
end
function CustomerService.SelectReaction(): string
    local total = 0
    for _, reaction in Customers.Reactions do
        total += reaction.Weight
    end
    local roll = math.random() * total
    for _, reaction in Customers.Reactions do
        roll -= reaction.Weight
        if roll <= 0 then
            return reaction.Id
        end
    end
    return Customers.Reactions[1].Id
end
function CustomerService.CalculatePayout(player: Player, grade: Types.Grade): number
    local upgrade = Upgrades.Payout[deps.PlayerDataService.GetUpgrade(player, "Payout")].Value
    local multiplier = if deps.PlayerDataService.HasEntitlement(player, "DoubleCash") then 2 else 1
    return math.floor(Economy.BasePayout * Economy.GradeMultiplier[grade] * upgrade * multiplier)
end
function CustomerService.CanSpawn(player: Player): (boolean, string?)
    local queue = queues[player]
    if not queue or not current(player, queue) then
        return false, "Plot flow inactive"
    end
    if #queue.Customers >= Economy.MaxCustomersPerPlot then
        return false, "Customer queue full"
    end
    if #eligibleRequests(player) == 0 then
        return false, "No eligible customer requests"
    end
    for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerExit" } do
        local marker, reason = deps.TycoonService.GetReference(player, name)
        if not marker then
            local message = "Cannot resolve "
                .. name
                .. " in "
                .. player.Name
                .. "'s plot: "
                .. (reason or "Missing marker")
            if RunService:IsStudio() then
                warn("[CustomerService] " .. message)
            end
            return false, message
        end
    end
    return true
end
-- Simple deterministic waypoint movement for the filming skeleton, not pathfinding.
local function move(record: any, destination: CFrame, finished: () -> ())
    record.MoveToken = (record.MoveToken or 0) + 1
    local token = record.MoveToken
    local current: CFrame = record.Model:GetPivot()
    local start = Placement.Face(current.Position, destination.Position, current)
    destination = Placement.Face(destination.Position, destination.Position + start.LookVector, start)
    record.Model:PivotTo(start)
    local distance = (start.Position - destination.Position).Magnitude
    local duration = math.max(0.1, distance / 8)
    record.Walk.SetMoving(distance > 0.0001)
    task.spawn(function()
        local elapsed = 0
        while record.Model.Parent and elapsed < duration do
            elapsed += task.wait()
            if not record.Model.Parent or record.MoveToken ~= token then
                return
            end
            local nextFrame = start:Lerp(destination, math.min(1, elapsed / duration))
            record.Model:PivotTo(nextFrame)
        end
        if record.MoveToken ~= token then
            return
        end
        record.Walk.SetMoving(false)
        if record.Model.Parent then
            finished()
        end
    end)
end
-- One ordered queue owns both destinations and eligibility. Route tokens invalidate old arrivals.
function CustomerService.RefreshQueue(player: Player)
    local queue = queues[player]
    if not queue then
        return
    end
    if not current(player, queue) then
        CustomerService.DeactivateForPlayer(player)
        return
    end
    for index, record in queue.Customers do
        local marker = deps.TycoonService.GetReference(player, queueMarkers[index])
        record.Model:SetAttribute("QueuePosition", index)
        if not marker then
            record.MoveToken = (record.MoveToken or 0) + 1
            record.TargetMarker = nil
            record.Ready = false
            record.Prompt.Enabled = false
            record.Walk.SetMoving(false)
        else
            local destination = Placement.AtMarker(marker, record.BottomOffset)
            if record.TargetMarker ~= marker or record.MarkerFrame ~= marker.CFrame or record.QueueIndex ~= index then
                record.TargetMarker = marker
                record.MarkerFrame = marker.CFrame
                record.QueueIndex = index
                record.Ready = false
                record.Prompt.Enabled = false
                move(record, destination, function()
                    if current(player, queue) and table.find(queue.Customers, record) then
                        record.Ready = queue.Customers[1] == record
                        record.Prompt.Enabled = record.Ready
                    end
                end)
            else
                record.Ready = index == 1 and record.Ready
                record.Prompt.Enabled = record.Ready
            end
        end
    end
end

function CustomerService.ActivateForPlayer(player: Player): boolean
    local plot = deps.TycoonService.GetPlot(player)
    if not plot or deps.TycoonService.GetOwner(plot) ~= player then
        CustomerService.DeactivateForPlayer(player)
        return false
    end
    local existing = queues[player]
    if existing and current(player, existing) then
        return true
    end
    CustomerService.DeactivateForPlayer(player)
    local queue: any = { Customers = {}, Plot = plot, Full = false }
    queues[player] = queue
    queue.PlotConnection = plot.AncestryChanged:Connect(function()
        if queues[player] == queue and not current(player, queue) then
            CustomerService.DeactivateForPlayer(player)
        end
    end)
    player:SetAttribute("CustomerFlowState", "PLOT_ACTIVE")
    diagnostic("flow started owner=" .. player.Name)
    local function tick()
        if queues[player] ~= queue then
            return
        end
        if not current(player, queue) then
            CustomerService.DeactivateForPlayer(player)
            return
        end
        CustomerService.RefreshQueue(player)
        local full = #queue.Customers >= Economy.MaxCustomersPerPlot
        if full and not queue.Full then
            diagnostic("queue full owner=" .. player.Name)
        end
        queue.Full = full
        local spawned = not full and CustomerService.SpawnForPlayer(player) ~= nil
        if not current(player, queue) then
            return
        end
        task.delay(
            if spawned
                then math.random(Economy.CustomerSpawnMinSeconds, Economy.CustomerSpawnMaxSeconds)
                else math.random(Economy.CustomerFullRetryMinSeconds, Economy.CustomerFullRetryMaxSeconds),
            tick
        )
    end
    task.delay(math.random(Economy.InitialCustomerDelayMin, Economy.InitialCustomerDelayMax), tick)
    return true
end

function CustomerService.SpawnForPlayer(player: Player): Model?
    if not CustomerService.CanSpawn(player) then
        return nil
    end
    local spawn = deps.TycoonService.GetReference(player, "CustomerSpawn")
    local counter = deps.TycoonService.GetReference(player, "CustomerCounter")
    local exit = deps.TycoonService.GetReference(player, "CustomerExit")
    if not spawn or not counter or not exit then
        return nil
    end
    diagnostic(
        string.format(
            "route owner=%s %s -> %s -> %s",
            player.Name,
            spawn:GetFullName(),
            counter:GetFullName(),
            exit:GetFullName()
        )
    )
    local customModel, candidate = cloneNPC(player)
    local templateName = if candidate then candidate.Template.Name else nil
    local template = ServerStorage:FindFirstChild("Customer")
    local selectedModel = customModel
    local legacyCandidate = if template and template:IsA("Model") then candidateFor(player, template) else nil
    if
        not selectedModel
        and template
        and template:IsA("Model")
        and template.Archivable
        and legacyCandidate
        and legacyCandidate.CustomerType == "Regular"
    then
        local ok, clone = pcall(function()
            return template:Clone()
        end)
        if ok and clone then
            cleanClone(clone)
            if npcRoot(clone) then
                selectedModel = clone
                templateName = template.Name
            else
                clone:Destroy()
                rejectTemplate(template, "clone has no usable root after cleanup")
            end
        end
    end
    if not selectedModel then
        local generic = Instance.new("Model")
        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2.5, 1)
        torso.Color = Color3.fromRGB(220, 170, 110)
        torso.Parent = generic
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(2, 1, 1)
        head.Position = Vector3.new(0, 2, 0)
        head.Color = Color3.fromRGB(245, 205, 170)
        head.Parent = generic
        generic.PrimaryPart = torso
        selectedModel = generic
    end
    local model = selectedModel :: Model
    model.Name = "CustomerNPC"
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    local root = npcRoot(model) :: BasePart
    model.PrimaryPart = root
    -- Normalize the clone upright before measuring; standard rigs face root -Z.
    model:PivotTo(CFrame.new(model:GetPivot().Position))
    local bottomOffset = Placement.BottomOffset(model)
    local spawnAt = Placement.AtMarker(spawn, bottomOffset)
    local counterAt = Placement.AtMarker(counter, bottomOffset)
    local exitAt = Placement.AtMarker(exit, bottomOffset)
    model:PivotTo(Placement.Face(spawnAt.Position, counterAt.Position, spawn.CFrame))
    if model:FindFirstChildOfClass("Humanoid") then
        Walk.PrepareRig(model, root)
    end
    -- The anchored PivotTo rig needs no network ownership assignment.
    model.Parent = workspace
    local walk = Walk.Create(model, templateName)
    ownedModels[player] = ownedModels[player] or {}
    ownedModels[player][model] = true
    local bubble = Instance.new("BillboardGui")
    bubble.Name = "OrderBubble"
    bubble.Size = UDim2.fromOffset(CUSTOMER_ORDER_WIDTH, CUSTOMER_ORDER_TEXT_HEIGHT)
    bubble.AlwaysOnTop = true
    bubble.MaxDistance = CUSTOMER_ORDER_MAX_DISTANCE
    -- Fail closed on every client; the owner's controller enables this locally.
    bubble.Enabled = false
    local head = model:FindFirstChild("Head", true)
    bubble.Adornee = if head and head:IsA("BasePart") then head else root
    bubble.StudsOffset = Vector3.new(0, CUSTOMER_ORDER_HEIGHT_OFFSET, 0)
    bubble.Parent = root
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.BorderSizePixel = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextStrokeTransparency = 0.1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = CUSTOMER_ORDER_TEXT_SIZE
    text.TextWrapped = true
    text.LineHeight = 0.95
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.TextYAlignment = Enum.TextYAlignment.Center
    text.Text = ""
    text.Parent = bubble
    local displayName = if candidate then candidate.DisplayName else "CustomerNPC"
    if displayName then
        -- Fixed separate rows keep the smaller name below the floating dialogue.
        bubble.Size = UDim2.fromOffset(CUSTOMER_ORDER_WIDTH, CUSTOMER_ORDER_TEXT_HEIGHT + CustomerNameHeight)
        text.Size = UDim2.fromOffset(CUSTOMER_ORDER_WIDTH, CUSTOMER_ORDER_TEXT_HEIGHT)
        text.Position = UDim2.fromOffset(0, 0)
        local nameText = text:Clone()
        nameText.Name = "CustomerName"
        nameText.Size = UDim2.fromOffset(CUSTOMER_ORDER_WIDTH, CustomerNameHeight)
        nameText.Position = UDim2.fromOffset(0, CUSTOMER_ORDER_TEXT_HEIGHT)
        nameText.TextSize = 18
        nameText.Text = displayName
        nameText.Parent = bubble
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- A single name row works even on imported rigs with hidden nameplates.
            humanoid.DisplayName = displayName
            Presentation.HideDefaultDisplay(humanoid)
        end
    end
    local audio = AudioService.CreateBlendGroup(root)
    local serveOrigin = Instance.new("Attachment")
    serveOrigin.Name = "ServePromptOrigin"
    serveOrigin.Position = Vector3.new(0, -0.5, -1.5)
    serveOrigin.Parent = root
    local prompt = WorldUtil.Prompt(root, "ServePrompt", "Serve smoothie")
    prompt.Enabled = false
    prompt:SetAttribute("InteractionOrigin", "ServePromptOrigin")
    prompt:SetAttribute("InteractionActionText", "SERVE")
    prompt.Style = Enum.ProximityPromptStyle.Custom
    local record: any = {
        Owner = player,
        BottomOffset = bottomOffset,
        CustomerType = if candidate then candidate.CustomerType else "Regular",
        FixedRequest = if candidate then candidate.Request else nil,
        DisplayName = displayName,
        CustomerId = CustomerRequests.NormalizeCustomerId(model:GetAttribute("CustomerId")),
        TemplateName = templateName or "<generic>",
        RequestId = nil :: string?,
        Served = false,
        Model = model,
        Walk = walk,
        Root = root,
        Preference = "",
        Request = nil,
        Ready = false,
        Text = text,
        Bubble = bubble,
        Audio = audio,
        Prompt = prompt,
        Exit = exitAt,
        ForcedReaction = nil,
    }
    local queue = queues[player]
    if not queue or not current(player, queue) or not assignRequest(player, record) then
        walk.Destroy()
        if ownedModels[player] then
            ownedModels[player][model] = nil
        end
        model:Destroy()
        return nil
    end
    table.insert(queue.Customers, record)
    if record.CustomerType == "Special" then
        lastSpecialSpawn[player] = os.clock()
    end
    model:SetAttribute("CustomerId", record.CustomerId)
    model:SetAttribute("OwnerUserId", player.UserId)
    diagnostic(string.format("queued owner=%s position=%d request=%s", player.Name, #queue.Customers, record.RequestId))
    prompt.Triggered:Connect(function(actor)
        if actor == player then
            CustomerService.Serve(actor, model)
        end
    end)
    model.Destroying:Connect(function()
        walk.Destroy()
        activeTypingTasks[text] = nil
        if ownedModels[player] then
            ownedModels[player][model] = nil
        end
        record.MoveToken = (record.MoveToken or 0) + 1
        if queues[player] == queue then
            local index = table.find(queue.Customers, record)
            if index then
                table.remove(queue.Customers, index)
                CustomerService.RefreshQueue(player)
            end
        end
    end)
    typewriterText(text, record.Request.DisplayText, audio.dialogueSound)
    CustomerService.RefreshQueue(player)
    return model
end
function CustomerService.GetSnapshot(player: Player): {
    Preference: string,
    CustomerId: string?,
    RequestId: string?,
    Ready: boolean,
    Model: Model,
}?
    local record = front(player)
    if not record then
        return nil
    end
    return {
        Preference = record.Preference,
        CustomerId = record.CustomerId,
        RequestId = if record.Request then record.Request.Id else nil,
        Ready = record.Ready,
        Model = record.Model,
    }
end
function CustomerService.Serve(player: Player, expectedModel: Model?): (boolean, string?)
    local queue = queues[player]
    local record = front(player)
    if
        not record
        or not record.Ready
        or not record.Request
        or record.Served
        or (expectedModel ~= nil and expectedModel ~= record.Model)
        or not queue
        or not current(player, queue)
        or not WorldUtil.Near(player, record.Root, Economy.InteractionDistance)
    then
        diagnostic("serve rejected owner=" .. player.Name .. " reason=No customer ready nearby")
        return false, "No customer ready nearby"
    end
    -- Lock this customer before consuming the selected reservation: destroying
    -- its visual can synchronously emit signals under Immediate signal behavior.
    record.Ready = false
    local result = deps.BlendService.ConsumeCup(player)
    if not result then
        record.Ready = true
        diagnostic("serve rejected owner=" .. player.Name .. " reason=No valid cup")
        record.Audio.notReadySound:Play()
        return false, "No valid cup"
    end
    -- No yield between consumption, payout, and removal from active state.
    record.Served = true
    record.Prompt.Enabled = false
    table.remove(queue.Customers, 1)
    record.Model:SetAttribute("QueuePosition", nil)
    local success, reason = CustomerService.ValidateRequest(result, record.Request)
    local grade: Types.Grade = if success then "A" else "D"
    local response = Presentation.Response(record.Request, grade)
    local reaction = record.ForcedReaction or (if success then "Smile" else "Disgust")
    local payout = if success then record.Request.BasePayout else 0
    if success then
        deps.PlayerDataService.AddCash(player, payout)
    end
    diagnostic(
        string.format(
            "served owner=%s request=%s blend=%s ingredients=[%s] success=%s reason=%s payout=%d cash=%d",
            player.Name,
            record.Request.Id,
            tostring(result.BlendId),
            table.concat(result.Ingredients, ", "),
            tostring(success),
            reason,
            payout,
            deps.PlayerDataService.GetCash(player)
        )
    )
    deps.PlayerDataService.IncrementStat(player, "CustomersServed")
    player:SetAttribute("CustomerSatisfaction", grade)
    player:SetAttribute("CustomerReaction", reaction)
    record.Model:SetAttribute("Reaction", reaction)
    record.Model:SetAttribute("Grade", grade)
    record.Model:SetAttribute("OrderSucceeded", success)
    record.Model:SetAttribute("RequestId", nil)
    record.Request = nil
    record.RequestId = nil
    Film.Emit(
        player,
        "CustomerReaction",
        { BlendId = result.BlendId, Customer = record.Model, ReactionId = reaction, Grade = grade, Payout = payout }
    )
    Film.Log(
        "Customer",
        string.format(
            "served blend=%s grade=%s reaction=%s payout=%d",
            tostring(result.BlendId),
            grade,
            reaction,
            payout
        )
    )
    -- Feedback uses the assigned order; reaction audio/VFX/attributes stay independent.
    activeTypingTasks[record.Text] = nil
    if response then
        typewriterText(record.Text, response, record.Audio.dialogueSound)
    else
        record.Bubble:Destroy()
    end
    local glow = ensureCustomerCounterGlow(record.Model)
    if glow and success then
        glow:Emit(20)
    end
    if success then
        record.Audio.customerServeSound:Play()
    else
        record.Audio.notReadySound:Play()
    end
    Debris:AddItem(record.Model, 15)
    task.delay(2, function()
        if record.Model.Parent then
            move(record, record.Exit, function()
                record.Model:Destroy()
            end)
        end
    end)
    CustomerService.RefreshQueue(player)
    diagnostic(string.format("advanced owner=%s count=%d", player.Name, #queue.Customers))
    onServed(player, grade)
    return true
end
-- Only DevContentService exposes this through its Studio gate; no remote.
function CustomerService.SetForcedReaction(player: Player, reaction: string?): boolean
    if not front(player) then
        return false
    end
    if reaction then
        local valid = false
        for _, definition in Customers.Reactions do
            if definition.Id == reaction then
                valid = true
            end
        end
        if not valid then
            return false
        end
    end
    front(player).ForcedReaction = reaction
    return true
end
-- Legacy colon-call compatibility. Unowned auto-spawns and attribute-based cup checks were removed.
function CustomerService:CreateCustomer(_spawnTarget: any, plotOwner: Player?): Model?
    if not plotOwner then
        warn("[CustomerService] CreateCustomer now requires a plot owner")
        return nil
    end
    return CustomerService.SpawnForPlayer(plotOwner)
end
function CustomerService:ServeCheck(player: Player, item: Instance?): boolean
    return deps.BlendService.GetCup(player, item) ~= nil
end
function CustomerService:GetSatisfaction(player: Player, item: Instance?, preference: string?): string
    local result = deps.BlendService.GetCup(player, item)
    if not result then
        return "D"
    end
    return CustomerService.CalculateGrade(
        result,
        preference or (front(player) and front(player).Preference) or "Surprise Me"
    )
end
function CustomerService:RefreshOrder(model: Model)
    for player, queue in queues do
        for _, record in queue.Customers do
            if record.Model == model then
                if assignRequest(player, record) then
                    typewriterText(record.Text, record.Request.DisplayText, record.Audio.dialogueSound)
                end
                return
            end
        end
    end
end
-- Snapshots expose presentation state, never mutable authoritative records.
function CustomerService.GetQueueSnapshot(player: Player): { any }
    local result = {}
    local queue = queues[player]
    if queue then
        for index, record in queue.Customers do
            table.insert(
                result,
                { Model = record.Model, RequestId = record.RequestId, Ready = record.Ready, Position = index }
            )
        end
    end
    return result
end
function CustomerService.DeactivateForPlayer(player: Player)
    local queue = queues[player]
    queues[player] = nil -- Invalidate scheduler and movement callbacks before destroying models.
    if queue and queue.PlotConnection then
        queue.PlotConnection:Disconnect()
    end
    player:SetAttribute("CustomerFlowState", "PLOT_INACTIVE")
    local models = ownedModels[player]
    ownedModels[player] = nil
    if models then
        for model in models do
            model:Destroy()
        end
    end
    if queue then
        diagnostic("flow stopped owner=" .. player.Name)
    end
end
function CustomerService.RemovePlayer(player: Player)
    CustomerService.DeactivateForPlayer(player)
    lastSpecialSpawn[player] = nil
    lastTemplates[player] = nil
    recentTemplates[player] = nil
    recentRequests[player] = nil
end
return require(script.Parent.StudioServices).Wrap("CustomerService", CustomerService)
