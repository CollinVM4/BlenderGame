-- Shares the cash presentation boundary; production tween and authored label renderer.
local model = loadModule("CashTickerModel")
local money = loadModule("MoneyFormat")
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
    check(not model.Sample(roll, roll.Duration + 1) and roll.Value == roll.Target, "final sample is exact")
end
local state = model.New(999)
model.Retarget(state, 1200, 10)
model.Sample(state, 10.15)
local displayed = state.Value
local start, from, duration = state.Start, state.From, state.Duration
model.Retarget(state, 1200, 10.15)
check(
    state.Start == start and state.From == from and state.Duration == duration,
    "same active target preserves the easing clock and origin"
)
model.Retarget(state, 1500, 10.15)
check(state.From == displayed and state.Value == displayed, "retarget keeps the last sampled value")
model.Sample(state, 10.25)
check(state.Value > displayed and state.Value < 1500, "consecutive payouts continue upward")
model.Retarget(state, 2000, 10.25)
check(not model.Sample(state, 20) and state.Value == 2000, "rapid retargets settle exactly")

local ticker = loadModule("CashTicker")
local replacementLabel = replacementCash:FindFirstChild("{Coins}")
replacementLabel.Text = "$1,500"
ticker.Bind(nil, 1500)
ticker.SetTarget(2000)
check(replacementLabel.Visible and replacementLabel.Text == "$1,500", "unbound ticker leaves label intact")
replacementLabel.Visible = false
ticker.Bind(replacementLabel, 1500)
check(
    replacementLabel.Visible and replacementLabel.Text == "$1,500" and hud.Resolve(playerGui) == replacementCash,
    "bind shows authored label and retains arrival destination"
)
local expected = model.New(1500)
ticker.SetTarget(2200)
model.Retarget(expected, 2200, now)
now += 0.15
render:Fire()
model.Sample(expected, now)
check(replacementLabel.Text == money.Full(math.floor(expected.Value + 0.5)), "view writes intermediate formatted cash")
ticker.SetTarget(2200.9)
now += 0.1
render:Fire()
model.Sample(expected, now)
check(
    replacementLabel.Text == money.Full(math.floor(expected.Value + 0.5)),
    "same-target SetTarget preserves original timing and origin after flooring"
)
ticker.SetTarget(3000)
model.Retarget(expected, 3000, now)
check(replacementLabel.Text == money.Full(math.floor(expected.Value + 0.5)), "retarget does not jump the text")
now += 0.1
render:Fire()
model.Sample(expected, now)
check(replacementLabel.Text == money.Full(math.floor(expected.Value + 0.5)), "retarget continues from last sample")
now += 2
render:Fire()
check(replacementLabel.Text == "$3,000", "view completes at exact formatted target")
replacementLabel.Text = "settled"
render:Fire()
check(replacementLabel.Text == "settled", "completed roll no longer writes text")
ticker.Snap(3000)
ticker.SetTarget(95)
now += 0.1
render:Fire()
check(
    replacementLabel.Text ~= "$3,000" and replacementLabel.Text ~= "$95",
    "spending counts down through intermediate cash"
)
now += 2
render:Fire()
check(replacementLabel.Text == "$95", "downward roll completes exactly")
ticker.SetTarget(1000)
ticker.Snap(425)
now += 2
render:Fire()
check(replacementLabel.Text == "$425" and replacementLabel.Visible, "respawn snaps immediately and stops old roll")
ticker.SetTarget(2000)
ticker.Clear()
now += 2
render:Fire()
check(replacementLabel.Visible and replacementLabel.Text == "$425", "clear leaves authored label and stops writes")
-- Reimport snaps the replacement renderer and stops writes to the previous label.
ticker.Bind(replacementLabel, 95)
ticker.SetTarget(1000)
local newLabel = ui("TextLabel", "ReplacementCash", replacementCash)
ticker.Bind(newLabel, 1234567)
now += 2
render:Fire()
check(
    replacementLabel.Visible and replacementLabel.Text == "$95" and newLabel.Visible and newLabel.Text == "$1,234,567",
    "replacement label snaps with full formatting and leaves previous renderer visible"
)
-- A transient render failure settles to the balance without hiding the label.
local originalSample = model.Sample
model.Sample = function()
    error("sample unavailable")
end
ticker.SetTarget(2000000)
render:Fire()
model.Sample = originalSample
check(newLabel.Visible and newLabel.Text == "$2,000,000", "render failure falls back to static correct balance")
ticker.Clear()
newLabel.Visible = false
ticker.Clear()
check(not newLabel.Visible, "clear never changes authored visibility")
print("PASS: cash ticker presentation contracts")
