local config = loadModule("LuckyBlockPresentation")
local gameplay = loadModule("LuckyBlockConfig")
local audio = loadModule("GameplayAudio")
for id, expected in
    {
        CashBoost = "2xCash",
        TopShelf = "TopShelf",
        StarPower = "Star",
        MegaBat = "MegaBat",
        PantryPack = "PantryPack",
        Invincibility = "Invincibility",
    }
do
    check(config.Rewards[id].Visual == expected, "reward maps to its exact imported visual name")
end
for _, reward in gameplay.Rewards do
    check(config.Rewards[reward.Id] ~= nil, "every server reward has a visual mapping")
end
check(config.Rewards.PantryPack.Visual == "PantryPack", "magnet reward maps to the authored Magnet visual")
check(
    config.TickSoundId == audio.IngredientPickupSoundId
        and config.PopSoundId == audio.IngredientThrowSoundId
        and config.PopVolume > config.TickVolume,
    "roulette reuses existing sounds with a stronger pop"
)
local sequence = loadModule("LuckyBlockSequence")
local clock = 0
local timers = {}
local function schedule(delay, callback)
    local timer = { At = clock + delay, Callback = callback }
    table.insert(timers, timer)
    return function()
        timer.Cancelled = true
    end
end
local function advance(at)
    while true do
        local nextTimer
        for _, timer in timers do
            if
                not timer.Cancelled
                and not timer.Ran
                and timer.At <= at
                and (not nextTimer or timer.At < nextTimer.At)
            then
                nextTimer = timer
            end
        end
        if not nextTimer then
            break
        end
        clock = nextTimer.At
        nextTimer.Ran = true
        nextTimer.Callback()
    end
    clock = at
end
local function view()
    local result = { Shows = {}, Fades = 0, Destroyed = false }
    result.Show = function(id, shadow)
        table.insert(result.Shows, { Id = id, Shadow = shadow, At = clock })
    end
    result.Fade = function()
        result.Fades += 1
    end
    result.Destroy = function()
        result.Destroyed = true
    end
    return result
end
local manager = sequence.new(schedule)
local first = view()
manager.Start("collector", "StarPower", true, first)
check(#first.Shows == 1 and first.Shows[1].At == 0 and first.Shows[1].Shadow, "first silhouette is immediate")
advance(0.56)
local seen = {}
check(#first.Shows == 5, "exactly five silhouettes precede reveal")
for index, shown in first.Shows do
    check(
        math.abs(shown.At - (index - 1) * 0.14) < 1e-6 and shown.Shadow and not seen[shown.Id],
        "five distinct powerups tick at the authored times"
    )
    seen[shown.Id] = true
end
advance(0.779)
check(#first.Shows == 5, "reward is not revealed early")
advance(0.78)
check(
    #first.Shows == 6 and first.Shows[6].Id == "StarPower" and not first.Shows[6].Shadow,
    "0.78-second reveal always matches the server reward"
)
advance(config.RevealSeconds + config.HoldSeconds - 0.001)
check(first.Fades == 0 and not first.Destroyed, "final reward remains for the configured hold duration")
advance(config.RevealSeconds + config.HoldSeconds)
check(first.Fades == 1, "fade starts after the configured hold duration")
advance(config.RevealSeconds + config.HoldSeconds + config.FadeSeconds)
check(first.Destroyed, "timeline releases presentation after fade")
local old, replacement = view(), view()
manager.Start("collector", "TopShelf", true, old)
manager.Start("collector", "MegaBat", true, replacement)
check(old.Destroyed, "rapid pickup replaces previous presentation")
advance(clock + 2)
check(
    #old.Shows == 1 and replacement.Shows[#replacement.Shows].Id == "MegaBat",
    "cancelled timeline cannot reveal stale rewards"
)
local observer = view()
manager.Start("observer", "PantryPack", false, observer)
check(#observer.Shows == 0, "observer has no silhouette sequence")
advance(clock + 0.78)
check(
    #observer.Shows == 1 and observer.Shows[1].Id == "PantryPack" and not observer.Shows[1].Shadow,
    "observer gets only the synchronized final reveal"
)
manager.Cancel("observer")
check(observer.Destroyed, "departure/reset cancellation releases observer view")
local delayed = view()
manager.Start("late", "CashBoost", true, delayed, 0.3)
check(
    #delayed.Shows == 1 and delayed.Shows[1].Shadow,
    "latency catches up to one current tick instead of replaying a backlog"
)
advance(clock + 0.48)
check(
    delayed.Shows[#delayed.Shows].Id == "CashBoost" and not delayed.Shows[#delayed.Shows].Shadow,
    "latency does not extend the final reveal deadline"
)
local expired = view()
check(
    not manager.Start(
            "expired",
            "CashBoost",
            true,
            expired,
            config.RevealSeconds + config.HoldSeconds + config.FadeSeconds
        ) and expired.Destroyed,
    "expired presentation is discarded"
)
local invalid = view()
check(
    not manager.Start("invalid", "FakeReward", true, invalid) and invalid.Destroyed,
    "unknown rewards are not presented"
)
manager.Destroy()
check(delayed.Destroyed, "manager teardown cancels every active timeline")
