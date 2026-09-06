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
        local audio = AudioService.CreateBlendGroup(part)
        local connection = prompt.Triggered:Connect(function(player)
            if services.TycoonService.GetOwner(part) ~= player then
                return
            end
            local success = services.BlendService.Dispense(player, part)
            if success then
                audio.pourSound:Play()
            else
                audio.notReadySound:Play()
            end
        end)
        return function()
            connection:Disconnect()
            prompt:Destroy()
            for _, sound in audio do
                sound:Destroy()
            end
        end
    end)
end
return DispenseButton
