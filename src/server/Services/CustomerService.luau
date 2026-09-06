--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local Customers = require(Shared.Constants.Customers)
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local AudioService = require(script.Parent.AudioService)
local Film = require(script.Parent.FilmingUtil)
local CustomerService = {}
local deps: any
local onServed: (Player, Types.Grade) -> ()
local canServe: (Player) -> boolean
local active: { [Player]: any } = {}
local ownedModels: { [Player]: { [Model]: boolean } } = {}
local activeTypingTasks = setmetatable({}, { __mode = "k" })

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
    for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerExit" } do
        if not deps.TycoonService.GetReference(player, name) then
            warn("[CustomerService] Missing " .. name .. " in " .. player.Name .. "'s plot")
            return false, "Missing " .. name
        end
    end
    return true
end
-- Simple deterministic waypoint movement for the filming skeleton, not pathfinding.
local function move(record: any, destination: CFrame, finished: () -> ())
    local start: CFrame = record.Model:GetPivot()
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
    local template = ServerStorage:FindFirstChild("Customer")
    local model: Model
    if template and template:IsA("Model") and WorldUtil.Part(template) then
        model = template:Clone()
    else
        model = Instance.new("Model")
        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2.5, 1)
        torso.Color = Color3.fromRGB(220, 170, 110)
        torso.Parent = model
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(2, 1, 1)
        head.Position = Vector3.new(0, 2, 0)
        head.Color = Color3.fromRGB(245, 205, 170)
        head.Parent = model
        model.PrimaryPart = torso
    end
    model.Name = "CustomerNPC"
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    model:PivotTo(spawn.CFrame)
    model.Parent = workspace
    local root = WorldUtil.Part(model) :: BasePart
    model.PrimaryPart = root
    ownedModels[player] = ownedModels[player] or {}
    ownedModels[player][model] = true
    local bubble = Instance.new("BillboardGui")
    bubble.Name = "OrderBubble"
    bubble.Size = UDim2.fromOffset(210, 48)
    bubble.StudsOffset = Vector3.new(0, 3.2, 0)
    bubble.AlwaysOnTop = true
    bubble.MaxDistance = 80
    bubble.Parent = root
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.TextWrapped = true
    text.Parent = bubble
    local audio = AudioService.CreateBlendGroup(root)
    local prompt = WorldUtil.Prompt(root, "ServePrompt", "Serve smoothie")
    prompt.Enabled = false
    local preference = Customers.Preferences[math.random(1, #Customers.Preferences)]
    local record = {
        Model = model,
        Root = root,
        Preference = preference,
        Ready = false,
        Text = text,
        Audio = audio,
        Prompt = prompt,
        Exit = exit.CFrame,
        ForcedReaction = nil,
    }
    active[player] = record
    model:SetAttribute("Preference", preference)
    model:SetAttribute("OwnerUserId", player.UserId)
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
    typewriterText(text, "Something " .. preference .. "!", audio.dialogueSound)
    move(record, counter.CFrame, function()
        if active[player] == record then
            record.Ready = true
            prompt.Enabled = true
        end
    end)
    return model
end
function CustomerService.GetSnapshot(player: Player): { Preference: string, Ready: boolean, Model: Model }?
    local record = active[player]
    if not record then
        return nil
    end
    return { Preference = record.Preference, Ready = record.Ready, Model = record.Model }
end
function CustomerService.Serve(player: Player): (boolean, string?)
    local record = active[player]
    if
        not record
        or not record.Ready
        or not canServe(player)
        or not WorldUtil.Near(player, record.Root, Economy.InteractionDistance)
    then
        return false, "No customer ready nearby"
    end
    local result = deps.BlendService.ConsumeCup(player)
    if not result then
        record.Audio.notReadySound:Play()
        return false, "No valid cup"
    end
    -- No yield between consumption, payout, and removal from active state.
    record.Ready = false
    record.Prompt.Enabled = false
    active[player] = nil
    local grade: Types.Grade = CustomerService.CalculateGrade(result, record.Preference)
    local reaction = record.ForcedReaction or CustomerService.SelectReaction()
    local payout = CustomerService.CalculatePayout(player, grade)
    deps.PlayerDataService.AddCash(player, payout)
    deps.PlayerDataService.IncrementStat(player, "CustomersServed")
    player:SetAttribute("CustomerSatisfaction", grade)
    player:SetAttribute("CustomerReaction", reaction)
    record.Model:SetAttribute("Reaction", reaction)
    record.Model:SetAttribute("Grade", grade)
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
    typewriterText(record.Text, grade .. " | " .. reaction .. " | +$" .. payout, record.Audio.dialogueSound)
    local glow = ensureCustomerCounterGlow(record.Model)
    if glow then
        glow:Emit(20)
    end
    record.Audio.customerServeSound:Play()
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
    for _, record in active do
        if record.Model == model then
            record.Preference = Customers.Preferences[math.random(1, #Customers.Preferences)]
            model:SetAttribute("Preference", record.Preference)
            typewriterText(record.Text, "Something " .. record.Preference .. "!", record.Audio.dialogueSound)
        end
    end
end
function CustomerService.RemovePlayer(player: Player)
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
return CustomerService
