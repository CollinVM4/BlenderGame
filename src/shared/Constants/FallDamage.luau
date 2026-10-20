--!strict
-- Peak downward speed is compensated by the player's jump tier, capped below.
-- Damage thresholds and the smooth curve remain independent of landing detection.
return {
    SafeImpactVelocity = 54,
    LightImpactVelocity = 69,
    HeavyImpactVelocity = 85,
    LethalImpactVelocity = 96,

    -- Damage applied at each named threshold; values between thresholds are
    -- smoothly interpolated rather than stepped.
    LightDamage = 16,
    HeavyDamage = 72,
    LethalDamage = 200, -- Deliberately exceeds max health to guarantee a kill.

    CompensationCap = 85, -- Set to math.huge to restore uncapped jump compensation.

    -- Landing detection only; these do not change the damage curve.
    ImpactProbePadding = 0.3,
    MinimumGroundNormalY = 0.5,
    ImpactSpeedDrop = 8,
    SettleVerticalSpeed = 4,
    GroundConfirmSeconds = 0.1,
    RepositionTolerance = 12, -- Extra studs beyond plausible per-step travel.
}
