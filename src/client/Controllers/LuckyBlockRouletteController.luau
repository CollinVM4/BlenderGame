--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Config = require(ReplicatedStorage.Shared.Constants.LuckyBlockPresentation)
local PickupConfig = require(ReplicatedStorage.Shared.Constants.LuckyBlockConfig)
local Sequence = require(script.Parent.Parent.UI.LuckyBlockSequence)
local View = require(script.Parent.Parent.UI.LuckyBlockView)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    local localPlayer = Players.LocalPlayer
    local manager = Sequence.new(function(seconds, callback)
        local completed = false
        local timer = task.delay(seconds, function()
            completed = true
            callback()
        end)
        return function()
            if not completed then
                pcall(task.cancel, timer)
            end
        end
    end)
    local watches: { [Player]: { RBXScriptConnection } } = {}
    local lastId: { [Player]: number } = {}
    local function unwatch(player: Player)
        manager.Cancel(player)
        local connections: { RBXScriptConnection } = watches[player] or {}
        for _, connection in connections do
            connection:Disconnect()
        end
        watches[player] = nil
    end
    local function receive(player: Player, payload: any, full: boolean)
        if
            type(payload) ~= "table"
            or type(payload.RewardId) ~= "string"
            or not (Config.Rewards :: any)[payload.RewardId]
        then
            return
        end
        if type(payload.PickupId) ~= "number" or type(payload.PickedUpAt) ~= "number" then
            return
        end
        if typeof(payload.Position) ~= "Vector3" then
            return
        end
        if lastId[player] and payload.PickupId <= lastId[player] then
            return
        end
        lastId[player] = payload.PickupId
        unwatch(player)
        local character = player.Character
        if character ~= payload.Character or not character or not character:IsDescendantOf(workspace) then
            return
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            return
        end
        local age = workspace:GetServerTimeNow() - payload.PickedUpAt
        if age >= Config.RevealSeconds + Config.HoldSeconds + Config.FadeSeconds then
            return
        end
        local view =
            View.Create(payload.Position, if full then nil else payload.RewardId, payload.PickupId, payload.PickedUpAt)
        if not view then
            return
        end
        watches[player] = {
            humanoid.Died:Connect(function()
                if player.Character == character then
                    unwatch(player)
                end
            end),
            player.CharacterRemoving:Connect(function(removing)
                if removing == character then
                    unwatch(player)
                end
            end),
            character.AncestryChanged:Connect(function()
                if player.Character == character and not character:IsDescendantOf(workspace) then
                    unwatch(player)
                end
            end),
        }
        local destroy = view.Destroy
        function view.Destroy()
            destroy()
            local connections: { RBXScriptConnection } = watches[player] or {}
            for _, connection in connections do
                connection:Disconnect()
            end
            watches[player] = nil
        end
        manager.Start(player, payload.RewardId, full, view, workspace:GetServerTimeNow() - payload.PickedUpAt)
    end
    Players.PlayerRemoving:Connect(function(player)
        unwatch(player)
        lastId[player] = nil
    end)
    -- Independent listeners: a missing observer remote cannot stall collector feedback.
    task.spawn(function()
        local remote = ReplicatedStorage.Shared.Events:WaitForChild(PickupConfig.RewardEventName) :: RemoteEvent
        remote.OnClientEvent:Connect(function(payload)
            receive(localPlayer, payload, true)
        end)
    end)
    task.spawn(function()
        local remote = ReplicatedStorage.Shared.Events:WaitForChild(Config.NearbyEventName) :: RemoteEvent
        remote.OnClientEvent:Connect(function(payload: any)
            if type(payload) ~= "table" or type(payload.UserId) ~= "number" then
                return
            end
            local player = Players:GetPlayerByUserId(payload.UserId)
            if player and player ~= localPlayer then
                receive(player, payload, false)
            end
        end)
    end)
    task.spawn(function()
        local tickSound, popSound = Instance.new("Sound"), Instance.new("Sound")
        tickSound.SoundId, popSound.SoundId = Config.TickSoundId, Config.PopSoundId
        local assets: { Instance } = { tickSound, popSound }
        local folder = ReplicatedStorage:FindFirstChild(Config.VisualFolderName)
        if folder then
            table.insert(assets, folder)
        end
        pcall(function()
            ContentProvider:PreloadAsync(assets)
        end)
        tickSound:Destroy()
        popSound:Destroy()
    end)
end

return Controller
