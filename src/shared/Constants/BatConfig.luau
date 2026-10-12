--!strict
return {
    SwingCooldown = 1.1,
    -- Server samples the live equipped Hitbox throughout this active swing window.
    HitActiveStart = 0.08,
    HitActiveEnd = 0.50,
    HitSampleInterval = 0.04,
    ImmunitySeconds = 2.5,
    Knockback = {
        HorizontalSpeed = 7, -- Legacy customer knockback; player hits use Levels below.
        UpwardSpeed = 4,
        ServerOwnershipSeconds = 0.2,
        MaxHorizontalSpeed = 110, -- Bound accumulated player launch speed, not displacement.
        MaxUpwardSpeed = 80, -- Never clamp an existing downward fall.
    },
    Scatter = {
        HorizontalMin = 8,
        HorizontalMax = 14,
        UpwardMin = 5,
        UpwardMax = 9,
        FanAngle = 140, -- A forward-facing fan, biased away from the attacker.
        SpawnRadius = 2,
        SpawnHeight = 1,
    },
    -- Loose anti-exploit radius, scaled by the purchased level's Scale.
    -- Contact still requires authored Hitbox overlap; Reach is not a root-distance veto.
    MaxRootDistance = 8,
    Levels = {
        -- Independent horizontal/upward velocity changes in studs/sec, mass-scaled at impact.
        {
            Scale = 1,
            Reach = 5,
            StunDuration = 1.5,
            HorizontalKnockback = 28,
            VerticalKnockback = 10,
            DamageFraction = 0.25,
        },
        {
            Scale = 1.12,
            Reach = 5.75,
            StunDuration = 2.25,
            HorizontalKnockback = 48,
            VerticalKnockback = 20,
            DamageFraction = 0.34,
        },
        {
            Scale = 1.25,
            Reach = 6.5,
            StunDuration = 3,
            HorizontalKnockback = 75,
            VerticalKnockback = 32,
            DamageFraction = 0.50,
        },
    },
}
