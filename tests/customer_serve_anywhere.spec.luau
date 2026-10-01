-- The fixture supplies a real plot session, queue routes, and one-use cup boundary.
customer.DeactivateForPlayer(owner)
requests.RegularWildcardChance = 0

local originalConsume = deps.BlendService.ConsumeCup
local ingredients = { "Apple", "Blueberry", "Banana" }
local tags = { "Red", "Blue", "Yellow" }
for targetIndex = 1, 3 do
    customer.ActivateForPlayer(owner)
    local spawned = {}
    local assigned = {}
    for index = 1, 3 do
        local request = {
            Id = "Position" .. index,
            DisplayText = tags[index] .. " for position " .. index,
            RequiredTags = { tags[index] },
            BasePayout = index * 100,
            MinJumpTier = 0,
        }
        table.clear(requests.Definitions)
        requests.Definitions[1] = request
        assigned[index] = request
        spawned[index] = customer.SpawnForPlayer(owner)
        setup(spawned[index], "spawn customer at each marker")
        flush()
    end

    local queue = customer.GetQueueSnapshot(owner)
    check(#queue == 3, "all queue positions are occupied")
    for index, entry in queue do
        local model = spawned[index]
        local serve = model:FindFirstChild("ServePrompt", true)
        local take = model:FindFirstChild("TakeOrderPrompt", true)
        check(
            entry.Model == model and entry.Ready and entry.RequestId == assigned[index].Id,
            "each marker keeps its own ready request"
        )
        check(model:GetPivot().Position.X == index * 10, "each customer reaches its own marker")
        check(not serve.Enabled and take.Enabled, "serve remains hidden until order reveal")
        take.Triggered:Fire(foreign)
        check(
            not serve.Enabled and model:GetAttribute("OrderRevealed") ~= true,
            "foreign owner cannot reveal order"
        )
        take.Triggered:Fire(owner)
        check(
            serve.Enabled and model:GetAttribute("OrderRevealed") == true,
            "each revealed customer exposes normal serve prompt"
        )
    end

    local selected = spawned[targetIndex]
    local serve = selected:FindFirstChild("ServePrompt", true)
    check(not customer.Serve(owner, selected), "a ready customer cannot be served without a smoothie")
    local ingredient = ingredients[targetIndex]
    cup = { Ingredients = { ingredient, ingredient, ingredient }, BlendId = "position-" .. targetIndex }
    local expectedPayout = customer.CalculateOrderPayout(owner, cup, assigned[targetIndex])
    local beforeCash = tycoon.GetCash(owner)
    local beforeConsumed = consumed
    local beforeServed = days.GetSnapshot(owner).Served
    serve.Triggered:Fire(foreign)
    check(cup ~= nil and tycoon.GetCash(owner) == beforeCash, "foreign serve cannot consume or pay")
    owner.Near = false
    check(not customer.Serve(owner, selected) and cup ~= nil, "distant serve cannot consume")
    owner.Near = true

    local nestedServe = nil
    deps.BlendService.ConsumeCup = function(actor)
        local result = originalConsume(actor)
        if result then
            nestedServe = customer.Serve(actor, selected)
        end
        return result
    end
    if targetIndex == 2 then
        serve.Triggered:Fire(owner)
    else
        setup(customer.Serve(owner, selected), "selected customer serves directly")
    end
    deps.BlendService.ConsumeCup = originalConsume
    check(
        nestedServe == false and cup == nil and consumed == beforeConsumed + 1,
        "one smoothie is consumed once"
    )
    check(tycoon.GetCash(owner) == beforeCash + expectedPayout, "selected request determines one payout")
    check(days.GetSnapshot(owner).Served == beforeServed + 1, "one customer completion is counted")
    check(
        selected:GetAttribute("OrderSucceeded") == true and selected:GetAttribute("Grade") == "A",
        "selected request enters existing evaluation"
    )
    check(not customer.Serve(owner, selected), "served customer rejects replay")
    serve.Triggered:Fire(owner)
    check(
        tycoon.GetCash(owner) == beforeCash + expectedPayout and consumed == beforeConsumed + 1,
        "prompt replay cannot pay twice"
    )

    local remaining = customer.GetQueueSnapshot(owner)
    check(#remaining == 2, "only selected customer leaves active queue")
    local nextIndex = 1
    for originalIndex, model in spawned do
        if originalIndex ~= targetIndex then
            check(
                remaining[nextIndex].Model == model and remaining[nextIndex].RequestId == assigned[originalIndex].Id,
                "unserved customer and request remain in order"
            )
            nextIndex += 1
        end
    end
    flush()
    for index, entry in customer.GetQueueSnapshot(owner) do
        check(
            entry.Ready and entry.Model:GetPivot().Position.X == index * 10,
            "remaining queue compacts to distinct markers"
        )
    end
    advance(2)
    check(selected.Destroyed, "served waiting customer exits without visiting counter")
    advance(35)
    check(#customer.GetQueueSnapshot(owner) == 3, "future customer spawning refills the queue")
    customer.DeactivateForPlayer(owner)
end
