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
for _, carry in { { 200, 2 }, { 200, 0 }, { 200, 1 }, { 1000, 2 } } do
    local value, place = carry[1], carry[2]
    local before = model.Phase(value - 0.01, place, true)
    local after = model.Phase(value + 0.01, place, true)
    local advance = (after - before) % 10
    check(advance > 0 and advance < 1, "carry advances less than one cell modulo the repeating cycle")
    check(before >= 10 and before < 20 and after >= 10 and after < 20, "rolling uses the middle cycle")
    check(model.Phase(value, place, false) % 1 == 0, "settled phases seat on whole cells")
end
local state = model.New(999)
model.Retarget(state, 1000, 10)
check(model.Wheels(state, true) == 4 and state.Value == 999, "growth adds a leading wheel without resetting value")
model.Sample(state, 10.15)
local displayed = state.Value
local start, from, duration = state.Start, state.From, state.Duration
model.Retarget(state, 1000, 10.15)
check(
    state.Start == start and state.From == from and state.Duration == duration,
    "same active target preserves the easing clock and origin"
)
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
for _, balances in { { 1950, 2200 }, { 2200, 1950 } } do
    local roll = model.New(balances[1])
    model.Retarget(roll, balances[2], 0)
    local direction = if balances[2] > balances[1] then 1 else -1
    for step = 1, 100 do
        local previous = roll.Value
        model.Sample(roll, roll.Duration * step / 100)
        check((roll.Value - previous) * direction >= 0, "cash moves monotonically in either direction")
        check((roll.Target - roll.Value) * direction >= 0, "cash never passes the target")
    end
    check(roll.Value == roll.Target, "cash settles exactly at the end of easing")
end

services.TextService = {
    GetTextSize = function(_, _, height)
        return vec(height * 0.6, height, 0)
    end,
}
-- CashTicker was loaded by the arrival module before this service was installed.
cache.CashTicker = nil
env.Enum.FillDirection = { Horizontal = "Horizontal" }
env.Enum.HorizontalAlignment = { Center = "Center" }
env.Enum.SortOrder = { LayoutOrder = "LayoutOrder" }
-- Supply the strip's measured geometry; the CLI fixture does not run Roblox layout.
local createUI = env.Instance.new
env.Instance.new = function(class)
    local object = createUI(class)
    if class == "Frame" then
        object.AbsoluteSize = vec(360, 21 * 640, 0)
    end
    return object
end
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
check(row:FindFirstChildOfClass("UIListLayout").HorizontalAlignment == "Center", "cash digits are centered")
ticker.SetTarget(2000)
local expected = model.New(1500)
model.Retarget(expected, 2000, now)
now += 0.15
render:Fire()
ticker.SetTarget(2000.9)
now += 0.1
render:Fire()
model.Sample(expected, now)
local rollingStrip = row:FindFirstChild("Wheel"):FindFirstChild("Strip")
check(
    near(-rollingStrip.Position.Y.Offset / (rollingStrip.AbsoluteSize.Y / 21), model.Phase(expected.Value, 0, true)),
    "same-target SetTarget poke preserves the original roll timing after flooring"
)
now += 2
render:Fire()
local function visibleDigits()
    local digits = {}
    for _, wheel in row:GetChildren() do
        if wheel.Name == "Wheel" then
            local strip = wheel:FindFirstChild("Strip")
            digits[-wheel.LayoutOrder + 1] = math.floor(-strip.Position.Y.Offset / (strip.AbsoluteSize.Y / 21) + 0.5)
                % 10
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
check(scaledWheel.Size.Y.Offset == 320, "clip window follows the label's measured height")
for _, wheel in scaledRow:GetChildren() do
    if wheel.Name == "Wheel" then
        wheel:FindFirstChild("Strip").AbsoluteSize = vec(180, 21 * 321.25, 0)
    end
end
ticker.Snap(425)
for _, wheel in scaledRow:GetChildren() do
    if wheel.Name == "Wheel" then
        local strip = wheel:FindFirstChild("Strip")
        local phase = -strip.Position.Y.Offset / 321.25
        check(near(phase % 1, 0) and phase >= 10, "every wheel seats inline from measured strip pitch")
        check(strip:FindFirstChild("Digit").TextSize == 321.25, "glyph size follows measured pitch")
        check(#strip:GetChildren() == 21, "cyclic strip includes both cycles and trailing zero")
    end
end
ticker.Clear()
check(newLabel.Visible and not replacementCash:FindFirstChild("CashTicker"), "replacement cleanup retains plain text")
scale:Destroy()
print("PASS: cash ticker presentation contracts")
