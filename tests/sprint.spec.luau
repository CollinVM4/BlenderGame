-- Real sprint/controller/movement modules, fake engine signals; no client state listener.
local function countedSignal()
    local event = signal()
    local connect = event.Connect
    event.ConnectionCount = 0
    function event:Connect(callback)
        self.ConnectionCount += 1
        return connect(self, callback)
    end
    return event
end
local heartbeat = countedSignal()
services.RunService.Heartbeat = heartbeat
local runner = instance("Player")
runner.Parent = services.Players
services.Players.GetPlayers = function()
    return { runner }
end
local character = instance("Model")
local humanoid = instance("Humanoid")
humanoid.Parent = character
humanoid.Health = 100
humanoid.UseJumpPower = true
runner.Character = character
local oldNew = env.Instance.new
env.Instance.new = function(class)
    local object = oldNew(class)
    if class == "BindableEvent" then
        function object:Fire(...)
            self.Event:Fire(...)
        end
    end
    return object
end
local serverSends = 0
local requests = {}
local remote = {
    OnServerEvent = countedSignal(),
    FireClient = function()
        serverSends += 1
    end,
    FireAllClients = function()
        serverSends += 1
    end,
}
function remote:FireServer(value)
    table.insert(requests, value)
    self.OnServerEvent:Fire(runner, value)
end
shared.Events.SprintEvents = "SprintEvents"
cache.SprintEvents = function()
    return remote
end
local data = loadModule("PlayerDataService")
local movement = loadModule("MovementService")
local sprint = loadModule("SprintService")
local config = loadModule("SprintConfig")
data.AddPlayer(runner)
local deps = { PlayerDataService = data, MovementService = movement }
movement.Init(deps)
sprint.Init(deps)
-- A repeated bootstrap must neither duplicate callbacks nor replace live dependencies.
sprint.Init({})
check(
    heartbeat.ConnectionCount == 1 and remote.OnServerEvent.ConnectionCount == 1,
    "server initializes one heartbeat and request listener"
)
movement.RefreshPlayer(runner)
sprint.ResetCharacter(runner)
local maximum = movement.GetMaxStamina(runner)
local function tick(dt)
    now += dt
    heartbeat:Fire(dt)
end
for _ = 1, 2048 do
    tick(1 / 60)
end
check(serverSends == 0, "2048 idle frames send no events, even without a client listener")
check(runner:GetAttribute("StaminaCurrent") == maximum, "idle stamina stays full")
remote.OnServerEvent:Fire(runner, true)
tick(1)
check(
    runner:GetAttribute("StaminaCurrent") == maximum - config.STAMINA_DRAIN_RATE,
    "one drain per tick after duplicate Init"
)
check(humanoid.WalkSpeed == movement.GetSprintWalkSpeed(runner), "server resolves sprint speed")
runner:SetAttribute("StaminaCurrent", 99999)
runner:SetAttribute("StaminaMax", 99999)
runner:SetAttribute("SprintWalkSpeed", 99999)
remote.OnServerEvent:Fire(runner, { stamina = 99999 })
tick(0)
check(sprint.GetSnapshot(runner).IsSprinting, "malformed intent cannot stop sprint")
check(
    runner:GetAttribute("StaminaCurrent") == maximum - config.STAMINA_DRAIN_RATE,
    "forged attributes cannot refill stamina"
)
check(
    runner:GetAttribute("StaminaMax") == maximum and humanoid.WalkSpeed == movement.GetSprintWalkSpeed(runner),
    "forged attributes cannot upgrade movement"
)
data.AddCash(runner, 10000)
check(data.PurchaseUpgrade(runner, "MovementSpeed"), "speed purchase succeeds")
check(data.PurchaseUpgrade(runner, "SprintStamina"), "stamina purchase succeeds")
movement.RefreshPlayer(runner)
maximum = movement.GetMaxStamina(runner)
check(runner:GetAttribute("StaminaCurrent") == maximum - config.STAMINA_DRAIN_RATE, "upgrade adds only capacity delta")
check(humanoid.WalkSpeed == movement.GetSprintWalkSpeed(runner), "upgrade applies during sprint")
runner:SetAttribute("StunnedUntil", now + 2)
tick(0)
check(humanoid.WalkSpeed == 0, "stun retains speed precedence")
tick(2)
check(humanoid.WalkSpeed == movement.GetSprintWalkSpeed(runner), "stun expiry restores resolved speed")
tick(100)
check(
    not sprint.GetSnapshot(runner).IsSprinting and runner:GetAttribute("StaminaCurrent") == 0,
    "exhaustion stops sprint"
)
remote.OnServerEvent:Fire(runner, true)
check(not sprint.GetSnapshot(runner).IsSprinting, "empty stamina rejects restart")
tick(1)
check(runner:GetAttribute("StaminaCurrent") == config.STAMINA_REGEN_RATE, "server regenerates stamina")
humanoid.Health = 0
remote.OnServerEvent:Fire(runner, true)
check(not sprint.GetSnapshot(runner).IsSprinting, "dead character rejects sprint")
runner.Character = nil
remote.OnServerEvent:Fire(runner, true)
check(not sprint.GetSnapshot(runner).IsSprinting, "missing character rejects sprint")
runner.Character = character
humanoid.Health = 100
sprint.ResetCharacter(runner)
check(
    runner:GetAttribute("StaminaCurrent") == maximum and not runner:GetAttribute("IsSprinting"),
    "respawn fills authoritative capacity and stops sprint"
)

local input = { InputBegan = countedSignal(), InputEnded = countedSignal(), WindowFocusReleased = countedSignal() }
services.UserInputService = input
env.Enum.KeyCode = { LeftShift = "LeftShift", RightShift = "RightShift", A = "A" }
local controller = loadModule("SprintController")
controller.Init()
controller.Init()
check(
    input.InputBegan.ConnectionCount == 1
        and input.InputEnded.ConnectionCount == 1
        and input.WindowFocusReleased.ConnectionCount == 1,
    "client initializes one listener per input signal"
)
local left, right = { KeyCode = "LeftShift" }, { KeyCode = "RightShift" }
input.InputBegan:Fire(left, true)
input.InputEnded:Fire(left, true)
input.InputBegan:Fire({ KeyCode = "A" }, false)
check(#requests == 0, "processed/unrelated input sends no sprint requests")
input.InputBegan:Fire(left, false)
input.InputBegan:Fire(left, false)
input.InputBegan:Fire(right, false)
check(#requests == 1 and requests[1] == true, "one start across duplicate Init, repeated input and both Shift keys")
for _ = 1, 2048 do
    tick(1 / 60)
end
check(#requests == 1 and serverSends == 0, "2048 held frames send no requests or state events")
check(not sprint.GetSnapshot(runner).IsSprinting, "held input does not restart exhausted sprint")
input.InputEnded:Fire(left, false)
check(#requests == 1, "releasing one Shift keeps remaining Shift intent")
input.InputEnded:Fire(right, true)
check(#requests == 2 and requests[2] == false, "last release sends one stop even when processed")
input.InputEnded:Fire(right, false)
check(#requests == 2, "duplicate release sends no request")
input.InputBegan:Fire(left, false)
tick(0)
check(#requests == 3 and sprint.GetSnapshot(runner).IsSprinting, "fresh press restarts after regeneration")
input.WindowFocusReleased:Fire()
input.WindowFocusReleased:Fire()
input.InputEnded:Fire(left, false)
tick(0)
check(
    #requests == 4 and requests[4] == false and not sprint.GetSnapshot(runner).IsSprinting,
    "focus loss stops once and clears held keys"
)
check(humanoid.WalkSpeed == movement.GetBaseWalkSpeed(runner), "stop restores upgraded base speed")
check(serverSends == 0, "server never sends SprintRequest during any lifecycle")
sprint.RemovePlayer(runner)
services.Players.GetPlayers = function()
    return {}
end
tick(1)
print(string.format("PASS: %d sprint network/stamina assertions (mocked Roblox boundary).", count))
