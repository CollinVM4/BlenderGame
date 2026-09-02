--!strict
local AudioService = {}

function AudioService.CreateCue(parent: Instance, soundId: string, volume: number, looped: boolean?): Sound
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.Looped = looped or false
    sound.RollOffMaxDistance = 50
    sound.RollOffMinDistance = 10
    sound.Parent = parent
    return sound
end

function AudioService.CreateBlendGroup(parent: Instance)
    local blendSound = AudioService.CreateCue(parent, "rbxassetid://365965609", 0, true)
    local dingSound = AudioService.CreateCue(parent, "rbxassetid://110253665387820", 1, false)
    local pourSound = AudioService.CreateCue(parent, "rbxassetid://9114612188", 1, false)
    local notReadySound = AudioService.CreateCue(parent, "rbxassetid://90524619811521", 1, false)
    local customerServeSound = AudioService.CreateCue(parent, "rbxassetid://135165335432475", 1, false)

    return {
        blendSound = blendSound,
        dingSound = dingSound,
        pourSound = pourSound,
        notReadySound = notReadySound,
        customerServeSound = customerServeSound,
    }
end

function AudioService.UpdateBlendGroup(group: { blendSound: Sound }, spinStrength: number)
    local targetVolume = math.clamp(spinStrength / 20, 0, 1)
    group.blendSound.Volume = targetVolume
    group.blendSound.PlaybackSpeed = 0.5 + (spinStrength / 25)
end

return AudioService
