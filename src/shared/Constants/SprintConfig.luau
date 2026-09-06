--!strict
-- Tuning values for the sprint/stamina system; StaminaMax can be overridden per-player by upgrades
local SprintConfig = {
    BASE_STAMINA_MAX = 100,
    STAMINA_DRAIN_RATE = 20, -- stamina per second while sprinting
    STAMINA_REGEN_RATE = 10, -- stamina per second while not sprinting
    WALK_SPEED_NORMAL = 16,
    SPRINT_SPEED_MULTIPLIER = 1.5,
}

return SprintConfig
