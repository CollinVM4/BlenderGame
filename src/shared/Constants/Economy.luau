--!strict
local rarityWeights: { [string]: number } = { Common = 75, Uncommon = 20, Rare = 5 }
return {
    MaxCustomersPerPlot = 3,
    InitialCustomerDelayMin = 2,
    InitialCustomerDelayMax = 5,
    CustomerSpawnMinSeconds = 35,
    CustomerSpawnMaxSeconds = 65,
    CustomerFullRetryMinSeconds = 5,
    CustomerFullRetryMaxSeconds = 10,
    SpecialCustomerCooldownSeconds = 300,
    BasePayout = 25,
    CashScale = 20, -- Request base values stay in authored units; scale only at award time.
    MissedOrderFraction = 0.15,
    PayoutRarityMultiplier = { Common = 1, Uncommon = 1.25, Rare = 1.75, Mystery = 2.5 },
    GradeMultiplier = { A = 1.5, B = 1, C = 0.7, D = 0.4 },
    GradeScore = { A = 4, B = 3, C = 2, D = 1 },
    MaxIngredients = 3,
    RequiredProgress = 85,
    BlendProgressScale = 3, -- Progress per radian of physical blade rotation.
    InteractionDistance = 12,
    NormalStash = { Slots = 5, Protected = 2 },
    VIPStash = { Slots = 10, Protected = 5 },
    StealCooldown = 3,
    VictimProtection = 5,
    DropProtection = 4,
    SlapCooldown = 0.8,
    SlapRange = 8,
    StunSeconds = 0.5,
    MarketRespawnSeconds = 12,
    WorldItemLifetime = 120,
    RarityWeights = rarityWeights,
}
