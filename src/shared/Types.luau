--!strict
export type BlendState = "EMPTY" | "LOADING" | "READY" | "BLENDING" | "COMPLETE" | "DISPENSED"
export type DayState = "PREP" | "SERVING" | "FINISHED"
export type Grade = "A" | "B" | "C" | "D"
export type IngredientItem = {
    IngredientId: string,
    ItemId: string,
    RipenessStoredSeconds: number,
    RipenessStoredAt: number?,
    IsRipe: boolean,
    SourceUserId: number?,
    SourceDisplayName: string?,
    SourceUsername: string?,
    -- Opaque server-only appearance identity; never contains an Instance.
    VisualKey: {}?,
    AnnouncementOwnership: AnnouncementOwnership?,
}
export type SmoothieData = { BlendId: string, Ingredients: { string }, IngredientItems: { IngredientItem }? }
export type AnnouncementOwnership = { LastOwnerUserId: number? }
export type StashSlot = {
    Value: number?,
    Ingredients: { IngredientItem },
    SlotIndex: number,
    ItemType: ("Ingredient" | "Smoothie")?,
    IngredientId: string?,
    Smoothie: SmoothieData?,
    Count: number,
    Capacity: number,
    Protected: boolean,
}
export type Stack = { IngredientId: string, Count: number }
export type Smoothie = {
    BlendId: string?,
    Ingredients: { string },
    IngredientItems: { IngredientItem }?,
    Tags: { string },
    Color: Color3,
    Discovery: string?,
}
export type DiscoveryState = {
    Ingredients: { [string]: boolean },
    SpecialCustomers: { [string]: boolean },
}
export type DiscoveryEvent = { Kind: "Ingredient" | "SpecialCustomer", Id: string }
export type PersonalPlayerData = {
    Upgrades: { CarryCapacity: number, StackSize: number },
    Discoveries: { [string]: boolean },
    Discovery: DiscoveryState,
    Stats: { CustomersServed: number, SmoothiesMade: number, PlayersSlapped: number, IngredientsStolen: number },
}
-- Compatibility snapshot: shared fields are projections, never a stored personal record.
export type PlayerData = {
    Cash: number,
    Upgrades: {
        Bat: number,
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
    Discovery: DiscoveryState,
    Stats: { CustomersServed: number, SmoothiesMade: number, PlayersSlapped: number, IngredientsStolen: number },
}
export type PlotRequestContext = { PlotSessionId: string, MembershipRevision: number }
export type PlotSessionState = {
    PlotId: string,
    PlotSessionId: string,
    OwnerUserId: number,
    TeammateUserId: number?,
    JoinMode: string,
    StandName: string,
    StandNameRevision: number,
    SharedCash: number,
    SharedUpgrades: { [string]: number },
    Status: string,
    MembershipRevision: number,
}
return {}
