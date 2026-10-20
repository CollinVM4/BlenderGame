-- Smoothie-only display contracts, sharing the input/Roblox fixture above.
local smoothieView = load("SmoothiePickupPromptPresentation")
local smoothieController = load("SmoothiePickupPromptController")
smoothieController.Init()
local smoothieObject = uiInstance("Part", "SmoothieWorldItem", workspaceFake)
smoothieObject.Transparency, smoothieObject.Size = 0, vec(2, 3, 2)
services.CollectionService:AddTag(smoothieObject, "SmoothieWorldItem")
for index, id in { "Strawberry", "Banana", "Strawberry" } do
    smoothieObject:SetAttribute("IngredientId" .. index, id)
end
local smoothiePrompt = uiInstance("ProximityPrompt", "SmoothieCarryPrompt", smoothieObject)
smoothiePrompt.Style, smoothiePrompt.Enabled = "Custom", true
smoothiePrompt:SetAttribute("SmoothiePickupPrompt", true)
smoothiePrompt.KeyboardKeyCode, smoothiePrompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
smoothiePrompt.ActionText, smoothiePrompt.ClickablePrompt, smoothiePrompt.HoldDuration = "Pickup", true, 0
prompts.PromptShown:Fire(smoothiePrompt, "Keyboard")
local smoothieGui = playerGui:FindFirstChild("SmoothiePickupPromptDisplay")
check(smoothieGui ~= nil and smoothieView.Width > style.BillboardSize.X, "smoothie panel wider than fruit")
local rowCount = 0
for _, child in smoothieGui:GetChildren() do
    if string.match(child.Name, "^IngredientRow") then
        rowCount += 1
    end
end
check(rowCount == 3, "exactly three ingredient rows")
check(
    smoothieGui:FindFirstChild("SmoothieValue").Text
        == load("MoneyFormat").Compact(definitions.Strawberry.Value * 2 + definitions.Banana.Value),
    "world smoothie subtotal includes duplicate ingredients"
)
for index, id in { "Strawberry", "Banana", "Strawberry" } do
    local row = smoothieGui:FindFirstChild("IngredientRow" .. index)
    local rarity = row:FindFirstChild("Rarity")
    local name = row:FindFirstChild("IngredientName")
    check(
        rarity.Text == definitions[id].Rarity and name.Text == definitions[id].DisplayName,
        "full rarity and ingredient name without separator"
    )
    check(
        rarity.Position.X.Scale + rarity.Size.X.Scale < name.Position.X.Scale,
        "rarity first with spacing before name"
    )
    check(rarity.TextColor3 == style.RarityStyles[definitions[id].Rarity].TextColor, "existing rarity color")
    check(name.TextColor3 == style.NameColor and name.Font == style.Font, "normal ingredient name styling")
end
check(string.find(smoothieGui:FindFirstChild("Action").Text, "E") ~= nil, "existing E input presentation")
prompts.PromptHidden:Fire(smoothiePrompt)
check(playerGui:FindFirstChild("SmoothiePickupPromptDisplay") == nil, "smoothie panel hides")

local beginCount, endCount = 0, 0
function smoothiePrompt:InputHoldBegin()
    beginCount += 1
end
function smoothiePrompt:InputHoldEnd()
    endCount += 1
end
prompts.PromptShown:Fire(smoothiePrompt, "Touch")
smoothieGui = playerGui:FindFirstChild("SmoothiePickupPromptDisplay")
local target = touchTarget(smoothieGui)
check(
    not smoothieGui.Active and target.Parent.Active and target.Size.X.Scale == 1 and target.Size.Y.Scale == 1,
    "smoothie uses inactive visual and active full-quad input"
)
check(
    math.abs(target.Parent.Size.X.Scale - 14.8 * 112 / smoothieView.Width) < 0.001
        and math.abs(target.Parent.Size.Y.Scale - 6.2 * 112 / smoothieView.Height) < 0.001,
    "smoothie input size uses its own reference canvas"
)
local targetCenter = renderedCenter(smoothieGui, target)
local actionCenter = renderedCenter(smoothieGui, smoothieGui:FindFirstChild("Action"))
check(
    math.abs(targetCenter.Y - actionCenter.Y - smoothieGui.AbsoluteSize.Y * style.InputHeight / smoothieView.Height / 2)
        < 0.001,
    "smoothie input aligns after caller SizeOffset"
)
local press = { UserInputType = "Touch" }
target.InputBegan:Fire(press)
services.UserInputService.InputEnded:Fire(press)
check(beginCount == 1 and endCount == 1, "smoothie target forwards native hold API")
local inputGui = target.Parent
prompts.PromptHidden:Fire(smoothiePrompt)
check(smoothieGui.Destroyed and inputGui.Destroyed, "smoothie cleanup destroys both billboards")
print("PASS: smoothie pickup panel contracts")
