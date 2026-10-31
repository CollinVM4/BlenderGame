local runner = instance("Player")
runner.Character = instance("Model")
local humanoid = instance("Humanoid")
humanoid.Health, humanoid.Parent = 100, runner.Character
services.Players.GetPlayers = function()
    return { runner }
end
local heartbeat = signal()
services.RunService.Heartbeat = heartbeat
local remote = { OnServerEvent = signal() }
shared.Events.SprintEvents = "SprintEvents"
cache.SprintEvents = function()
    return remote
end
local star = false
local sprint = loadModule("SprintService")
sprint.Init({
    MovementService = {
        GetMaxStamina = function()
            return 100
        end,
        IsInitialized = function()
            return true
        end,
        CanPerformGameplayAction = function()
            return true
        end,
        IsMovementLocked = function()
            return false
        end,
        GetBaseWalkSpeed = function()
            return 26
        end,
        GetSprintWalkSpeed = function()
            return 40
        end,
        Changed = signal(),
    },
    LuckyBlockService = {
        IsBuffActive = function(p, id)
            return p == runner and id == "StarPower" and star
        end,
    },
})
sprint.ResetCharacter(runner)
remote.OnServerEvent:Fire(runner, true)
heartbeat:Fire(1)
local drained = sprint.GetSnapshot(runner).StaminaCurrent
check(drained < 100, "ordinary sprint drains")
star = true
heartbeat:Fire(1)
check(sprint.GetSnapshot(runner).StaminaCurrent == drained, "StarPower preserves partially spent stamina")
remote.OnServerEvent:Fire(runner, false)
heartbeat:Fire(0.1)
check(sprint.GetSnapshot(runner).StaminaCurrent > drained, "StarPower preserves idle regeneration")
star = false
remote.OnServerEvent:Fire(runner, true)
heartbeat:Fire(1)
check(sprint.GetSnapshot(runner).StaminaCurrent < drained, "ordinary drain resumes")
