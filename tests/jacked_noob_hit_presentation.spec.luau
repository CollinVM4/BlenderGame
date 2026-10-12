-- Presentation boundary: real reaction module, deterministic audio/tweens/timers.
env.Enum.EasingStyle = { Back = "Back" }
env.Enum.EasingDirection = { Out = "Out" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
services.TweenService = {
    Create = function(_, object, _, properties)
        return {
            Play = function()
                for key, value in properties do
                    object[key] = value
                end
            end,
        }
    end,
}
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Run = callback })
end
local function advance(seconds)
    now += seconds
    local pending = timers
    timers = {}
    for _, timer in pending do
        if timer.At <= now then
            timer.Run()
        else
            table.insert(timers, timer)
        end
    end
end
local plays = 0
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "Sound" then
        object.Stop = function() end
        object.Play = function()
            plays += 1
        end
    end
    return object
end
local rig = instance("Model")
rig.Parent = workspaceFake
local head = instance("Part")
head.Name, head.Parent = "Head", rig
local reaction = loadModule("JackedNoobHitReaction")
local config = loadModule("JackedNoob")
reaction.Play(head)
local gui = head:FindFirstChild("JackedNoobHitReaction")
local text = gui:FindFirstChildWhichIsA("TextLabel")
local sound = head:FindFirstChild("JackedNoobHurt")
check(text.Text == "HEY STOP THAT" and text.Font == env.Enum.Font.FredokaOne, "exact hurt dialogue uses Fredoka")
check(
    text.TextColor3.R == 1 and text:FindFirstChild("DialogueOutline").Thickness >= 2,
    "hurt lettering is white with a readable outline"
)
check(gui.Adornee == head and gui.Parent == head and gui.AlwaysOnTop, "bubble follows NPC head")
check(
    sound.Parent == head
        and sound.SoundId == config.HurtSoundId
        and plays == 1
        and sound.RollOffMaxDistance == 50
        and sound.Volume == 0.7,
    "noticeable spatial hurt sound reuses asset"
)
advance(0.1)
reaction.Play(head)
local replacement = head:FindFirstChild("JackedNoobHitReaction")
check(gui.Destroyed and replacement ~= gui and plays == 1, "rapid repeat replaces bubble without sound spam")
advance(config.HitReactionCooldownSeconds)
reaction.Play(head)
check(replacement.Destroyed and plays == 2, "cooldown permits sound replay without stacked bubble")
local last = head:FindFirstChild("JackedNoobHitReaction")
advance(config.HitDialogueSeconds - 0.3)
check(
    not last.Destroyed and last:FindFirstChildWhichIsA("TextLabel").TextTransparency == 1,
    "current reaction fades near two seconds"
)
advance(0.3)
check(last.Destroyed, "reaction expires after two seconds")
reaction.Play(head)
local dyingBubble = head:FindFirstChild("JackedNoobHitReaction")
reaction.Clear()
check(dyingBubble.Destroyed and sound.Destroyed, "lifecycle clear removes UI and audio")
local newHead = instance("Part")
newHead.Parent = rig
reaction.Play(newHead)
check(newHead:FindFirstChild("JackedNoobHurt") ~= sound, "respawn receives fresh spatial audio")
advance(config.HitDialogueSeconds)
check(
    not newHead:FindFirstChild("JackedNoobHitReaction").Destroyed,
    "old callbacks cannot delete the replacement reaction before its fade completes"
)
advance(0.3)
reaction.Clear()
