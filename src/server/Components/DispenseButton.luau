--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local DispenseButton = {}
function DispenseButton.Init(services: any)
    WorldUtil.BindTag("DispenseButton", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[DispenseButton] Requires a BasePart")
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "DispensePrompt", "Dispense smoothie")
        prompt:SetAttribute("InteractionOrigin", "DispenserTextOrigin")
        prompt:SetAttribute("InteractionActionText", "DISPENSE")
        prompt.Style = Enum.ProximityPromptStyle.Custom
        local audio = AudioService.CreateBlendGroup(part)
        services.GameplayService.RegisterPlotInteraction(prompt, function(player, context)
            if not services.TycoonService.IsMember(player, part) then
                return
            end
            local success = services.BlendService.Dispense(player, part, context)
            if success then
                audio.pourSound:Play()
            else
                audio.notReadySound:Play()
            end
        end)
        return function()
            prompt:Destroy()
            for _, sound in audio do
                sound:Destroy()
            end
        end
    end)
end
return DispenseButton
