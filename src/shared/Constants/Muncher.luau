--!strict
-- Provisional casino weights. Entries are basis points (10,000 = 100%).
return {
    PurchaseCost = 100000,
    RevealDepth = 6,
    RevealSeconds = 0.95,
    FeedDistance = 10,
    ScanInterval = 0.1,
    MaxDistance = 36,
    ChewSeconds = 1.65,
    BusySeconds = 0.3,
    -- Approved spatial clips; the unsupplied reel tick is deliberately silent.
    InsertSoundId = "rbxassetid://106774791990073",
    RollSoundId = "rbxassetid://132738338678605",
    ReelStopSoundId = "",
    WinSoundId = "rbxassetid://76556910414303",
    LoseSoundId = "rbxassetid://137571524170744",
    Vacuum = {
        Radius = 10,
        CaptureTolerance = 1.4,
        OverlapTolerance = 2.4,
        PullStrength = 30,
        CenteringStrength = 12,
        MaxSpeed = 40,
        MaxAcceleration = 600,
        EdgeStrength = 0.4,
        MaxStep = 1 / 30,
        MaxPullSeconds = 1.5,
        ReleaseSeconds = 1,
        MaxParts = 64,
        DiagnosticLimit = 60,
    },
    SpitSeconds = 0.15,
    RetrySeconds = 0.5,
    RecoverySeconds = 5,
    QuickRetries = 3,
    PlayerHeadFallbackBaseValue = 5000,
    TierMinimums = { 1000, 5000, 20000, 50000 },
    -- High Roller interpolation saturates at the highest static catalog value.
    TierMaximums = { 4999, 19999, 49999, 165000 },
    DebugLogging = false,
    LogLimit = 40,
    -- Explicit remaining mass, including real catalog IDs. Never output a player head.
    -- Provisional EV guardrail: 110% at floor/mid/ceiling, except Cheap floor.
    -- Approved sub-$1,053 lottery exception retains 99% Rock at floor. That cutoff
    -- cannot cover all infeasible inputs; see docs/MUNCHER_REWARD_RETUNE.md.
    RewardPools = {
        {
            { Id = "Rock", Weight = 9900 },
            { Id = "Apple", Weight = 50 },
            { Id = "Banana", Weight = 20 },
            { Id = "Mushrooms", Weight = 10 },
            { Id = "Dragon_Fruit", Weight = 20 },
        },
        {
            { Id = "Mushrooms", Weight = 7800 },
            { Id = "Protein", Weight = 600 },
            { Id = "Pear", Weight = 1200 },
            { Id = "Honey", Weight = 350 },
            { Id = "Dragon_Fruit", Weight = 50 },
        },
        {
            { Id = "Pear", Weight = 5400 },
            { Id = "Honey", Weight = 2000 },
            { Id = "Crab", Weight = 2000 },
            { Id = "Golden_Potato", Weight = 500 },
            { Id = "Dragon_Fruit", Weight = 100 },
        },
        {
            { Id = "Coconut", Weight = 2500 },
            { Id = "Crab", Weight = 1700 },
            { Id = "Golden_Potato", Weight = 3400 },
            { Id = "Pizza", Weight = 2200 },
            { Id = "Dragon_Fruit", Weight = 200 },
        },
    },
}
