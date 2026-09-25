--!strict
local TextStyle = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local CustomerPresentation = {}

local RESULT_DURATION = 4
local RESULT_GAP = 6
local RESULT_DROP = 32
local GRADE_COLORS: { [string]: string } = {
    A = "rgb(100,225,120)",
    B = "rgb(100,170,255)",
    C = "rgb(195,135,255)",
    D = "rgb(255,95,95)",
    F = "rgb(255,95,95)",
}

-- Measure once in the resting pose; never follow the animated Head or camera axes.
function CustomerPresentation.CreateAnchor(root: BasePart, head: BasePart?): Attachment
    local height = if head then head.Position.Y - root.Position.Y + head.Size.Y / 2 else root.Size.Y / 2
    local anchor = Instance.new("Attachment")
    anchor.Name = "ServePromptOrigin"
    anchor.Position = Vector3.new(0, math.max(0, height) + 0.35, 0)
    anchor.Parent = root
    return anchor
end

local function outline(text: TextLabel)
    TextStyle.Outline(text)
end

-- Both customer types share lettering; specials retain their separate name row.
local function styleDialogueText(text: TextLabel, size: number)
    text.Font = TextStyle.Font
    text.TextSize = size
    text.TextScaled = false
    text.TextWrapped = true
    text.TextColor3 = Color3.new(1, 1, 1)
    text.LineHeight = 1
    outline(text)
end

function CustomerPresentation.StyleDialogue(bubble: BillboardGui, text: TextLabel, special: boolean)
    if not special then
        bubble.Size = UDim2.fromOffset(300, 112)
        text.Size = UDim2.fromScale(1, 1)
    end
    styleDialogueText(text, 21)
    local name = bubble:FindFirstChild("CustomerName")
    if name and name:IsA("TextLabel") then
        name.Visible = special
        if special then
            styleDialogueText(name, 18)
        end
    end
end

function CustomerPresentation.ShowResult(
    order: BillboardGui,
    grade: string,
    payout: number,
    rarity: number
): BillboardGui
    -- Serving has disabled both action prompts. Lower the reaction and reward as
    -- one fixed-pixel stack, keeping their gap and special name row intact.
    order.SizeOffset = Vector2.new(order.SizeOffset.X, 0.5 - RESULT_DROP / order.Size.Y.Offset)
    local cash = tostring(payout):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    local gui = Instance.new("BillboardGui")
    gui.Name = "CustomerResult"
    gui.Adornee = order.Adornee
    gui.StudsOffset = Vector3.zero
    local height = if grade == "D" then 76 else 54
    gui.Size = UDim2.fromOffset(300, height)
    -- Same stable anchor, fixed pixel rows above the entire reaction dialogue.
    local dialogueTop = (order.SizeOffset.Y + 0.5) * order.Size.Y.Offset
    gui.SizeOffset = Vector2.new(0, (dialogueTop + height / 2 + RESULT_GAP) / height)
    gui.AlwaysOnTop = true
    gui.MaxDistance = order.MaxDistance
    gui.Enabled = false
    local function row(name: string, y: number, height: number, size: number, content: string): TextLabel
        local text = Instance.new("TextLabel")
        text.Name = name
        text.Size = UDim2.fromOffset(300, height)
        text.Position = UDim2.fromOffset(0, y)
        text.BackgroundTransparency = 1
        text.Font = TextStyle.Font
        text.TextSize = size
        text.TextScaled = false
        text.TextColor3 = Color3.new(1, 1, 1)
        text.RichText = true
        text.Text = content
        outline(text)
        text.Parent = gui
        return text
    end
    row(
        "Result",
        0,
        32,
        24,
        string.format(
            '<font color="%s">%s</font>  <font color="rgb(255,222,115)">+$%s</font>',
            GRADE_COLORS[grade] or "rgb(255,255,255)",
            grade,
            cash
        )
    )
    row("Rarity", 34, 20, 18, string.format("Rarity Bonus x%s", tostring(rarity)))
    if grade == "D" then
        local retry = row("Retry", 56, 20, 16, "TRY AGAIN \u{00B7} 15% PAYOUT")
        retry.TextColor3 = Color3.fromRGB(255, 95, 95)
    end
    gui.Parent = order.Parent
    gui:SetAttribute("ResultExpiresAt", os.clock() + RESULT_DURATION)
    game:GetService("Debris"):AddItem(gui, RESULT_DURATION)
    return gui
end

-- A short exit route must not truncate the readable hold or delay the next customer.
-- Snapshot only the presentation at the final root position before normal rig cleanup.
function CustomerPresentation.PreserveResult(gui: BillboardGui)
    local expires = gui:GetAttribute("ResultExpiresAt")
    local anchor = gui.Adornee
    if
        not gui.Parent
        or typeof(expires) ~= "number"
        or expires <= os.clock()
        or not anchor
        or not anchor:IsA("Attachment")
    then
        return
    end
    local root = anchor.Parent
    if not root or not root:IsA("BasePart") then
        return
    end
    local customer = root.Parent
    if not customer then
        return
    end
    local holder = Instance.new("Model")
    holder.Name = "CustomerResultHold"
    holder:SetAttribute("OwnerUserId", customer:GetAttribute("OwnerUserId"))
    local origin = Instance.new("Part")
    origin.Name = "ResultOrigin"
    origin.Anchored = true
    origin.Transparency = 1
    origin.CanCollide, origin.CanTouch, origin.CanQuery = false, false, false
    origin.CFrame = root.CFrame
    origin.Parent = holder
    local fixedAnchor = Instance.new("Attachment")
    fixedAnchor.Position = anchor.Position
    fixedAnchor.Parent = origin
    local copy = gui:Clone()
    copy.Enabled = false
    copy.Adornee = fixedAnchor
    copy.Parent = origin
    holder.Parent = workspace
    game:GetService("Debris"):AddItem(holder, math.max(0, expires - os.clock()))
end

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
