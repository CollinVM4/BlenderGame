--!strict
return {
    ModelName = "LuckyBlock", -- Direct child of ServerStorage.LuckyBlockTemplates.
    TemplateFolderName = "LuckyBlockTemplates",
    MarkerTag = "LuckyBlockSpawn",
    WorldTag = "LuckyBlockWorld",
    WorldFolderName = "LuckyBlocks",
    RewardEventName = "LuckyBlockPickedUp",
    Rewards = {
        { Id = "DoubleCash", Weight = 18, DurationSeconds = 30 },
        { Id = "SuperJump", Weight = 22, DurationSeconds = 12 },
        { Id = "RainbowRampage", Weight = 8, DurationSeconds = 10 },
        { Id = "MegaBat", Weight = 15, DurationSeconds = 15 },
        { Id = "IngredientMagnet", Weight = 20, DurationSeconds = 15 },
        { Id = "Invincibility", Weight = 17, DurationSeconds = 8 },
    },
    Spawn = {
        ContainerName = "LuckyBlockSpawns",
        Levels = { "Level0", "Level1", "Level2", "Level3" },
        MaxActivePerLevel = 1,
        HeightOffset = 3,
        RetrySeconds = 5,
    },
    Respawn = { MinRespawnSeconds = 180, MaxRespawnSeconds = 240 },
    Pickup = { Radius = 4, PollSeconds = 0.15, PlayerCooldownSeconds = 0.75 },
    Animation = { BobAmplitude = 0.5, BobPeriodSeconds = 2.5, RotationDegreesPerSecond = 45 },
}
