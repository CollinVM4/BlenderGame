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

-- Keep authored fixtures, but retire the manual gameplay interaction.
function DayButton.Init(_services: any)
    WorldUtil.BindTag("StartDayButton", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            return nil
        end
        local prompt = existingPrompt(object, part)
        if prompt then
            prompt.Enabled = false
        end
        return nil
    end)
end
return DayButton
