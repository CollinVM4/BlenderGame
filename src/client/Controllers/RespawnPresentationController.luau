--!strict
-- Lightweight full-screen "RESPAWNING..." countdown. Purely cosmetic; the
-- server (Players.RespawnTime) is the sole authority on when respawn happens.
local Players = game:GetService("Players")
local RespawnConfig = require(game:GetService("ReplicatedStorage").Shared.Constants.RespawnConfig)
local Controller = {}
local started = false

local ink = Color3.fromRGB(245, 248, 255)
local backdrop = Color3.fromRGB(12, 14, 20)

local function build(): (ScreenGui, TextLabel, TextLabel)
    local screen = Instance.new("ScreenGui")
    screen.Name = "RespawnGui"
    screen.ResetOnSpawn = false
    screen.DisplayOrder = 100
    screen.IgnoreGuiInset = true
    screen.Enabled = false

    local backgroundFrame = Instance.new("Frame")
    backgroundFrame.Name = "Backdrop"
    backgroundFrame.Size = UDim2.fromScale(1, 1)
    backgroundFrame.BackgroundColor3 = backdrop
    backgroundFrame.BackgroundTransparency = 0.15
    backgroundFrame.BorderSizePixel = 0
    backgroundFrame.Parent = screen

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.42)
    title.Size = UDim2.fromScale(0.8, 0.12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextColor3 = ink
    title.Text = "RESPAWNING..."
    title.Parent = backgroundFrame

    local countdown = Instance.new("TextLabel")
    countdown.Name = "Countdown"
    countdown.AnchorPoint = Vector2.new(0.5, 0.5)
    countdown.Position = UDim2.fromScale(0.5, 0.56)
    countdown.Size = UDim2.fromScale(0.3, 0.16)
    countdown.BackgroundTransparency = 1
    countdown.Font = Enum.Font.GothamBold
    countdown.TextScaled = true
    countdown.TextColor3 = ink
    countdown.Text = tostring(math.ceil(RespawnConfig.RespawnDelaySeconds))
    countdown.Parent = backgroundFrame

    return screen, title, countdown
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local screen, _title, countdown = build()
    screen.Parent = playerGui
    local activeThread: thread? = nil

    local function stopCountdown()
        if activeThread then
            task.cancel(activeThread)
            activeThread = nil
        end
        screen.Enabled = false
    end

    local function startCountdown()
        stopCountdown()
        screen.Enabled = true
        activeThread = task.spawn(function()
            local remaining = math.ceil(RespawnConfig.RespawnDelaySeconds)
            while remaining > 0 do
                countdown.Text = tostring(remaining)
                task.wait(1)
                remaining -= 1
            end
        end)
    end

    local function onCharacterAdded(character: Model)
        stopCountdown()
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid and humanoid:IsA("Humanoid") then
            humanoid.Died:Connect(startCountdown)
        end
    end

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

return Controller
