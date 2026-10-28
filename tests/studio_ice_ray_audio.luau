-- Run in EACH CLIENT Command Bar in a Studio Server & Clients session before firing.
-- Read-only probe; stops listening after 90 seconds. No audio is created by this probe.
local ContentProvider = game:GetService("ContentProvider")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceShotgunPresentationConfig)
task.spawn(function()
    local ok, err = pcall(function()
        ContentProvider:PreloadAsync(
            { Config.ShotSoundId, Config.FallbackSoundId, "rbxassetid://87015121" },
            function(id, status)
                print("[IceRay audio fetch]", id, status.Name)
            end
        )
    end)
    if not ok then
        warn("[IceRay audio fetch]", err)
    end
end)
local connection = workspace.DescendantAdded:Connect(function(object)
    if not object:IsA("Sound") then
        return
    end
    task.delay(0.1, function()
        if not object.Parent or not string.match(object.Name, "^IceRay") then
            return
        end
        local parent = object.Parent
        local position = if parent:IsA("Attachment")
            then parent.WorldPosition
            elseif parent:IsA("BasePart") then parent.Position
            else nil
        local camera = workspace.CurrentCamera
        print(
            "[IceRay actual audio]",
            object.Name,
            object.SoundId,
            "loaded",
            object.IsLoaded,
            "playing",
            object.Playing,
            "time",
            object.TimePosition,
            "volume",
            object.Volume,
            "rolloff",
            object.RollOffMode.Name,
            object.RollOffMinDistance,
            object.RollOffMaxDistance,
            "source",
            parent:GetFullName(),
            "listener distance",
            if camera and position then (camera.CFrame.Position - position).Magnitude else nil
        )
    end)
end)
task.delay(90, function()
    connection:Disconnect()
end)
print("[IceRay audio] Listening for 90 seconds; fire from both clients and compare actual playback with fetch status.")
