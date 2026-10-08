local format = loadModule("AnnouncementFormat")
local money = loadModule("MoneyFormat")
for _, case in { { 6500, "$6.5K" }, { 125000, "$125K" }, { 1000000, "$1M" }, { 1250000, "$1.25M" }, { 125, "$125" } } do
    check(money.Announcement(case[1]) == case[2], "announcement money precision " .. case[2])
end
local acquired = format.Build({ Type = "MysteryAcquired", DisplayName = "<b>A&B</b>", Priority = 10 })
check(string.find(acquired.Text, "&lt;b&gt;A&amp;B&lt;/b&gt;", 1, true) ~= nil, "player names cannot inject RichText")
local spawn = format.Build({
    Type = "RareIngredientSpawned",
    Mystery = true,
    DisplayName = "Hidden",
    LocationName = "Cloud <Garden>",
})
check(
    string.find(spawn.Text, "MYSTERY ITEM", 1, true) and string.find(spawn.Text, "Cloud &lt;Garden&gt;", 1, true),
    "spawn preserves escaped location and Mystery title"
)
local served = format.Build({ Type = "MysteryServed", DisplayName = "Player", Payout = 1250000 })
check(string.find(served.Text, "$1.25M", 1, true) ~= nil, "serve formats authoritative payout")
check(
    format.Build({ Type = "MysteryServed", DisplayName = "Player", Payout = 0 / 0 }) == nil,
    "invalid payout rejected"
)
local ordinary = format.Build({ Type = "ServerAnnouncement", Text = "World event", Priority = 0 })
local queue = {}
format.Enqueue(queue, ordinary)
format.Enqueue(queue, acquired)
local second = format.Build({ Type = "MysteryAcquired", DisplayName = "Second", Priority = 10 })
format.Enqueue(queue, second)
check(
    table.remove(queue, 1) == acquired and table.remove(queue, 1) == second and table.remove(queue, 1) == ordinary,
    "pending priority is stable FIFO within each priority"
)
format.Enqueue(queue, acquired)
check(not format.ShouldInterrupt(queue), "ordinary mystery announcements preserve the visible hold")
local warning = format.Build({
    Type = "ServerAnnouncement",
    Text = "LOOSE INGREDIENTS CLEAR IN 1 MINUTE!",
    Immediate = true,
    Priority = 100,
})
for _ = 1, 20 do
    format.Enqueue(queue, second)
end
format.Enqueue(queue, warning)
check(
    format.ShouldInterrupt(queue) and table.remove(queue, 1) == warning,
    "cleanup warning interrupts hold and bypasses backlog"
)
check(not format.ShouldInterrupt(queue) and queue[1] == acquired, "pending mystery notices retain order after warning")

local countdown = format.Build({ Type = "IngredientCleanupCountdown", EndsAt = 105, Priority = 100 })
setup(countdown ~= nil, "valid countdown deadline")
for seconds = 5, 1, -1 do
    local text = format.VisibleText(countdown, 105 - seconds)
    check(
        text
            == '<font color="#FF6666">LOOSE INGREDIENTS</font> CLEAR IN <font color="#FF6666">'
                .. tostring(seconds)
                .. (if seconds == 1 then " SECOND" else " SECONDS")
                .. "</font>!",
        "countdown highlights ingredients and remaining time in red"
    )
end
check(
    format.VisibleText(countdown, 101.6) == format.CleanupCountdownText(4),
    "delayed countdown catches up to server deadline"
)
check(
    format.VisibleText(countdown, 105) == nil and format.VisibleText(countdown, 106) == nil,
    "expired countdown disappears and cannot replay"
)
check(format.VisibleText(ordinary, 106) == ordinary.Text, "ordinary notices retain their text")
format.Enqueue(queue, countdown)
check(
    format.ShouldInterrupt(queue) and table.remove(queue, 1) == countdown,
    "final countdown bypasses backlog and interrupts ordinary hold"
)
for _, deadline in { "105", 0 / 0, math.huge, -math.huge } do
    check(
        format.Build({ Type = "IngredientCleanupCountdown", EndsAt = deadline }) == nil,
        "invalid countdown deadline rejected"
    )
end
