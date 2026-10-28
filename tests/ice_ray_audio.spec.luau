-- Exercise real freeze/thaw effects with a minimal engine/audio boundary.
local bank = env.Instance.new("Folder")
bank.Name, bank.Parent = "IceGunEffects", storage
storage.WaitForChild = storage.FindFirstChild
local block = env.Instance.new("Part")
block.Name, block.Parent = "IceBlock", bank
local mesh = env.Instance.new("SpecialMesh")
mesh.Scale, mesh.Parent = vec(1, 1, 1), block
local folder = env.Instance.new("Folder")
folder.Name, folder.Parent = "FreezeEffects", bank
local originalFrame = frame
frame = function(...)
    local result = originalFrame(...)
    getmetatable(result).__add = function(at, offset)
        return frame(at.Position + offset)
    end
    return result
end
env.CFrame.Angles = function()
    return frame()
end
local clips = {}
local function once(event)
    event.Once = function(self, callback)
        local connection
        connection = self:Connect(function(...)
            connection:Disconnect()
            callback(...)
        end)
        return connection
    end
    return event
end
for _, name in { "IceCrack", "Shatter" } do
    local template = env.Instance.new("Sound")
    template.Name, template.Parent = name, folder
    template.Clone = function()
        local clip = env.Instance.new("Sound")
        clip.Ended = once(signal())
        once(clip.Destroying)
        table.insert(clips, clip)
        return clip
    end
end
local effects = loadModule("IceGunEffects")
local targets = {}
for i = 1, 6 do
    local player = fighter("B")
    local torso = env.Instance.new("Part")
    torso.Name, torso.Parent, torso.Position = "UpperTorso", player.Character, vec(i, 0, 0)
    table.insert(targets, player)
    effects.Freeze(player.Character)
end
local total = 0
for _, clip in clips do
    total += clip.Volume
    check(clip.Parent.Name == "UpperTorso" and clip.Name == "IceRayFreeze", "freeze audio follows victim")
    check(
        clip.RollOffMode == "InverseTapered" and clip.RollOffMinDistance == 6 and clip.RollOffMaxDistance == 60,
        "freeze audio has explicit bounded attenuation"
    )
end
check(total <= presentationConfig.FreezeVolume + 0.000001, "six simultaneous freezes share one quiet volume budget")
for _, clip in table.clone(clips) do
    clip.Ended:Fire()
end
clips = {}
for _, player in targets do
    effects.ClearFreeze(player.Character, true)
end
total = 0
for _, clip in clips do
    total += clip.Volume
    check(clip.Parent.Name == "HumanoidRootPart" and clip.Name == "IceRayThaw", "thaw audio follows recovered victim")
end
check(total <= presentationConfig.ThawVolume + 0.000001, "six simultaneous thaws share a softer volume budget")
for _, clip in table.clone(clips) do
    clip.Ended:Fire()
end
clips = {}
effects.Freeze(targets[1].Character)
check(clips[1].Volume == presentationConfig.FreezeVolume, "finished voices release the audio budget")
effects.ClearFreeze(targets[1].Character, false)
check(clips[1].Destroyed, "early freeze cancellation stops its attached audio")
print("PASS: Ice Ray positional freeze/thaw audio and simultaneous voice budget")
