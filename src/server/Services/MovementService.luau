--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local RunService = game:GetService("RunService")
local Upgrades = require(Shared.Constants.Upgrades)
local SprintConfig = require(Shared.Constants.SprintConfig)
local MovementService = {}
local data: any
type Stats = { BaseWalkSpeed: number, SprintWalkSpeed: number, MaxStamina: number, JumpPower: number }
local resolved: { [Player]: Stats } = {}
local overrides: { [Player]: { [string]: number? } } = {}
local changed = Instance.new("BindableEvent")
MovementService.Changed = changed.Event

function MovementService.Init(dependencies)
    data = dependencies.PlayerDataService
end

function MovementService.GetBaseWalkSpeed(player: Player): number
    return resolved[player].BaseWalkSpeed
end
function MovementService.GetSprintWalkSpeed(player: Player): number
    return resolved[player].SprintWalkSpeed
end
function MovementService.GetMaxStamina(player: Player): number
    return resolved[player].MaxStamina
end
function MovementService.GetJumpPower(player: Player): number
    return resolved[player].JumpPower
end

local function applyJump(player: Player, humanoid: Humanoid)
    local power = MovementService.GetJumpPower(player)
    if humanoid.UseJumpPower then
        humanoid.JumpPower = power
    else
        humanoid.JumpHeight = power * power / (2 * workspace.Gravity)
    end
end

function MovementService.RefreshPlayer(player: Player)
    local speedIndex = data.GetUpgrade(player, "MovementSpeed")
    local jumpIndex = data.GetUpgrade(player, "Jump")
    local staminaIndex = data.GetUpgrade(player, "SprintStamina")
    local debugLevels: { [string]: number? } = overrides[player] or {}
    local effectiveSpeed = if debugLevels.MovementSpeed ~= nil then debugLevels.MovementSpeed + 1 else speedIndex
    local effectiveJump = if debugLevels.Jump ~= nil then debugLevels.Jump + 1 else jumpIndex
    local effectiveStamina = if debugLevels.SprintStamina ~= nil then debugLevels.SprintStamina + 1 else staminaIndex
    local speed = Upgrades.MovementSpeed[effectiveSpeed].Value
    resolved[player] = {
        BaseWalkSpeed = speed,
        SprintWalkSpeed = speed * SprintConfig.SPRINT_SPEED_MULTIPLIER,
        MaxStamina = Upgrades.SprintStamina[effectiveStamina].Value,
        JumpPower = Upgrades.Jump[effectiveJump].Value,
    }
    player:SetAttribute("MovementSpeedLevel", effectiveSpeed - 1)
    player:SetAttribute("JumpLevel", effectiveJump - 1)
    player:SetAttribute("SprintStaminaLevel", effectiveStamina - 1)
    player:SetAttribute("BaseWalkSpeed", speed)
    player:SetAttribute("SprintWalkSpeed", resolved[player].SprintWalkSpeed)
    player:SetAttribute("StaminaMax", resolved[player].MaxStamina)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        applyJump(player, humanoid)
    end
    changed:Fire(player)
end

-- Bootstrap owns the sole CharacterAdded connection. Never block its other resets.
function MovementService.ApplyCharacter(player: Player, character: Model)
    MovementService.RefreshPlayer(player)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        applyJump(player, humanoid)
    else
        task.spawn(function()
            local pending = character:WaitForChild("Humanoid", 5)
            if pending and pending:IsA("Humanoid") and player.Character == character and resolved[player] then
                applyJump(player, pending)
            end
        end)
    end
end

local function assertStudioServer()
    assert(RunService:IsServer() and RunService:IsStudio() and RunService:IsRunning(), "Studio Play server only")
end

function MovementService.SetStudioLevel(player: Player, track: string, level: number?)
    assertStudioServer()
    assert(track == "MovementSpeed" or track == "Jump" or track == "SprintStamina", "Invalid movement track")
    assert(
        level == nil or (type(level) == "number" and level >= 0 and level <= 3 and level == math.floor(level)),
        "Invalid displayed level; expected 0-3"
    )
    assert(resolved[player] ~= nil, "Movement player is not initialized")
    local levels = overrides[player] or {}
    levels[track] = level
    overrides[player] = levels
    if track == "Jump" then
        player:SetAttribute("StudioJumpTier", level)
    end
    MovementService.RefreshPlayer(player)
end

-- Pads and Command Bar commands share one jump override. Last setter wins.
function MovementService.SetStudioJumpTier(player: Player, tier: number?)
    assert(tier == nil or (tier >= 1 and tier <= 3 and tier == math.floor(tier)), "Invalid Studio jump tier")
    MovementService.SetStudioLevel(player, "Jump", tier)
end

function MovementService.ResetStudioOverrides(player: Player)
    assertStudioServer()
    overrides[player] = nil
    player:SetAttribute("StudioJumpTier", nil)
    MovementService.RefreshPlayer(player)
end

function MovementService.GetStudioSnapshot(player: Player)
    assertStudioServer()
    local result = table.clone(resolved[player])
    return result, table.clone(overrides[player] or {})
end

function MovementService.RemovePlayer(player: Player)
    resolved[player] = nil
    overrides[player] = nil
end
return require(script.Parent.StudioServices).Wrap("MovementService", MovementService)
