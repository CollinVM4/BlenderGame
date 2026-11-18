--!strict
return {
    SwingCooldown = 1.1,
    -- Bat 1 dimensions in studs. The long axis of the authored Hitbox is local Z.
    HitboxSize = Vector3.new(3.75, 3, 8.5),
    SwingHalfAngle = 55,
    CloseContactRadius = 1.875,
    -- The server samples the front sweep during the contact portion of the animation.
    HitActiveStart = 0.08,
    HitActiveEnd = 0.28,
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
    Levels = {
        -- Independent horizontal/upward velocity changes in studs/sec, mass-scaled at impact.
        {
            LengthScale = 1,
            StunDuration = 1.5,
            HorizontalKnockback = 28,
            VerticalKnockback = 10,
            DamageFraction = 0.25,
        },
        {
            LengthScale = 1.40,
            StunDuration = 2.25,
            HorizontalKnockback = 48,
            VerticalKnockback = 20,
            DamageFraction = 0.34,
        },
        {
            LengthScale = 1.80,
            StunDuration = 3,
            HorizontalKnockback = 75,
            VerticalKnockback = 32,
            DamageFraction = 0.50,
        },
    },
}
