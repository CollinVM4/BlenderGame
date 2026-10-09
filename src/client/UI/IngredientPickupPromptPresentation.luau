--!strict
local InputPresentation = require(script.Parent.InteractionPromptPresentation)
local Style = require(script.Parent.IngredientPickupPromptStyle)
local Shared = game:GetService("ReplicatedStorage").Shared
local Ingredients = require(Shared.Constants.Ingredients)
local MoneyFormat = require(Shared.MoneyFormat)
local IngredientName = require(Shared.IngredientName)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Presentation = {}

-- Rotated-part extents keep the label above the actual visible geometry,
-- excluding the invisible pivot root created for multipart ingredients.
function Presentation.Bounds(object: BasePart | Model): (Vector3, Vector3)
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
    if not found then
        minimum = object:GetPivot().Position
        maximum = minimum
    end
    return minimum, maximum
end

function Presentation.Top(object: BasePart | Model): Vector3
    local minimum, maximum = Presentation.Bounds(object)
    return Vector3.new((minimum.X + maximum.X) / 2, maximum.Y, (minimum.Z + maximum.Z) / 2)
end

function Presentation.MobilePosition(minimum: Vector3, maximum: Vector3): Vector3
    local center = (minimum + maximum) / 2
    local height = maximum.Y - minimum.Y
    local clearance = math.min(Style.MobileGroundClearance, height / 2)
    return Vector3.new(
        center.X,
        math.max(
            minimum.Y + clearance,
            center.Y - math.min(height * Style.MobileLowerFraction, Style.MobileMaxLowerStuds)
        ),
        center.Z
    )
end

function Presentation.Create(
    prompt: ProximityPrompt,
    object: BasePart | Model,
    definition: Ingredients.IngredientDefinition,
    parent: Instance,
    inputType: Enum.ProximityPromptInputType
): (() -> (), () -> ())
    local mobile = inputType == Enum.ProximityPromptInputType.Touch
    local inputY = Style.TitleHeight + Style.NameHeight + Style.ValueHeight + 2 * Style.RowSpacing + Style.InputSpacing
    local inputCenter = inputY + Style.InputHeight / 2
    local canvasHeight = if mobile then Style.MobileCanvasHeight else Style.BillboardSize.Y
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
        Height = canvasHeight,
        Available = function()
            local owner = object:GetAttribute("OwnerUserId")
            return object:IsDescendantOf(workspace)
                and CollectionService:HasTag(object, "IngredientWorldItem")
                and object:GetAttribute("IngredientId") == definition.Id
                and (typeof(owner) ~= "number" or owner == 0 or owner == Players.LocalPlayer.UserId)
        end,
        TouchWidth = if mobile then Style.MobileTouchSize else nil,
        TouchHeight = if mobile then Style.MobileTouchSize else nil,
        TouchCenterY = if mobile then inputCenter else nil,
        TextSize = Style.InputTextSize,
        MaxDistance = Style.MaxDistance,
    })
    gui.Name = "IngredientPickupPromptDisplay"
    gui.SizeOffset = Vector2.new(0, if mobile then (inputCenter - canvasHeight / 2) / canvasHeight else 0.5)
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
    title.Name = "Rarity"
    title.RichText = true
    local function rarityText(): string
        local ripe = object:GetAttribute("IsRipe") == true
        local stateColor = if ripe then "#FFDE73" else "#D2D6D5"
        return string.upper(rarity)
            .. ' <font color="#D2D6D5">•</font> <font color="'
            .. stateColor
            .. '">'
            .. (if ripe then "Ripe" else "Unripe")
            .. "</font>"
    end
    title.Text = rarityText()
    formatText(title, 0, Style.TitleHeight, Style.TitleTextSize, palette.TextColor, palette.StrokeColor)
    title.Parent = gui
    local label = Instance.new("TextLabel")
    label.Name, label.Text = "IngredientName", name
    local nameY = Style.TitleHeight + Style.RowSpacing
    formatText(label, nameY, Style.NameHeight, Style.NameTextSize, Style.NameColor, Style.StrokeColor)
    label.Parent = gui
    local value = Instance.new("TextLabel")
    value.Name, value.Text =
        "IngredientValue",
        MoneyFormat.Compact((object:GetAttribute("EffectiveIngredientValue") :: number?) or definition.Value)
    local valueY = nameY + Style.NameHeight + Style.RowSpacing
    formatText(value, valueY, Style.ValueHeight, Style.ValueTextSize, Style.ValueColor, Style.StrokeColor)
    value.Parent = gui
    local input = gui:FindFirstChild("Action") :: TextLabel
    formatText(
        input,
        valueY + Style.ValueHeight + Style.InputSpacing,
        Style.InputHeight,
        Style.InputTextSize,
        palette.TextColor,
        palette.StrokeColor
    )
    local function update()
        if definition.Id == "PlayerHead" then
            label.Text = IngredientName.Resolve(
                definition.Id,
                name,
                object:GetAttribute("SourceUserId"),
                object:GetAttribute("SourceDisplayName")
            )
        end
        title.Text = rarityText()
        value.Text =
            MoneyFormat.Compact((object:GetAttribute("EffectiveIngredientValue") :: number?) or definition.Value)
        if mobile then
            local minimum, maximum = Presentation.Bounds(object)
            local position = Presentation.MobilePosition(minimum, maximum)
            gui.StudsOffsetWorldSpace = position - anchor.Position
            -- Keep the visible row above the ingredient's bottom/contact plane even
            -- when a tiny ingredient or a steep camera angle compresses its height.
            local lift = 0
            local camera = workspace.CurrentCamera
            if camera then
                local point, visible = camera:WorldToViewportPoint(position)
                local bottom = camera:WorldToViewportPoint(Vector3.new(position.X, minimum.Y, position.Z))
                if visible and bottom.Z > 0 then
                    lift = math.max(0, point.Y + Style.InputHeight / 2 + 2 - bottom.Y)
                end
            end
            gui.SizeOffset = Vector2.new(0, (inputCenter - canvasHeight / 2 + lift) / canvasHeight)
        else
            gui.StudsOffsetWorldSpace = Presentation.Top(object) - anchor.Position + Style.PromptStudsOffset
        end
    end
    update()
    return cleanup, update
end

return Presentation
