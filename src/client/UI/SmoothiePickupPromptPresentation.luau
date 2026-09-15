--!strict
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local Input = require(script.Parent.InteractionPromptPresentation)
local IngredientPresentation = require(script.Parent.IngredientPickupPromptPresentation)
local Style = require(script.Parent.IngredientPickupPromptStyle)
local Presentation = { Width = 460, Height = 160 }
type Row = { Id: string, Name: string, Rarity: string }

-- Display-only ordered metadata. Never aggregate duplicate ingredients.
function Presentation.Rows(object: Instance): { Row }?
    local rows: { Row } = {}
    for index = 1, 3 do
        local id = object:GetAttribute("IngredientId" .. index)
        local definition = if typeof(id) == "string" then Definitions[id] else nil
        if not definition then
            return nil
        end
        local rarity = Style.Resolve(definition)
        table.insert(rows, { Id = definition.Id, Name = definition.DisplayName or definition.Id, Rarity = rarity })
    end
    return rows
end

function Presentation.Create(
    prompt: ProximityPrompt,
    object: BasePart | Model,
    rows: { Row },
    parent: Instance,
    inputType: Enum.ProximityPromptInputType
): (() -> (), () -> ())
    local anchor = if object:IsA("BasePart")
        then object
        else object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
    assert(anchor and anchor:IsA("BasePart"))
    local cleanup, gui = Input.Create(prompt, anchor, parent, inputType, {
        InputOnly = true,
        Width = Presentation.Width,
        Height = Presentation.Height,
        TextSize = Style.InputTextSize,
        MaxDistance = Style.MaxDistance,
    })
    gui.Name = "SmoothiePickupPromptDisplay"
    gui.SizeOffset = Vector2.new(0, 0.5)
    for index = 1, 3 do
        local row = rows[index]
        local palette = (Style.RarityStyles :: any)[row.Rarity]
        local container = Instance.new("Frame")
        container.Name = "IngredientRow" .. index
        container.Position = UDim2.fromOffset(0, (index - 1) * 38)
        container.Size = UDim2.new(1, 0, 0, 36)
        container.BackgroundTransparency = 1
        container.Parent = gui
        for _, column in
            {
                {
                    Name = "Rarity",
                    Text = row.Rarity,
                    X = 0,
                    Width = 170,
                    Color = palette.TextColor,
                    Stroke = palette.StrokeColor,
                    Align = Enum.TextXAlignment.Right,
                },
                {
                    Name = "IngredientName",
                    Text = row.Name,
                    X = 186,
                    Width = Presentation.Width - 186,
                    Color = Style.NameColor,
                    Stroke = Style.StrokeColor,
                    Align = Enum.TextXAlignment.Left,
                },
            }
        do
            local label = Instance.new("TextLabel")
            label.Name, label.Text = column.Name, column.Text
            label.Position = UDim2.fromOffset(column.X, 0)
            label.Size = UDim2.fromOffset(column.Width, 36)
            label.BackgroundTransparency = 1
            label.Font, label.TextSize, label.TextScaled = Style.Font, 25, true
            label.TextColor3, label.TextXAlignment = column.Color, column.Align
            local limit = Instance.new("UITextSizeConstraint")
            limit.MinTextSize, limit.MaxTextSize, limit.Parent = 12, 25, label
            local stroke = Instance.new("UIStroke")
            stroke.Color, stroke.Thickness = column.Stroke, Style.StrokeThickness
            stroke.Transparency, stroke.Parent = Style.TextStrokeTransparency, label
            label.Parent = container
        end
    end
    local action = gui:FindFirstChild("Action") :: TextButton
    action.Position = UDim2.fromOffset(0, 120)
    action.Size = UDim2.new(1, 0, 0, Style.InputHeight)
    local function update()
        gui.StudsOffsetWorldSpace = IngredientPresentation.Top(object) - anchor.Position + Style.PromptStudsOffset
    end
    update()
    return cleanup, update
end
return Presentation
