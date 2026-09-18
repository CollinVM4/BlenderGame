--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local DayButton = {}

local function existingPrompt(object: Instance, part: BasePart): ProximityPrompt?
    -- The authored prompt may be a sibling of the button, directly on its Model.
    local root: Instance? = object
    while root and root ~= workspace do
        local origin = root:FindFirstChild("StartDayTextOrigin")
        if origin and origin:IsA("Attachment") then
            local prompt = root:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                return prompt
            end
            break
        end
        root = root.Parent
    end
    return part:FindFirstChildOfClass("ProximityPrompt")
end

function DayButton.Init(services: any)
    WorldUtil.BindTag("StartDayButton", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[DayButton] Requires a BasePart")
            return nil
        end
        local authoredPrompt = existingPrompt(object, part)
        local prompt = authoredPrompt or WorldUtil.Prompt(part, "StartDayPrompt", "Start Day")
        local oldStyle = prompt.Style
        local oldOrigin = prompt:GetAttribute("InteractionOrigin")
        local oldAction = prompt:GetAttribute("InteractionActionText")
        local oldKey = prompt:GetAttribute("InteractionKeyText")
        prompt:SetAttribute("InteractionOrigin", "StartDayTextOrigin")
        prompt:SetAttribute("InteractionActionText", "START DAY")
        prompt:SetAttribute("InteractionKeyText", nil) -- Use the prompt's actual input key.
        prompt.Style = Enum.ProximityPromptStyle.Custom
        local connection = prompt.Triggered:Connect(function(player)
            if services.TycoonService.GetOwner(part) ~= player then
                return
            end
            local ok, reason = services.GameService.StartDay(player)
            player:SetAttribute("LastActionError", if ok then "" else reason)
        end)
        return function()
            connection:Disconnect()
            if authoredPrompt then
                prompt.Style = oldStyle
                prompt:SetAttribute("InteractionOrigin", oldOrigin)
                prompt:SetAttribute("InteractionActionText", oldAction)
                prompt:SetAttribute("InteractionKeyText", oldKey)
            else
                prompt:Destroy()
            end
        end
    end)
end
return DayButton
