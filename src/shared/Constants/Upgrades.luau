--!strict
return {
    -- Demo prices; index 1 is displayed level 0 for movement tracks.
    MovementSpeed = {
        { Cost = 0, Value = 26 },
        { Cost = 1000, Value = 32 },
        { Cost = 5000, Value = 37 },
        { Cost = 10000, Value = 41 },
    },
    Jump = {
        { Cost = 0, Value = 60 },
        { Cost = 2000, Value = 85 },
        { Cost = 5000, Value = 95 },
        { Cost = 8000, Value = 116 },
    },
    SprintStamina = {
        { Cost = 0, Value = 60 },
        { Cost = 1000, Value = 80 },
        { Cost = 5000, Value = 100 },
        { Cost = 8000, Value = 130 },
    },
    Hand = {
        { Cost = 0, Damage = 10, Knockback = 22, Size = 1 },
        { Cost = 3000, Damage = 15, Knockback = 30, Size = 1.3 },
        { Cost = 8000, Damage = 20, Knockback = 38, Size = 1.6 },
    },
    CarryCapacity = { { Cost = 0, Value = 3 }, { Cost = 3000, Value = 5 }, { Cost = 11000, Value = 7 } },
    StackSize = { { Cost = 0, Value = 5 }, { Cost = 5000, Value = 10 } },
    BlendSpeed = { { Cost = 0, Value = 1 }, { Cost = 2000, Value = 1.25 }, { Cost = 6000, Value = 1.5 } },
    Payout = { { Cost = 0, Value = 1 }, { Cost = 3000, Value = 1.3 }, { Cost = 9000, Value = 1.7 } },
}
