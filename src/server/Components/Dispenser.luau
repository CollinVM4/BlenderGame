--!strict
-- Inventory-to-physical-unit API only. IngredientPickup owns loose-item interaction.
local Dispenser = {}
local deps: any
function Dispenser.Init(services: any)
    deps = services
end
function Dispenser.DispenseIngredient(player: Player, id: string): Instance?
    return deps.InventoryService.ReleaseUnit(player, id)
end
return Dispenser
