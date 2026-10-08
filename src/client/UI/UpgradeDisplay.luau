--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Upgrades = require(Shared.Constants.Upgrades)

local Display = {}
Display.Tracks = {
    { Id = "CarryCapacity", Name = "CARRY CAPACITY", Attribute = "CarryCapacity" },
    { Id = "MovementSpeed", Name = "MOVEMENT SPEED", Attribute = "BaseWalkSpeed" },
    { Id = "SprintStamina", Name = "SPRINT STAMINA", Attribute = "StaminaMax" },
    { Id = "Jump", Name = "JUMP LEVEL", Attribute = "JumpLevel" },
    { Id = "Bat", Name = "STUN-BAT", Attribute = "BatLevel" },
}
local tiers: { [string]: { { Cost: number, Value: number } } } = {
    Bat = Upgrades.Bat,
    CarryCapacity = Upgrades.CarryCapacity,
    MovementSpeed = Upgrades.MovementSpeed,
    SprintStamina = Upgrades.SprintStamina,
    Jump = Upgrades.Jump,
}

local batNames = { "NONE", "BAT", "BIG BAT", "GIANT" }
local prefixes: { [string]: string } = { Jump = "JUMP", MovementSpeed = "SPEED", SprintStamina = "STAM" }

local function valueText(id: string, level: number, value: number): string
    if id == "Bat" then
        return batNames[level + 1]
    elseif id == "CarryCapacity" then
        return tostring(value) .. " ITEMS"
    end
    return prefixes[id] .. " " .. tostring(level)
end

-- Progression and prices come from purchased tiers, never temporary effective stats.
-- Keep the optional third argument for existing consumers.
function Display.Row(
    id: string,
    level: number?,
    _current: number?
): { Level: number, Stat: string, Current: string, Next: string, Price: number?, Max: boolean }?
    local track = tiers[id]
    if not track or level == nil or level % 1 ~= 0 or not track[level + 1] then
        return nil
    end
    local nextTier = track[level + 2]
    local currentText = valueText(id, level, track[level + 1].Value)
    local nextText = if nextTier then valueText(id, level + 1, nextTier.Value) else "MAX"
    return {
        Level = level,
        Stat = currentText .. " \u{2192} " .. nextText,
        Current = currentText,
        Next = nextText,
        Price = if nextTier then nextTier.Cost else nil,
        Max = nextTier == nil,
    }
end

function Display.Feedback(success: boolean, reason: string?): string
    if success then
        return "PURCHASED!"
    elseif reason == "InsufficientCash" then
        return "NOT ENOUGH"
    elseif reason == "MaxLevel" then
        return "MAX"
    end
    return "TRY AGAIN"
end

return Display
