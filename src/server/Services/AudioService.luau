--!strict
local AudioService = {}
local BadCustomers = require(game:GetService("ReplicatedStorage").Shared.Constants.BadCustomers)

function AudioService.PlayBadCustomerCue(parent: Instance, cue: string)
    local config = (BadCustomers.Audio :: any)[cue]
    if not config then
        return
    end
    local sound = AudioService.ConstructAudioCue(parent, config.SoundId, config.Volume, false)
    sound.PlaybackSpeed = config.PlaybackSpeed
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 8)
end

local CUSTOMER_DIALOGUE_SOUND_ID = "rbxassetid://130763160561998"

function AudioService.ConstructAudioCue(parent: Instance, soundId: string, volume: number, looped: boolean?): Sound
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.Looped = looped or false
    sound.RollOffMaxDistance = 50
    sound.RollOffMinDistance = 10
    sound.Parent = parent
    return sound
end

function AudioService.PlayCustomerDialogue(sound: Sound?)
    if sound and sound.Parent and not sound.IsPlaying then
        sound:Play()
    end
end

function AudioService.CreateBlendGroup(parent: Instance): { [string]: Sound }
    local blendSound = AudioService.ConstructAudioCue(parent, "rbxassetid://365965609", 0, true)
    local dingSound = AudioService.ConstructAudioCue(parent, "rbxassetid://110253665387820", 1, false)
    local pourSound = AudioService.ConstructAudioCue(parent, "rbxassetid://9114612188", 1, false)
    local notReadySound = AudioService.ConstructAudioCue(parent, "rbxassetid://90524619811521", 1, false)
    local customerServeSound = AudioService.ConstructAudioCue(parent, "rbxassetid://135165335432475", 1, false)
    local dialogueSound = AudioService.ConstructAudioCue(parent, CUSTOMER_DIALOGUE_SOUND_ID, 1, false)
    dialogueSound.PlaybackSpeed = 1

    return {
        blendSound = blendSound,
        dingSound = dingSound,
        pourSound = pourSound,
        notReadySound = notReadySound,
        customerServeSound = customerServeSound,
        dialogueSound = dialogueSound,
    }
end

-- Dynamically adjust volume based on the blades RPM / blend strength.
function AudioService.UpdateBlendGroup(group: { blendSound: Sound }, blendStrength: number)
    local targetVolume = math.clamp(blendStrength / 20, 0, 1)
    group.blendSound.Volume = targetVolume
    group.blendSound.PlaybackSpeed = 0.5 + (blendStrength / 25)
end

return AudioService
