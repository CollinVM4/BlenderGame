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
local AudioService = require(script.Parent.AudioService)
local Film = require(script.Parent.FilmingUtil)
local CustomerService = {}
local deps: any
local onServed: (Player, Types.Grade) -> ()
local canServe: (Player) -> boolean
local active: { [Player]: any } = {}
local ownedModels: { [Player]: { [Model]: boolean } } = {}
local specialCounts: { [Player]: number } = {}
local lastTemplates: { [Player]: Model } = {}
local warnedTemplates = setmetatable({} :: { [Instance]: boolean }, { __mode = "k" })
local activeTypingTasks = setmetatable({}, { __mode = "k" })
local CustomerBillboardExtraHeight = 2
local CustomerNameHeight = 28

local function diagnostic(message: string)
    if RunService:IsStudio() then
        print("[CustomerService] " .. message)
    end
end

-- Pure request decision, separate from legacy grading and cosmetic reactions.
-- Read definitions from actual ingredient IDs, never cup attributes or supplied result.Tags.
function CustomerService.ValidateRequest(result: Types.Smoothie, request: CustomerRequests.Request): (boolean, string)
    if #result.Ingredients == 0 or #request.RequiredTags == 0 then
        return false, "Empty smoothie or request"
    end
    local tags: { [string]: boolean } = {}
    for _, id in result.Ingredients do
        local definition = Ingredients[id]
        if not definition then
            return false, "Unknown ingredient: " .. id
        end
        for _, tag in definition.Tags do
            tags[tag] = true
        end
    end
    for _, tag in request.RequiredTags do
        if not tags[tag] then
            return false, "Missing required tag: " .. tag
        end
    end
    return true, "Required tags matched"
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
        selectedRequest = eligible[math.random(1, #eligible)]
    end
    local request = selectedRequest :: CustomerRequests.Request
    record.Request = request
    record.RequestId = request.Id
    record.Preference = request.RequiredTags[1]
    record.Model:SetAttribute("Preference", record.Preference)
    record.Model:SetAttribute("RequestId", request.Id)
    diagnostic(
        string.format(
            "selected type=%s template=%s customerId=%s displayName=%s request=%s jumpTier=%s forced=%s",
            record.CustomerType,
            record.TemplateName,
            record.CustomerId or "<absent>",
            record.DisplayName or "<absent>",
            request.Id,
            tostring(player:GetAttribute("JumpLevel") or 0),
            tostring(forced)
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
        DisplayName = if config and config.DisplayName then config.DisplayName else id,
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
        for _, template in folder:GetChildren() do
            if not template:IsA("Model") then
                rejectTemplate(template, "expected a Model")
            elseif not template:FindFirstChildOfClass("Humanoid") or not npcRoot(template) then
                rejectTemplate(template, "requires Humanoid and a BasePart root")
            elseif not template.Archivable then
                rejectTemplate(template, "enable Archivable to allow cloning")
            else
                local candidate = candidateFor(player, template)
                if candidate then
                    table.insert(if candidate.CustomerType == "Special" then special else regular, candidate)
                end
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
        and (specialCounts[player] or 0) < CustomerRequests.MaxSpecialCustomersPerDay
        and math.random() < CustomerRequests.SpecialCustomerChance
    local candidates = if useSpecial then special else regular
    -- Prefer alternatives within the chosen category; never increase special frequency to avoid a repeat.
    local function take(pool: { Candidate }): Candidate
        local alternatives: { number } = {}
        for index, candidate in pool do
            if candidate.Template ~= lastTemplates[player] then
                table.insert(alternatives, index)
            end
        end
        if #alternatives == 0 then
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
        return table.remove(pool, chosen) :: Candidate
    end
    while #candidates > 0 do
        local candidate = take(candidates)
        local template = candidate.Template
        local ok, clone = pcall(function()
            return template:Clone()
        end)
        if ok and clone then
            cleanClone(clone)
        end
        if ok and clone and clone:FindFirstChildOfClass("Humanoid") and npcRoot(clone) then
            lastTemplates[player] = template
            if candidate.CustomerType == "Special" then
                specialCounts[player] = (specialCounts[player] or 0) + 1
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

-- Called only on a new authoritative day, never when resuming an interrupted day.
function CustomerService.BeginDay(player: Player)
    specialCounts[player] = 0
end

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

function CustomerService.Init(services, servedCallback, servingCallback)
    deps = services
    onServed = servedCallback
    canServe = servingCallback
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
    if active[player] then
        return false, "Customer already active"
    end
    if #eligibleRequests(player) == 0 then
        return false, "No eligible customer requests"
    end
    for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerExit" } do
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
    local current: CFrame = record.Model:GetPivot()
    local start = Placement.Face(current.Position, destination.Position, current)
    destination = Placement.Face(destination.Position, destination.Position + start.LookVector, start)
    record.Model:PivotTo(start)
    local duration = math.max(0.1, (start.Position - destination.Position).Magnitude / 8)
    task.spawn(function()
        local elapsed = 0
        while record.Model.Parent and elapsed < duration do
            elapsed += task.wait()
            record.Model:PivotTo(start:Lerp(destination, math.min(1, elapsed / duration)))
        end
        if record.Model.Parent then
            finished()
        end
    end)
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
    model.Parent = workspace
    ownedModels[player] = ownedModels[player] or {}
    ownedModels[player][model] = true
    local bubble = Instance.new("BillboardGui")
    bubble.Name = "OrderBubble"
    bubble.Size = UDim2.fromOffset(300, 80)
    bubble.AlwaysOnTop = true
    bubble.MaxDistance = 80
    local head = model:FindFirstChild("Head", true)
    bubble.Adornee = if head and head:IsA("BasePart") then head else root
    bubble.StudsOffset = Vector3.new(0, 2.5, 0) + Vector3.new(0, CustomerBillboardExtraHeight, 0)
    bubble.Parent = root
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.BorderSizePixel = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextStrokeTransparency = 0.25
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 24
    text.TextWrapped = true
    text.Text = ""
    text.Parent = bubble
    local displayName = if candidate and candidate.CustomerType == "Special" then candidate.DisplayName else nil
    if displayName then
        -- Keep the full order area and a stable name above the typewritten dialogue.
        bubble.Size = UDim2.fromOffset(300, 80 + CustomerNameHeight)
        text.Size = UDim2.fromOffset(300, 80)
        text.Position = UDim2.fromOffset(0, CustomerNameHeight)
        local nameText = text:Clone()
        nameText.Name = "CustomerName"
        nameText.Size = UDim2.fromOffset(300, CustomerNameHeight)
        nameText.Position = UDim2.fromOffset(0, 0)
        nameText.Text = displayName
        nameText.Parent = bubble
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Suppress the imported name only where our own name row replaces it.
            humanoid.NameDisplayDistance = 0
        end
    end
    local audio = AudioService.CreateBlendGroup(root)
    local prompt = WorldUtil.Prompt(root, "ServePrompt", "Serve smoothie")
    prompt.Enabled = false
    local record: any = {
        Owner = player,
        CustomerType = if candidate then candidate.CustomerType else "Regular",
        FixedRequest = if candidate then candidate.Request else nil,
        DisplayName = displayName,
        CustomerId = CustomerRequests.NormalizeCustomerId(model:GetAttribute("CustomerId")),
        TemplateName = templateName or "<generic>",
        RequestId = nil :: string?,
        Served = false,
        Model = model,
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
    active[player] = record
    model:SetAttribute("CustomerId", record.CustomerId)
    model:SetAttribute("RequestId", nil)
    model:SetAttribute("OwnerUserId", player.UserId)
    diagnostic("spawned owner=" .. player.Name)
    prompt.Triggered:Connect(function(actor)
        if actor == player then
            CustomerService.Serve(actor)
        end
    end)
    model.Destroying:Connect(function()
        activeTypingTasks[text] = nil
        if ownedModels[player] then
            ownedModels[player][model] = nil
        end
        if active[player] == record then
            active[player] = nil
        end
    end)
    move(record, counterAt, function()
        if active[player] == record then
            if not assignRequest(player, record) then
                return
            end
            typewriterText(text, (record.Request :: CustomerRequests.Request).DisplayText, audio.dialogueSound)
            record.Ready = true
            prompt.Enabled = true
        end
    end)
    return model
end
function CustomerService.GetSnapshot(player: Player): {
    Preference: string,
    CustomerId: string?,
    RequestId: string?,
    Ready: boolean,
    Model: Model,
}?
    local record = active[player]
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
function CustomerService.Serve(player: Player): (boolean, string?)
    local record = active[player]
    if
        not record
        or not record.Ready
        or not record.Request
        or not canServe(player)
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
    active[player] = nil
    local success, reason = CustomerService.ValidateRequest(result, record.Request)
    local grade: Types.Grade = if success then "A" else "D"
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
    -- The order presentation ends with the transaction; reactions remain in audio/VFX/attributes.
    activeTypingTasks[record.Text] = nil
    record.Bubble:Destroy()
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
    onServed(player, grade)
    return true
end
-- Only DevContentService exposes this through its Studio gate; no remote.
function CustomerService.SetForcedReaction(player: Player, reaction: string?): boolean
    if not active[player] then
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
    active[player].ForcedReaction = reaction
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
        preference or (active[player] and active[player].Preference) or "Surprise Me"
    )
end
function CustomerService:RefreshOrder(model: Model)
    for player, record in active do
        if record.Model == model and record.Ready then
            if not assignRequest(player, record) then
                return
            end
            typewriterText(record.Text, record.Request.DisplayText, record.Audio.dialogueSound)
        end
    end
end
function CustomerService.RemovePlayer(player: Player)
    specialCounts[player] = nil
    lastTemplates[player] = nil
    local record = active[player]
    active[player] = nil
    if record then
        activeTypingTasks[record.Text] = nil
        record.Model:Destroy()
    end
    local models = ownedModels[player]
    ownedModels[player] = nil
    if models then
        for model in models do
            model:Destroy()
        end
    end
end
return require(script.Parent.StudioServices).Wrap("CustomerService", CustomerService)
