--!strict
local CustomerPresentation = {}

-- Presentation only: keys are normalized tags, never ingredient-derived colors.
-- Aliases describe wording in authored dialogue; they do not change tag validation.
CustomerPresentation.TagHighlights = {
    red = { Color = Color3.fromRGB(255, 95, 95) },
    yellow = { Color = Color3.fromRGB(255, 220, 65) },
    green = { Color = Color3.fromRGB(100, 225, 120) },
    purple = { Color = Color3.fromRGB(195, 135, 255) },
    blue = { Color = Color3.fromRGB(100, 170, 255) },
    cold = { Color = Color3.fromRGB(105, 225, 255) },
    sweet = { Color = Color3.fromRGB(255, 140, 200) },
    spicy = { Color = Color3.fromRGB(255, 140, 65), Aliases = { "spice", "heat" } },
    protein = { Color = Color3.fromRGB(235, 180, 120) },
    fruit = { Color = Color3.fromRGB(255, 175, 95), Aliases = { "fruity" } },
    seafood = { Color = Color3.fromRGB(95, 215, 200), Aliases = { "ocean", "fish" } },
    ["fast food"] = { Color = Color3.fromRGB(255, 190, 75) },
    milk = { Color = Color3.fromRGB(190, 205, 255) },
    weird = { Color = Color3.fromRGB(210, 145, 245) },
    sour = { Color = Color3.fromRGB(195, 235, 85) },
    veggie = { Color = Color3.fromRGB(135, 215, 105), Aliases = { "veggies" } },
    mushroom = { Color = Color3.fromRGB(220, 180, 145), Aliases = { "mushrooms" } },
    watermelon = { Color = Color3.fromRGB(255, 130, 155) },
    steak = { Color = Color3.fromRGB(225, 140, 120) },
} :: { [string]: { Color: Color3, Aliases: { string }? } }

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
