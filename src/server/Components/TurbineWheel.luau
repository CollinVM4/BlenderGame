local TurbineWheel = {}
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Import the config
local Recipes = require(ReplicatedStorage.Shared.Constants.Recipes)

function TurbineWheel.Init()
    local turbineRoot = workspace:WaitForChild("Blender"):WaitForChild("Turbine")
    local turbineAssembly = turbineRoot:FindFirstChild("turbine") or turbineRoot
    local spinningPart = turbineAssembly:FindFirstChild("blade") or turbineAssembly:WaitForChild("stem")
    local dispenseButton = workspace:WaitForChild("Blender"):WaitForChild("DispenseButton")

    -- Mock active order (later, get this from your CustomerService)
    local activeRecipe = Recipes["Fruit Smoothie"]
    local blendProgress = 0
    local targetProgress = activeRecipe.RequiredProgress
    local hasDinged = false
    local labelOverrideUntil = 0

    -- 1. Setup Audio
    local blendSound = Instance.new("Sound")
    blendSound.SoundId = "rbxassetid://365965609" -- Replace with your blending SFX
    blendSound.Looped = true
    blendSound.Volume = 0
    blendSound.RollOffMaxDistance = 50
    blendSound.RollOffMinDistance = 10
    blendSound.Parent = spinningPart
    blendSound:Play()

    local dingSound = Instance.new("Sound")
    dingSound.SoundId = "rbxassetid://110253665387820"
    dingSound.Looped = false
    dingSound.Volume = 1
    dingSound.RollOffMaxDistance = 50
    dingSound.RollOffMinDistance = 10
    dingSound.Parent = spinningPart

    local pourSound = Instance.new("Sound")
    pourSound.SoundId = "rbxassetid://9114612188"
    pourSound.Looped = false
    pourSound.Volume = 1
    pourSound.RollOffMaxDistance = 50
    pourSound.RollOffMinDistance = 10
    pourSound.Parent = spinningPart

    local notReadySound = Instance.new("Sound")
    notReadySound.SoundId = "rbxassetid://90524619811521"
    notReadySound.Looped = false
    notReadySound.Volume = 1
    notReadySound.RollOffMaxDistance = 50
    notReadySound.RollOffMinDistance = 10
    notReadySound.Parent = spinningPart

    -- 2. Setup Particles
    local splashParticles = Instance.new("ParticleEmitter")
    splashParticles.Color = ColorSequence.new(activeRecipe.Color)
    splashParticles.Rate = 0
    splashParticles.Speed = NumberRange.new(5, 10)
    splashParticles.Parent = spinningPart

    -- 3. Setup UI (Kept from MVP for visual testing)
    local debugGui = Instance.new("BillboardGui", spinningPart)
    debugGui.Size = UDim2.fromOffset(140, 22)
    debugGui.StudsOffset = Vector3.new(0, 4, 0)
    debugGui.AlwaysOnTop = true

    local background = Instance.new("Frame", debugGui)
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(22, 22, 22)

    local fill = Instance.new("Frame", background)
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = activeRecipe.Color

    local failFlash = Instance.new("Frame", background)
    failFlash.Size = UDim2.fromScale(1, 1)
    failFlash.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
    failFlash.BackgroundTransparency = 1
    failFlash.BorderSizePixel = 0
    failFlash.ZIndex = 2

    local label = Instance.new("TextLabel", debugGui)
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 12
    label.Text = "0%"

    local dispensePrompt = Instance.new("ProximityPrompt")
    dispensePrompt.ActionText = "Dispense Smoothie"
    dispensePrompt.ObjectText = "Blender"
    dispensePrompt.Parent = dispenseButton

    dispensePrompt.Triggered:Connect(function(player)
        if blendProgress >= targetProgress then
            blendProgress = 0
            hasDinged = false
            labelOverrideUntil = 0
            fill.Size = UDim2.new(0, 0, 1, 0)
            label.Text = "0%"
            pourSound:Play()

            local backpack = player:FindFirstChild("Backpack") or player:FindFirstChildOfClass("Backpack")
            local smoothieTool = ServerStorage:FindFirstChild("Smoothie")

            if smoothieTool and backpack then
                local smoothieClone = smoothieTool:Clone()
                smoothieClone.Parent = backpack
            end
        else
            label.Text = "NOT READY!"
            labelOverrideUntil = os.clock() + 1
            fill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
            failFlash.BackgroundTransparency = 0.45
            notReadySound:Play()

            task.delay(0.2, function()
                fill.BackgroundColor3 = activeRecipe.Color
                failFlash.BackgroundTransparency = 1
            end)
        end
    end)

    -- 4. The Core Loop
    RunService.Heartbeat:Connect(function()
        local magnitude = spinningPart.AssemblyAngularVelocity.Magnitude
        local clampedVelocity = math.clamp(magnitude, 0, 50)

        if labelOverrideUntil > 0 and os.clock() >= labelOverrideUntil then
            labelOverrideUntil = 0
        end

        if blendProgress < targetProgress then
            -- Advance progress
            blendProgress += clampedVelocity * 0.05

            -- Scale SFX and VFX dynamically with speed
            blendSound.Volume = math.clamp(clampedVelocity / 20, 0, 1)
            blendSound.PlaybackSpeed = 0.5 + (clampedVelocity / 25)
            splashParticles.Rate = clampedVelocity * 2
        else
            -- Blend Complete State
            blendProgress = targetProgress
            blendSound.Volume = 0
            splashParticles.Rate = 0

            if not hasDinged then
                dingSound:Play()
                hasDinged = true
            end

            if labelOverrideUntil == 0 then
                label.Text = "READY TO DISPENSE!"
            end
        end

        -- Update UI Math based on dynamic recipe target
        local progressRatio = math.clamp(blendProgress / targetProgress, 0, 1)
        fill.Size = UDim2.new(progressRatio, 0, 1, 0)

        if blendProgress < targetProgress and labelOverrideUntil == 0 then
            label.Text = string.format("%.1f%%", (blendProgress / targetProgress) * 100)
        end

        if blendProgress >= targetProgress then
            dispensePrompt.ActionText = "Dispense Smoothie"
        else
            dispensePrompt.ActionText = "Not Ready"
        end
    end)
end

return TurbineWheel