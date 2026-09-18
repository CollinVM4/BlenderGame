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
for index, id in { "Strawberry", "Banana", "Strawberry" } do
    local row = smoothieGui:FindFirstChild("IngredientRow" .. index)
    local rarity = row:FindFirstChild("Rarity")
    local name = row:FindFirstChild("IngredientName")
    check(
        rarity.Text == definitions[id].Rarity and name.Text == definitions[id].DisplayName,
        "full rarity and ingredient name without separator"
    )
    check(
        rarity.Position.X.Offset + rarity.Size.X.Offset < name.Position.X.Offset,
        "rarity first with spacing before name"
    )
    check(rarity.TextColor3 == style.RarityStyles[definitions[id].Rarity].TextColor, "existing rarity color")
    check(name.TextColor3 == style.NameColor and name.Font == style.Font, "normal ingredient name styling")
end
check(string.find(smoothieGui:FindFirstChild("Action").Text, "E") ~= nil, "existing E input presentation")
prompts.PromptHidden:Fire(smoothiePrompt)
check(playerGui:FindFirstChild("SmoothiePickupPromptDisplay") == nil, "smoothie panel hides")
print("PASS: smoothie pickup panel contracts")
