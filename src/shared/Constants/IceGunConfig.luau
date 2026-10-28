--!strict
return table.freeze({
    IceGunGamePassId = 2022020489, -- Creator Hub pass ID, not the asset ID. Fail closed until configured.
    StudioGamePassSimulation = true, -- Explicit opt-in; server + Studio + negative UserId only.
    DebugLogging = false, -- Opt-in, Studio-only, rate-limited lifecycle/fire diagnostics.
    MaximumCameraDistance = 128, -- Bounds untrusted third-person camera intent.
    ShotCooldown = 4.5,
    DirectDamage = 5,
    FreezeSeconds = 4,
    CustomerRagdollSeconds = 2.5,
    FreezeGrowthSeconds = 0.2,
    ImmunitySeconds = 4,
    -- Radial Ice Ray blast radius, measured in 3D from the server caster root
    -- to each target root. The client pulse is sized to exactly this radius,
    -- so the visible blast and the actual hit area are the same sphere.
    -- There is no cone angle: direction and line of sight do not gate hits.
    BlastRadius = 22,
    ProjectileLifetime = 110 / 70, -- Retained for the unused imported cosmetic projectile helper.
    TeamDamage = false, -- Server-only opt-in bypasses shared-plot and Roblox-team protection for ice shots.
    OwnershipRetrySeconds = 15,
    RequestInterval = 0.5,
    PurchaseDistance = 8,
    DisplayRadiansPerSecond = math.rad(35),
})
