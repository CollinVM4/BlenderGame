--!strict
return {
    SwingCooldown = 1.1,
    -- Contact timestamp (seconds) in Bat.SwingAnimation at 1x playback speed.
    -- Authored "bat hit2" contact frame at normal playback speed.
    -- The server uses this delay; client animation markers never authorize hits.
    ImpactDelay = 0.21,
    -- Three discrete server samples: contact minus half-window, contact, contact plus half-window.
    ImpactWindow = 0.08,
    ImmunitySeconds = 2.5,
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
        { Scale = 1, Reach = 5, StunDuration = 1.5 },
        { Scale = 1.12, Reach = 5.75, StunDuration = 2.25 },
        { Scale = 1.25, Reach = 6.5, StunDuration = 3 },
    },
}
