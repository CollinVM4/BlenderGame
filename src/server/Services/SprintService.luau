--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SprintConfig = require(ReplicatedStorage.Shared.Constants.SprintConfig)
local getSprintEvent = require(ReplicatedStorage.Shared.Events.SprintEvents)

local SprintService = {}
local movement: any

local staminaCurrent: { [Player]: number } = {}
local staminaMax: { [Player]: number } = {}
local isSprinting: { [Player]: boolean } = {}

local function ensurePlayer(player: Player)
    if staminaMax[player] == nil then
        staminaMax[player] = movement.GetMaxStamina(player)
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

    local humanoid = getHumanoid(player)
    isSprinting[player] = wantsToSprint and humanoid ~= nil and humanoid.Health > 0
end

function SprintService.ApplySpeed(player: Player)
    local humanoid = getHumanoid(player)
    if humanoid then
        humanoid.WalkSpeed = if os.clock() < (tonumber(player:GetAttribute("StunnedUntil")) or 0)
            then 0
            elseif isSprinting[player] then movement.GetSprintWalkSpeed(player)
            else movement.GetBaseWalkSpeed(player)
    end
end

function SprintService.ResetCharacter(player: Player)
    ensurePlayer(player)
    isSprinting[player] = false
    staminaMax[player] = movement.GetMaxStamina(player)
    staminaCurrent[player] = staminaMax[player]
    player:SetAttribute("StaminaMax", staminaMax[player])
    player:SetAttribute("StaminaCurrent", staminaCurrent[player])
    player:SetAttribute("IsSprinting", false)
    SprintService.ApplySpeed(player)
end

-- Copy authoritative runtime values for server diagnostics; never read UI attributes.
function SprintService.GetSnapshot(player: Player)
    ensurePlayer(player)
    return {
        StaminaCurrent = staminaCurrent[player],
        StaminaMax = staminaMax[player],
        IsSprinting = isSprinting[player],
    }
end

function SprintService.RemovePlayer(player: Player)
    staminaCurrent[player] = nil
    staminaMax[player] = nil
    isSprinting[player] = nil
end

function SprintService.Init(dependencies)
    movement = dependencies.MovementService
    local sprintEvent = getSprintEvent()
    movement.Changed:Connect(function(player: Player)
        SprintService.SetStaminaMax(player, movement.GetMaxStamina(player))
        SprintService.ApplySpeed(player)
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

            local humanoid = getHumanoid(player)
            if not humanoid or humanoid.Health <= 0 then
                isSprinting[player] = false
            end
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

            player:SetAttribute("IsSprinting", isSprinting[player])
            SprintService.ApplySpeed(player)

            sprintEvent:FireClient(player, isSprinting[player], staminaCurrent[player], staminaMax[player])
        end
    end)
end

-- Extension point for future upgrades that increase a player's stamina capacity
function SprintService.SetStaminaMax(player: Player, newMax: number)
    assert(
        type(newMax) == "number" and newMax == newMax and newMax > 0 and newMax < math.huge,
        "Invalid stamina maximum"
    )
    ensurePlayer(player)
    local increase = math.max(0, newMax - staminaMax[player])
    staminaMax[player] = newMax
    staminaCurrent[player] = math.clamp(staminaCurrent[player] + increase, 0, newMax)
    player:SetAttribute("StaminaMax", staminaMax[player])
    player:SetAttribute("StaminaCurrent", staminaCurrent[player])
end

return require(script.Parent.StudioServices).Wrap("SprintService", SprintService)
