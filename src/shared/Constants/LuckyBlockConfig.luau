--!strict
local rewards: { { Id: string, Weight: number, DurationSeconds: number? } } = {
    { Id = "CashBoost", Weight = 15, DurationSeconds = 90 },
    { Id = "StarPower", Weight = 13, DurationSeconds = 10 },
    { Id = "MegaBat", Weight = 17, DurationSeconds = 15 },
    { Id = "Invincibility", Weight = 17, DurationSeconds = 8 },
    { Id = "PantryPack", Weight = 20 },
    { Id = "TopShelf", Weight = 10 },
    { Id = "MysteryBox", Weight = 8 },
}
return {
    ModelName = "LuckyBlock", -- Direct child of ServerStorage.LuckyBlockTemplates.
    TemplateFolderName = "LuckyBlockTemplates",
    MarkerTag = "LuckyBlockSpawn",
    WorldTag = "LuckyBlockWorld",
    WorldFolderName = "LuckyBlocks",
    RewardEventName = "LuckyBlockPickedUp",
    Rewards = rewards,
    Spawn = {
        ContainerName = "LuckyBlockSpawns",
        Levels = { "Level0", "Level1", "Level2", "Level3" },
        SlotsPerLevel = { Level0 = 3, Level1 = 1, Level2 = 1, Level3 = 0 },
        Level0Sync = true,
        HeightOffset = 3,
        RetrySeconds = 5,
    },
    Respawn = { MinRespawnSeconds = 180, MaxRespawnSeconds = 240 },
    Pickup = { Radius = 4, PollSeconds = 0.15, PlayerCooldownSeconds = 0.75, LabelMaxDistance = 60 },
    Animation = { BobAmplitude = 0.5, BobPeriodSeconds = 2.5, RotationDegreesPerSecond = 45 },
}
