--!strict
-- World pickup adapter and inventory-to-physical-unit API; no free ingredient grants.
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Dispenser = {}
local deps: any
function Dispenser.Init(services: any)
    deps = services
    WorldUtil.BindTag("IngredientWorldItem", function(object)
        local record = services.IngredientService.GetRecord(object)
        local part = WorldUtil.Part(object)
        if not record or not record.Claimable or not part then
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "PickupPrompt", "Collect " .. record.Id)
        local connection = prompt.Triggered:Connect(function(player)
            services.InventoryService.ClaimWorldItem(player, object)
        end)
        return function()
            connection:Disconnect()
            prompt:Destroy()
        end
    end)
end
function Dispenser.DispenseIngredient(player: Player, id: string): Instance?
    return deps.InventoryService.ReleaseUnit(player, id)
end
return Dispenser
