-- Shares the cash presentation boundary; production model and view, no economy copy.
local model = loadModule("CashTickerModel")
local function near(a, b)
    return math.abs(a - b) < 0.000001
end
check(model.Digit(0, 0) == 0, "zero starts on zero")
check(model.Digit(95, 0) == 5 and model.Digit(95, 1) == 9.5, "wheels share the continuous value")
check(model.Digit(100, 0) == 0 and model.Digit(100, 2) == 1, "hundred carry wraps lower wheels")
check(near(model.Digit(999.5, 3), 0.9995), "new thousands wheel approaches one before carry")
check(near(model.Digit(999.5, 1), 9.95), "tens creeps toward its carry")
local state = model.New(999)
model.Retarget(state, 1000, 10)
check(model.Wheels(state, true) == 4 and state.Value == 999, "growth adds a leading wheel without resetting value")
model.Sample(state, 10.15)
local displayed = state.Value
model.Retarget(state, 1200, 10.15)
check(state.From == displayed and state.Value == displayed, "retarget keeps the rendered value")
model.Sample(state, 10.25)
check(state.Value > displayed and state.Value < 1200, "consecutive payouts continue upward")
model.Retarget(state, 1500, 10.25)
check(not model.Sample(state, 20) and state.Value == 1500, "rapid retargets settle exactly")
model.Retarget(state, 95, 20)
check(model.Wheels(state, true) == 4, "spending retains extra wheels during roll")
model.Sample(state, 20.1)
check(state.Value < 1500 and state.Value > 95, "spending rolls down")
model.Sample(state, 30)
check(model.Wheels(state, false) == 2 and state.Value == 95, "shrink removes leading wheels only at settlement")
for _, value in { 0, 9, 10, 99, 100, 999, 1000 } do
    check(model.Digits(value) == #tostring(value), "power-of-ten digit counts")
end

services.TextService = {
    GetTextSize = function(_, _, height)
        return vec(height * 0.6, height, 0)
    end,
}
-- CashTicker was loaded by the arrival module before this service was installed.
cache.CashTicker = nil
env.Enum.FillDirection = { Horizontal = "Horizontal" }
env.Enum.HorizontalAlignment = { Right = "Right" }
env.Enum.SortOrder = { LayoutOrder = "LayoutOrder" }
local ticker = loadModule("CashTicker")
local replacementLabel = replacementCash:FindFirstChild("{Coins}")
replacementLabel.Text = "$1,500"
ticker.Bind(nil, 1500)
ticker.SetTarget(2000)
check(
    replacementLabel.Visible and replacementLabel.Text == "$1,500",
    "unresolved target leaves formatted fallback intact"
)
ticker.Bind(replacementLabel, 1500)
check(
    not replacementLabel.Visible and hud.Resolve(playerGui) == replacementCash,
    "ticker replaces label while cash flight target remains active"
)
local row = replacementCash:FindFirstChild("CashTicker")
check(row and not row.Active, "ticker never consumes top bar input")
ticker.SetTarget(2000)
now += 2
render:Fire()
local function visibleDigits()
    local digits = {}
    for _, wheel in row:GetChildren() do
        if wheel.Name == "Wheel" then
            local strip = wheel:FindFirstChild("Strip")
            digits[-wheel.LayoutOrder + 1] =
                math.floor(-strip.Position.Y.Offset / replacementLabel.AbsoluteSize.Y + 0.5)
            check(not wheel.Active and wheel.ClipsDescendants and not strip.Active, "wheel clips and permits taps")
        end
    end
    return digits
end
local digits = visibleDigits()
check(digits[1] == 0 and digits[4] == 2, "view settles on exact balance")
ticker.SetTarget(9)
now += 2
render:Fire()
digits = visibleDigits()
check(#digits == 1 and digits[1] == 9, "view shrinks after spending")
ticker.Snap(425)
digits = visibleDigits()
check(digits[1] == 5 and digits[2] == 2 and digits[3] == 4, "respawn snaps every digit immediately")
ticker.Clear()
check(replacementLabel.Visible and replacementLabel.Text == "$1,500", "cleanup restores authored fallback")
local measure = services.TextService.GetTextSize
services.TextService.GetTextSize = function()
    error("font unavailable")
end
ticker.Bind(replacementLabel, 100)
check(
    replacementLabel.Visible and not replacementCash:FindFirstChild("CashTicker"),
    "construction failure preserves plain text"
)
services.TextService.GetTextSize = measure
-- A reimport replaces the bound instance, restoring the old text and snapping the new one.
ticker.Bind(replacementLabel, 95)
ticker.SetTarget(1000)
local newLabel = ui("TextLabel", "ReplacementCash", replacementCash)
newLabel.Text = "$425"
ticker.Bind(newLabel, 425)
check(replacementLabel.Visible and not newLabel.Visible, "reimport restores old label and activates replacement")
local scale = ui("UIScale", "MobileScale", replacementCash)
scale.Scale = 0.5
newLabel.AbsoluteSize = vec(180, 320, 0)
ticker.Snap(425)
local scaledRow = replacementCash:FindFirstChild("CashTicker")
local scaledWheel = scaledRow:FindFirstChild("Wheel")
check(scaledWheel.Size.Y.Offset == 640, "mobile ancestor scale applies to local cells once")
ticker.Clear()
check(newLabel.Visible and not replacementCash:FindFirstChild("CashTicker"), "replacement cleanup retains plain text")
scale:Destroy()
print("PASS: cash ticker presentation contracts")
