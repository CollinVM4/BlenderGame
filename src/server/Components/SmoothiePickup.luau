--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local SmoothiePickup = {}
function SmoothiePickup.Init(services: any)
    WorldUtil.BindTag("SmoothieWorldItem", function(object)
        local record = services.SmoothieWorldItemService.GetData(object)
        local part = WorldUtil.Part(object)
        if not record or not part then
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "SmoothieCarryPrompt", "Pickup")
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt:SetAttribute("SmoothiePickupPrompt", true)
        prompt.ObjectText = "Smoothie"
        local connection = prompt.Triggered:Connect(function(player)
            services.InventoryService.CarryWorldSmoothie(player, object)
        end)
        return function()
            connection:Disconnect()
            prompt:Destroy()
        end
    end)
end
return SmoothiePickup
