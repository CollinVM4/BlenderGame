--!strict
local RunService = game:GetService("RunService")
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local BlenderInput = {}
function BlenderInput.Init(services: any)
    WorldUtil.BindTag("BlenderInput", function(object)
        if not object:IsA("BasePart") then
            warn("[BlenderInput] Tag a BasePart")
            return nil
        end
        local elapsed = 0
        local connection = RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed < 0.1 then
                return
            end
            elapsed = 0
            local owner = services.TycoonService.GetOwner(object)
            if not owner then
                return
            end
            for _, part in workspace:GetPartsInPart(object) do
                local item = services.IngredientService.Resolve(part)
                if item then
                    services.BlendService.TryInput(owner, item, object)
                end
            end
        end)
        return function()
            connection:Disconnect()
        end
    end)
end
return BlenderInput
