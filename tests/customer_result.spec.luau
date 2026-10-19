local presentation = loadModule("CustomerPresentation")
local model = instance("Model")
model:SetAttribute("OwnerUserId", 51)
model:SetAttribute("PlotSessionId", "session")
local root = instance("Part")
root.Parent = model
local head = instance("Part")
head.Position = vec(0, 3, 0)
local anchor = presentation.CreateAnchor(root, head)
local rewardAnchor = root:FindFirstChild("CustomerRewardOrigin")
local resting = rewardAnchor.Position
check(resting.Y == 2.65, "cash anchor sits 0.35 studs below resting head center")
head.Position = vec(0, 5, 0)
check(rewardAnchor.Position == resting, "head animation cannot move cash anchor")
local expirations = {}
services.Debris.AddItem = function(_, object, seconds)
    expirations[object] = seconds
end
local order = instance("BillboardGui")
order.Parent, order.Adornee = root, anchor
order.Size, order.SizeOffset = env.UDim2.fromScale(7, 2.6), env.Vector2.new(0, 0.5)
order.MaxDistance = 30
local result = presentation.ShowResult(order, "A", 1313, 4500)
check(
    result:FindFirstChild("Result").Text
        == '<font color="rgb(100,225,120)">A</font> \u{00B7} <font color="rgb(255,222,115)">+$1,313</font>',
    "grade and final cash share one row"
)
check(not result:FindFirstChild("Ingredients"), "no ingredient subtotal or second cash amount")
check(result.Adornee == rewardAnchor and result.StudsOffset.Magnitude == 0, "cash uses its stable body attachment")
local text = result:FindFirstChild("Result")
check(
    text.Font == "FredokaOne" and text.TextScaled and text:FindFirstChildOfClass("UIStroke").Thickness == 2.5,
    "existing readable lettering retained"
)
check(expirations[result] == 4, "existing four-second hold retained")
for _, size in { 84, 112 } do
    order.Size = env.UDim2.fromScale(8, size / 37.5)
    for _, grade in { "A", "B", "C", "D" } do
        local gui = presentation.ShowResult(order, grade, 197, 4500)
        local primaryCenter = -gui.SizeOffset.Y - 0.5 + gui:FindFirstChild("Result").Size.Y.Scale / 2
        check(math.abs(primaryCenter) < 0.001, "grade and special-card height cannot lift cash row")
        check(not gui:FindFirstChild("Ingredients"), "all grades omit ingredient subtotal")
        if grade == "D" then
            check(
                gui:FindFirstChild("Retry").Position.Y.Scale >= gui:FindFirstChild("Result").Size.Y.Scale,
                "retry stays separate below payout"
            )
        end
    end
end
local wildcard = presentation.ShowResult(order, nil, 1234567, 6500)
check(
    wildcard:FindFirstChild("Result").Text == '<font color="rgb(255,222,115)">+$1,234,567</font>'
        and not wildcard:FindFirstChild("Retry"),
    "wildcard has only cash and no letter grade"
)
local debit = presentation.ShowResult(order, nil, -500)
check(
    debit:FindFirstChild("Result").Text == '<font color="rgb(255,95,95)">-$500</font>',
    "freeloader debit keeps actual signed amount"
)
presentation.PreserveResult(result)
local hold
for object in expirations do
    if object.Name == "CustomerResultHold" then
        hold = object
    end
end
setup(hold ~= nil, "short exit retains presentation")
check(expirations[hold] > 0 and expirations[hold] <= 4, "exit does not restart reward lifetime")
check(hold:GetAttribute("PlotSessionId") == "session", "remaining display retains shared-plot visibility")
local copy = hold:FindFirstChild("CustomerResult", true)
check(
    copy.Adornee.Position == resting and copy.Adornee.Parent.CFrame == root.CFrame,
    "exit preserves final cash anchor"
)
model:Destroy()
check(not copy.Destroyed, "customer cleanup cannot truncate payout text")

result:SetAttribute("ResultExpiresAt", 0)
local before = 0
for _ in expirations do
    before += 1
end
presentation.PreserveResult(result)
local after = 0
for _ in expirations do
    after += 1
end
check(before == after, "expired results cannot restart their hold")
