--!strict
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local MoneyFormat = require(game:GetService("ReplicatedStorage").Shared.MoneyFormat)
local Input = require(script.Parent.InteractionPromptPresentation)
local IngredientPresentation = require(script.Parent.IngredientPickupPromptPresentation)
local Style = require(script.Parent.IngredientPickupPromptStyle)
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
local InfoHeight = 126
local Presentation = { Width = 460, Height = InfoHeight + Style.InputSpacing + Style.InputHeight }
type Row = { Id: string, Name: string }

-- Display-only ordered metadata. Never aggregate duplicate ingredients.
function Presentation.Rows(object: Instance): { Row }?
    local rows: { Row } = {}
    for index = 1, 3 do
        local id = object:GetAttribute("IngredientId" .. index)
        local definition = if typeof(id) == "string" then Definitions[id] else nil
        if not definition then
            return nil
        end
        table.insert(rows, { Id = definition.Id, Name = definition.DisplayName or definition.Id })
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
        TouchCenterY = (InfoHeight + Style.InputSpacing + Style.InputHeight / 2) / Presentation.Height,
        TextSize = Style.InputTextSize,
        MaxDistance = Style.MaxDistance,
    })
    local strokeCleanups: { () -> () } = {}
    gui.Name = "SmoothiePickupPromptDisplay"
    gui.SizeOffset = Vector2.new(0, 0.5)

    local function line(name: string, content: string, y: number, height: number, color: Color3)
        local label = Instance.new("TextLabel")
        label.Name, label.Text = name, content
        label.Position = UDim2.fromScale(0, y / Presentation.Height)
        label.Size = UDim2.fromScale(1, height / Presentation.Height)
        label.BackgroundTransparency = 1
        label.Font, label.TextScaled, label.TextColor3 = Style.Font, true, color
        local limit = Instance.new("UITextSizeConstraint")
        limit.MinTextSize, limit.MaxTextSize, limit.Parent = 1, 1000, label
        table.insert(
            strokeCleanups,
            BillboardStyle.ApplyWorldStroke(label, gui, {
                Color = Style.StrokeColor,
                ThicknessStuds = Style.StrokeThicknessStuds,
                Transparency = Style.TextStrokeTransparency,
            })
        )
        label.Parent = gui
    end

    local names = {}
    local fallbackValue = 0
    for _, row in rows do
        table.insert(names, row.Name)
        fallbackValue += Definitions[row.Id].Value
    end
    local value = object:GetAttribute("SmoothieValue")
    local colors = object:GetAttribute("SmoothieColors")
    local description = object:GetAttribute("SmoothieDescription")
    line(
        "SmoothieValue",
        MoneyFormat.Full(math.round(if type(value) == "number" then value else fallbackValue)) .. " blend value",
        0,
        36,
        Style.ValueColor
    )
    if type(colors) == "string" then
        line("SmoothieColors", "Order colors: " .. colors, 36, 30, Style.NameColor)
    end
    if type(description) == "string" then
        line("SmoothieDescription", description, 66, 27, Style.NameColor)
    end
    line("SmoothieIngredients", table.concat(names, " + "), 93, 29, Style.NameColor)

    local action = gui:FindFirstChild("Action") :: TextButton
    action.Position = UDim2.fromScale(0, (InfoHeight + Style.InputSpacing) / Presentation.Height)
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
