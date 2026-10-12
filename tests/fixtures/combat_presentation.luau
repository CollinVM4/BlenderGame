-- Client engine boundary. Real controllers; no claims about native rendering/audio.
local statusSignals = {}
local presentationNew = env.Instance.new
local emitted, playedSounds = {}, {}
env.Instance.new = function(class)
    local object = presentationNew(class)
    object.CharacterAdded = signal()
    statusSignals[object] = {}
    function object:GetAttributeChangedSignal(name)
        statusSignals[self][name] = statusSignals[self][name] or signal()
        return statusSignals[self][name]
    end
    local setAttribute = object.SetAttribute
    function object:SetAttribute(name, value)
        local changed = self:GetAttribute(name) ~= value
        setAttribute(self, name, value)
        if changed then
            self:GetAttributeChangedSignal(name):Fire()
        end
    end
    function object:Play()
        table.insert(playedSounds, self.SoundId)
    end
    function object:Emit(amount)
        self.EmittedCount = (self.EmittedCount or 0) + amount
        table.insert(emitted, { Emitter = self, Count = amount })
    end
    return object
end
env.CFrame.fromMatrix = function(position, right, up, back)
    local result = frame(position)
    result.RightVector, result.UpVector, result.LookVector = right, up, back * -1
    return result
end
env.NumberSequence = {
    new = function(keys)
        return keys
    end,
}
env.NumberSequenceKeypoint = {
    new = function(time, value)
        return { Time = time, Value = value }
    end,
}
env.TweenInfo = {
    new = function(seconds)
        return { Time = seconds }
    end,
}
env.Enum.Material = { Glass = "Glass", Neon = "Neon" }
env.Enum.NormalId = { Front = "Front" }
env.Enum.PartType = { Ball = "Ball" }
env.Enum.EasingStyle, env.Enum.EasingDirection = { Quad = "Quad" }, { Out = "Out" }
env.Enum.HighlightDepthMode = { Occluded = "Occluded" }
env.Enum.PreferredInput = { Touch = "Touch", KeyboardAndMouse = "KeyboardAndMouse" }
env.Enum.AssetFetchStatus = { Success = "Success", Failure = "Failure" }
services.TweenService = {
    Create = function(_, object, info, properties)
        return {
            Play = function()
                env.task.delay(info.Time, function()
                    if not object.Destroyed then
                        for key, value in properties do
                            object[key] = value
                        end
                    end
                end)
            end,
        }
    end,
}
local preloadMode = "failure"
services.ContentProvider = {
    PreloadAsync = function(_, assets, callback)
        if preloadMode == "error" then
            error("asset permissions unavailable")
        end
        for _, asset in assets do
            callback(asset, if preloadMode == "success" then "Success" else "Failure")
        end
    end,
}
services.UserInputService = { PreferredInput = "KeyboardAndMouse" }
services.Players.PlayerAdded, services.Players.PlayerRemoving = signal(), signal()
workspaceFake.CurrentCamera = { CFrame = frame(0, 1, 0) }
workspaceFake.GetChildren = function(self)
    local children = {}
    for _, object in allInstances do
        if object.Parent == self then
            table.insert(children, object)
        end
    end
    return children
end
-- Exercise real Unix server timestamps and large Roblox UserIds, unlike the small gameplay fixture clock.
workspaceFake.GetServerTimeNow = function()
    return 1791820800 + now
end
local resultRemote = env.Instance.new("RemoteEvent")
resultRemote.Name, resultRemote.Parent, resultRemote.OnClientEvent = "IceShotgunResult", shared.Events, signal()
function shared.Events:WaitForChild(name)
    return self:FindFirstChild(name)
end
local localPlayer, localH = fighter("A")
localPlayer.UserId = 2022020489
services.Players.LocalPlayer = localPlayer
local playerGui = env.Instance.new("PlayerGui")
playerGui.Parent = localPlayer
local presentationConfig = loadModule("IceShotgunPresentationConfig")
local function childrenNamed(parent, name)
    local result = {}
    for _, child in parent:GetChildren() do
        if child.Name == name then
            table.insert(result, child)
        end
    end
    return result
end
