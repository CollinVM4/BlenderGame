--!strict
return {
    SecondStorage = { { Cost = 0, Value = 5 }, { Cost = 400000, Value = 10 } },
    -- Index 1 is displayed level 0 for movement tracks.
    MovementSpeed = {
        { Cost = 0, Value = 26 },
        { Cost = 20000, Value = 32 },
        { Cost = 125000, Value = 37 },
        { Cost = 400000, Value = 41 },
    },
    Jump = {
        { Cost = 0, Value = 60 },
        { Cost = 50000, Value = 85 },
        { Cost = 375000, Value = 95 },
        { Cost = 800000, Value = 116 },
    },
    SprintStamina = {
        { Cost = 0, Value = 60 },
        { Cost = 15000, Value = 80 },
        { Cost = 100000, Value = 100 },
        { Cost = 300000, Value = 130 },
    },
    Bat = {
        { Cost = 0, Value = 0 },
        { Cost = 50000, Value = 1 },
        { Cost = 175000, Value = 2 },
        { Cost = 450000, Value = 3 },
    },
    -- Deprecated Hand data remains for saved upgrade compatibility; Bat is the playable combat path.
    Hand = {
        { Cost = 0, Damage = 10, Knockback = 22, Size = 1 },
        { Cost = 3000, Damage = 15, Knockback = 30, Size = 1.3 },
        { Cost = 8000, Damage = 20, Knockback = 38, Size = 1.6 },
    },
    CarryCapacity = { { Cost = 0, Value = 3 }, { Cost = 40000, Value = 5 }, { Cost = 350000, Value = 7 } },
    StackSize = { { Cost = 0, Value = 5 }, { Cost = 250000, Value = 10 } },
    BlendSpeed = { { Cost = 0, Value = 1 }, { Cost = 75000, Value = 1.25 }, { Cost = 250000, Value = 1.5 } },
    Payout = { { Cost = 0, Value = 1 }, { Cost = 150000, Value = 1.3 }, { Cost = 600000, Value = 1.7 } },
}
