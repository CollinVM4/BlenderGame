--!strict
local CustomerPresentation = {}

function CustomerPresentation.HideDefaultDisplay(humanoid: Humanoid)
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
end

local function nonempty(value: any): string?
    return if type(value) == "string" and string.find(value, "%S") then value else nil
end

function CustomerPresentation.DisplayName(
    template: Model,
    special: boolean,
    configured: string?,
    identity: string?
): string
    if not special then
        return "CustomerNPC"
    end
    local humanoid = template:FindFirstChildOfClass("Humanoid")
    return (if humanoid then nonempty(humanoid.DisplayName) else nil)
        or nonempty(configured)
        or nonempty(identity)
        or template.Name
end

function CustomerPresentation.Response(request: { GoodResponse: string?, BadResponse: string? }, grade: string): string?
    if grade == "A" or grade == "B" then
        return nonempty(request.GoodResponse)
    elseif grade == "C" or grade == "D" or grade == "F" then
        return nonempty(request.BadResponse)
    end
    return nil
end

return CustomerPresentation
