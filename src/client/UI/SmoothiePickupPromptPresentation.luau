--!strict
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local MoneyFormat = require(game:GetService("ReplicatedStorage").Shared.MoneyFormat)
local Input = require(script.Parent.InteractionPromptPresentation)
local IngredientPresentation = require(script.Parent.IngredientPickupPromptPresentation)
local Style = require(script.Parent.IngredientPickupPromptStyle)
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
local Presentation = { Width = 460, Height = 160 + Style.ValueHeight + Style.InputSpacing }
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
        WidthStuds = 14.8,
        HeightStuds = 6.2,
        CanvasWidth = Presentation.Width,
        CanvasHeight = Presentation.Height,
        TouchWidth = if inputType == Enum.ProximityPromptInputType.Touch then Style.MobileTouchSize else nil,
        TouchHeight = Style.MobileTouchSize,
        TouchCenterY = (114 + Style.ValueHeight + Style.InputSpacing + Style.InputHeight / 2) / Presentation.Height,
        TextSize = Style.InputTextSize,
        MaxDistance = Style.MaxDistance,
    })
    local strokeCleanups: { () -> () } = {}
    gui.Name = "SmoothiePickupPromptDisplay"
    gui.SizeOffset = Vector2.new(0, 0.5)
    for index = 1, 3 do
        local row = rows[index]
        local palette = (Style.RarityStyles :: any)[row.Rarity]
        local container = Instance.new("Frame")
        container.Active = false
        container.Name = "IngredientRow" .. index
        container.Position = UDim2.fromScale(0, (index - 1) * 38 / Presentation.Height)
        container.Size = UDim2.fromScale(1, 36 / Presentation.Height)
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
            label.Active = false
            label.Name, label.Text = column.Name, column.Text
            label.Position = UDim2.fromScale(column.X / Presentation.Width, 0)
            label.Size = UDim2.fromScale(column.Width / Presentation.Width, 1)
            label.BackgroundTransparency = 1
            label.Font, label.TextSize, label.TextScaled = Style.Font, 25, true
            label.TextColor3, label.TextXAlignment = column.Color, column.Align
            local limit = Instance.new("UITextSizeConstraint")
            limit.MinTextSize, limit.MaxTextSize, limit.Parent = 1, 1000, label
            table.insert(
                strokeCleanups,
                BillboardStyle.ApplyWorldStroke(label, gui, {
                    Color = column.Stroke,
                    ThicknessStuds = Style.StrokeThicknessStuds,
                    Transparency = Style.TextStrokeTransparency,
                })
            )
            label.Parent = container
        end
    end
    local total = 0
    for _, row in rows do
        total += Definitions[row.Id].Value
    end
    local value = Instance.new("TextLabel")
    value.Active = false
    value.Name, value.Text = "SmoothieValue", MoneyFormat.Compact(total)
    value.Position = UDim2.fromScale(0, 114 / Presentation.Height)
    value.Size = UDim2.fromScale(1, Style.ValueHeight / Presentation.Height)
    value.BackgroundTransparency = 1
    value.Font, value.TextSize = Style.Font, Style.ValueTextSize
    value.TextColor3 = Style.ValueColor
    value.TextStrokeTransparency = 1
    value.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MinTextSize, limit.MaxTextSize, limit.Parent = 1, 1000, value
    table.insert(
        strokeCleanups,
        BillboardStyle.ApplyWorldStroke(value, gui, {
            Color = Style.StrokeColor,
            ThicknessStuds = Style.StrokeThicknessStuds,
            Transparency = Style.TextStrokeTransparency,
        })
    )
    value.Parent = gui
    local action = gui:FindFirstChild("Action") :: TextButton
    action.Position = UDim2.fromScale(0, (114 + Style.ValueHeight + Style.InputSpacing) / Presentation.Height)
    action.Size = UDim2.fromScale(1, Style.InputHeight / Presentation.Height)
    local function update()
        gui.StudsOffsetWorldSpace = IngredientPresentation.Top(object) - anchor.Position + Style.PromptStudsOffset
    end
    update()
    return function()
        for _, stop in strokeCleanups do
            stop()
        end
        cleanup()
    end,
        update
end
return Presentation
