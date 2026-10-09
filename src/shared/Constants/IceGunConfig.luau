--!strict
return table.freeze({
    IceGunGamePassId = 2022020489, -- Creator Hub pass ID, not the asset ID. Fail closed until configured.
    StudioGamePassSimulation = true, -- Explicit opt-in; server + Studio + negative UserId only.
    DebugLogging = false, -- Optional, rate-limited lifecycle/fire diagnostics.
    MaximumCameraDistance = 128, -- Bounds untrusted third-person camera intent.
    ProjectileSpeed = 70,
    ShotCooldown = 2,
    DirectDamage = 14,
    SplashDamage = 0,
    FreezeChance = 1,
    FreezeSeconds = 2.75,
    FreezeGrowthSeconds = 0.2,
    ImmunitySeconds = 4,
    MaximumRange = 110,
    ProjectileLifetime = 110 / 70,
    TeamDamage = false,
    MaxActiveProjectiles = 1,
    OwnershipRetrySeconds = 15,
    RequestInterval = 0.5,
    PurchaseDistance = 8,
    DisplayRadiansPerSecond = math.rad(35),
})
