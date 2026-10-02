local logic = loadModule("JackedNoobLogic")
local config = loadModule("JackedNoob")
local deadlines = {}
local a, b = instance("Player"), instance("Player")
local grants = { [a] = 0, [b] = 0 }
local space = true
local grantSucceeds = true
local function talk(player, now)
    return logic.TryReward(deadlines, player, now, function()
        return space
    end, function()
        if not grantSucceeds then
            return false
        end
        grants[player] += 1
        return true
    end)
end

check(config.ProteinIngredientId == "Protein" and config.ProteinCooldownSeconds == 90, "authored reward and cooldown")
check(talk(a, 100) == "Here buddy, you need this." and grants[a] == 1 and deadlines[a] == 190, "eligible grant")
check(talk(a, 101) == "Come back later.." and grants[a] == 1 and deadlines[a] == 190, "cooldown does not extend")
check(talk(b, 101) == "Here buddy, you need this." and grants[b] == 1, "players are independent")
check(talk(a, 190) == "Here buddy, you need this." and grants[a] == 2, "expiry is inclusive")

space = false
check(talk(a, 280) == "Your hands are full, buddy." and deadlines[a] == 280, "full carry does not consume cooldown")
space = true
grantSucceeds = false
check(talk(a, 280) == "Can't grab it right now, buddy." and deadlines[a] == 280, "failed commit does not consume cooldown")
grantSucceeds = true
check(talk(a, 280) == "Here buddy, you need this." and deadlines[a] == 370, "retry commits one reward")

local rng = { NextNumber = function(_, low, high)
    return high
end }
local size = vec(20, 1, 14)
local edge = logic.LocalTarget(size, config.RoamEdgeMargin, rng)
check(edge.X == 7.5 and edge.Z == 4.5, "local roam target respects inset")
local returned = logic.ReturnTarget(vec(50, 0, -30), size, config.RoamEdgeMargin)
check(returned.X == 7.5 and returned.Z == -4.5, "outside rig walks toward bounded local point")
