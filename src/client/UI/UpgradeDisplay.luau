--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Upgrades = require(Shared.Constants.Upgrades)
local SprintConfig = require(Shared.Constants.SprintConfig)

local Display = {}
Display.Tracks = {
    { Id = "MovementSpeed", Name = "MOVEMENT SPEED", Attribute = "BaseWalkSpeed" },
    { Id = "SprintStamina", Name = "SPRINT STAMINA", Attribute = "StaminaMax" },
    { Id = "Jump", Name = "JUMP", Attribute = "JumpLevel" },
}
local tiers: { [string]: { { Cost: number, Value: number } } } = {
    MovementSpeed = Upgrades.MovementSpeed,
    SprintStamina = Upgrades.SprintStamina,
    Jump = Upgrades.Jump,
}

function Display.Stat(id: string, value: number): string
    if id == "SprintStamina" then
        return string.format("%.0fs", value / SprintConfig.STAMINA_DRAIN_RATE)
    end
    return tostring(value)
end

function Display.Row(
    id: string,
    level: number?,
    current: number?
): { Level: number, Stat: string, Price: number?, Max: boolean }?
    local track = tiers[id]
    if not track or level == nil or level % 1 ~= 0 or not track[level + 1] then
        return nil
    end
    if id == "Jump" then
        current = track[level + 1].Value
    end
    if current == nil then
        return nil
    end
    local nextTier = track[level + 2]
    return {
        Level = level,
        Stat = Display.Stat(id, current) .. (if nextTier then " → " .. Display.Stat(id, nextTier.Value) else ""),
        Price = if nextTier then nextTier.Cost else nil,
        Max = nextTier == nil,
    }
end

function Display.Feedback(success: boolean, reason: string?): string
    if success then
        return "UPGRADED!"
    elseif reason == "InsufficientCash" then
        return "NOT ENOUGH CASH"
    elseif reason == "MaxLevel" then
        return "MAX"
    elseif reason == "InvalidUpgrade" then
        return "UNAVAILABLE"
    end
    return "PLEASE TRY AGAIN"
end

return Display
