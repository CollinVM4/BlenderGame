--!strict
local Audio = require(script.Parent.GameplayAudio)
local rewards: { [string]: { Visual: string, Name: string } } = {
    DoubleCash = { Visual = "2xCash", Name = "Double Cash" },
    SuperJump = { Visual = "Jump", Name = "Super Jump" },
    RainbowRampage = { Visual = "Star", Name = "Star Power" },
    MegaBat = { Visual = "MegaBat", Name = "Mega Bat" },
    IngredientMagnet = { Visual = "Magnet", Name = "Ingredient Magnet" },
    Invincibility = { Visual = "Invincibility", Name = "Invincibility" },
}
return {
    VisualFolderName = "LuckyBlockVisuals",
    NearbyEventName = "LuckyBlockRevealed",
    NearbyDistance = 70,
    TickTimes = { 0, 0.14, 0.28, 0.42, 0.56 },
    RevealSeconds = 0.78,
    HoldSeconds = 1.7,
    FadeSeconds = 0.15,
    TickSoundId = Audio.IngredientPickupSoundId,
    PopSoundId = Audio.IngredientThrowSoundId,
    TickVolume = 0.25,
    PopVolume = 0.6,
    HeightOffset = 2.5,
    ModelSize = 2.6,
    TiltDegrees = 12,
    BeatYawDegrees = 24,
    RevealYawDegrees = 30,
    PopScale = 1.25,
    PopSeconds = 0.1,
    SettleSeconds = 0.12,
    Rewards = rewards,
}
