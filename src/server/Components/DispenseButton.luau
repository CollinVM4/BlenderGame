--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local Shared = game:GetService("ReplicatedStorage").Shared
local Debug = require(Shared.MobilePromptDebug)
local Economy = require(Shared.Constants.Economy)
local Summary = require(Shared.SmoothieSummary)
local DispenseButton = {}
function DispenseButton.Init(services: any)
    local reveal = Instance.new("RemoteEvent")
    reveal.Name = "SmoothieDispensed"
    reveal.Parent = Shared.Events
    WorldUtil.BindTag("DispenseButton", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[DispenseButton] Requires a BasePart")
            return nil
        end
        local prompt = WorldUtil.Prompt(part, "DispensePrompt", "Dispense smoothie")
        -- Match the existing authoritative dispense radius, independent of camera zoom.
        prompt.MaxActivationDistance = Economy.InteractionDistance
        prompt.HoldDuration = 0.65
        prompt:SetAttribute("InteractionOrigin", "DispenserTextOrigin")
        prompt:SetAttribute("InteractionActionText", "DISPENSE")
        prompt.Style = Enum.ProximityPromptStyle.Custom
        local audio = AudioService.CreateBlendGroup(part)
        prompt.Triggered:Connect(function(player)
            Debug.Log(prompt, "TRIGGERED", "server dispenser")
            if not services.TycoonService.IsMember(player, part) then
                Debug.Log(prompt, "REJECTED", "server: not a member of this blender")
                return
            end
            Debug.Log(prompt, "ACTION DISPATCHED", "server BlendService.Dispense")
            local context = services.TycoonService.GetRequestContext(player)
            local success, _, smoothie = services.BlendService.Dispense(player, part, context)
            if success then
                audio.pourSound:Play()
                if smoothie then
                    reveal:FireClient(player, Summary.Build(smoothie, workspace:GetServerTimeNow()))
                end
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
