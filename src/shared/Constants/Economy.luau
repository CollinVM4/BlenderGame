--!strict
local rarityWeights: { [string]: number } = { Common = 75, Uncommon = 20, Rare = 5 }
return {
    MaxCustomersPerPlot = 3,
    InitialCustomerDelayMin = 2,
    InitialCustomerDelayMax = 5,
    CustomerSpawnMinSeconds = 25,
    CustomerSpawnMaxSeconds = 45,
    CustomerFullRetryMinSeconds = 3,
    CustomerFullRetryMaxSeconds = 5,
    SpecialCustomerCooldownSeconds = 300,
    BasePayout = 25,
    CashScale = 20, -- Legacy CalculatePayout compatibility only; live orders use ingredient dollars.
    GradeMultiplier = { A = 1.25, B = 1.1, C = 0.9, D = 0.15 },
    GradeScore = { A = 4, B = 3, C = 2, D = 1 },
    MaxIngredients = 3,
    RequiredProgress = 65,
    BlendProgressScale = 3, -- Progress per radian of physical blade rotation.
    InteractionDistance = 12,
    NormalStash = {
        Slots = 5,
        Protected = 2,
        IngredientCapacity = 3,
        RaidWindowSeconds = 6,
        RaidProtectionSeconds = 30,
    },
    VIPStash = { Slots = 10, Protected = 5 },
    StealCooldown = 3,
    VictimProtection = 5,
    DropProtection = 4,
    SlapCooldown = 0.8,
    SlapRange = 8,
    StunSeconds = 0.5,
    MarketRespawnSeconds = 12,
    WorldIngredientCleanupInterval = 360,
    WorldIngredientCleanupWarningSeconds = 60,
    WorldIngredientCleanupCountdownSeconds = 5,
    RarityWeights = rarityWeights,
}
