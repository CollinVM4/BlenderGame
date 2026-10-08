--!strict
return {
    PurchaseCost = 100000,
    Required = 25,
    BuffDuration = 300,
    RevealDepth = 6,
    RevealSeconds = 0.95,
    Buffs = {
        { Id = "Cash125", Name = "CASH BOOST 1.25x", CashMultiplier = 1.25 },
        { Id = "Cash150", Name = "CASH BOOST 1.5x", CashMultiplier = 1.5 },
        { Id = "Cash200", Name = "CASH BOOST 2x", CashMultiplier = 2 },
    },
    FeedDistance = 10,
    FeedCooldown = 0.15,
    ScanInterval = 0.1,
    TravelSeconds = 0.18,
    MaxDistance = 36, -- Same viewing distance as stash world labels.
}
