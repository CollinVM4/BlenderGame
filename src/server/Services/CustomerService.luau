--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Customers = require(Shared.Constants.Customers)
local CustomerRequests = require(Shared.Constants.CustomerRequests)
local TutorialOrders = require(Shared.Constants.TutorialOrders)
local tutorialRequests: { [number]: CustomerRequests.Request } = {}
for index, order in TutorialOrders do
    for _, request in CustomerRequests.Definitions do
        if request.Id == order.RequestId then
            tutorialRequests[index] = request
            break
        end
    end
end
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
local BatConfig = require(Shared.Constants.BatConfig)
local Knockback = require(script.Parent.BatKnockback)
local GameplaySfx = require(script.Parent.GameplaySfxService)
local OrderEvaluation = require(script.Parent.CustomerOrderEvaluation)
local BadCustomers = require(Shared.Constants.BadCustomers)
local BadBehavior = require(script.Parent.BadCustomerBehavior)
local RejectFloorButton = require(script.Parent.RejectFloorButton)
local CustomerService = {}
local deps: any
local onServed: (Player, Types.Grade?) -> ()
local queues: { [string]: any } = {}
local function key(player: Player): string
    return deps.TycoonService.GetSessionId(player) or ""
end
local queueMarkers = { "CustomerCounter", "CustomerWait1", "CustomerWait2" }
local function front(player: Player): any
    local queue = queues[key(player)]
    return if queue then queue.Customers[1] else nil
end
local function current(_player: Player, queue: any): boolean
    return queues[queue.SessionId] == queue and deps.TycoonService.GetSessionOwner(queue.SessionId) ~= nil
end
local ownedModels: { [string]: { [Model]: any } } = {}
local lastSpecialSpawn: { [string]: number } = {}
local lastTemplates: { [string]: Model } = {}
-- Runtime-only regular selections survive flow restarts.
local recentTemplates: { [string]: { Model } } = {}
local recentRequests: { [string]: { string } } = {}
local recentRequestGroups: { [string]: { string } } = {}
local recentRequestSimilarity: { [string]: { { string } } } = {}

local function remember<T>(histories: { [string]: { T } }, player: Player, value: T, window: number)
    local history = histories[key(player)] or {}
    table.insert(history, value)
    while #history > math.max(0, window) do
        table.remove(history, 1)
    end
    histories[key(player)] = history
end
local warnedTemplates = setmetatable({} :: { [Instance]: boolean }, { __mode = "k" })
local activeTypingTasks = setmetatable({}, { __mode = "k" })
local CustomerNameHeight = 28
local CUSTOMER_ORDER_MAX_DISTANCE = 30
local CUSTOMER_ORDER_WIDTH = 270
local CUSTOMER_ORDER_TEXT_HEIGHT = 56
local CUSTOMER_ORDER_TEXT_SIZE = 21

local function diagnostic(message: string)
    if RunService:IsStudio() then
        print("[CustomerService] " .. message)
    end
end

-- Validate authored request metadata; runtime matching and grading live in OrderEvaluation.
-- Read definitions from actual ingredient IDs, never cup attributes or supplied result.Tags.
-- Only tag comparisons ignore case; ingredient IDs and CustomerIds keep their existing semantics.
function CustomerService.ValidateRequestDefinition(request: CustomerRequests.Request): { string }
    local diagnostics: { string } = {}
    local requiredIngredients: { CustomerRequests.IngredientRequirement } = request.RequiredIngredients or {}
    for slot, requirement in requiredIngredients do
        if type(requirement) == "table" then
            local accessible = false
            local valid = false
            if #requirement == 0 then
                table.insert(diagnostics, "Empty ingredient alternative group at slot " .. slot)
            end
            for _, id in requirement do
                local definition = Ingredients[id]
                if not definition then
                    table.insert(diagnostics, "Unknown required ingredient: " .. id)
                else
                    valid = true
                    accessible = accessible or definition.JumpLocation <= request.MinJumpTier
                end
            end
            if valid and not accessible then
                table.insert(
                    diagnostics,
                    "No ingredient alternative at slot "
                        .. slot
                        .. " is accessible at MinJumpTier "
                        .. request.MinJumpTier
                )
            end
            continue
        end
        local id = requirement
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
    local evaluation = OrderEvaluation.Evaluate(result, request)
    return evaluation.IsValid and evaluation.RequirementsCovered and not evaluation.RestrictionViolated,
        evaluation.Reason
end

local function eligibleRequests(player: Player): { CustomerRequests.Request }
    -- Purchased session progression; personal Studio movement overrides are irrelevant.
    local playerJumpTier = deps.TycoonService.GetJumpTier(player)
    local eligible: { CustomerRequests.Request } = {}
    for _, request in CustomerRequests.Definitions do
        if not request.NPCOnly and not request.Wildcard and playerJumpTier >= request.MinJumpTier then
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

-- Group choice is uniform, so large groups do not dominate the request queue.
-- Missing metadata shares a legacy bucket; it never makes a request ineligible.
local function variedRequestPool(player: Player, pool: { CustomerRequests.Request }): { CustomerRequests.Request }
    local groups: { [string]: { CustomerRequests.Request } } = {}
    local groupNames: { string } = {}
    local freshGroups: { string } = {}
    local history = recentRequestGroups[key(player)] or {}
    for _, request in pool do
        local group = request.RequestGroup or "Ungrouped"
        if not groups[group] then
            groups[group] = {}
            table.insert(groupNames, group)
            if not table.find(history, group) then
                table.insert(freshGroups, group)
            end
        end
        table.insert(groups[group], request)
    end
    local choices = if #freshGroups > 0 then freshGroups else groupNames
    local group = choices[if #choices == 1 then 1 else math.random(1, #choices)]
    local candidates = groups[group]
    local recentKeys: { [string]: boolean } = {}
    local similarityHistory: { { string } } = recentRequestSimilarity[key(player)] or {}
    for _, keys in similarityHistory do
        for _, concept in keys do
            recentKeys[concept] = true
        end
    end
    local fresh: { CustomerRequests.Request } = {}
    for _, request in candidates do
        local overlaps = false
        local similarityKeys: { string } = request.SimilarityKeys or {}
        for _, concept in similarityKeys do
            if recentKeys[concept] then
                overlaps = true
                break
            end
        end
        if not overlaps then
            table.insert(fresh, request)
        end
    end
    return if #fresh > 0 then fresh else candidates
end

local function assignRequest(player: Player, record: any): boolean
    local selectedRequest = record.FixedRequest
    local forced = selectedRequest ~= nil
    local recentFiltered, recentFallback = false, false
    if selectedRequest and (deps.TycoonService.GetJumpTier(player)) < selectedRequest.MinJumpTier then
        diagnostic("special became ineligible before assignment; removing customer owner=" .. player.Name)
        record.Model:Destroy()
        return false
    end
    -- Identity is already selected. Keep this encounter's roll stable on RefreshOrder.
    if record.Wildcard == nil then
        local chance = if record.CustomerType == "Special"
            then CustomerRequests.SpecialWildcardChance
            else CustomerRequests.RegularWildcardChance
        record.Wildcard = chance > 0 and math.random() < chance
    end
    if record.Wildcard then
        selectedRequest = CustomerRequests.WildcardRequest
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
                if not table.find(recentRequests[key(player)] or {}, request.Id) then
                    table.insert(fresh, request)
                end
            end
            recentFiltered = #fresh < #eligible
            recentFallback = #fresh == 0
            if #fresh > 0 then
                pool = fresh
            end
            pool = variedRequestPool(player, pool)
        end
        selectedRequest = pool[math.random(1, #pool)]
    end
    local request = selectedRequest :: CustomerRequests.Request
    record.Request = request
    record.RequestId = request.Id
    -- RefreshOrder can replace a gameplay request; revisiting an ID on this
    -- customer keeps its original line. UI refreshes never draw dialogue again.
    record.RequestTexts = record.RequestTexts or {}
    if not record.RequestTexts[request.Id] then
        local variants = request.DisplayTexts
        record.RequestTexts[request.Id] = if variants and #variants > 0
            then variants[math.random(1, #variants)]
            else request.DisplayText
    end
    record.RequestText = record.RequestTexts[request.Id]
    record.Preference = request.RequiredTags[1] or "Surprise Me"
    record.Model:SetAttribute("Preference", record.Preference)
    record.Model:SetAttribute("RequestId", request.Id)
    if not forced and not request.Wildcard and record.CustomerType == "Regular" then
        remember(recentRequests, player, request.Id, CustomerRequests.RegularRequestRecencyWindow)
        remember(
            recentRequestGroups,
            player,
            request.RequestGroup or "Ungrouped",
            CustomerRequests.RegularRequestGroupRecencyWindow
        )
        remember(
            recentRequestSimilarity,
            player,
            table.clone(request.SimilarityKeys or {}),
            CustomerRequests.RegularRequestSimilarityRecencyWindow
        )
    end
    diagnostic(
        string.format(
            "selected type=%s template=%s customerId=%s displayName=%s request=%s jumpTier=%s forced=%s requestRecencyFiltered=%s requestRecencyFallback=%s",
            record.CustomerType,
            record.TemplateName,
            record.CustomerId or "<absent>",
            record.DisplayName or "<absent>",
            request.Id,
            tostring(deps.TycoonService.GetJumpTier(player)),
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
    Rejectable: boolean?,
    BadCustomerType: string?,
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
        if request and (deps.TycoonService.GetJumpTier(player)) < request.MinJumpTier then
            diagnostic(
                string.format(
                    "special ineligible customerId=%s request=%s requiredJumpTier=%d playerJumpTier=%s",
                    id or "<absent>",
                    request.Id,
                    request.MinJumpTier,
                    tostring(deps.TycoonService.GetJumpTier(player))
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
        Rejectable = config and config.Rejectable == true,
        BadCustomerType = if config then config.BadCustomerType else nil,
    }
end

local function cloneNPC(player: Player, customerId: string?, regularOnly: boolean?): (Model?, Candidate?)
    local folder = ServerStorage:FindFirstChild("CustomerNPCs")
    if customerId then
        local id = CustomerRequests.NormalizeCustomerId(customerId)
        local special = folder and folder:FindFirstChild("Special")
        if id and special and special:IsA("Folder") then
            for _, template in special:GetChildren() do
                if
                    template:IsA("Model")
                    and CustomerRequests.NormalizeCustomerId(template:GetAttribute("CustomerId")) == id
                then
                    local candidate = candidateFor(player, template)
                    if candidate and candidate.CustomerType == "Special" and template.Archivable then
                        local ok, clone = pcall(function()
                            return template:Clone()
                        end)
                        if ok and clone then
                            cleanClone(clone)
                            if clone:FindFirstChildOfClass("Humanoid") and npcRoot(clone) then
                                lastTemplates[key(player)] = template
                                return clone, candidate
                            end
                            clone:Destroy()
                        end
                    end
                end
            end
        end
        warn("[CustomerService] Cannot inject special customer: " .. customerId .. " (check template and jump tier)")
        return nil, nil
    end
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
            if special[index].Template == lastTemplates[key(player)] then
                table.remove(special, index)
            end
        end
    end
    local useSpecial = not regularOnly
        and #special > 0
        and (lastSpecialSpawn[key(player)] == nil or os.clock() - lastSpecialSpawn[key(player)] >= Economy.SpecialCustomerCooldownSeconds)
        and math.random() < CustomerRequests.SpecialCustomerChance
    local candidates = if useSpecial then special else regular
    -- Regulars use rolling recency; specials retain their existing immediate-repeat rule.
    -- Never increase special frequency to avoid a regular repeat.
    local function take(pool: { Candidate }): (Candidate, boolean, boolean)
        local alternatives: { number } = {}
        for index, candidate in pool do
            local recent = if candidate.CustomerType == "Regular"
                then table.find(recentTemplates[key(player)] or {}, candidate.Template) ~= nil
                else candidate.Template == lastTemplates[key(player)]
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
            lastTemplates[key(player)] = template
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

local function escapeRichText(message: string): string
    local escaped = message:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return escaped
end

function CustomerService.FormatRequestText(request: CustomerRequests.Request, displayText: string?): string
    local names: { { Name: string, Color: Color3 } } = {}
    local seen: { [string]: boolean } = {}
    local requiredIngredients: { CustomerRequests.IngredientRequirement } = request.RequiredIngredients or {}
    for _, requirement in requiredIngredients do
        local alternatives: { string } = if type(requirement) == "string" then { requirement } else requirement
        for _, id in alternatives do
            local definition = Ingredients[id]
            if definition then
                local name = string.lower(definition.DisplayName or definition.Id)
                if name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(names, { Name = name, Color = definition.BlendColor })
                end
            end
        end
    end
    -- Ingredient names were added first, so a tag cannot replace their catalog color.
    local function addTag(tag: string)
        local normalized = string.lower(tag)
        local highlight = Presentation.TagHighlights[normalized]
        if not highlight then
            return
        end
        local phrases = { normalized }
        local aliases: { string } = highlight.Aliases or {}
        for _, alias in aliases do
            table.insert(phrases, alias)
        end
        for _, phrase in phrases do
            if not seen[phrase] then
                seen[phrase] = true
                table.insert(names, { Name = phrase, Color = highlight.Color })
            end
        end
    end
    local requiredTags: { string } = request.RequiredTags or {}
    for _, tag in requiredTags do
        addTag(tag)
    end
    local forbiddenTags: { string } = request.ForbiddenTags or {}
    for _, tag in forbiddenTags do
        addTag(tag)
    end
    -- Prefer full multiword names over shorter names contained within them.
    table.sort(names, function(a, b)
        return #a.Name > #b.Name
    end)
    local message = displayText or request.DisplayText
    local lower = string.lower(message)
    local output: { string } = {}
    local index = 1
    while index <= #message do
        local matched = false
        for _, entry in names do
            local last = index + #entry.Name - 1
            if
                lower:sub(index, last) == entry.Name
                and not lower:sub(index - 1, index - 1):match("[%w_]")
                and not lower:sub(last + 1, last + 1):match("[%w_]")
            then
                local color = entry.Color
                table.insert(
                    output,
                    string.format(
                        '<font color="rgb(%d,%d,%d)">%s</font>',
                        math.round(color.R * 255),
                        math.round(color.G * 255),
                        math.round(color.B * 255),
                        escapeRichText(message:sub(index, last))
                    )
                )
                index = last + 1
                matched = true
                break
            end
        end
        if not matched then
            table.insert(output, escapeRichText(message:sub(index, index)))
            index += 1
        end
    end
    return table.concat(output)
end

local function typewriterText(textLabel: TextLabel, message: string, dialogueSound: Sound?, richMessage: string?)
    local currentToken = {}
    activeTypingTasks[textLabel] = currentToken
    AudioService.PlayCustomerDialogue(dialogueSound)
    local totalGraphemes = 0
    for _ in utf8.graphemes(message) do
        totalGraphemes += 1
    end

    textLabel.RichText = true
    textLabel.MaxVisibleGraphemes = 0
    textLabel.Text = richMessage or escapeRichText(message)

    task.spawn(function()
        local index = 0
        local replayScheduled = false
        for _ in utf8.graphemes(message) do
            index += 1
            if not textLabel.Parent or activeTypingTasks[textLabel] ~= currentToken then
                return
            end

            textLabel.MaxVisibleGraphemes = index

            task.wait(0.04)

            local remainingGraphemes = totalGraphemes - index
            if
                dialogueSound
                and dialogueSound.Parent
                and not dialogueSound.IsPlaying
                and remainingGraphemes >= 4
                and not replayScheduled
                and textLabel.Parent
                and activeTypingTasks[textLabel] == currentToken
            then
                replayScheduled = true
                task.delay(0.08, function()
                    replayScheduled = false
                    if
                        textLabel.Parent
                        and activeTypingTasks[textLabel] == currentToken
                        and totalGraphemes - index >= 4
                    then
                        AudioService.PlayCustomerDialogue(dialogueSound)
                    end
                end)
            end
        end

        if textLabel.Parent and activeTypingTasks[textLabel] == currentToken then
            textLabel.MaxVisibleGraphemes = -1
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
function CustomerService.EvaluateOrder(
    result: Types.Smoothie,
    request: CustomerRequests.Request
): OrderEvaluation.Evaluation
    return OrderEvaluation.Evaluate(result, request)
end
function CustomerService.CalculateGrade(result: Types.Smoothie, preference: string): Types.Grade?
    local request: CustomerRequests.Request = {
        Id = "LegacyPreference",
        DisplayText = preference,
        RequiredTags = if preference == "Surprise Me" then {} else { preference },
        BasePayout = 0,
        MinJumpTier = 0,
        Wildcard = preference == "Surprise Me",
    }
    return OrderEvaluation.Evaluate(result, request).Grade
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
    local upgrade = Upgrades.Payout[deps.TycoonService.GetUpgrade(player, "Payout")].Value
    local multiplier = if deps.PlayerDataService.HasEntitlement(player, "DoubleCash") then 2 else 1
    local muncher = if deps.MuncherService then deps.MuncherService.GetCashMultiplier(player) else 1
    return math.round(
        Economy.BasePayout * Economy.CashScale * Economy.GradeMultiplier[grade] * upgrade * multiplier * muncher
    )
end

-- Called only with the consumed server cup and the customer's assigned request.
local IngredientItem = require(game:GetService("ReplicatedStorage").Shared.IngredientItem)
function CustomerService.CalculateOrderPayout(
    player: Player,
    result: Types.Smoothie,
    request: CustomerRequests.Request,
    evaluation: OrderEvaluation.Evaluation?
): (number, number)
    local ingredientValue = IngredientItem.GetSmoothieValue(result, workspace:GetServerTimeNow())
    evaluation = evaluation or OrderEvaluation.Evaluate(result, request)
    local upgrade = Upgrades.Payout[deps.TycoonService.GetUpgrade(player, "Payout")].Value
    local entitlement = if deps.PlayerDataService.HasEntitlement(player, "DoubleCash") then 2 else 1
    local gradeMultiplier = if evaluation.IsWildcard
        then 1
        else Economy.GradeMultiplier[evaluation.Grade :: Types.Grade]
    local muncher = if deps.MuncherService then deps.MuncherService.GetCashMultiplier(player) else 1
    local amount = (ingredientValue + request.BasePayout) * gradeMultiplier * upgrade * entitlement * muncher
    return math.round(amount), ingredientValue
end
function CustomerService.CanSpawn(player: Player): (boolean, string?)
    local queue = queues[key(player)]
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
-- Keep all low-level traversal and pose handling in the existing walking helper.
local function move(record: any, destination: CFrame, finished: () -> ())
    Walk.Move(record, destination, function(reached)
        if reached or (record.ReturningFromHit and not record.Served) then
            if not reached then
                -- CustomerWalk already exhausted its bounded retries. Preserve the order.
                record.Root.AssemblyLinearVelocity = Vector3.zero
                record.Root.AssemblyAngularVelocity = Vector3.zero
                record.Model:PivotTo(destination)
            end
            if record.ReturningFromHit then
                record.ReturningFromHit = false
                record.HitImmuneUntil = os.clock() + BatConfig.ImmunitySeconds
                record.TakeOrderPrompt.Enabled = not record.Served and not record.OrderTaken
            end
            finished()
        elseif record.Model.Parent then
            -- Existing Destroying cleanup removes the failed entry and advances waiters.
            warn("[CustomerWalk] route exhausted; removing unreachable customer")
            record.Model:Destroy()
        end
    end)
end
-- Authoritative queue index maps directly to its destination marker; no intermediate entrance route.
function CustomerService.RefreshQueue(player: Player)
    local queue = queues[key(player)]
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
            Walk.Cancel(record)
            record.TargetMarker = nil
            record.Ready = false
            record.Prompt.Enabled = false
            record.Walk.SetMoving(false)
        else
            local destination = Placement.AtMarker(marker, record.BottomOffset)
            local changed = record.TargetMarker ~= marker
                or record.MarkerFrame ~= marker.CFrame
                or record.QueueIndex ~= index
            if record.Recovering then
                record.TargetMarker = marker
                record.MarkerFrame = marker.CFrame
                record.QueueIndex = index
                record.Ready = false
                record.Prompt.Enabled = false
            elseif changed then
                record.TargetMarker = marker
                record.MarkerFrame = marker.CFrame
                record.QueueIndex = index
                record.Ready = false
                record.Prompt.Enabled = false
                move(record, destination, function()
                    if current(player, queue) and table.find(queue.Customers, record) then
                        record.Ready = true
                        record.Prompt.Enabled = record.Ready and record.OrderTaken
                    end
                end)
            else
                record.Prompt.Enabled = record.Ready and record.OrderTaken
            end
        end
    end
end

-- Resolve from the physical customer registry, never names, tags or attributes.
local function hitRecord(player: Player, model: Model): (any, any)
    local queue = queues[key(player)]
    if not queue or not current(player, queue) then
        return nil, nil
    end
    local record = ownedModels[queue.SessionId] and ownedModels[queue.SessionId][model]
    if record and record.Model == model and record.SessionId == queue.SessionId and model:IsDescendantOf(workspace) then
        return record, queue
    end
    return nil, nil
end

local function active(record: any): boolean
    return record.State == "Queued"
        or record.State == "OrderTaken"
        or record.State == "Stealing"
        or record.State == "Escaping"
end

local function bad(record: any): boolean
    return record.Rejectable == true and (record.BadCustomerType == "Thief" or record.BadCustomerType == "Freeloader")
end

-- Queue membership is separate from the lifetime registry. Every logical exit
-- uses this operation; destruction after an earlier release is a no-op.
local function releaseQueue(record: any, queue: any)
    local index = table.find(queue.Customers, record)
    if not index then
        return
    end
    table.remove(queue.Customers, index)
    record.Model:SetAttribute("QueuePosition", nil)
    local owner = deps.TycoonService.GetSessionOwner(queue.SessionId)
    if owner and current(owner, queue) then
        CustomerService.RefreshQueue(owner)
    end
end

local function invalidate(record: any)
    record.RuntimeToken = (record.RuntimeToken or 0) + 1
    record.RecoveryToken += 1
    record.ReturningFromHit = false
    record.Ready = false
    record.TakeOrderPrompt.Enabled = false
    record.Prompt.Enabled = false
    record.Request, record.RequestId = nil, nil
    record.Model:SetAttribute("RequestId", nil)
    activeTypingTasks[record.Text] = nil
    Walk.Cancel(record)
end

local function behaviorContext(record: any, queue: any): any
    local token = record.RuntimeToken
    local context: any = {}
    context.Valid = function(): boolean
        local owner = deps.TycoonService.GetSessionOwner(queue.SessionId)
        return owner ~= nil
            and current(owner, queue)
            and (not bad(record) or record.SpawnOwnerUserId == owner.UserId)
            and record.RuntimeToken == token
            and ownedModels[queue.SessionId] ~= nil
            and ownedModels[queue.SessionId][record.Model] == record
            and record.Model:IsDescendantOf(workspace)
    end
    context.Marker = function(name: string): BasePart?
        local owner = deps.TycoonService.GetSessionOwner(queue.SessionId)
        return if owner and context.Valid() then deps.TycoonService.GetReference(owner, name) else nil
    end
    context.Destroy = function()
        if context.Valid() then
            record.Model:Destroy()
        end
    end
    context.Exit = function()
        if not context.Valid() then
            return
        end
        -- An un-rejected thief remains catchable through the final exit leg.
        if record.State ~= "Escaping" then
            record.State = "Leaving"
        end
        local exit = context.Marker("CustomerExit")
        if not exit then
            context.Destroy()
            return
        end
        task.delay(BadCustomers.ExitTimeout, context.Destroy)
        Walk.Move(record, Placement.AtMarker(exit, record.BottomOffset), function()
            context.Destroy()
        end)
    end
    context.Theft = function()
        if not context.Valid() or record.State ~= "Stealing" or record.TheftAttempted then
            return
        end
        local owner = deps.TycoonService.GetSessionOwner(queue.SessionId)
        local transaction = owner
            and deps.TycoonService.BeginTransaction(owner, deps.TycoonService.GetRequestContext(owner))
        if not transaction then
            return
        end
        -- Reserve the exact removed unit before inventory publishes stash signals.
        record.TheftAttempted = true
        deps.InventoryService.RemoveThiefIngredient(owner, transaction, function(unit)
            record.StolenIngredient = unit
        end)
        deps.TycoonService.EndTransaction(transaction)
        if record.StolenIngredient and context.Valid() and deps.IngredientService then
            pcall(function()
                local visual =
                    deps.IngredientService.CreateVisual(record.StolenIngredient.IngredientId, record.StolenIngredient)
                if visual then
                    record.StolenVisual = Presentation.AttachStolenIngredient(record.Model, visual)
                end
            end)
        end
    end
    return context
end

local function badCue(record: any, cue: string)
    -- Audio availability must never hold queue/economy authority hostage.
    pcall(function()
        AudioService.PlayBadCustomerCue(record.Root, cue)
    end)
end

-- Revealed thieves are explicitly associated with this plot's lifetime registry.
-- Hidden queue occupants never get discovered by the override.
function CustomerService.ResolveRejectTarget(player: Player): Model?
    local queue = queues[key(player)]
    if not queue or not current(player, queue) or deps.TycoonService.GetSessionOwner(queue.SessionId) ~= player then
        return nil
    end
    -- Escaping wins over Stealing; ties use the oldest encounter deterministically.
    local fallback: any = nil
    for _, record in queue.Records do
        local humanoid = record.Model:FindFirstChildOfClass("Humanoid")
        if
            bad(record)
            and record.BadCustomerType == "Thief"
            and (record.State == "Stealing" or record.State == "Escaping")
            and record.SessionId == queue.SessionId
            and record.Model:IsDescendantOf(workspace)
            and record.SpawnOwnerUserId == player.UserId
            and (not humanoid or humanoid.Health > 0)
            and (
                not fallback
                or (record.State == "Escaping" and fallback.State ~= "Escaping")
                or (record.State == fallback.State and record.Sequence < fallback.Sequence)
            )
        then
            fallback = record
        end
    end
    if fallback then
        return fallback.Model
    end
    for _, record in queue.Customers do
        if active(record) and record.SessionId == queue.SessionId and record.Model:IsDescendantOf(workspace) then
            return record.Model
        end
    end
    return nil
end

function CustomerService.DismissCustomer(player: Player, model: Model, _reason: string?, context: any): boolean
    local record, queue = hitRecord(player, model)
    if
        not record
        or not active(record)
        or bad(record)
        or deps.TycoonService.GetSessionOwner(queue.SessionId) ~= player
    then
        return false
    end
    local transaction =
        deps.TycoonService.BeginTransaction(player, context or deps.TycoonService.GetRequestContext(player))
    if not transaction then
        return false
    end
    record.Bubble.MaxDistance = CUSTOMER_ORDER_MAX_DISTANCE
    record.State = "Dismissed" -- Claim before any Immediate signals/presentation.
    invalidate(record)
    releaseQueue(record, queue)
    record.Model:SetAttribute("OrderRevealed", true)
    record.Model:SetAttribute("Reaction", "Disgust")
    local responses = BadCustomers.DismissalResponses
    typewriterText(record.Text, responses[math.random(1, #responses)], record.Audio.dialogueSound)
    Film.Emit(player, "CustomerReaction", { Customer = model, ReactionId = "Disgust", PlotSessionId = transaction })
    local runtime = behaviorContext(record, queue)
    deps.TycoonService.EndTransaction(transaction)
    if record.Recovering then
        pcall(function()
            deps.RagdollService.SetRagdolled(model, false)
        end)
        record.Recovering = false
    end
    -- Like normal service, hold the reaction briefly while queue authority has
    -- already moved on. Missing exits still clean immediately.
    if runtime.Marker("CustomerExit") then
        task.delay(BadCustomers.DismissalResponseHold, runtime.Exit)
    else
        runtime.Destroy()
    end
    return true
end

-- The ONLY bad-customer rejection entry. Button and valid owner Bat hit share it.
function CustomerService.RejectCustomer(player: Player, model: Model, _reason: string, context: any): boolean
    local record, queue = hitRecord(player, model)
    if
        not record
        or not active(record)
        or not bad(record)
        or deps.TycoonService.GetSessionOwner(queue.SessionId) ~= player
    then
        return false
    end
    local transaction =
        deps.TycoonService.BeginTransaction(player, context or deps.TycoonService.GetRequestContext(player))
    if not transaction then
        return false
    end
    record.Bubble.MaxDistance = CUSTOMER_ORDER_MAX_DISTANCE
    record.State = "Rejected"
    invalidate(record)
    record.Recovering = true
    releaseQueue(record, queue)
    local stolen = record.StolenIngredient
    -- Rejected is the exclusive claim. Relinquish ownership and remove the inert
    -- carried projection before world publication, audio, ragdoll or impulse.
    record.StolenIngredient = nil
    if record.StolenVisual then
        record.StolenVisual:Destroy()
        record.StolenVisual = nil
    end
    if stolen then
        deps.InventoryService.ReleaseThiefIngredient(stolen, record.Root.CFrame * CFrame.new(0, 2, -4))
    end
    badCue(record, "Reject")
    local runtime = behaviorContext(record, queue)
    deps.TycoonService.EndTransaction(transaction)
    if runtime.Valid() then
        BadBehavior.Reject(record, runtime, deps.RagdollService)
    end
    return true
end

function CustomerService.RejectFront(player: Player, plot: Instance?, context: any): boolean
    local queue = queues[key(player)]
    if not queue or (plot and queue.Plot ~= plot) then
        return false
    end
    local model = CustomerService.ResolveRejectTarget(player)
    if not model then
        return false
    end
    local record = hitRecord(player, model)
    if not record then
        return false
    end
    return if bad(record)
        then CustomerService.RejectCustomer(player, model, "RejectButton", context)
        else CustomerService.DismissCustomer(player, model, "RejectedByOwner", context)
end

local function bindRejectButton(queue: any)
    local assembly = queue.Plot:FindFirstChild("RejectButton")
    local button = assembly and assembly:FindFirstChild("Button")
    local base = assembly and assembly:FindFirstChild("BlackBase")
    local origin = assembly and assembly:FindFirstChild("Attachment")
    if
        not button
        or not button:IsA("BasePart")
        or not base
        or not base:IsA("BasePart")
        or not origin
        or not origin:IsA("Attachment")
    then
        if RunService:IsStudio() then
            warn("[Customer] RejectButton needs sibling Button, BlackBase, Attachment; interaction skipped")
        end
        return
    end
    local oldPrompt = button:FindFirstChild("RejectPrompt")
    if oldPrompt then
        oldPrompt:Destroy()
    end
    queue.RejectCleanup = RejectFloorButton.Bind(button, origin, function()
        return if queues[queue.SessionId] == queue then deps.TycoonService.GetSessionOwner(queue.SessionId) else nil
    end, function(actor)
        return current(actor, queue)
            and WorldUtil.Near(actor, button, 10)
            and CustomerService.ResolveRejectTarget(actor) ~= nil
    end, function(actor)
        if queues[queue.SessionId] ~= queue or deps.TycoonService.GetSessionOwner(queue.SessionId) ~= actor then
            return false
        end
        return CustomerService.RejectFront(actor, queue.Plot, deps.TycoonService.GetRequestContext(actor))
    end)
end

function CustomerService.CanHitCustomer(player: Player, model: Model): boolean
    local record = hitRecord(player, model)
    if record and bad(record) and active(record) and deps.TycoonService.GetSessionOwner(record.SessionId) == player then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        return record.Root.Parent ~= nil and not record.Root.Anchored and humanoid ~= nil and humanoid.Health > 0
    end
    if
        record
        and (
            record.State == "Rejected"
            or record.State == "Dismissed"
            or record.State == "Leaving"
            or record.State == "Destroyed"
        )
    then
        return false
    end
    if not record or record.Recovering or record.ReturningFromHit or os.clock() < (record.HitImmuneUntil or 0) then
        return false
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if
        not root
        or not root:IsA("BasePart")
        or root ~= record.Root
        or root.Anchored
        or not humanoid
        or humanoid.Health <= 0
    then
        return false
    end
    local ok, compatible = pcall(function()
        return deps.RagdollService.PrepareCharacter(model)
    end)
    return ok and compatible == true
end

function CustomerService.HitCustomer(
    player: Player,
    model: Model,
    context: { Direction: Vector3, Duration: number }
): boolean
    local candidate = hitRecord(player, model)
    if
        candidate
        and bad(candidate)
        and active(candidate)
        and deps.TycoonService.GetSessionOwner(candidate.SessionId) == player
    then
        return CustomerService.RejectCustomer(player, model, "Bat", nil)
    end
    if not CustomerService.CanHitCustomer(player, model) then
        return false
    end
    local record, queue = hitRecord(player, model)
    local specialInterrupted = bad(record) and (record.State == "Stealing" or record.State == "Escaping")
    if specialInterrupted then
        record.RuntimeToken += 1
    end
    local token = (record.RecoveryToken or 0) + 1
    record.RecoveryToken = token
    record.Recovering = true
    record.Ready = false
    record.TakeOrderPrompt.Enabled = false
    record.Prompt.Enabled = false
    Walk.Cancel(record)
    local function valid(): boolean
        return current(player, queue)
            and record.SessionId == queue.SessionId
            and ownedModels[queue.SessionId] ~= nil
            and ownedModels[queue.SessionId][model] == record
            and record.Model == model
            and model:IsDescendantOf(workspace)
            and record.RecoveryToken == token
    end
    local function resumeDestination()
        if not valid() then
            return
        end
        record.Recovering = false
        if specialInterrupted then
            BadBehavior.Thief(record, behaviorContext(record, queue))
            return
        end
        record.ReturningFromHit = true
        if record.Served then
            record.ResumeExit()
            return
        end
        -- Force a fresh route even if the queue marker has not changed.
        record.TargetMarker = nil
        local owner = deps.TycoonService.GetSessionOwner(queue.SessionId)
        if owner then
            CustomerService.RefreshQueue(owner)
        end
    end
    local ok, enabled = pcall(function()
        return deps.RagdollService.SetRagdolled(model, true)
    end)
    if not ok or enabled ~= true then
        pcall(function()
            deps.RagdollService.SetRagdolled(model, false)
        end)
        resumeDestination()
        return false
    end
    GameplaySfx.Emit("CustomerHurt", record.Root.Position)
    RunService.Heartbeat:Once(function()
        if valid() and record.Recovering then
            pcall(function()
                if deps.RagdollService.IsRagdolled(model) then
                    Knockback.Apply(record.Root, context.Direction)
                end
            end)
        end
    end)
    task.delay(context.Duration, function()
        if not valid() then
            return
        end
        local restored, result = pcall(function()
            return deps.RagdollService.SetRagdolled(model, false)
        end)
        if not restored or result ~= true then
            warn("[Customer] ragdoll recovery failed")
            return
        end
        -- Give native GettingUp a physics step before locomotion takes over.
        RunService.Heartbeat:Once(resumeDestination)
    end)
    return true
end

-- Released/unfulfilled tutorial records get a replacement through this same queue.
local function pendingTutorial(queue: any): (number?, boolean)
    if not queue.TutorialOrders then
        return nil, false
    end
    for index, order in TutorialOrders do
        local record = queue.TutorialOrders[index]
        if record and record.TutorialFulfilled then
            continue
        end
        if not record or not table.find(queue.Customers, record) or not record.Model.Parent then
            return if os.clock() >= queue.StartedAt + order.Arrival then index else nil, true
        end
    end
    return nil, false
end

function CustomerService.ActivateForPlayer(player: Player, tutorial: boolean?): boolean
    local plot = deps.TycoonService.GetPlot(player)
    if not plot then
        CustomerService.DeactivateForPlayer(player)
        return false
    end
    local existing = queues[key(player)]
    if existing and current(player, existing) then
        return true
    end
    CustomerService.DeactivateForPlayer(player)
    local queue: any = { Customers = {}, Records = {}, Plot = plot, Full = false, SessionId = key(player) }
    if tutorial then
        queue.TutorialOrders = {}
        queue.StartedAt = os.clock()
        queue.TutorialInserted = 0
        queue.NextNormalAt = 0
    end
    queues[key(player)] = queue
    bindRejectButton(queue)
    queue.PlotConnection = plot.AncestryChanged:Connect(function()
        if queues[queue.SessionId] == queue and not current(player, queue) then
            CustomerService.CleanupSession(queue.SessionId)
        end
    end)
    player:SetAttribute("CustomerFlowState", "PLOT_ACTIVE")
    diagnostic("flow started owner=" .. player.Name)
    local function tick()
        if queues[queue.SessionId] ~= queue then
            return
        end
        local activeOwner = deps.TycoonService.GetSessionOwner(queue.SessionId)
        if not activeOwner then
            CustomerService.CleanupSession(queue.SessionId)
            return
        end
        player = activeOwner
        if queues[queue.SessionId] ~= queue then
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
        local tutorialIndex, tutorialPending = pendingTutorial(queue)
        if queue.TutorialOrders then
            local normalDue = not tutorialPending and os.clock() >= queue.NextNormalAt
            if not full and (tutorialIndex or normalDue) then
                local spawned = CustomerService.SpawnForPlayer(player) ~= nil
                if spawned and not tutorialIndex then
                    queue.NextNormalAt = os.clock()
                        + math.random(Economy.CustomerSpawnMinSeconds, Economy.CustomerSpawnMaxSeconds)
                end
            end
            if current(player, queue) then
                task.delay(0.5, tick)
            end
            return
        end
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
    if tutorial then
        task.defer(tick) -- claim transaction must release before spawning
    else
        task.delay(math.random(Economy.InitialCustomerDelayMin, Economy.InitialCustomerDelayMax), tick)
    end
    return true
end

local function spawnForPlayer(player: Player, customerId: string?, tutorialIndex: number?): Model?
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
    local customModel, candidate = cloneNPC(player, customerId, tutorialIndex ~= nil)
    if customerId and not customModel then
        return nil
    end
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
    model.Parent = workspace
    Walk.Prepare(model, root)
    local walk = Walk.Create(model, templateName)
    ownedModels[key(player)] = ownedModels[key(player)] or {}
    ownedModels[key(player)][model] = true
    local bubble = Instance.new("BillboardGui")
    bubble.Name = "OrderBubble"
    bubble.Size = UDim2.fromOffset(CUSTOMER_ORDER_WIDTH, CUSTOMER_ORDER_TEXT_HEIGHT)
    bubble.AlwaysOnTop = true
    bubble.MaxDistance = CUSTOMER_ORDER_MAX_DISTANCE
    -- Fail closed on every client; the owner's controller enables this locally.
    bubble.Enabled = false
    local head = model:FindFirstChild("Head", true)
    bubble.Adornee = Presentation.CreateAnchor(root, if head and head:IsA("BasePart") then head else nil)
    bubble.StudsOffset = Vector3.zero
    bubble.SizeOffset = Vector2.new(0, 0.5) -- Bottom edge stays at the rig anchor.
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
    Presentation.StyleDialogue(bubble, text, candidate ~= nil and candidate.CustomerType ~= "Regular")
    local audio = AudioService.CreateBlendGroup(root)
    local prompt = WorldUtil.Prompt(root, "ServePrompt", "Serve smoothie")
    prompt.Enabled = false
    prompt:SetAttribute("InteractionOrigin", "ServePromptOrigin")
    prompt:SetAttribute("InteractionActionText", "SERVE")
    prompt.Style = Enum.ProximityPromptStyle.Custom
    local takeOrder = WorldUtil.Prompt(root, "TakeOrderPrompt", "Take Order")
    takeOrder.Enabled = true
    takeOrder.Style = Enum.ProximityPromptStyle.Custom
    takeOrder:SetAttribute("InteractionOrigin", "ServePromptOrigin")
    takeOrder:SetAttribute("InteractionActionText", "TAKE ORDER")
    for _, interaction in { takeOrder, prompt } do
        interaction:SetAttribute("InteractionOwnerUserId", player.UserId)
        interaction:SetAttribute("PlotSessionId", key(player))
        interaction:SetAttribute("InteractionCustomerAction", if interaction == takeOrder then "TakeOrder" else "Serve")
    end
    local record: any = {
        State = "Queued",
        SpawnOwnerUserId = player.UserId,
        RuntimeToken = 0,
        Rejectable = candidate and candidate.Rejectable == true,
        BadCustomerType = if candidate then candidate.BadCustomerType else nil,
        Wildcard = if tutorialIndex or (candidate and candidate.Rejectable) then false else nil,
        OrderTaken = false,
        Recovering = false,
        RecoveryToken = 0,
        ReturningFromHit = false,
        TakeOrderPrompt = takeOrder,
        SessionId = key(player),
        BottomOffset = bottomOffset,
        CustomerType = if candidate then candidate.CustomerType else "Regular",
        FixedRequest = if tutorialIndex
            then tutorialRequests[tutorialIndex]
            else if candidate then candidate.Request else nil,
        TutorialIndex = tutorialIndex,
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
    ownedModels[key(player)][model] = record
    local queue = queues[key(player)]
    if not queue or not current(player, queue) or not assignRequest(player, record) then
        walk.Destroy()
        if ownedModels[key(player)] then
            ownedModels[key(player)][model] = nil
        end
        model:Destroy()
        return nil
    end
    queue.Records[model] = record
    queue.Sequence = (queue.Sequence or 0) + 1
    record.Sequence = queue.Sequence
    table.insert(queue.Customers, record)
    if tutorialIndex then
        queue.TutorialOrders[tutorialIndex] = record
        queue.TutorialInserted = math.max(queue.TutorialInserted, tutorialIndex)
        if queue.TutorialInserted == #TutorialOrders then
            queue.NextNormalAt = os.clock()
                + math.random(Economy.CustomerSpawnMinSeconds, Economy.CustomerSpawnMaxSeconds)
        end
        model:SetAttribute("TutorialOrderIndex", tutorialIndex)
    end
    if record.CustomerType == "Special" then
        lastSpecialSpawn[key(player)] = os.clock()
        if deps.DiscoveryService then
            for _, member in deps.TycoonService.GetMembers(record.SessionId) do
                deps.DiscoveryService.DiscoverSpecialCustomer(member, record.CustomerId)
            end
        end
    end
    model:SetAttribute("CustomerId", record.CustomerId)
    model:SetAttribute("OwnerUserId", player.UserId)
    model:SetAttribute("PlotSessionId", key(player))
    model:SetAttribute("OrderRevealed", false)
    diagnostic(string.format("queued owner=%s position=%d request=%s", player.Name, #queue.Customers, record.RequestId))
    deps.GameplayService.RegisterPlotInteraction(takeOrder, function(actor, context)
        CustomerService.TakeOrder(actor, model, context)
    end)
    deps.GameplayService.RegisterPlotInteraction(prompt, function(actor, context)
        CustomerService.Serve(actor, model, context)
    end)
    model.Destroying:Connect(function()
        record.State = "Destroyed"
        -- Escape, death/reset and generic cleanup consume held loot; only the
        -- successful rejection operation above is allowed to publish a drop.
        record.StolenIngredient = nil
        record.StolenVisual = nil
        record.RuntimeToken += 1
        Walk.Cancel(record)
        if deps.RagdollService then
            pcall(function()
                deps.RagdollService.CleanupCharacter(model)
            end)
        end
        queue.Records[model] = nil
        walk.Destroy()
        activeTypingTasks[text] = nil
        if ownedModels[queue.SessionId] then
            ownedModels[queue.SessionId][model] = nil
        end
        record.RecoveryToken += 1
        record.MoveToken = (record.MoveToken or 0) + 1
        releaseQueue(record, queue)
    end)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            model:Destroy()
        end)
    end
    CustomerService.RefreshQueue(player)
    return model
end
-- An explicit ID is a Studio-only injection; normal arrivals still use random selection.
function CustomerService.SpawnForPlayer(player: Player, customerId: string?): Model?
    if customerId and not (RunService:IsStudio() and RunService:IsServer()) then
        return nil
    end
    local queue = queues[key(player)]
    local tutorialIndex: number? = nil
    local tutorialPending = false
    if queue then
        tutorialIndex, tutorialPending = pendingTutorial(queue)
    end
    if tutorialPending and not tutorialIndex then
        return nil
    end
    local token = deps.TycoonService.BeginTransaction(player, deps.TycoonService.GetRequestContext(player))
    if not token then
        return nil
    end
    local model = spawnForPlayer(player, if tutorialIndex then nil else customerId, tutorialIndex)
    deps.TycoonService.EndTransaction(token)
    return model
end
-- Reveal only the assigned request; waiting customers are eligible too.
function CustomerService.TakeOrder(player: Player, model: Model, context: any): boolean
    if not deps.TycoonService.ValidateActor(player, context or deps.TycoonService.GetRequestContext(player)) then
        return false
    end
    local queue = queues[key(player)]
    if not queue or not current(player, queue) then
        return false
    end
    for _, record in queue.Customers do
        if record.Model == model then
            if
                record.OrderTaken
                or (bad(record) and record.BadCustomerType == "Thief" and deps.TycoonService.GetSessionOwner(
                    queue.SessionId
                ) ~= player)
                or not active(record)
                or record.Recovering
                or record.ReturningFromHit
                or record.Served
                or not record.Request
                or not model.Parent
                or not WorldUtil.Near(player, record.Root, Economy.InteractionDistance)
            then
                return false
            end
            local token =
                deps.TycoonService.BeginTransaction(player, context or deps.TycoonService.GetRequestContext(player))
            if not token then
                return false
            end
            record.Bubble.MaxDistance = if bad(record)
                then CUSTOMER_ORDER_MAX_DISTANCE
                else CUSTOMER_ORDER_MAX_DISTANCE * 1.25
            record.OrderTaken = true
            record.State = "OrderTaken"
            record.TakeOrderPrompt.Enabled = false
            record.Prompt.Enabled = record.Ready
            model:SetAttribute("OrderRevealed", true)
            typewriterText(
                record.Text,
                record.RequestText,
                record.Audio.dialogueSound,
                CustomerService.FormatRequestText(record.Request, record.RequestText)
            )
            if bad(record) and record.BadCustomerType == "Thief" then
                record.State = "Stealing"
                local suspiciousText = record.RequestText
                invalidate(record)
                releaseQueue(record, queue)
                typewriterText(record.Text, suspiciousText, record.Audio.dialogueSound)
                badCue(record, "Thief")
                local runtime = behaviorContext(record, queue)
                deps.TycoonService.EndTransaction(token)
                BadBehavior.Thief(record, runtime)
                return true
            end
            deps.TycoonService.EndTransaction(token)
            return true
        end
    end
    return false
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
function CustomerService.Serve(player: Player, expectedModel: Model?, context: any): (boolean, string?)
    context = context or deps.TycoonService.GetRequestContext(player)
    if not deps.TycoonService.ValidateActor(player, context) then
        return false, "StaleSession"
    end
    local queue = queues[key(player)]
    local record = if expectedModel then hitRecord(player, expectedModel) else front(player)
    local index = if queue and record then table.find(queue.Customers, record) else nil
    if
        not record
        or not index
        or not record.Ready
        or record.Recovering
        or record.ReturningFromHit
        or not record.Request
        or record.Served
        or (bad(record) and record.BadCustomerType == "Thief")
        or not active(record)
        or record.State == "Stealing"
        or record.State == "Escaping"
        or not queue
        or not current(player, queue)
        or not WorldUtil.Near(player, record.Root, Economy.InteractionDistance)
    then
        diagnostic("serve rejected owner=" .. player.Name .. " reason=No customer ready nearby")
        return false, "No customer ready nearby"
    end
    -- Lock this customer before consuming the selected reservation: destroying
    -- its visual can synchronously emit signals under Immediate signal behavior.
    local transaction = deps.TycoonService.BeginTransaction(player, context)
    if not transaction then
        return false, "StaleSession"
    end
    local freeloader = bad(record) and record.BadCustomerType == "Freeloader"
    if freeloader then
        local selected = deps.BlendService.GetCup(player)
        if not selected or not OrderEvaluation.Evaluate(selected, record.Request).IsValid then
            deps.TycoonService.EndTransaction(transaction)
            return false, "No valid cup"
        end
    end
    local previousState = record.State
    record.State = "Serving" -- Exclusive claim before cup destruction can emit signals.
    record.Ready = false
    local result = deps.BlendService.ConsumeCup(player)
    if not result then
        record.State = previousState
        record.Ready = true
        deps.TycoonService.EndTransaction(transaction)
        diagnostic("serve rejected owner=" .. player.Name .. " reason=No valid cup")
        record.Audio.notReadySound:Play()
        return false, "No valid cup"
    end
    -- No yield between consumption, payout, and removal from active state.
    record.Served = true
    record.Bubble.MaxDistance = CUSTOMER_ORDER_MAX_DISTANCE
    record.State = "Served"
    record.TakeOrderPrompt.Enabled = false
    record.Model:SetAttribute("OrderRevealed", true)
    record.Prompt.Enabled = false
    releaseQueue(record, queue)
    local evaluation = OrderEvaluation.Evaluate(result, record.Request)
    local grade = evaluation.Grade
    local success = evaluation.IsFulfilled
    if record.TutorialIndex then
        record.TutorialFulfilled = success and evaluation.IsValid
    end
    local response = if evaluation.IsWildcard
        then record.Request.GoodResponse
        else Presentation.Response(record.Request, grade :: Types.Grade)
    local reaction = record.ForcedReaction
        or (
            if evaluation.IsWildcard
                    or grade == "A"
                    or grade == "B"
                then "Smile"
                elseif grade == "C" then "Shudder"
                else "Disgust"
        )
    local payout, ingredientValue = BadCustomers.FreeloaderPayout, 0
    if freeloader then
        deps.TycoonService.DebitTransaction(transaction, -payout)
    else
        payout, ingredientValue = CustomerService.CalculateOrderPayout(player, result, record.Request, evaluation)
        deps.TycoonService.CreditTransaction(transaction, payout)
    end
    if deps.AnnouncementService then
        deps.AnnouncementService.Served(player, result.Ingredients, payout)
    end
    diagnostic(
        string.format(
            "served owner=%s request=%s blend=%s ingredients=[%s] success=%s reason=%s payout=%d cash=%d",
            player.Name,
            record.Request.Id,
            tostring(result.BlendId),
            table.concat(result.Ingredients, ", "),
            tostring(success),
            evaluation.Reason,
            payout,
            deps.TycoonService.GetCash(player)
        )
    )
    deps.PlayerDataService.IncrementStat(player, "CustomersServed")
    if deps.TutorialService then
        deps.TutorialService.Mark(player, "ServedCustomer")
    end
    for _, member in deps.TycoonService.GetMembers(transaction) do
        member:SetAttribute("CustomerSatisfaction", grade)
        member:SetAttribute("CustomerReaction", reaction)
    end
    record.Model:SetAttribute("Reaction", reaction)
    record.Model:SetAttribute("Grade", grade)
    record.Model:SetAttribute("IsWildcard", evaluation.IsWildcard)
    record.Model:SetAttribute("OrderSucceeded", success)
    local resultGui = Presentation.ShowResult(record.Bubble, grade, payout, if freeloader then nil else ingredientValue)
    record.Model:SetAttribute("RequestId", nil)
    record.Request = nil
    record.RequestId = nil
    -- FilmingUtil broadcasts once to all clients; both members also receive attributes above.
    Film.Emit(player, "CustomerReaction", {
        BlendId = result.BlendId,
        Customer = record.Model,
        ReactionId = reaction,
        Grade = grade,
        IsWildcard = evaluation.IsWildcard,
        Payout = payout,
        IngredientValue = ingredientValue,
        PlotSessionId = transaction,
    })
    Film.Log(
        "Customer",
        string.format(
            "served blend=%s grade=%s reaction=%s payout=%d",
            tostring(result.BlendId),
            tostring(grade),
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
    record.ResumeExit = function()
        if
            current(player, queue)
            and ownedModels[queue.SessionId] ~= nil
            and ownedModels[queue.SessionId][record.Model] == record
            and record.Model:IsDescendantOf(workspace)
            and not record.Recovering
        then
            move(record, record.Exit, function()
                Presentation.PreserveResult(resultGui)
                record.Model:Destroy()
            end)
        end
    end
    task.delay(2, function()
        if not record.ReturningFromHit then
            record.ResumeExit()
        end
    end)
    CustomerService.RefreshQueue(player)
    diagnostic(string.format("advanced owner=%s count=%d", player.Name, #queue.Customers))
    onServed(player, grade)
    deps.TycoonService.EndTransaction(transaction)
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
function CustomerService:GetSatisfaction(player: Player, item: Instance?, preference: string?): Types.Grade?
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
    for sessionId, queue in queues do
        local player = deps.TycoonService.GetSessionOwner(sessionId)
        if not player then
            continue
        end
        for _, record in queue.Customers do
            if record.Model == model then
                if assignRequest(player, record) and record.OrderTaken then
                    typewriterText(
                        record.Text,
                        record.RequestText,
                        record.Audio.dialogueSound,
                        CustomerService.FormatRequestText(record.Request, record.RequestText)
                    )
                end
                return
            end
        end
    end
end
-- Snapshots expose presentation state, never mutable authoritative records.
function CustomerService.GetTutorialSnapshot(player: Player): { any }?
    local queue = queues[key(player)]
    if not queue or not queue.TutorialOrders then
        return nil
    end
    local snapshot = {}
    for index, order in TutorialOrders do
        local record = queue.TutorialOrders[index]
        local present = record and table.find(queue.Customers, record) ~= nil and record.Model.Parent ~= nil
        snapshot[index] = {
            RequestId = order.RequestId,
            Served = record ~= nil and record.TutorialFulfilled == true,
            OrderTaken = present and record.OrderTaken == true,
            Model = if present then record.Model else nil,
        }
    end
    return snapshot
end
function CustomerService.GetQueueSnapshot(player: Player): { any }
    local result = {}
    local queue = queues[key(player)]
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
local function cleanupFlow(sessionId: string)
    local queue = queues[sessionId]
    queues[sessionId] = nil -- Invalidate scheduler/movement before destroying models.
    if queue and queue.PlotConnection then
        queue.PlotConnection:Disconnect()
    end
    if queue and queue.RejectCleanup then
        queue.RejectCleanup()
    end
    local models = ownedModels[sessionId]
    ownedModels[sessionId] = nil
    if models then
        for model in models do
            model:Destroy()
        end
    end
end
function CustomerService.CleanupSession(sessionId: string)
    cleanupFlow(sessionId)
    lastSpecialSpawn[sessionId], lastTemplates[sessionId] = nil, nil
    recentTemplates[sessionId], recentRequests[sessionId] = nil, nil
    recentRequestGroups[sessionId], recentRequestSimilarity[sessionId] = nil, nil
end
-- Explicit server flow reset, not a departing-player cleanup path.
function CustomerService.DeactivateForPlayer(player: Player)
    cleanupFlow(key(player))
    player:SetAttribute("CustomerFlowState", "PLOT_INACTIVE")
end
function CustomerService.BindPlayer(player: Player)
    local queue = queues[key(player)]
    player:SetAttribute("CustomerFlowState", if queue then "PLOT_ACTIVE" else "PLOT_INACTIVE")
    if queue then
        local owner = deps.TycoonService.GetSessionOwner(queue.SessionId)
        if owner then
            for model, record in table.clone((ownedModels[queue.SessionId] or {}) :: { [Model]: any }) do
                if bad(record) and record.SpawnOwnerUserId ~= owner.UserId then
                    model:Destroy()
                else
                    model:SetAttribute("OwnerUserId", owner.UserId)
                end
            end
        end
    end
end
function CustomerService.RemovePlayer(player: Player)
    player:SetAttribute("CustomerFlowState", "PLOT_INACTIVE")
end
return require(script.Parent.StudioServices).Wrap("CustomerService", CustomerService)
