--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SprintConfig = require(ReplicatedStorage.Shared.Constants.SprintConfig)
local getSprintEvent = require(ReplicatedStorage.Shared.Events.SprintEvents)

local SprintService = {}

local staminaCurrent: { [Player]: number } = {}
local staminaMax: { [Player]: number } = {}
local isSprinting: { [Player]: boolean } = {}

local function ensurePlayer(player: Player)
    if staminaMax[player] == nil then
        staminaMax[player] = SprintConfig.BASE_STAMINA_MAX
    end
    if staminaCurrent[player] == nil then
        staminaCurrent[player] = staminaMax[player]
    end
    if isSprinting[player] == nil then
        isSprinting[player] = false
    end

    player:SetAttribute("StaminaMax", staminaMax[player])
    player:SetAttribute("StaminaCurrent", staminaCurrent[player])
end

local function getHumanoid(player: Player): Humanoid?
    local character = player.Character
    if character == nil then
        return nil
    end
    return character:FindFirstChildOfClass("Humanoid")
end

local function setSprinting(player: Player, wantsToSprint: boolean)
    ensurePlayer(player)

    if wantsToSprint and staminaCurrent[player] <= 0 then
        wantsToSprint = false
    end

    isSprinting[player] = wantsToSprint
end

function SprintService.Init()
    local sprintEvent = getSprintEvent()

    for _, player in Players:GetPlayers() do
        ensurePlayer(player)
    end

    Players.PlayerAdded:Connect(function(player)
        ensurePlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        staminaCurrent[player] = nil
        staminaMax[player] = nil
        isSprinting[player] = nil
    end)

    sprintEvent.OnServerEvent:Connect(function(player: Player, wantsToSprint: boolean)
        if type(wantsToSprint) ~= "boolean" then
            return
        end
        setSprinting(player, wantsToSprint)
    end)

    RunService.Heartbeat:Connect(function(deltaTime: number)
        for _, player in Players:GetPlayers() do
            ensurePlayer(player)

            if isSprinting[player] then
                staminaCurrent[player] =
                    math.max(0, staminaCurrent[player] - SprintConfig.STAMINA_DRAIN_RATE * deltaTime)
                if staminaCurrent[player] <= 0 then
                    isSprinting[player] = false
                end
            else
                staminaCurrent[player] =
                    math.min(staminaMax[player], staminaCurrent[player] + SprintConfig.STAMINA_REGEN_RATE * deltaTime)
            end

            player:SetAttribute("StaminaCurrent", staminaCurrent[player])

            local humanoid = getHumanoid(player)
            if humanoid then
                humanoid.WalkSpeed = if os.clock() < (player:GetAttribute("StunnedUntil") or 0)
                    then 0
                    else isSprinting[player]
                            and SprintConfig.WALK_SPEED_NORMAL * SprintConfig.SPRINT_SPEED_MULTIPLIER
                        or SprintConfig.WALK_SPEED_NORMAL
            end

            sprintEvent:FireClient(player, isSprinting[player], staminaCurrent[player], staminaMax[player])
        end
    end)
end

-- Extension point for future upgrades that increase a player's stamina capacity
function SprintService.SetStaminaMax(player: Player, newMax: number)
    ensurePlayer(player)
    staminaMax[player] = newMax
    staminaCurrent[player] = math.min(staminaCurrent[player], newMax)
    player:SetAttribute("StaminaMax", staminaMax[player])
    player:SetAttribute("StaminaCurrent", staminaCurrent[player])
end

return SprintService
