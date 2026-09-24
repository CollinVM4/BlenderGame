local descendants = {}
workspaceFake.GetDescendants = function()
    return descendants
end
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
services.Players.LocalPlayer = { UserId = 51 }
local model = instance("Model")
model:SetAttribute("OrderRevealed", true)
model:SetAttribute("OwnerUserId", 51)
local ownership = signal()
model.GetAttributeChangedSignal = function()
    return ownership
end
local root = instance("Part")
root.Parent = model
local head = instance("Part")
head.Parent = model
head.Position = vec(0, 3, 0)
local presentation = loadModule("CustomerPresentation")
local anchor = presentation.CreateAnchor(root, head)
local restingPosition = anchor.Position
head.Position = vec(0, 4, 0)
check(anchor.Parent == root and anchor.Position == restingPosition, "head animation cannot move UI anchor")
local order = instance("BillboardGui")
order.Name, order.Parent, order.Adornee = "OrderBubble", root, anchor
order.Size = env.UDim2.fromOffset(300, 112)
order.SizeOffset = env.Vector2.new(0, 0.5)
order.StudsOffset, order.MaxDistance = vec(0, 0, 0), 30
local expirations = {}
services.Debris.AddItem = function(_, object, seconds)
    expirations[object] = seconds
end
local result = presentation.ShowResult(order, "A", 1313, 1.75)
local main, rarity = result:FindFirstChild("Result"), result:FindFirstChild("Rarity")
check(
    math.abs((0.5 - order.SizeOffset.Y) * order.Size.Y.Offset - 32) < 0.001,
    "served reaction and reward move down 32 fixed pixels"
)
check(
    main.Text == '<font color="rgb(100,225,120)">A</font>  <font color="rgb(255,222,115)">+$1,313</font>',
    "grade and gold awarded cash occupy primary row"
)
check(rarity.Text == "Rarity Bonus x1.75" and rarity.TextSize < main.TextSize, "rarity has smaller second row")
check(rarity.Position.Y.Offset >= main.Size.Y.Offset, "result rows have separate pixel regions")
for _, text in { main, rarity } do
    check(
        text.Font == "FredokaOne" and not text.TextScaled and text:FindFirstChildOfClass("UIStroke").Thickness == 2.5,
        "rounded fixed-size result lettering with thick outline"
    )
end
check(
    not result.Enabled and result.Adornee == anchor and result.StudsOffset.Magnitude == 0,
    "result uses same stable root anchor"
)
check(
    result.Size.X.Scale == 0 and result.Size.Y.Scale == 0 and result.Size.X.Offset <= 300,
    "pixel canvas fits narrow screens"
)
-- Pixel separation translates with the common projected anchor; it cannot collapse with distance/pitch.
for _, projectedY in { 100, 240, 450 } do
    local resultBottom = projectedY - result.SizeOffset.Y * result.Size.Y.Offset + result.Size.Y.Offset / 2
    local dialogueTop = projectedY - order.SizeOffset.Y * order.Size.Y.Offset - order.Size.Y.Offset / 2
    check(
        math.abs(dialogueTop - resultBottom - 6) < 0.001,
        "result remains 6 pixels clear of reaction at any projected height"
    )
end
check(expirations[result] == 4, "result holds fully readable for four seconds")
table.insert(descendants, result)
table.insert(descendants, order)
loadModule("CustomerOrderController").Init()
check(result.Enabled and order.Enabled, "owner sees both separate displays")
model:SetAttribute("OwnerUserId", 99)
ownership:Fire()
check(not result.Enabled and not order.Enabled, "other owner cannot see either display")
model:SetAttribute("OwnerUserId", 51)
ownership:Fire()
local missed = presentation.ShowResult(order, "D", 197, 1.75)
workspaceFake.DescendantAdded:Fire(missed)
check(
    missed.Enabled
        and missed:FindFirstChild("Result").Text
            == '<font color="rgb(255,95,95)">D</font>  <font color="rgb(255,222,115)">+$197</font>',
    "missed result shows actual cash in first row"
)
check(
    missed:FindFirstChild("Retry").Text == "TRY AGAIN \u{00B7} 15% PAYOUT",
    "missed result explains consolation and retry"
)
check(
    missed:FindFirstChild("Retry").Position.Y.Offset
        >= missed:FindFirstChild("Rarity").Position.Y.Offset + missed:FindFirstChild("Rarity").Size.Y.Offset,
    "retry has a reserved row below rarity"
)
workspaceFake.DescendantRemoving:Fire(missed)
ownership:Fire()
check(not missed.Enabled, "removed result stays hidden")
local large = presentation.ShowResult(order, "A", 1234567, 2.5)
check(string.find(large:FindFirstChild("Result").Text, "+$1,234,567", 1, true) ~= nil, "multiple thousands separators")

-- Both outcomes stay above the full special card, including its name row.
local specialOrder = instance("BillboardGui")
specialOrder.Parent, specialOrder.Adornee = root, anchor
specialOrder.Size = env.UDim2.fromOffset(270, 84)
specialOrder.SizeOffset = env.Vector2.new(0, 0.5)
specialOrder.MaxDistance = 30
for _, orderGui in { order, specialOrder } do
    for _, grade in { "A", "D" } do
        local reward = presentation.ShowResult(orderGui, grade, 750, 1.5)
        local bottom = -reward.SizeOffset.Y * reward.Size.Y.Offset + reward.Size.Y.Offset / 2
        local top = -(orderGui.SizeOffset.Y + 0.5) * orderGui.Size.Y.Offset
        check(math.abs(top - bottom - 6) < 0.001, "success and failure clear regular reaction and full special card")
        local white = reward:FindFirstChild("Rarity").TextColor3
        check(white.R == 1 and white.G == 1 and white.B == 1, "rarity cannot inherit gold cash tint")
    end
end

-- Finishing a short route retains only the remaining presentation lifetime.
presentation.PreserveResult(result)
local hold
for object in expirations do
    if object.Name == "CustomerResultHold" then
        hold = object
    end
end
setup(hold ~= nil, "short exit creates a remaining result display")
check(expirations[hold] > 0 and expirations[hold] <= 4, "exit never restarts the four-second hold")
check(hold:GetAttribute("OwnerUserId") == 51, "remaining display retains owner isolation")
hold.GetAttributeChangedSignal = function()
    return signal()
end
local copy = hold:FindFirstChild("CustomerResult", true)
workspaceFake.DescendantAdded:Fire(copy)
check(copy.Enabled, "owner controller enables the remaining display")
local fixedOrigin = copy.Adornee.Parent
check(
    fixedOrigin.CFrame == root.CFrame and copy.Adornee.Position == anchor.Position,
    "remaining display uses the final stable root transform"
)
check(
    fixedOrigin.Anchored
        and not fixedOrigin.CanCollide
        and not fixedOrigin.CanTouch
        and not fixedOrigin.CanQuery
        and fixedOrigin.Transparency == 1,
    "remaining origin has no gameplay presence"
)
model:Destroy()
check(not copy.Destroyed and copy.Parent ~= nil, "customer cleanup cannot truncate the result")
result:SetAttribute("ResultExpiresAt", 0)
local count = 0
for _ in expirations do
    count += 1
end
presentation.PreserveResult(result)
local after = 0
for _ in expirations do
    after += 1
end
check(after == count, "expired results cannot be revived")
