--!strict
-- One presentation path for spawn, acquisition, serving and future server events.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Banner = require(script.Parent.Parent.UI.AnnouncementBanner)
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
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
        local surface = Banner.Create(playerGui, "RareIngredientAnnouncement")
        local banner = surface.Label
        local cue = Instance.new("Sound")
        cue.Name = "AnnouncementCue"
        cue.Volume = 0.35
        cue.Parent = SoundService
        local queue: { Format.Message } = {}
        local showing = false
        local function drain()
            while #queue > 0 do
                local message = assert(table.remove(queue, 1))
                local text = Format.VisibleText(message, workspace:GetServerTimeNow())
                if not text then
                    continue -- Expired countdowns must not replay after a backlog.
                end
                Banner.SetGlobalActive(true)
                surface.Show(text)
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
                    text = Format.VisibleText(message, workspace:GetServerTimeNow())
                    if text then
                        banner.Text = text
                    end
                until not text
                    or (message.CountdownEndsAt == nil and os.clock() >= holdUntil)
                    or Format.ShouldInterrupt(queue)
                surface.Exit()
                task.wait(0.18)
                surface.Hide()
            end
            Banner.SetGlobalActive(false)
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
