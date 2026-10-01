--!strict
-- Tuning for HealthRegenService: deliberately much slower than Roblox's
-- built-in regeneration so surviving a fall/fight/knockback has lasting cost.
return {
    HealthRegenDelaySeconds = 10,
    HealthRegenPerSecond = 1.25,
}
