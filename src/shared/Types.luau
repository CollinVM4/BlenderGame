--!strict
export type BlendState = "EMPTY" | "LOADING" | "READY" | "BLENDING" | "COMPLETE" | "DISPENSED"
export type DayState = "PREP" | "SERVING" | "FINISHED"
export type Grade = "A" | "B" | "C" | "D"
export type SmoothieData = { BlendId: string, Ingredients: { string } }
export type StashSlot = {
    SlotIndex: number,
    ItemType: ("Ingredient" | "Smoothie")?,
    IngredientId: string?,
    Smoothie: SmoothieData?,
    Count: number,
    Capacity: number,
    Protected: boolean,
}
export type Stack = { IngredientId: string, Count: number }
export type Smoothie =
    { BlendId: string?, Ingredients: { string }, Tags: { string }, Color: Color3, Discovery: string? }
export type PersonalPlayerData = {
    Upgrades: { CarryCapacity: number, StackSize: number },
    Discoveries: { [string]: boolean },
    Stats: { CustomersServed: number, SmoothiesMade: number, PlayersSlapped: number, IngredientsStolen: number },
}
-- Compatibility snapshot: shared fields are projections, never a stored personal record.
export type PlayerData = {
    Cash: number,
    Upgrades: {
        Hand: number,
        CarryCapacity: number,
        StackSize: number,
        BlendSpeed: number,
        Payout: number,
        MovementSpeed: number,
        Jump: number,
        SprintStamina: number,
    },
    Discoveries: { [string]: boolean },
    Stats: { CustomersServed: number, SmoothiesMade: number, PlayersSlapped: number, IngredientsStolen: number },
}
export type PlotRequestContext = { PlotSessionId: string, MembershipRevision: number }
export type PlotSessionState = {
    PlotId: string,
    PlotSessionId: string,
    OwnerUserId: number,
    TeammateUserId: number?,
    JoinMode: string,
    SharedCash: number,
    SharedUpgrades: { [string]: number },
    Status: string,
    MembershipRevision: number,
}
return {}
