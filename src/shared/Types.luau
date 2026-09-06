--!strict
export type BlendState = "EMPTY" | "LOADING" | "READY" | "BLENDING" | "COMPLETE" | "DISPENSED"
export type DayState = "PREP" | "SERVING" | "FINISHED"
export type Grade = "A" | "B" | "C" | "D"
export type Stack = { IngredientId: string, Count: number }
export type Smoothie = { Ingredients: { string }, Tags: { string }, Color: Color3, Discovery: string? }
export type PlayerData = {
    Cash: number,
    Upgrades: { Hand: number, StackSize: number, BlendSpeed: number, Payout: number },
    Discoveries: { [string]: boolean },
    Stats: { CustomersServed: number, SmoothiesMade: number, PlayersSlapped: number, IngredientsStolen: number },
}
return {}
