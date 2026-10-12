--!strict
-- Cosmetic budgets only; gameplay tuning stays in IceGunConfig.
return table.freeze({
    Lifetime = 0.65,
    ConeGrowSeconds = 0.11,
    ConeFadeSeconds = 0.24,
    ViewDistance = 100,
    MobileViewDistance = 70,
    MaxActiveBlasts = 4,
    MobileMaxActiveBlasts = 2,
    ConeSegments = 8,
    MobileConeSegments = 6,
    FrostCount = 24,
    MobileFrostCount = 12,
    ShardCount = 4,
    MobileShardCount = 2,
    MaxImpactEffects = 4,
    MobileMaxImpactEffects = 2,
    MaxEventAge = 0.75,
    OutlineDistance = 100,
    MaxOutlines = 20,
    OutlineInterval = 0.1,
    ImmunityFlashSeconds = 0.22,
    Blue = Color3.fromRGB(90, 200, 255),
    White = Color3.fromRGB(245, 250, 255),
    ShotSoundId = "rbxassetid://11900833", -- Original imported Launch.
    ImpactSoundId = "rbxassetid://4508963254", -- Original imported Shatter.
    FallbackSoundId = "rbxasset://sounds/impact_water.mp3",
    FrostTexture = "rbxassetid://276120078", -- Original imported snow.
    FallbackTexture = "rbxasset://textures/particles/sparkles_main.dds",
})
