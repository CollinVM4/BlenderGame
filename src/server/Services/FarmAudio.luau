--!strict
local Debris = game:GetService("Debris")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.FarmConfig)
local Audio = require(script.Parent.AudioService)
local FarmAudio = {}

function FarmAudio.Play(soundId: string?, position: Vector3)
    if not soundId or soundId == "" then
        return
    end
    -- Independent emitter survives harvest destruction and never participates in physics.
    local emitter = Instance.new("Part")
    emitter.Name = "FarmSound"
    emitter.Size = Vector3.new(0.1, 0.1, 0.1)
    emitter.Anchored, emitter.Transparency = true, 1
    emitter.CanCollide, emitter.CanTouch, emitter.CanQuery = false, false, false
    emitter.Position = position
    local sound = Audio.ConstructAudioCue(emitter, soundId, Config.SoundVolume)
    sound.RollOffMaxDistance = Config.SoundRollOffMaxDistance
    emitter.Parent = workspace
    sound.Ended:Once(function()
        emitter:Destroy()
    end)
    Debris:AddItem(emitter, 30) -- Also cleans up invalid/unavailable assets.
    sound:Play()
end

return FarmAudio
