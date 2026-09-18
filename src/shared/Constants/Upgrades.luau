--!strict
return {
    -- Demo prices; index 1 is displayed level 0 for movement tracks.
    MovementSpeed = {
        { Cost = 0, Value = 30 },
        { Cost = 50, Value = 35 },
        { Cost = 250, Value = 40 },
        { Cost = 500, Value = 45 },
    },
    Jump = {
        { Cost = 0, Value = 60},
        { Cost = 100, Value = 85},
        { Cost = 250, Value = 95},
        { Cost = 400, Value = 116 },
    },
    SprintStamina = {
        { Cost = 0, Value = 60 },
        { Cost = 50, Value = 80 },
        { Cost = 250, Value = 100 },
        { Cost = 400, Value = 130 },
    },
    Hand = {
        { Cost = 0, Damage = 10, Knockback = 22, Size = 1 },
        { Cost = 150, Damage = 15, Knockback = 30, Size = 1.3 },
        { Cost = 400, Damage = 20, Knockback = 38, Size = 1.6 },
    },
    CarryCapacity = { { Cost = 0, Value = 3 }, { Cost = 150, Value = 5 }, { Cost = 550, Value = 7 } },
    StackSize = { { Cost = 0, Value = 5 }, { Cost = 250, Value = 10 } },
    BlendSpeed = { { Cost = 0, Value = 1 }, { Cost = 100, Value = 1.25 }, { Cost = 300, Value = 1.5 } },
    Payout = { { Cost = 0, Value = 1 }, { Cost = 150, Value = 1.2 }, { Cost = 600, Value = 1.4 } },
}
