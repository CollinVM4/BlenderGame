--!strict
-- Cosmetic budgets only; gameplay tuning stays in IceGunConfig.
return table.freeze({
    Lifetime = 0.65,
    -- Radial pulse timing, in the Illari-burst style: a fast outward expansion
    -- to the full hit radius, then a fade. Kept at the old cone timings so the
    -- pulse is fully grown by 0.11s and fully faded by 0.35s.
    PulseGrowSeconds = 0.11,
    PulseFadeSeconds = 0.24,
    PulseStartTransparency = 0.45,
    ViewDistance = 100,
    MobileViewDistance = 70,
    MaxActiveBlasts = 4,
    MobileMaxActiveBlasts = 2,
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
    FallbackSoundId = "rbxassetid://32788850", -- Original icy IceCrack, never water.
    CastVolume = 0.3,
    FreezeVolume = 0.16,
    ThawVolume = 0.12,
    SoundMinDistance = 6,
    SoundMaxDistance = 60,
    SoundLifetime = 4, -- Independent of the short radial pulse lifetime.
    FrostTexture = "rbxassetid://276120078", -- Original imported snow.
    FallbackTexture = "rbxasset://textures/particles/sparkles_main.dds",
})
