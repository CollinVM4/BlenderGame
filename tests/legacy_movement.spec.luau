-- Extracted unchanged so unrelated movement failures cannot mask inventory/blend/serve.
services.RunService.IsRunning = function()
    return true
end
services.RunService.IsServer = function()
    return true
end
studio = true
local runtimeAccess = loadModule("StudioServices")
runtimeAccess.BeginBootstrap()
studio = false
local function player(name)
    local p = instance("Player")
    p.Name = name
    p.UserId = #allInstances
    p.Near = true
    p.Parent = services.Players
    p.Backpack = instance("Backpack")
    function p:FindFirstChildOfClass(name)
        return if name == "Backpack" then self.Backpack else nil
    end
    return p
end
local p, other = player("Owner"), player("Visitor")
local data = loadModule("PlayerDataService")
data.AddPlayer(p)
data.AddPlayer(other)
-- Movement integration runs real data/resolver/sprint/purchase modules with signals and time.
do
    local movementStartCount = count
    local savedHeartbeat = services.RunService.Heartbeat
    local savedGetPlayers = services.Players.GetPlayers
    local runner = player("MovementRunner")
    data.AddPlayer(runner)
    local oldNew = env.Instance.new
    env.Instance.new = function(class)
        local object = oldNew(class)
        if class == "BindableEvent" then
            object.Event = signal()
            function object:Fire(...)
                self.Event:Fire(...)
            end
        elseif class == "RemoteEvent" then
            object.OnServerEvent = signal()
            object.Results = {}
            function object:FireClient(recipient, ...)
                table.insert(self.Results, { recipient, ... })
            end
        end
        return object
    end
    local heartbeat = signal()
    services.RunService.Heartbeat = heartbeat
    services.Players.GetPlayers = function()
        return { runner }
    end
    local sprintRemote = env.Instance.new("RemoteEvent")
    shared.Events.SprintEvents = "SprintEvents"
    cache.SprintEvents = function()
        return sprintRemote
    end
    workspaceFake.Gravity = 196.2
    local movement = loadModule("MovementService")
    local sprint = loadModule("SprintService")
    local movementDeps = { PlayerDataService = data, MovementService = movement }
    movement.Init(movementDeps)
    sprint.Init(movementDeps)
    movement.RefreshPlayer(runner)
    local function spawnCharacter(usePower)
        local character = instance("Model")
        runner.Character = character
        local humanoid = instance("Humanoid")
        humanoid.Name = "Humanoid"
        humanoid.Parent = character
        humanoid.Health = 100
        humanoid.UseJumpPower = usePower
        runner:SetAttribute("StunnedUntil", 0)
        movement.ApplyCharacter(runner, character)
        sprint.ResetCharacter(runner)
        return humanoid
    end
    local humanoid = spawnCharacter(true)
    local function tick(seconds)
        now += seconds
        heartbeat:Fire(seconds)
    end
    local function requestSprint(value)
        sprintRemote.OnServerEvent:Fire(runner, value)
        tick(0)
    end
    check(humanoid.WalkSpeed == 22 and humanoid.JumpPower == 60, "comfortable movement baseline applies")
    check(
        runner:GetAttribute("StaminaMax") == 110 and runner:GetAttribute("StaminaCurrent") == 110,
        "base stamina full at 110"
    )
    check(
        runner:GetAttribute("MovementSpeedLevel") == 0 and data.GetUpgrade(runner, "MovementSpeed") == 1,
        "movement display level differs from internal index"
    )
    runner:SetAttribute("BaseWalkSpeed", 900)
    runner:SetAttribute("MovementSpeedLevel", 3)
    runner:SetAttribute("StaminaMax", 9000)
    requestSprint(true)
    check(
        humanoid.WalkSpeed == 33 and runner:GetAttribute("StaminaMax") == 110,
        "forged attributes do not affect resolved sprint or stamina"
    )
    tick(2)
    check(runner:GetAttribute("StaminaCurrent") == 70, "sprint drains 20 per second")
    data.AddCash(runner, 10000)
    check(data.PurchaseUpgrade(runner, "SprintStamina"), "purchase next stamina tier")
    movement.RefreshPlayer(runner)
    check(
        runner:GetAttribute("StaminaMax") == 140 and runner:GetAttribute("StaminaCurrent") == 100,
        "capacity upgrade adds delta without refilling"
    )
    movement.RefreshPlayer(runner)
    check(runner:GetAttribute("StaminaCurrent") == 100, "refresh does not award capacity twice")
    requestSprint(false)
    tick(1)
    check(runner:GetAttribute("StaminaCurrent") == 130, "stamina regenerates 30 per second")
    tick(100)
    check(runner:GetAttribute("StaminaCurrent") == 140, "regeneration clamps at maximum")
    for _, maximum in { 170, 230 } do
        check(data.PurchaseUpgrade(runner, "SprintStamina"), "next stamina purchase succeeds")
        movement.RefreshPlayer(runner)
        check(
            movement.GetMaxStamina(runner) == maximum and runner:GetAttribute("StaminaCurrent") == maximum,
            "stamina tiers resolve and preserve full capacity"
        )
    end
    for index, base in { 27, 33, 40 } do
        requestSprint(true)
        check(data.PurchaseUpgrade(runner, "MovementSpeed"), "next speed purchase succeeds")
        movement.RefreshPlayer(runner)
        check(humanoid.WalkSpeed == base * 1.5, "purchase while sprinting immediately uses upgraded speed")
        check(runner:GetAttribute("MovementSpeedLevel") == index, "speed display level is index minus one")
        requestSprint(false)
        check(humanoid.WalkSpeed == base, "sprint stop restores upgraded base")
        runner:SetAttribute("StunnedUntil", now + 1)
        tick(0)
        check(humanoid.WalkSpeed == 0, "stun overrides upgraded normal speed")
        requestSprint(true)
        check(humanoid.WalkSpeed == 0, "stun overrides upgraded sprint")
        tick(1)
        check(humanoid.WalkSpeed == base * 1.5, "stun recovery restores upgraded sprint")
        requestSprint(false)
        runner:SetAttribute("StunnedUntil", now + 1)
        tick(1)
        check(humanoid.WalkSpeed == base, "stun recovery restores upgraded normal speed")
    end
    requestSprint(true)
    tick(100)
    check(
        runner:GetAttribute("StaminaCurrent") == 0 and not runner:GetAttribute("IsSprinting"),
        "exhaustion stops sprint at zero"
    )
    requestSprint(true)
    check(humanoid.WalkSpeed == 40 and not runner:GetAttribute("IsSprinting"), "zero stamina rejects sprint restart")
    tick(1)
    requestSprint(true)
    requestSprint("true")
    check(runner:GetAttribute("IsSprinting"), "invalid sprint payload cannot change state")
    humanoid = spawnCharacter(true)
    check(
        runner:GetAttribute("StaminaCurrent") == 230
            and not runner:GetAttribute("IsSprinting")
            and humanoid.WalkSpeed == 40,
        "respawn fills current max, stops intent, and applies upgraded base"
    )
    for _, power in { 72, 94, 116 } do
        check(data.PurchaseUpgrade(runner, "Jump"), "next jump purchase succeeds")
        movement.RefreshPlayer(runner)
        check(humanoid.JumpPower == power, "jump power upgrade applies")
    end
    humanoid = spawnCharacter(false)
    check(
        math.abs(humanoid.JumpHeight - 116 ^ 2 / (2 * workspaceFake.Gravity)) < 1e-9,
        "respawn converts purchased jump using current gravity"
    )
    studio = true
    movement.SetStudioLevel(runner, "Jump", 1)
    check(
        movement.GetJumpPower(runner) == 72 and data.GetUpgrade(runner, "Jump") == 4,
        "Studio override does not change owned jump"
    )
    humanoid = spawnCharacter(true)
    check(humanoid.JumpPower == 72, "Studio override survives respawn")
    movement.SetStudioLevel(runner, "Jump", nil)
    check(humanoid.JumpPower == 116 and runner:GetAttribute("JumpLevel") == 3, "Studio reset restores purchased jump")
    studio = false
    check(not pcall(movement.SetStudioLevel, runner, "Jump", 1), "live servers reject Studio override")
    for _, invalid in { 0, -1, math.huge, 0 / 0 } do
        check(not pcall(sprint.SetStaminaMax, runner, invalid), "invalid stamina capacity rejected")
    end
    sprint.SetStaminaMax(runner, 100)
    check(runner:GetAttribute("StaminaCurrent") == 100, "capacity decrease clamps current stamina")
    movement.RefreshPlayer(runner)
    requestSprint(true)
    humanoid.Health = 0
    tick(1)
    check(not runner:GetAttribute("IsSprinting"), "death clears sprint intent")
    requestSprint(true)
    check(not runner:GetAttribute("IsSprinting"), "dead character cannot start sprint")
    humanoid = spawnCharacter(true)

    -- Exercise the actual network adapter, including malicious extra arguments.
    data.RemovePlayer(runner)
    data.AddPlayer(runner)
    movement.RefreshPlayer(runner)
    local gameplay = loadModule("GameplayService")
    gameplay.Init(movementDeps)
    local remote = shared.Events:FindFirstChild("GameplayRequest")
    local function purchase(id, ...)
        now += 0.2
        remote.OnServerEvent:Fire(runner, "PurchaseUpgrade", id, ...)
        return remote.Results[#remote.Results][3]
    end
    local result = purchase("MovementSpeed")
    check(
        not result.success and result.reason == "InsufficientCash" and result.level == 0,
        "purchase result distinguishes insufficient cash"
    )
    result = purchase("NotAnUpgrade")
    check(result.reason == "InvalidUpgrade" and result.level == nil, "unknown upgrade result")
    result = purchase({ WalkSpeed = 999 })
    check(result.reason == "InvalidUpgrade", "malformed upgrade result")
    data.AddCash(runner, 1000)
    result = purchase("MovementSpeed", { price = 0, level = 3, WalkSpeed = 999, JumpPower = 999, MaxStamina = 9999 })
    check(
        result.success and result.reason == "Success" and result.upgradeId == "MovementSpeed" and result.level == 1,
        "success result exposes next displayed level"
    )
    check(
        data.GetCash(runner) == 900 and data.GetUpgrade(runner, "MovementSpeed") == 2 and humanoid.WalkSpeed == 27,
        "server chooses price and next speed despite forged payload"
    )
    check(humanoid.JumpPower == 60 and runner:GetAttribute("StaminaMax") == 110, "extra client stats ignored")
    purchase("MovementSpeed")
    purchase("MovementSpeed")
    local cash = data.GetCash(runner)
    result = purchase("MovementSpeed")
    check(
        result.reason == "MaxLevel" and result.level == 3 and data.GetCash(runner) == cash,
        "max level rejection preserves cash"
    )
    data.AddCash(runner, 1000)
    requestSprint(true)
    tick(2)
    result = purchase("SprintStamina")
    check(
        result.success and runner:GetAttribute("StaminaCurrent") == 100,
        "network stamina purchase adds capacity delta"
    )
    result = purchase("Jump")
    check(result.success and humanoid.JumpPower == 72, "network jump purchase applies immediately")
    local responses = #remote.Results
    remote.OnServerEvent:Fire(runner, "PurchaseUpgrade", "Jump")
    check(
        #remote.Results == responses and data.GetUpgrade(runner, "Jump") == 2,
        "existing throttle rejects repeated purchase"
    )
    local dev = loadModule("DevContentService")
    movementDeps.SprintService = sprint
    dev.Init(movementDeps)
    local savedTypeof = env.typeof
    env.typeof = function(value)
        return if type(value) == "table" and value.ClassName then "Instance" else typeof(value)
    end
    local runtimeServices = table.clone(movementDeps)
    runtimeServices.DevContentService = dev
    local commandCache = {}
    local function commandRequire(name)
        if name ~= "DevContentService" and name ~= "StudioServices" then
            return loadModule(name)
        end
        if commandCache[name] then
            return commandCache[name]
        end
        local chunk = assert(loadstring(sources[name], "MovementCommandBar" .. name))
        setfenv(chunk, setmetatable({ script = { Parent = parent }, require = commandRequire }, { __index = env }))
        commandCache[name] = chunk()
        return commandCache[name]
    end
    studio = true
    dev = commandRequire("DevContentService")
    local beforePublish, beforeReason = pcall(dev.SetMovementSpeedLevel, runner, 1)
    check(
        not beforePublish and string.find(beforeReason, "Runtime unavailable"),
        "movement Command Bar reports absent runtime bridge"
    )
    runtimeAccess.Publish(runtimeServices)
    -- The repro has no EnableDevContent opt-in. It must work through this proxy.
    storage:SetAttribute("EnableDevContent", nil)
    requestSprint(false)
    check(dev.SetMovementSpeedLevel(runner, 1), "Command Bar setter works without EnableDevContent")
    check(
        runner:GetAttribute("MovementSpeedLevel") == 1
            and runner:GetAttribute("BaseWalkSpeed") == 27
            and runner:GetAttribute("SprintWalkSpeed") == 40.5
            and humanoid.WalkSpeed == 27,
        "Command Bar level 1 updates all effective attributes and runtime speed"
    )
    check(dev.SetMovementSpeedLevel(runner, 3), "Command Bar level 3 succeeds")
    check(
        runner:GetAttribute("MovementSpeedLevel") == 3
            and runner:GetAttribute("BaseWalkSpeed") == 40
            and runner:GetAttribute("SprintWalkSpeed") == 60
            and humanoid.WalkSpeed == 40,
        "Command Bar level 3 updates all effective attributes and runtime speed"
    )
    local savedMovement = movementDeps.MovementService
    movementDeps.MovementService = nil
    local bound, bindingReason = pcall(dev.SetMovementSpeedLevel, runner, 1)
    check(
        not bound and string.find(bindingReason, "Runtime MovementService.SetStudioLevel is not bound", 1, true),
        "unbound runtime resolver errors explicitly through Command Bar bridge"
    )
    movementDeps.MovementService = savedMovement
    local savedEnabled = storage:GetAttribute("EnableDevContent")
    storage:SetAttribute("EnableDevContent", true)
    studio = true
    local owned = data.GetSnapshot(runner)
    data.SetCash(runner, 0)
    for level = 0, 3 do
        check(dev.SetMovementSpeedLevel(runner, level), "debug speed accepts displayed tier")
        check(runner:GetAttribute("MovementSpeedLevel") == level, "speed attribute exposes effective debug tier")
        requestSprint(true)
        check(humanoid.WalkSpeed == ({ 33, 40.5, 49.5, 60 })[level + 1], "debug sprint speeds survive Heartbeat")
        requestSprint(false)
        check(humanoid.WalkSpeed == ({ 22, 27, 33, 40 })[level + 1], "debug normal speed resolves independently")
        check(dev.SetSprintStaminaLevel(runner, level), "debug stamina accepts displayed tier")
        check(runner:GetAttribute("SprintStaminaLevel") == level, "stamina attribute exposes effective debug tier")
        local max = ({ 110, 140, 170, 230 })[level + 1]
        check(
            sprint.GetSnapshot(runner).StaminaCurrent == max and movement.GetMaxStamina(runner) == max,
            "debug stamina immediately fills selected capacity"
        )
        requestSprint(true)
        tick(1)
        check(sprint.GetSnapshot(runner).StaminaCurrent == max - 20, "runtime drains overridden capacity")
        check(
            dev.SetJumpLevel(runner, level) and humanoid.JumpPower == ({ 60, 72, 94, 116 })[level + 1],
            "debug jump supports all tiers"
        )
    end
    check(runner:GetAttribute("JumpLevel") == 3, "jump attribute exposes effective debug tier")
    check(data.GetCash(runner) == 0, "debug setters need no cash")
    for _, track in { "MovementSpeed", "Jump", "SprintStamina" } do
        check(data.GetUpgrade(runner, track) == owned.Upgrades[track], "debug does not mutate purchased track")
    end
    local _, debugCopy = movement.GetStudioSnapshot(runner)
    debugCopy.MovementSpeed = 0
    check(movement.GetBaseWalkSpeed(runner) == 40, "debug snapshot cannot mutate override state")
    check(dev.SetMovementSpeedLevel(runner, 0), "debug override can differ from purchased speed")
    humanoid = spawnCharacter(true)
    check(
        humanoid.WalkSpeed == 22
            and humanoid.JumpPower == 116
            and sprint.GetSnapshot(runner).StaminaCurrent == 230
            and not sprint.GetSnapshot(runner).IsSprinting,
        "respawn preserves overrides, fills capacity, and stops intent"
    )
    dev.SetJumpLevel(runner, 0)
    movement.SetStudioLevel(runner, "Jump", 2)
    check(humanoid.JumpPower == 94, "movement setter replaces command jump override")
    dev.SetJumpLevel(runner, 1)
    check(humanoid.JumpPower == 72, "command replaces movement jump override")
    movement.SetStudioLevel(runner, "Jump", nil)
    check(
        humanoid.JumpPower == 72 and movement.GetBaseWalkSpeed(runner) == 22 and movement.GetMaxStamina(runner) == 230,
        "clearing jump override preserves other movement overrides"
    )
    runner:SetAttribute("IsSprinting", true)
    runner:SetAttribute("StaminaCurrent", 9999)
    local output = dev.PrintMovement(runner)
    check(
        string.find(output, "MovementSpeedLevel: 0 (purchased: 3; Studio override: 0)", 1, true) ~= nil,
        "debug print distinguishes effective, purchased, and override levels"
    )
    check(
        string.find(output, "IsSprinting: false", 1, true) ~= nil
            and string.find(output, "StaminaCurrent: 230", 1, true) ~= nil,
        "debug print uses authoritative sprint state"
    )
    for _, label in
        {
            "BaseWalkSpeed",
            "SprintWalkSpeed",
            "SprintStaminaLevel",
            "StaminaMax",
            "JumpLevel",
            "JumpPower (resolved)",
            "Humanoid.WalkSpeed",
            "Humanoid.JumpPower",
            "Humanoid.JumpHeight",
            "Humanoid.UseJumpPower",
            "StunnedUntil",
        }
    do
        check(string.find(output, label, 1, true) ~= nil, "movement print includes " .. label)
    end
    check(dev.ResetMovement(runner), "debug reset succeeds")
    local _, cleared = movement.GetStudioSnapshot(runner)
    check(
        next(cleared) == nil
            and humanoid.WalkSpeed == 40
            and humanoid.JumpPower == 72
            and sprint.GetSnapshot(runner).StaminaCurrent == 140,
        "reset restores all purchased tracks and full purchased stamina"
    )
    check(
        runner:GetAttribute("MovementSpeedLevel") == 3
            and runner:GetAttribute("JumpLevel") == 1
            and runner:GetAttribute("SprintStaminaLevel") == 1,
        "Command Bar reset restores purchased level attributes"
    )
    for _, bad in { -1, 4, 1.5, math.huge, 0 / 0, "3" } do
        check(not dev.SetMovementSpeedLevel(runner, bad), "invalid debug levels rejected")
    end
    storage:SetAttribute("EnableDevContent", false)
    check(
        dev.SetJumpLevel(runner, 3) and runner:GetAttribute("JumpLevel") == 3,
        "movement commands ignore content-spawning opt-in"
    )
    storage:SetAttribute("EnableDevContent", true)
    studio = false
    check(not pcall(dev.SetMovementSpeedLevel, runner, 0), "Command Bar bridge rejects production calls")
    dev = runtimeServices.DevContentService
    check(
        not dev.SetMovementSpeedLevel(runner, 0)
            and not dev.SetSprintStaminaLevel(runner, 0)
            and not dev.SetJumpLevel(runner, 0)
            and not dev.ResetMovement(runner)
            and dev.PrintMovement(runner) == nil,
        "production rejects every movement debug command"
    )
    check(
        not pcall(movement.SetStudioLevel, runner, "MovementSpeed", 0)
            and not pcall(movement.ResetStudioOverrides, runner)
            and not pcall(movement.GetStudioSnapshot, runner),
        "production rejects lower-level debug APIs"
    )
    studio = true
    local savedServer = services.RunService.IsServer
    services.RunService.IsServer = function()
        return false
    end
    check(
        not dev.SetMovementSpeedLevel(runner, 0) and not dev.ResetMovement(runner) and dev.PrintMovement(runner) == nil,
        "client context cannot use debug commands"
    )
    services.RunService.IsServer = savedServer
    dev.SetMovementSpeedLevel(runner, 3)
    dev.SetSprintStaminaLevel(runner, 3)
    dev.SetJumpLevel(runner, 3)
    studio = false
    storage:SetAttribute("EnableDevContent", savedEnabled)
    storage:FindFirstChild("StudioServiceCalls"):Destroy()
    env.typeof = savedTypeof
    sprint.RemovePlayer(runner)
    movement.RemovePlayer(runner)
    gameplay.RemovePlayer(runner)
    data.RemovePlayer(runner)
    data.AddPlayer(runner)
    movement.RefreshPlayer(runner)
    humanoid = spawnCharacter(true)
    check(
        humanoid.WalkSpeed == 22 and humanoid.JumpPower == 60 and runner:GetAttribute("StaminaCurrent") == 110,
        "cleanup releases movement, overrides, and stamina for new session"
    )
    services.RunService.Heartbeat = savedHeartbeat
    services.Players.GetPlayers = savedGetPlayers
    remote:Destroy()
    sprintRemote:Destroy()
    runner:Destroy()
    env.Instance.new = oldNew
    print(string.format("PASS: %d movement assertions.", count - movementStartCount))
end
