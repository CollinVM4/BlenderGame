--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local IngredientPickup = {}
function IngredientPickup.Init(services: any)
    WorldUtil.BindTag("IngredientWorldItem", function(object)
        local record = services.IngredientService.GetRecord(object)
        local part = WorldUtil.Part(object)
        -- Market collection keeps its existing stock transaction; filming props are already owned.
        if not record or not record.Owner or not record.Claimable or not part then
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "CarryPrompt", "Pick up / click to throw")
        prompt.ObjectText = record.Id
        local connection = prompt.Triggered:Connect(function(player)
            services.InventoryService.CarryWorldItem(player, object)
        end)
        return function()
            connection:Disconnect()
            prompt:Destroy()
        end
    end)
end
return IngredientPickup
