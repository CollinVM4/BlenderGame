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
    FillerValueFraction = 0.25,
    FillerCapFraction = 0.5,
    OriginMultiplier = { [0] = 1, [1] = 1.1, [2] = 1.25, [3] = 1.5 },
    MaxIngredients = 3,
    RequiredProgress = 65,
    BlendProgressScale = 3, -- Progress per radian of physical blade rotation.
    InteractionDistance = 12,
    NormalStash = {
        Slots = 5,
        ProtectionTag = "ProtectedStashSlot",
        -- Explicit permanent designations; Second Storage adds no protected entries.
        SlotProtection = { [1] = true, [2] = true },
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
    RefillSeconds = { [0] = 3, [1] = 12, [2] = 40, [3] = 90 },
    -- Placeholder: replace with the intended secret-pedestal cadence during Studio tuning.
    SpecialRefillSeconds = { Gummy_Bear = 300 } :: { [string]: number },
    WorldIngredientCleanupInterval = 360,
    WorldIngredientCleanupWarningSeconds = 60,
    WorldIngredientCleanupCountdownSeconds = 5,
    RarityWeights = rarityWeights,
}
