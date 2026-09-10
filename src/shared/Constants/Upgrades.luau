--!strict
return {
    -- Demo prices; index 1 is displayed level 0 for movement tracks.
    MovementSpeed = {
        { Cost = 0, Value = 22 },
        { Cost = 100, Value = 25 },
        { Cost = 250, Value = 28 },
        { Cost = 500, Value = 31 },
    },
    Jump = {
        { Cost = 0, Value = 60 },
        { Cost = 100, Value = 72 },
        { Cost = 250, Value = 94 },
        { Cost = 500, Value = 116 },
    },
    SprintStamina = {
        { Cost = 0, Value = 60 },
        { Cost = 100, Value = 80 },
        { Cost = 250, Value = 100 },
        { Cost = 500, Value = 120 },
    },
    Hand = {
        { Cost = 0, Damage = 10, Knockback = 22, Size = 1 },
        { Cost = 150, Damage = 15, Knockback = 30, Size = 1.3 },
        { Cost = 400, Damage = 20, Knockback = 38, Size = 1.6 },
    },
    StackSize = { { Cost = 0, Value = 5 }, { Cost = 250, Value = 10 } },
    BlendSpeed = { { Cost = 0, Value = 1 }, { Cost = 200, Value = 1.25 }, { Cost = 500, Value = 1.5 } },
    Payout = { { Cost = 0, Value = 1 }, { Cost = 250, Value = 1.2 }, { Cost = 600, Value = 1.4 } },
}
