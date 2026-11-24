--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Debug = require(game:GetService("ReplicatedStorage").Shared.MobilePromptDebug)
local IngredientPickup = {}
function IngredientPickup.Init(services: any)
    WorldUtil.BindTag("IngredientWorldItem", function(object)
        local record = services.IngredientService.GetRecord(object)
        local part = WorldUtil.Part(object)
        -- Eligibility only; InventoryService authorizes the triggering player's loose pickup.
        -- Nonclaimable market stock keeps its existing pedestal transaction.
        if not record or not record.Claimable or not part then
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "CarryPrompt", "Pickup")
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt:SetAttribute("IngredientPickupPrompt", true)
        prompt.ObjectText = record.Id
        local releaseConnection: RBXScriptConnection? = nil
        if record.FarmManaged then
            -- Leave E available for planting while the crop is still in its row.
            prompt.KeyboardKeyCode = Enum.KeyCode.F
            releaseConnection = object:GetAttributeChangedSignal("FrozenUntilPickup"):Connect(function()
                if object:GetAttribute("FrozenUntilPickup") ~= true then
                    prompt.KeyboardKeyCode = Enum.KeyCode.E
                end
            end)
        end
        local connection = prompt.Triggered:Connect(function(player)
            Debug.Log(prompt, "TRIGGERED", "server ingredient")
            Debug.Log(prompt, "ACTION DISPATCHED", "server CarryWorldItem")
            services.InventoryService.CarryWorldItem(player, object)
        end)
        return function()
            if releaseConnection then
                releaseConnection:Disconnect()
            end
            connection:Disconnect()
            prompt:Destroy()
        end
    end)
end
return IngredientPickup
