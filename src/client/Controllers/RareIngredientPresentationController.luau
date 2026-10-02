--!strict
-- One presentation path for spawn, acquisition, serving and future server events.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared.Constants.DialogueTextStyle)
local Format = require(Shared.AnnouncementFormat)
local Controller = {}
local started = false
local sounds = { Mystery = "rbxassetid://110253665387820" } -- Existing blender-ready ding.

function Controller.Init()
    if started then
        return
    end
    started = true
    task.spawn(function()
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local remote = Shared:WaitForChild("Events"):WaitForChild("RareIngredientSpawned")
        assert(remote:IsA("RemoteEvent"), "RareIngredientSpawned must be a RemoteEvent")
        local gui = Instance.new("ScreenGui")
        gui.Name = "RareIngredientAnnouncement"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = false
        gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
        gui.DisplayOrder = 20
        gui.Parent = playerGui
        local banner = Instance.new("TextLabel")
        banner.Name = "Announcement"
        banner.AnchorPoint = Vector2.new(0.5, 0)
        local resting = UDim2.fromScale(0.5, 0.065)
        banner.Position = resting
        banner.Size = UDim2.new(0.92, 0, 0, 104)
        banner.BackgroundTransparency = 1
        Style.Apply(banner, 32)
        banner.TextWrapped = true
        banner.TextScaled = true
        banner.RichText = true
        banner.Visible = false
        banner.Parent = gui
        local width = Instance.new("UISizeConstraint")
        width.MaxSize = Vector2.new(780, 104)
        width.Parent = banner
        local textSize = Instance.new("UITextSizeConstraint")
        textSize.MinTextSize = 18
        textSize.MaxTextSize = 32
        textSize.Parent = banner
        local stroke = Style.Outline(banner)
        local scale = Instance.new("UIScale")
        scale.Parent = banner
        local cue = Instance.new("Sound")
        cue.Name = "AnnouncementCue"
        cue.Volume = 0.35
        cue.Parent = SoundService
        local queue: { Format.Message } = {}
        local showing = false
        local function drain()
            while #queue > 0 do
                local message = assert(table.remove(queue, 1))
                banner.Text = message.Text
                banner.Position = resting - UDim2.fromOffset(0, 14)
                banner.TextTransparency = 1
                stroke.Transparency = 1
                scale.Scale = 0.93
                banner.Visible = true
                local enter = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                TweenService:Create(banner, enter, { Position = resting, TextTransparency = 0 }):Play()
                TweenService:Create(scale, enter, { Scale = 1 }):Play()
                TweenService:Create(stroke, TweenInfo.new(0.16), { Transparency = 0 }):Play()
                local soundId = if message.SoundType then sounds[message.SoundType] else nil
                if soundId then
                    cue.SoundId = soundId
                    cue:Play()
                    task.delay(1.5, function()
                        cue:Stop()
                    end)
                end
                local holdUntil = os.clock() + 0.24 + message.Duration
                repeat
                    task.wait(0.1)
                until os.clock() >= holdUntil or Format.ShouldInterrupt(queue)
                local exit = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                TweenService
                    :Create(banner, exit, { Position = resting - UDim2.fromOffset(0, 10), TextTransparency = 1 })
                    :Play()
                TweenService:Create(stroke, exit, { Transparency = 1 }):Play()
                task.wait(0.18)
                banner.Visible = false
            end
            showing = false
        end
        remote.OnClientEvent:Connect(function(payload: any)
            local message = Format.Build(payload)
            if not message then
                return
            end
            Format.Enqueue(queue, message)
            if not showing then
                showing = true
                task.spawn(drain)
            end
        end)
    end)
end

return Controller
