env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
dependency.PlayerDataService.HasEntitlement = dataService.HasEntitlement
local tycoon = dependency.TycoonService
local config = loadModule("CustomerRequests")
table.clear(config.Definitions)
config.Definitions[1] =
    { Id = "Race", RequiredTags = { "Yellow" }, DisplayText = "Yellow", BasePayout = 25, MinJumpTier = 0 }
config.SpecialCustomerChance = 0
for _, operation in { "purchase", "input", "progress", "dispense", "serve" } do
    for _, transition in { "kick", "leave", "promotion", "teardown" } do
        local manager, peer = player(), player()
        tycoon.RemovePlayer(peer)
        setup(tycoon.JoinSession(peer, manager, tycoon.GetRequestContext(manager)), "race join")
        local actor = if transition == "kick" or transition == "leave" then peer else manager
        local context = tycoon.GetRequestContext(actor)
        local sessionId = context.PlotSessionId
        local input, wheel = references[manager].BlenderInput, references[manager].TurbineWheel
        tycoon.SetCash(manager, 10000)
        local cup, npc, item
        if operation == "progress" or operation == "dispense" then
            complete(manager)
            if operation == "progress" then
                blend.Reset(manager)
                for _ = 1, 3 do
                    local source = ingredients.Spawn("Banana", frame(), manager, true)
                    input.Overlaps = { source }
                    setup(blend.TryInput(manager, source, input), "ready batch")
                end
            end
        elseif operation == "input" then
            item = ingredients.Spawn("Banana", frame(), actor, true)
            input.Overlaps = { item }
        elseif operation == "serve" then
            grant(actor, "race-cup")
            customer.ActivateForPlayer(manager)
            npc = customer.SpawnForPlayer(manager)
            flush()
        end
        local cleanup, invalid, transitioned = 0, false, false
        tycoon.Init({
            SessionEnded = function(id)
                cleanup += 1
                invalid = tycoon.GetSessionOwner(id) == nil
                customer.CleanupSession(id)
                blend.CleanupSession(id)
            end,
        })
        local function change()
            if transitioned then
                return
            end
            transitioned = true
            if transition == "kick" then
                tycoon.Kick(manager, peer, tycoon.GetRequestContext(manager))
            elseif transition == "leave" then
                tycoon.RemovePlayer(peer)
            elseif transition == "promotion" then
                tycoon.RemovePlayer(manager)
            else
                tycoon.RemovePlayer(peer)
                tycoon.RemovePlayer(manager)
            end
        end
        local restore
        if operation == "input" then
            local original = ingredients.Consume
            ingredients.Consume = function(...)
                change()
                return original(...)
            end
            restore = function()
                ingredients.Consume = original
            end
        elseif operation == "dispense" then
            local original = inventory.GrantSmoothie
            inventory.GrantSmoothie = function(...)
                change()
                return original(...)
            end
            restore = function()
                inventory.GrantSmoothie = original
            end
        elseif operation == "serve" then
            local original = blend.ConsumeCup
            blend.ConsumeCup = function(...)
                change()
                return original(...)
            end
            restore = function()
                blend.ConsumeCup = original
            end
        else
            local original = actor.SetAttribute
            actor.SetAttribute = function(self, attribute, value)
                original(self, attribute, value)
                if
                    (operation == "purchase" and attribute == "playerCash")
                    or (operation == "progress" and attribute == "BlendState")
                then
                    change()
                end
            end
            restore = function()
                actor.SetAttribute = original
            end
        end
        local function act()
            if operation == "purchase" then
                return tycoon.PurchaseUpgrade(actor, "Jump", 2, context)
            elseif operation == "input" then
                return blend.TryInput(actor, item, input, context)
            elseif operation == "progress" then
                return blend.AddProgress(actor, wheel, loadModule("Economy").RequiredProgress, context)
            elseif operation == "dispense" then
                return blend.Dispense(actor, wheel, context)
            else
                return customer.Serve(actor, npc, context)
            end
        end
        check(act() and transitioned, operation .. " commits once before reentrant " .. transition)
        restore()
        check(not act(), operation .. " rejects old membership after " .. transition)
        if transition == "teardown" then
            check(
                cleanup == 1 and invalid and tycoon.GetSessionOwner(sessionId) == nil,
                "teardown cleans once after invalidation"
            )
        else
            local survivor = tycoon.GetSessionOwner(sessionId)
            check(survivor ~= nil and cleanup == 0, "nonfinal transition retains session")
            if operation == "purchase" then
                check(
                    tycoon.GetCash(survivor) == 8000 and tycoon.GetUpgrade(survivor, "Jump") == 2,
                    "purchase remains committed"
                )
            elseif operation == "input" then
                check(#blend.GetSnapshot(survivor).Ingredients == 1, "contribution remains committed")
            elseif operation == "progress" then
                check(blend.GetSnapshot(survivor).State == "COMPLETE", "progress remains committed")
            elseif operation == "dispense" then
                check(
                    blend.GetCup(actor) ~= nil and blend.GetSnapshot(survivor).State == "DISPENSED",
                    "actor receives single committed dispense"
                )
            else
                check(
                    npc:GetAttribute("Grade") == "A" and blend.GetCup(actor) == nil and tycoon.GetCash(survivor) > 10000,
                    "serve remains committed"
                )
            end
            tycoon.RemovePlayer(survivor)
        end
        flush()
    end
end
