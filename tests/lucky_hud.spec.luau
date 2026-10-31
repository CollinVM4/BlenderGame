local messages = loadModule("LuckyBlockMessages")
local attributes = {}
local function read(name)
    return attributes[name]
end
check(#messages.Read(read, now) == 0, "rolling creates no powerup message")
attributes.LuckyBuffStarPowerExpiresAt = now + 10
local entries = messages.Read(read, now + 0.1)
check(#entries == 1 and entries[1].Text == "STAR POWER ? 10s", "countdown uses ceil of authoritative server expiry")
check(messages.Read(read, now + 9.9)[1].Text == "STAR POWER ? 1s", "fractional final second stays readable")
check(#messages.Read(read, now + 10) == 0, "expiry removes entry instead of showing zero")
attributes.LuckyBuffStarPowerExpiresAt = now + 16
check(
    #messages.Read(read, now + 6) == 1 and messages.Read(read, now + 6)[1].Text == "STAR POWER ? 10s",
    "same reward refresh replaces expiry without another entry"
)
attributes.LuckyBuffCashBoostExpiresAt = now + 90
attributes.LuckyBuffMegaBatExpiresAt = now + 15
attributes.LuckyBuffInvincibilityExpiresAt = now + 8
check(#messages.Read(read, now) == 4, "all four simultaneous buffs get separate entries")
for _, id in { "PantryPack", "TopShelf", "MysteryBox" } do
    attributes["LuckyInstant" .. id .. "Until"] = now + 2.5
end
entries = messages.Read(read, now + 1)
check(#entries == 7, "instant confirmations coexist with buffs")
for _, entry in entries do
    if string.find(entry.Text, "COLLECTED", 1, true) then
        check(not string.find(entry.Text, "s$"), "instant confirmation has no duration")
    end
end
check(#messages.Read(read, now + 3) == 4, "instant confirmations end at their server deadline")
for _, screen in { { 1280, 720 }, { 640, 360 }, { 360, 640 }, { 320, 568 } } do
    local x, y, width, row = messages.Layout(screen[1], screen[2], 7)
    check(
        y > screen[2] * 0.065 + 104
            and y + row * 7 <= screen[2] * (if screen[2] > screen[1] then 0.55 else 0.72) + 0.001,
        "stack fits below banner and above hotbar/mobile region"
    )
    check(x - width / 2 >= screen[1] * 0.3 and x + width / 2 <= screen[1] * 0.7, "stack stays in central HUD space")
end
-- Real HUD/controller boundary: style, keyed refresh, UI recreation, and local ownership.
env.UDim2.new = function(xs, xo, ys, yo)
    return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
env.Enum.ScreenInsets = { CoreUISafeInsets = "Safe" }
env.TweenInfo = {
    new = function()
        return {}
    end,
}
services.TweenService = {
    Create = function()
        return { Play = function() end, Cancel = function() end }
    end,
}
local player = instance("Player")
local other = instance("Player")
local playerGui = instance("PlayerGui")
playerGui.Parent = player
for name, value in attributes do
    player:SetAttribute(name, value)
end
other:SetAttribute("LuckyBuffStarPowerExpiresAt", now + 1000)
services.Players.LocalPlayer = player
services.RunService.Heartbeat = signal()
local controller = loadModule("LuckyBlockHudController")
controller.Init()
local gui = playerGui:FindFirstChild("LuckyPowerups")
local function row(name)
    return gui:FindFirstChild(name, true)
end
local star = row("StarPower")
check(star ~= nil and gui.ResetOnSpawn == false, "HUD survives character resets")
local label = star:FindFirstChildOfClass("TextLabel")
local style = loadModule("DialogueTextStyle")
check(
    label.Font == style.Font and label.TextColor3.R == 1 and label:FindFirstChild("DialogueOutline").Thickness == 2.5,
    "HUD reuses Fredoka white text and thick dark outline"
)
player:SetAttribute("LuckyBuffStarPowerExpiresAt", now + 20)
services.RunService.Heartbeat:Fire(0.1)
check(row("StarPower") == star and label.Text == "STAR POWER ? 20s", "refresh updates existing HUD row")
player:SetAttribute("LuckyBuffStarPowerExpiresAt", nil)
services.RunService.Heartbeat:Fire(0.1)
check(not row("StarPower"), "another player's buff cannot populate local HUD")
gui:Destroy()
services.RunService.Heartbeat:Fire(0.1)
gui = playerGui:FindFirstChild("LuckyPowerups")
check(
    gui ~= nil and row("CashBoost") ~= nil and not row("StarPower"),
    "recreated UI rebuilds only current authoritative state"
)
