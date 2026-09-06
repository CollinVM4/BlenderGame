--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local DayButton = {}
function DayButton.Init(services: any)
    WorldUtil.BindTag("StartDayButton", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[DayButton] Requires a BasePart")
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "StartDayPrompt", "Start Day")
        local connection = prompt.Triggered:Connect(function(player)
            if services.TycoonService.GetOwner(part) ~= player then
                return
            end
            local ok, reason = services.GameService.StartDay(player)
            player:SetAttribute("LastActionError", if ok then "" else reason)
        end)
        return function()
            connection:Disconnect()
            prompt:Destroy()
        end
    end)
end
return DayButton
