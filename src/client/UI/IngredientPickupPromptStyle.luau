--!strict
-- All ingredient pickup appearance tuning lives here; no gameplay effects.
local Style = {
    RarityStyles = {
        Common = { TextColor = Color3.fromRGB(240, 240, 235), StrokeColor = Color3.fromRGB(20, 20, 24) },
        Uncommon = { TextColor = Color3.fromRGB(135, 245, 145), StrokeColor = Color3.fromRGB(15, 35, 22) },
        Rare = { TextColor = Color3.fromRGB(255, 212, 85), StrokeColor = Color3.fromRGB(45, 28, 12) },
        Mystery = { TextColor = Color3.fromRGB(225, 155, 255), StrokeColor = Color3.fromRGB(37, 13, 55) },
    },
    TitleTextSize = 23,
    NameTextSize = 29,
    InputTextSize = 21,
    TitleHeight = 28,
    NameHeight = 38,
    InputHeight = 34,
    RowSpacing = 2,
    InputSpacing = 6,
    BillboardSize = Vector2.new(320, 112),
    PromptStudsOffset = Vector3.new(0, 0.35, 0),
    -- Camera-distance cull only; Roblox still owns prompt activation range.
    MaxDistance = math.huge,
    HideMysteryNames = true,
    Font = Enum.Font.GothamBold,
    NameColor = Color3.fromRGB(255, 250, 235),
    StrokeColor = Color3.fromRGB(16, 16, 20),
    TextStrokeTransparency = 0.05,
    StrokeThickness = 2,
}

function Style.Resolve(definition: { Id: string, DisplayName: string?, Rarity: string? }): (string, string)
    local rarity = definition.Rarity or "Common"
    if not (Style.RarityStyles :: any)[rarity] then
        rarity = "Common"
    end
    local name = definition.DisplayName or definition.Id
    if rarity == "Mystery" and Style.HideMysteryNames then
        name = "???"
    end
    return rarity, name
end

return Style
