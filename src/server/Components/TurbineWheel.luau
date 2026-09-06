--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AudioService = require(script.Parent.Parent.Services.AudioService)
local PhysicsService = require(script.Parent.Parent.Services.PhysicsService)
local Recipes = require(ReplicatedStorage.Shared.Constants.Recipes)

local TurbineWheel = {}

local function findBlenderRoots()
    local blenderRoots = {}

    local plotsFolder = workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in ipairs(plotsFolder:GetChildren()) do
            local blender = plot:FindFirstChild("Blender")
            if blender then
                table.insert(blenderRoots, blender)
            end
        end
    end

    local directBlender = workspace:FindFirstChild("Blender")
    if directBlender and not table.find(blenderRoots, directBlender) then
        table.insert(blenderRoots, directBlender)
    end

    if #blenderRoots == 0 then
        table.insert(blenderRoots, workspace:WaitForChild("Plots"):WaitForChild("Plot1"):WaitForChild("Blender"))
    end

    return blenderRoots
end

function TurbineWheel.Init()
    for _, blenderRoot in ipairs(findBlenderRoots()) do
        local turbineRoot = blenderRoot:WaitForChild("Turbine")
        local turbineAssembly = turbineRoot:FindFirstChild("turbine") or turbineRoot
        local spinningPart = turbineAssembly:FindFirstChild("blade") or turbineAssembly:WaitForChild("stem")
        local dispenseButton = blenderRoot:WaitForChild("DispenseButton")

        local activeRecipe = Recipes["Fruit Smoothie"]
        local blendProgress = 0
        local targetProgress = activeRecipe.RequiredProgress
        local hasDinged = false
        local labelOverrideUntil = 0

        local blendAudio = AudioService.CreateBlendGroup(spinningPart)
        blendAudio.blendSound:Play()

        local splashParticles = Instance.new("ParticleEmitter")
        splashParticles.Color = ColorSequence.new(activeRecipe.Color)
        splashParticles.Rate = 0
        splashParticles.Speed = NumberRange.new(5, 10)
        splashParticles.Parent = spinningPart

        local debugGui = Instance.new("BillboardGui", spinningPart)
        debugGui.Size = UDim2.fromOffset(200, 28)
        debugGui.StudsOffset = Vector3.new(0, 4, 0)
        debugGui.AlwaysOnTop = true
        debugGui.MaxDistance = 80

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

        dispensePrompt.Triggered:Connect(function(player: Player)
            if blendProgress >= targetProgress then
                blendProgress = 0
                hasDinged = false
                labelOverrideUntil = 0
                fill.Size = UDim2.new(0, 0, 1, 0)
                label.Text = "0%"
                blendAudio.pourSound:Play()

                local backpack = player:FindFirstChild("Backpack") or player:FindFirstChildOfClass("Backpack")
                local smoothieTool = ServerStorage:FindFirstChild("Smoothie")

                if smoothieTool and backpack then
                    local smoothieClone = smoothieTool:Clone()
                    smoothieClone.Name = "Smoothie"
                    smoothieClone:SetAttribute("RecipeName", "Fruit Smoothie")
                    smoothieClone:SetAttribute("IsFinished", true)
                    smoothieClone.Parent = backpack
                    player:SetAttribute("HasSmoothie", true)
                    player:SetAttribute("CurrentRecipeName", "Fruit Smoothie")
                end
            else
                label.Text = "NOT READY!"
                labelOverrideUntil = os.clock() + 1
                fill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
                failFlash.BackgroundTransparency = 0.45
                blendAudio.notReadySound:Play()

                task.delay(0.2, function()
                    fill.BackgroundColor3 = activeRecipe.Color
                    failFlash.BackgroundTransparency = 1
                end)
            end
        end)

        RunService.Heartbeat:Connect(function()
            local camera = workspace.CurrentCamera
            local guiScale = 1
            if camera then
                local distance = (camera.CFrame.Position - spinningPart.Position).Magnitude
                guiScale = math.clamp(1 - (distance / 80), 0.45, 1)
                debugGui.StudsOffset = Vector3.new(0, 4 + math.clamp(distance * 0.02, 0, 1.5), 0)
            end

            debugGui.Enabled = true
            debugGui.Size = UDim2.fromOffset(200 * guiScale, 28 * guiScale)

            local spinStrength = PhysicsService.GetSpinStrength(spinningPart)

            if labelOverrideUntil > 0 and os.clock() >= labelOverrideUntil then
                labelOverrideUntil = 0
            end

            if blendProgress < targetProgress then
                blendProgress += PhysicsService.GetBlendDelta(spinningPart)
                AudioService.UpdateBlendGroup(blendAudio, spinStrength)
                splashParticles.Rate = spinStrength * 2
            else
                blendProgress = targetProgress
                splashParticles.Rate = 0
                AudioService.UpdateBlendGroup(blendAudio, 0)

                if not hasDinged then
                    blendAudio.dingSound:Play()
                    hasDinged = true
                end

                if labelOverrideUntil == 0 then
                    label.Text = "READY TO DISPENSE!"
                end
            end

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
end

return TurbineWheel