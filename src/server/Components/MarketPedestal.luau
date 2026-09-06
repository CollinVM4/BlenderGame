--!strict
local RunService = game:GetService("RunService")
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local MarketPedestal = {}
function MarketPedestal.Init(services: any)
    WorldUtil.BindTag("MarketPedestal", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[MarketPedestal] Requires a BasePart")
            return nil
        end
        services.MarketService.Register(part)
        local prompt = WorldUtil.Prompt(part, "ClaimPrompt", "Collect ingredient")
        local connection = prompt.Triggered:Connect(function(player)
            services.MarketService.Claim(player, part)
        end)
        return function()
            connection:Disconnect()
            prompt:Destroy()
            services.MarketService.Unregister(part)
        end
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 1 then
            elapsed = 0
            services.MarketService.Step()
        end
    end)
end
return MarketPedestal
