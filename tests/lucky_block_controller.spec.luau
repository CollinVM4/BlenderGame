local config = loadModule("LuckyBlockPresentation")
env.typeof = function(value)
    return if getmetatable(value) == vector then "Vector3" else typeof(value)
end
local timers = {}
env.task.delay = function(seconds, callback)
    local timer = { At = now + seconds, Callback = callback }
    table.insert(timers, timer)
    return timer
end
env.task.cancel = function(timer)
    timer.Cancelled = true
end
local function advance(seconds)
    local untilAt = now + seconds
    while true do
        local soonest
        for _, timer in timers do
            if
                not timer.Cancelled
                and not timer.Ran
                and timer.At <= untilAt
                and (not soonest or timer.At < soonest.At)
            then
                soonest = timer
            end
        end
        if not soonest then
            break
        end
        now = soonest.At
        soonest.Ran = true
        soonest.Callback()
    end
    now = untilAt
end
local views = {}
cache.LuckyBlockView = {
    Create = function(position, finalOnly)
        local view = { Position = position, FinalOnly = finalOnly, Shows = {} }
        view.Show = function(id, shadow)
            table.insert(view.Shows, { Id = id, Shadow = shadow })
        end
        view.Fade = function()
            view.Faded = true
        end
        view.Destroy = function()
            view.Destroyed = true
        end
        table.insert(views, view)
        return view
    end,
}
local function subject(id)
    local player = instance("Player")
    player.UserId = id
    local character = instance("Model")
    character.Parent, player.Character = workspaceFake, character
    local humanoid = instance("Humanoid")
    humanoid.Health, humanoid.Parent, humanoid.Died = 100, character, signal()
    return player, humanoid
end
local collector, humanoid = subject(1)
local other, otherHumanoid = subject(2)
services.Players.LocalPlayer = collector
services.Players.PlayerRemoving = signal()
services.Players.GetPlayerByUserId = function(_, id)
    return if id == 2 then other else collector
end
local gui = instance("PlayerGui")
gui.Parent = collector
local pickup = instance("RemoteEvent")
pickup.Name, pickup.Parent, pickup.OnClientEvent = "LuckyBlockPickedUp", shared.Events, signal()
local nearby = instance("RemoteEvent")
nearby.Name, nearby.Parent, nearby.OnClientEvent = config.NearbyEventName, shared.Events, signal()
shared.Events.WaitForChild = shared.Events.FindFirstChild
services.ContentProvider = { PreloadAsync = function() end }
services.ReplicatedStorage.FindFirstChild = function()
    return nil
end
local controller = loadModule("LuckyBlockRouletteController")
controller.Init()
controller.Init()
flush()
local function message(player, id, reward)
    return {
        UserId = player.UserId,
        Character = player.Character,
        RewardId = reward or "IngredientMagnet",
        PickupId = id,
        PickedUpAt = now,
        Position = vec(12, 6, 9),
    }
end
pickup.OnClientEvent:Fire(message(collector, 1))
check(#views == 1 and #views[1].Shows == 1, "collector starts one full sequence after repeated controller Init")
collector.Character:PivotTo(frame(100, 0, 0))
check((views[1].Position - vec(12, 6, 9)).Magnitude == 0, "running away does not move the collection-location roulette")
advance(0.15)
pickup.OnClientEvent:Fire(message(collector, 2, "MegaBat"))
check(views[1].Destroyed and #views == 2, "second pickup disposes the old roulette")
advance(0.78)
check(
    views[2].Shows[#views[2].Shows].Id == "MegaBat" and not views[2].Shows[#views[2].Shows].Shadow,
    "collector reveals the authoritative second reward"
)
pickup.OnClientEvent:Fire(message(collector, 2))
check(#views == 2, "duplicate notifications cannot replace a valid presentation")
humanoid.Health = 0
humanoid.Died:Fire()
check(views[2].Destroyed, "death destroys active presentation")
local oldCharacter = collector.Character
collector.CharacterRemoving:Fire(oldCharacter)
local _, freshHumanoid = subject(3)
collector.Character = freshHumanoid.Parent
humanoid = freshHumanoid
local stale = message(collector, 3)
stale.Character = oldCharacter
pickup.OnClientEvent:Fire(stale)
check(#views == 2, "old-character pickup cannot attach to replacement avatar")
pickup.OnClientEvent:Fire(message(collector, 4))
collector.CharacterRemoving:Fire(oldCharacter)
check(not views[3].Destroyed, "stale old-character removal cannot cancel the replacement avatar's roulette")
collector.CharacterRemoving:Fire(collector.Character)
check(views[3].Destroyed, "reset cancels the new character's presentation")
nearby.OnClientEvent:Fire(message(other, 5, "DoubleCash"))
check(#views == 4 and #views[4].Shows == 0, "nearby notification schedules no silhouette ticks")
check(
    views[4].FinalOnly == "DoubleCash" and (views[4].Position - views[1].Position).Magnitude == 0,
    "nearby final-only view uses the same server collection position"
)
advance(0.78)
check(
    #views[4].Shows == 1 and views[4].Shows[1].Id == "DoubleCash" and not views[4].Shows[1].Shadow,
    "nearby player sees only the final server-selected reward"
)
services.Players.PlayerRemoving:Fire(other)
check(views[4].Destroyed, "player departure destroys observer presentation")
other.Character.Parent = workspaceFake
nearby.OnClientEvent:Fire(message(other, 6))
other.Character.Parent = nil
other.Character.AncestryChanged:Fire()
check(views[5].Destroyed, "character streaming/removal cancels pending reveal safely")
advance(2)
check(#views[5].Shows == 0, "cancelled observer never reappears from stale callbacks")
collector.Character.Parent = workspaceFake
pickup.OnClientEvent:Fire(message(collector, 7))
advance(1.7)
check(views[6].Destroyed and views[6].Faded, "normal completion fades and destroys all presentation resources")
local invalid = message(collector, 8)
invalid.Position = nil
pickup.OnClientEvent:Fire(invalid)
check(#views == 6, "missing collection position cannot fall back to the avatar's location")
