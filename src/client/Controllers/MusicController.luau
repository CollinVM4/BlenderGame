--!strict
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.MusicPresentation)
local Controller = {}
local enabled = Config.DefaultEnabled
local volume = Config.DefaultVolume
local started = false
local sound: Sound? = nil
local index = 1

function Controller.IsEnabled(): boolean
    return enabled
end

function Controller.GetVolume(): number
    return volume
end

function Controller.SetEnabled(value: boolean)
    if type(value) ~= "boolean" then
        return
    end
    enabled = value
    Players.LocalPlayer:SetAttribute("MusicEnabled", enabled)
    if sound then
        if enabled then
            sound:Resume()
        else
            sound:Pause()
        end
    end
end

function Controller.SetVolume(value: number)
    if type(value) ~= "number" or value ~= value then
        return
    end
    volume = math.clamp(value, 0, 1)
    Players.LocalPlayer:SetAttribute("MusicVolume", volume)
    if sound then
        sound.Volume = volume
    end
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local savedEnabled = player:GetAttribute("MusicEnabled")
    local savedVolume = player:GetAttribute("MusicVolume")
    Controller.SetEnabled(if type(savedEnabled) == "boolean" then savedEnabled else Config.DefaultEnabled)
    Controller.SetVolume(if type(savedVolume) == "number" then savedVolume else Config.DefaultVolume)
    if #Config.TrackIds == 0 then
        if RunService:IsStudio() then
            warn("MusicController: empty TrackIds; music playback is inert until assets are configured")
        end
        return
    end
    local playing = Instance.new("Sound")
    playing.Name = "BackgroundMusic"
    playing.Looped = true
    playing.Volume = volume
    playing.SoundId = Config.TrackIds[index]
    playing.Parent = SoundService
    sound = playing
    local function advance()
        index = index % #Config.TrackIds + 1
        playing.SoundId = Config.TrackIds[index]
        playing.TimePosition = 0
        playing:Play()
        if not enabled then
            playing:Pause()
        end
    end
    playing.Ended:Connect(advance)
    -- Looped sounds emit DidLoop rather than Ended in Roblox.
    playing.DidLoop:Connect(function()
        if #Config.TrackIds > 1 then
            advance()
        end
    end)
    playing:Play()
    if not enabled then
        playing:Pause()
    end
end

return Controller
