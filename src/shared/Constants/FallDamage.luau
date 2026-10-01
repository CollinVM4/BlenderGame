--!strict
-- Tuning for FallDamageService. Velocities are studs/sec of downward speed at
-- landing, after subtracting the character's own current jump power (so a
-- normal jump-and-land on the same level never counts as a fall).
-- Thresholds are the original tuning divided by ~1.3 (and non-lethal damage
-- multiplied by ~1.3) for ~30% more sensitivity; jump safety is unaffected
-- because the jump-power subtraction already nets ~0 effective velocity.
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

    -- Landing detection only; these do not change the damage curve.
    ImpactProbePadding = 0.3,
    MinimumGroundNormalY = 0.5,
    ImpactSpeedDrop = 8,
    SettleVerticalSpeed = 4,
    SettleSeconds = 0.25,
    RepositionTolerance = 12, -- Extra studs beyond plausible per-step travel.
}
