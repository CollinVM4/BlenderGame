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
