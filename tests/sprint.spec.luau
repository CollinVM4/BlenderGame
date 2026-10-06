env.UDim2.new = function(xScale, xOffset, yScale, yOffset)
    return { X = { Scale = xScale, Offset = xOffset }, Y = { Scale = yScale, Offset = yOffset } }
end
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
bindTestData(data)
local movement = loadModule("MovementService")
local sprint = loadModule("SprintService")
local config = loadModule("SprintConfig")
data.AddPlayer(runner)
assignTestSession(runner)
local deps = { PlayerDataService = data, MovementService = movement, TycoonService = sessionTestAuthority }
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
check(buyTestUpgrade(data, runner, "MovementSpeed"), "speed purchase succeeds")
check(buyTestUpgrade(data, runner, "SprintStamina"), "stamina purchase succeeds")
movement.RefreshPlayer(runner)
maximum = movement.GetMaxStamina(runner)
check(runner:GetAttribute("StaminaCurrent") == maximum - config.STAMINA_DRAIN_RATE, "upgrade adds only capacity delta")
check(humanoid.WalkSpeed == movement.GetSprintWalkSpeed(runner), "upgrade applies during sprint")
movement.SetStunned(runner, true)
tick(0)
check(humanoid.WalkSpeed == 0, "stun retains speed precedence")
movement.SetStunned(runner, false)
tick(2)
check(humanoid.WalkSpeed == movement.GetBaseWalkSpeed(runner), "unstun restores resolved base speed")
remote.OnServerEvent:Fire(runner, true)
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
local touchAction
services.ContextActionService = {
    BindAction = function(_, _, callback, createTouchButton)
        setup(createTouchButton, "sprint provides a mobile button")
        touchAction = callback
    end,
    SetTitle = function() end,
    SetPosition = function() end,
}
env.Enum.ContextActionResult = { Sink = "Sink" }
env.Enum.UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel" }
env.Enum.KeyCode = { LeftShift = "LeftShift", RightShift = "RightShift", A = "A" }
services.Players.LocalPlayer = runner
local stunChanged = signal()
function runner:GetAttributeChangedSignal()
    return stunChanged
end
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
movement.SetStunned(runner, true)
stunChanged:Fire()
local requestsBeforeStunned = #requests
services.UserInputService.InputBegan:Fire({ KeyCode = env.Enum.KeyCode.LeftShift }, false)
check(#requests == requestsBeforeStunned and humanoid.WalkSpeed == 0, "local sprint input cannot bypass stun")
movement.SetStunned(runner, false)
stunChanged:Fire()
input.InputEnded:Fire(left)
local beforeTouch = #requests
touchAction("SprintHeld", "Begin")
touchAction("SprintHeld", "Begin")
check(#requests == beforeTouch + 1 and requests[#requests], "holding mobile sprint sends one start")
input.InputBegan:Fire(left, false)
touchAction("SprintHeld", "End")
check(#requests == beforeTouch + 1, "mobile release preserves held keyboard sprint")
input.InputEnded:Fire(left)
check(requests[#requests] == false, "last held input release stops sprint")
touchAction("SprintHeld", "Begin")
touchAction("SprintHeld", "Cancel")
check(requests[#requests] == false, "cancelled mobile touch stops sprint")
touchAction("SprintHeld", "Begin")
input.WindowFocusReleased:Fire()
check(requests[#requests] == false, "focus loss stops held mobile sprint")
touchAction("SprintHeld", "Begin")
movement.SetStunned(runner, true)
stunChanged:Fire()
local beforeStunnedTouch = #requests
touchAction("SprintHeld", "Begin")
check(#requests == beforeStunnedTouch and requests[#requests] == false, "stun clears and blocks held mobile sprint")
touchAction("SprintHeld", "End")
movement.SetStunned(runner, false)
stunChanged:Fire()
check(serverSends == 0, "server never sends SprintRequest during any lifecycle")
sprint.RemovePlayer(runner)
movement.RemovePlayer(runner)
local beforeCleanupTick = runner:GetAttribute("StaminaCurrent")
movement.Changed:Fire(runner)
remote.OnServerEvent:Fire(runner, true)
tick(1)
check(
    runner:GetAttribute("StaminaCurrent") == beforeCleanupTick,
    "late notifications and heartbeat cannot recreate removed movement state"
)
services.Players.GetPlayers = function()
    return {}
end
tick(1)
print(string.format("PASS: %d sprint network/stamina assertions (mocked Roblox boundary).", count))
