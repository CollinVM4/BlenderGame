--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioService = require(script.Parent.AudioService)
local TycoonService = require(script.Parent.TycoonService)
local Recipes = require(ReplicatedStorage.Shared.Constants.Recipes)

local CustomerService = {
    Templates = {
        {
            Name = "Fruit Smoothie",
            Pay = 25,
            ValidNames = { "Fruit Smoothie", "Smoothie" },
        },
        {
            Name = "Berry Blend",
            Pay = 35,
            ValidNames = { "Berry Blend", "Berry Smoothie" },
        },
        {
            Name = "Green Cleanser",
            Pay = 45,
            ValidNames = { "Green Cleanser", "Green Smoothie" },
        },
        {
            Name = "Tropical Boost",
            Pay = 55,
            ValidNames = { "Tropical Boost", "Tropical Smoothie" },
        },
    },
    ActiveOrder = {
        Name = "Fruit Smoothie",
        Pay = 25,
        ValidNames = { "Fruit Smoothie", "Smoothie" },
    },
    ActiveCustomer = nil,
    ActiveCustomerText = nil,
    ActiveCustomerPrompt = nil,
}

local DIALOGUE_SOUND_ID = "rbxassetid://000000000"
local SUCCESS_SOUND_ID = "rbxassetid://000000000"

local function pickRandomOrder()
    local index = math.random(1, #CustomerService.Templates)
    return CustomerService.Templates[index]
end

function CustomerService:ServeCheck(player: Player, item: Instance?): boolean
    if not player then
        return false
    end

    local heldItem = item
    if not heldItem then
        local character = player.Character
        if character then
            heldItem = character:FindFirstChild("Smoothie")
        end

        if not heldItem and player:FindFirstChild("Backpack") then
            heldItem = player.Backpack:FindFirstChild("Smoothie")
        end
    end

    local possibleName = player:GetAttribute("CurrentSmoothieName")
    if heldItem then
        possibleName = heldItem:GetAttribute("RecipeName") or heldItem:GetAttribute("DrinkName") or heldItem:GetAttribute("SmoothieName") or heldItem.Name
    end

    if not possibleName then
        return false
    end

    local normalized = tostring(possibleName)
    for _, validName in ipairs(self.ActiveOrder.ValidNames) do
        if normalized == validName then
            return true
        end
    end

    return false
end

function CustomerService:RefreshOrder()
    self.ActiveOrder = pickRandomOrder()

    if self.ActiveCustomerText then
        self.ActiveCustomerText.Text = "Need a " .. self.ActiveOrder.Name
    end

    if self.ActiveCustomerPrompt then
        self.ActiveCustomerPrompt.ActionText = "Serve " .. self.ActiveOrder.Name
    end
end

function CustomerService:CreateCustomer(spawnPosition: Vector3?): Model
    self.ActiveOrder = pickRandomOrder()

    local storefront = Workspace:FindFirstChild("Storefront")
    if not storefront then
        storefront = Instance.new("Folder")
        storefront.Name = "Storefront"
        storefront.Parent = Workspace
    end

    local spawnPoint = storefront:FindFirstChild("SpawnPoint")
    if not spawnPoint then
        spawnPoint = Instance.new("Part")
        spawnPoint.Name = "SpawnPoint"
        spawnPoint.Anchored = true
        spawnPoint.Size = Vector3.new(2, 1, 2)
        spawnPoint.Position = spawnPosition or Vector3.new(0, 1, 20)
        spawnPoint.Color = Color3.fromRGB(60, 60, 60)
        spawnPoint.Material = Enum.Material.SmoothPlastic
        spawnPoint.Parent = storefront
    end

    local customerRoot = storefront:FindFirstChild("CustomerNPC")
    if customerRoot then
        self.ActiveCustomer = customerRoot
        return customerRoot
    end

    local customerModel = Instance.new("Model")
    customerModel.Name = "CustomerNPC"
    customerModel.Parent = storefront

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2.5, 1)
    torso.Position = spawnPoint.Position + Vector3.new(0, 2.5, 0)
    torso.Anchored = true
    torso.Color = Color3.fromRGB(220, 170, 110)
    torso.Parent = customerModel

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2, 1, 1)
    head.Position = torso.Position + Vector3.new(0, 2, 0)
    head.Anchored = true
    head.Color = Color3.fromRGB(245, 205, 170)
    head.Parent = customerModel

    local counter = Instance.new("Part")
    counter.Name = "Counter"
    counter.Size = Vector3.new(5, 1, 2)
    counter.Position = spawnPoint.Position + Vector3.new(0, 0.5, -3)
    counter.Anchored = true
    counter.Color = Color3.fromRGB(88, 86, 82)
    counter.Material = Enum.Material.SmoothPlastic
    counter.Parent = storefront

    local counterGlow = Instance.new("ParticleEmitter")
    counterGlow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    counterGlow.Rate = 0
    counterGlow.Speed = NumberRange.new(0.5, 1)
    counterGlow.Lifetime = NumberRange.new(0.4, 0.7)
    counterGlow.Color = ColorSequence.new(Color3.fromRGB(255, 224, 100))
    counterGlow.Parent = counter

    customerModel.PrimaryPart = torso
    customerModel:PivotTo(CFrame.new(spawnPoint.Position + Vector3.new(0, 1.5, 0)))

    local label = Instance.new("BillboardGui")
    label.Name = "OrderBubble"
    label.Size = UDim2.fromOffset(190, 42)
    label.StudsOffset = Vector3.new(0, 3.2, 0)
    label.AlwaysOnTop = true
    label.Parent = head

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    background.BorderSizePixel = 0
    background.Parent = label

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Text = "Need a " .. self.ActiveOrder.Name
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Parent = label
    self.ActiveCustomerText = text

    local dialogueSound = AudioService.CreateCue(head, DIALOGUE_SOUND_ID, 1, false)
    local successSound = AudioService.CreateCue(head, SUCCESS_SOUND_ID, 1, false)

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Serve " .. self.ActiveOrder.Name
    prompt.ObjectText = "Customer"
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 10
    prompt.HoldDuration = 0.2
    prompt.Parent = torso
    self.ActiveCustomerPrompt = prompt

    prompt.Triggered:Connect(function(player: Player)
        local heldItem = nil
        local character = player.Character
        if character then
            heldItem = character:FindFirstChild("Smoothie")
        end

        if not heldItem and player:FindFirstChild("Backpack") then
            heldItem = player.Backpack:FindFirstChild("Smoothie")
        end

        local isCorrect = self:ServeCheck(player, heldItem)
        if not isCorrect then
            dialogueSound:Play()
            text.Text = "Wrong smoothie!"
            task.delay(1.2, function()
                text.Text = "Need a " .. self.ActiveOrder.Name
            end)
            return
        end

        if heldItem then
            heldItem:Destroy()
        end

        player:SetAttribute("HasSmoothie", false)
        player:SetAttribute("CurrentSmoothieName", "")
        local payout = TycoonService.AddCash(player, self.ActiveOrder.Pay)

        text.Text = "Cash +$" .. tostring(self.ActiveOrder.Pay)
        prompt.ActionText = "Thanks!"

        counterGlow.Rate = 30
        counterGlow:Emit(20)
        dialogueSound:Play()
        successSound:Play()

        task.delay(1.2, function()
            text.Text = "Need a " .. self.ActiveOrder.Name
            prompt.ActionText = "Serve " .. self.ActiveOrder.Name
            counterGlow.Rate = 0
        end)

        task.delay(3, function()
            self:RefreshOrder()
        end)
    end)

    self.ActiveCustomer = customerModel
    return customerModel
end

function CustomerService.Init()
    CustomerService:CreateCustomer()
end

return CustomerService
