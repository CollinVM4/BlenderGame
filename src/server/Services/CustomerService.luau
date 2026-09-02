--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AudioService = require(script.Parent.AudioService)
local TycoonService = require(script.Parent.TycoonService)
local Recipes = require(ReplicatedStorage.Shared.Constants.Recipes)

type RecipeTemplate = {
    Name: string,
    Pay: number,
}

type CustomerData = {
    Order: RecipeTemplate,
    TextLabel: TextLabel?,
    Prompt: ProximityPrompt?,
    DialogueSound: Sound?,
    PlotOwner: Player?,
}

local activeTypingTasks = {}

local CustomerService: {
    Templates: { RecipeTemplate },
    ActiveCustomers: { [Model]: CustomerData },
    ActiveCustomer: Model?,
} = {
    Templates = {},
    ActiveCustomers = {},
    ActiveCustomer = nil,
}


local function normalizeRecipeName(value: string): string
    return tostring(value):lower()
end

local function buildTemplatesFromRecipes(): { RecipeTemplate }
    local templates: { RecipeTemplate } = {}

    for recipeName, recipeData in pairs(Recipes) do
        table.insert(templates, {
            Name = tostring(recipeName),
            Pay = tonumber(recipeData and recipeData.Pay) or 25,
        })
    end

    if #templates == 0 then
        return {
            {
                Name = "Fruit Smoothie",
                Pay = 25,
            },
        }
    end

    table.sort(templates, function(a: RecipeTemplate, b: RecipeTemplate)
        return a.Name < b.Name
    end)

    return templates
end

local function pickRandomOrder(): RecipeTemplate
    local templates = buildTemplatesFromRecipes()
    local index = math.random(1, #templates)
    return templates[index]
end

local function getSmoothieName(player: Player, item: Instance?): string?
    if item then
        local recipeName = item:GetAttribute("RecipeName")
        if recipeName then
            return tostring(recipeName)
        end

        return tostring(item.Name)
    end

    local character = player.Character
    if character then
        local heldItem = character:FindFirstChild("Smoothie")
        if heldItem then
            local recipeName = heldItem:GetAttribute("RecipeName")
            if recipeName then
                return tostring(recipeName)
            end

            return tostring(heldItem.Name)
        end
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local heldItem = backpack:FindFirstChild("Smoothie")
        if heldItem then
            local recipeName = heldItem:GetAttribute("RecipeName")
            if recipeName then
                return tostring(recipeName)
            end

            return tostring(heldItem.Name)
        end
    end

    local currentRecipeName = player:GetAttribute("CurrentRecipeName")
    if currentRecipeName then
        return tostring(currentRecipeName)
    end

    return nil
end

function CustomerService:GetSatisfaction(player: Player, item: Instance?, orderName: string?): string
    local smoothieName = getSmoothieName(player, item)
    if not smoothieName or smoothieName == "" then
        return "Bad"
    end

    local normalizedName = normalizeRecipeName(smoothieName)
    local activeOrderName = orderName or ""

    if normalizeRecipeName(activeOrderName) == normalizedName then
        return "Good"
    end

    if Recipes[smoothieName] then
        return "Good"
    end

    return "Bad"
end

function CustomerService:ServeCheck(player: Player, item: Instance?): boolean
    if not player then
        return false
    end

    local smoothieName = getSmoothieName(player, item)
    if not smoothieName or smoothieName == "" then
        return false
    end

    return Recipes[smoothieName] ~= nil
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
            if activeTypingTasks[textLabel] ~= currentToken then
                return
            end

            local character = string.sub(message, index, index)
            textLabel.Text = string.sub(message, 1, index)

            local shouldPlayDialogueSound = dialogueSound
                and dialogueSound.Parent
                and character ~= " "
                and (index % dialogueStep == 0 or index == #message)

            if shouldPlayDialogueSound then
                dialogueSound.TimePosition = 0
                dialogueSound.PlaybackSpeed = math.random(90, 120) / 100

                local pitchShift = dialogueSound:FindFirstChildOfClass("PitchShiftSoundEffect")
                if not pitchShift then
                    pitchShift = Instance.new("PitchShiftSoundEffect")
                    pitchShift.Parent = dialogueSound
                end

                pitchShift.Octave = math.random(92, 108) / 100
                dialogueSound:Play()
            end

            task.wait(0.04)
        end

        if activeTypingTasks[textLabel] == currentToken then
            activeTypingTasks[textLabel] = nil
        end
    end)
end

function CustomerService:RefreshOrder(customerModel: Model)
    local customerData = self.ActiveCustomers[customerModel]
    if not customerData then
        return
    end

    customerData.Order = pickRandomOrder()

    if customerData.TextLabel then
        typewriterText(customerData.TextLabel, "Need a " .. customerData.Order.Name, customerData.DialogueSound)
    end

    if customerData.Prompt then
        customerData.Prompt.ActionText = "Serve " .. customerData.Order.Name
    end
end

local function resolveSpawnCFrame(spawnTarget: any): CFrame
    if typeof(spawnTarget) == "CFrame" then
        return spawnTarget
    end

    if typeof(spawnTarget) == "Vector3" then
        return CFrame.new(spawnTarget)
    end

    if typeof(spawnTarget) == "Instance" then
        if spawnTarget:IsA("BasePart") then
            return spawnTarget.CFrame
        end

        if spawnTarget:IsA("Model") then
            local rootPart = spawnTarget:FindFirstChild("HumanoidRootPart") or spawnTarget.PrimaryPart
            if rootPart and rootPart:IsA("BasePart") then
                return rootPart.CFrame
            end
        end
    end

    return CFrame.new(Vector3.new(-18.96, 0.87, 100.89))
end

local function getRigRoot(model: Model): BasePart?
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.RootPart and humanoid.RootPart:IsA("BasePart") then
        return humanoid.RootPart
    end

    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end

    local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
        return humanoidRootPart
    end

    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("LowerTorso")
    if torso and torso:IsA("BasePart") then
        return torso
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end

    return nil
end

local function ensureCustomerRig(model: Model): BasePart?
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = Instance.new("Humanoid")
        humanoid.Parent = model
    end

    local rigRoot = getRigRoot(model)
    if rigRoot then
        model.PrimaryPart = rigRoot
        return rigRoot
    end

    local generatedRoot = Instance.new("Part")
    generatedRoot.Name = "HumanoidRootPart"
    generatedRoot.Transparency = 1
    generatedRoot.Size = Vector3.new(2, 2, 1)
    generatedRoot.CanCollide = false
    generatedRoot.Parent = model

    model.PrimaryPart = generatedRoot
    return generatedRoot
end

local function attachCustomerPrompt(customerModel: Model, rootPart: BasePart, textLabel: TextLabel, customerServeAudio: any)
    local existingPrompt = customerModel:FindFirstChild("ServePrompt")
    if existingPrompt and existingPrompt:IsA("ProximityPrompt") then
        existingPrompt:Destroy()
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ServePrompt"
    prompt.ActionText = "Start interaction"
    prompt.ObjectText = "Customer"
    prompt.RequiresLineOfSight = false -- generated root part occludes the raycast otherwise
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration = 0.5
    prompt.Parent = rootPart

    prompt.Triggered:Connect(function(player: Player)
        local customerData = CustomerService.ActiveCustomers[customerModel]
        if not customerData then
            return
        end

        local heldItem = nil
        local character = player.Character
        if character then
            heldItem = character:FindFirstChild("Smoothie")
        end

        if not heldItem and player:FindFirstChild("Backpack") then
            heldItem = player.Backpack:FindFirstChild("Smoothie")
        end

        local currentOrder = customerData.Order
        local isCorrect = CustomerService:ServeCheck(player, heldItem)
        local satisfaction = CustomerService:GetSatisfaction(player, heldItem, currentOrder.Name)
        player:SetAttribute("CustomerSatisfaction", satisfaction)

        if not isCorrect then
            customerServeAudio.notReadySound:Play()
            typewriterText(textLabel, "Wrong smoothie!", customerServeAudio.dialogueSound)
            task.delay(1.2, function()
                typewriterText(textLabel, "Need a " .. currentOrder.Name, customerServeAudio.dialogueSound)
            end)
            return
        end

        if heldItem then
            heldItem:Destroy()
        end

        player:SetAttribute("HasSmoothie", false)
        player:SetAttribute("CurrentRecipeName", "")
        TycoonService.AddCash(player, currentOrder.Pay)

        typewriterText(textLabel, "Cash +$" .. tostring(currentOrder.Pay) .. " (" .. satisfaction .. ")", customerServeAudio.dialogueSound)
        prompt.ActionText = "Thanks!"

        local counterGlow = customerModel:FindFirstChild("CustomerCounterGlow")
        if not counterGlow or not counterGlow:IsA("ParticleEmitter") then
            counterGlow = ensureCustomerCounterGlow(customerModel)
        end

        if counterGlow and counterGlow:IsA("ParticleEmitter") then
            counterGlow.Rate = 30
            counterGlow:Emit(20)
        end

        customerServeAudio.customerServeSound:Play()

        task.delay(1.2, function()
            typewriterText(textLabel, "Need a " .. currentOrder.Name, customerServeAudio.dialogueSound)
            prompt.ActionText = "Serve " .. currentOrder.Name
            if counterGlow and counterGlow:IsA("ParticleEmitter") then
                counterGlow.Rate = 0
            end
        end)

        task.delay(3, function()
            CustomerService:RefreshOrder(customerModel)
        end)
    end)

    local customerData = CustomerService.ActiveCustomers[customerModel]
    if customerData then
        customerData.Prompt = prompt
    end
end

function CustomerService:CreateCustomer(spawnTarget: any, plotOwner: Player?): Model
    self.Templates = buildTemplatesFromRecipes()

    local customerModel: Model
    local desiredSpawnCFrame: CFrame

    if typeof(spawnTarget) == "Instance" and spawnTarget:IsA("Model") then
        customerModel = spawnTarget
    else
        customerModel = Instance.new("Model")
        customerModel.Name = "CustomerNPC"
        customerModel.Parent = Workspace

        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2.5, 1)
        torso.Color = Color3.fromRGB(220, 170, 110)
        torso.Anchored = true
        torso.Parent = customerModel

        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(2, 1, 1)
        head.Position = torso.Position + Vector3.new(0, 2, 0)
        head.Anchored = true
        head.Color = Color3.fromRGB(245, 205, 170)
        head.Parent = customerModel

        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"
        root.Size = Vector3.new(2, 2, 1)
        root.Transparency = 1
        root.CanCollide = false
        root.Anchored = true
        root.Parent = customerModel

        local humanoid = Instance.new("Humanoid")
        humanoid.Parent = customerModel

        customerModel.PrimaryPart = root
        customerModel:PivotTo(CFrame.new(Vector3.new(-18.96, 0.87, 100.89)))

        local prompt = customerModel:FindFirstChild("ServePrompt")
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt:Destroy()
        end
    end

    if customerModel.Parent == nil then
        customerModel.Parent = Workspace
    end

    if customerModel:FindFirstChildOfClass("Humanoid") == nil then
        local generatedHumanoid = Instance.new("Humanoid")
        generatedHumanoid.Parent = customerModel
    end

    local rigRoot = ensureCustomerRig(customerModel)
    desiredSpawnCFrame = resolveSpawnCFrame(spawnTarget)
    customerModel:PivotTo(desiredSpawnCFrame)

    if customerModel.Name ~= "CustomerNPC" then
        customerModel.Name = "CustomerNPC"
    end

    if not CollectionService:HasTag(customerModel, "StoreCustomer") then
        CollectionService:AddTag(customerModel, "StoreCustomer")
    end

    if self.ActiveCustomer and self.ActiveCustomer ~= customerModel then
        local oldCustomerData = self.ActiveCustomers[self.ActiveCustomer]
        if oldCustomerData and oldCustomerData.TextLabel and oldCustomerData.TextLabel.Parent then
            oldCustomerData.TextLabel:Destroy()
        end
        self.ActiveCustomers[self.ActiveCustomer] = nil
    end

    local billboardTarget = customerModel:FindFirstChild("Head") or rigRoot
    local label = Instance.new("BillboardGui")
    label.Name = "OrderBubble"
    label.Size = UDim2.fromOffset(190, 42)
    label.StudsOffset = Vector3.new(0, 3.2, 0)
    label.AlwaysOnTop = true
    label.Parent = billboardTarget

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    background.BorderSizePixel = 0
    background.Parent = label

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Text = ""
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Parent = label

    local customerServeAudio = AudioService.CreateBlendGroup(billboardTarget)
    local customerData: CustomerData = {
        Order = pickRandomOrder(),
        TextLabel = text,
        Prompt = nil,
        DialogueSound = customerServeAudio.dialogueSound,
        PlotOwner = plotOwner,
    }

    self.ActiveCustomers[customerModel] = customerData
    self.ActiveCustomer = customerModel

    ensureCustomerCounterGlow(customerModel)
    attachCustomerPrompt(customerModel, rigRoot, text, customerServeAudio)
    self:RefreshOrder(customerModel)

    return customerModel
end

function CustomerService.Init()
    local taggedCustomers = CollectionService:GetTagged("StoreCustomer")
    if #taggedCustomers > 0 then
        for _, customerModel in ipairs(taggedCustomers) do
            if customerModel:IsA("Model") then
                CustomerService:CreateCustomer(customerModel)
            end
        end
        return
    end

    CustomerService:CreateCustomer()
end

return CustomerService
