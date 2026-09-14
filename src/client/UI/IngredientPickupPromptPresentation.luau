--!strict
local InputPresentation = require(script.Parent.InteractionPromptPresentation)
local Style = require(script.Parent.IngredientPickupPromptStyle)
local Presentation = {}

-- Rotated-part extents keep the label above the actual visible geometry,
-- excluding the invisible pivot root created for multipart ingredients.
function Presentation.Top(object: BasePart | Model): Vector3
    local minimum = Vector3.new(math.huge, math.huge, math.huge)
    local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    local found = false
    for _, part in parts do
        if part:IsA("BasePart") and part.Transparency < 1 then
            local cf, half = part.CFrame, part.Size / 2
            local extent = cf.RightVector:Abs() * half.X + cf.UpVector:Abs() * half.Y + cf.LookVector:Abs() * half.Z
            minimum = minimum:Min(part.Position - extent)
            maximum = maximum:Max(part.Position + extent)
            found = true
        end
    end
    return if found
        then Vector3.new((minimum.X + maximum.X) / 2, maximum.Y, (minimum.Z + maximum.Z) / 2)
        else object:GetPivot().Position
end

function Presentation.Create(
    prompt: ProximityPrompt,
    object: BasePart | Model,
    definition: { Id: string, DisplayName: string?, Rarity: string? },
    parent: Instance,
    inputType: Enum.ProximityPromptInputType
): (() -> (), () -> ())
    local rarity, name = Style.Resolve(definition)
    local palette = (Style.RarityStyles :: any)[rarity]
    local anchor = if object:IsA("BasePart")
        then object
        else object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    assert(anchor and anchor:IsA("BasePart"), "Ingredient presentation requires a physical part")
    -- Reuse the existing keyboard/gamepad/touch and hold lifecycle implementation.
    local cleanup, gui = InputPresentation.Create(prompt, anchor, parent, inputType, {
        InputOnly = true,
        Width = Style.BillboardSize.X,
        Height = Style.BillboardSize.Y,
        TextSize = Style.InputTextSize,
        MaxDistance = Style.MaxDistance,
    })
    gui.Name = "IngredientPickupPromptDisplay"
    gui.SizeOffset = Vector2.new(0, 0.5)
    local function formatText(
        text: TextLabel | TextButton,
        y: number,
        height: number,
        size: number,
        color: Color3,
        strokeColor: Color3
    )
        local label = text :: TextLabel
        label.Position = UDim2.fromOffset(0, y)
        label.Size = UDim2.new(1, 0, 0, height)
        label.BackgroundTransparency = 1
        label.Font = Style.Font
        label.TextSize = size
        label.TextColor3 = color
        label.TextStrokeTransparency = 1
        label.TextScaled = true
        local limit = Instance.new("UITextSizeConstraint")
        limit.MinTextSize = 12
        limit.MaxTextSize = size
        limit.Parent = label
        local stroke = Instance.new("UIStroke")
        stroke.Color = strokeColor
        stroke.Thickness = Style.StrokeThickness
        stroke.Transparency = Style.TextStrokeTransparency
        stroke.Parent = label
    end
    local title = Instance.new("TextLabel")
    title.Name, title.Text = "Rarity", string.upper(rarity)
    formatText(title, 0, Style.TitleHeight, Style.TitleTextSize, palette.TextColor, palette.StrokeColor)
    title.Parent = gui
    local label = Instance.new("TextLabel")
    label.Name, label.Text = "IngredientName", name
    local nameY = Style.TitleHeight + Style.RowSpacing
    formatText(label, nameY, Style.NameHeight, Style.NameTextSize, Style.NameColor, Style.StrokeColor)
    label.Parent = gui
    local input = gui:FindFirstChild("Action") :: TextButton
    formatText(
        input,
        nameY + Style.NameHeight + Style.InputSpacing,
        Style.InputHeight,
        Style.InputTextSize,
        palette.TextColor,
        palette.StrokeColor
    )
    local function update()
        gui.StudsOffsetWorldSpace = Presentation.Top(object) - anchor.Position + Style.PromptStudsOffset
    end
    update()
    return cleanup, update
end

return Presentation
