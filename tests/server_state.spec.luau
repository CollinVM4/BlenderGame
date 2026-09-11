-- CLI test boundary. run_state_tests.py prepends unmodified module sources.
local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local vector = {}
vector.__index = function(v, key)
    if key == "Magnitude" then
        return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    end
    if key == "Unit" then
        return v / v.Magnitude
    end
    return vector[key]
end
local function vec(x, y, z)
    return setmetatable({ X = x, Y = y, Z = z }, vector)
end
vector.__add = function(a, b)
    return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vector.__sub = function(a, b)
    return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vector:Cross(b)
    return vec(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
end
function vector:Dot(b)
    return self.X * b.X + self.Y * b.Y + self.Z * b.Z
end
vector.__div = function(a, b)
    return vec(a.X / b, a.Y / b, a.Z / b)
end
vector.__mul = function(a, b)
    return vec(a.X * b, a.Y * b, a.Z * b)
end
local function color(r, g, b)
    return { R = r, G = g, B = b }
end
local deferred = {}
local function flush()
    local pending = deferred
    deferred = {}
    for _, fn in pending do
        fn()
    end
end
local allInstances = {}
local presentation = {}
local function signal()
    local listeners = {}
    return {
        Connect = function(_, fn)
            table.insert(listeners, fn)
            return {
                Disconnect = function()
                    local i = table.find(listeners, fn)
                    if i then
                        table.remove(listeners, i)
                    end
                end,
            }
        end,
        Fire = function(_, ...)
            for _, fn in table.clone(listeners) do
                fn(...)
            end
        end,
    }
end
local function frame(x, y, z)
    local cf = {
        Position = vec(x or 0, y or 0, z or 0),
        LookVector = vec(0, 0, -1),
        RightVector = vec(1, 0, 0),
        UpVector = vec(0, 1, 0),
    }
    function cf:ToObjectSpace(other)
        return frame(
            other.Position.X - self.Position.X,
            other.Position.Y - self.Position.Y,
            other.Position.Z - self.Position.Z
        )
    end
    function cf:Lerp(other, alpha)
        local v = self.Position + (other.Position - self.Position) * alpha
        return frame(v.X, v.Y, v.Z)
    end
    return setmetatable(cf, {
        __mul = function(a, b)
            local v = a.Position
                + a.RightVector * b.Position.X
                + a.UpVector * b.Position.Y
                - a.LookVector * b.Position.Z
            local result = frame(v.X, v.Y, v.Z)
            result.RightVector, result.UpVector, result.LookVector = a.RightVector, a.UpVector, a.LookVector
            return result
        end,
    })
end
local function instance(class)
    local object = { ClassName = class, Children = {}, Attributes = {} }
    table.insert(allInstances, object)
    object.Event = signal()
    function object:Fire(...)
        self.Event:Fire(...)
    end
    object.Activated = signal()
    object.Unequipped = signal()
    object.CharacterRemoving = signal()
    object.Triggered = signal()
    object.Destroying = signal()
    object.AncestryChanged = signal()
    object.CFrame = frame()
    object.Position = vec(0, 0, 0)
    function object:GetChildren()
        local found = {}
        for _, child in allInstances do
            if child.Parent == self then
                table.insert(found, child)
            end
        end
        return found
    end
    function object:GetDescendants()
        local found = {}
        for _, child in self:GetChildren() do
            table.insert(found, child)
            for _, descendant in child:GetDescendants() do
                table.insert(found, descendant)
            end
        end
        return found
    end
    function object:IsDescendantOf(target)
        local current = self.Parent
        while current do
            if current == target then
                return true
            end
            current = current.Parent
        end
        return false
    end
    function object:PivotTo(at)
        self.CFrame = at
        self.Position = at.Position
    end
    function object:GetBoundingBox()
        local part = self:FindFirstChildWhichIsA("BasePart", true)
        return self.CFrame, part and part.Size or vec(1, 1, 1)
    end
    function object:ScaleTo(scale)
        for _, part in self:GetDescendants() do
            if part:IsA("BasePart") then
                part.Size = part.Size * scale
            end
        end
    end
    function object:GetPivot()
        return self.CFrame
    end
    function object:CanSetNetworkOwnership()
        return true
    end
    function object:SetNetworkOwner(owner)
        self.NetworkOwner = owner
    end
    function object:Clone()
        local clone = instance(self.ClassName)
        clone.Name = self.Name
        clone.Size = self.Size
        clone.Color = self.Color
        clone.CFrame = self.CFrame
        for _, child in self:GetChildren() do
            local c = child:Clone()
            c.Parent = clone
        end
        return clone
    end
    function object:FindFirstChildOfClass(name)
        for _, child in self:GetChildren() do
            if child:IsA(name) then
                return child
            end
        end
        return self.Children[name]
    end
    function object:IsA(name)
        return name == self.ClassName or (name == "BasePart" and self.ClassName == "Part")
    end
    function object:FindFirstChild(name, recursive)
        for _, child in self:GetChildren() do
            if child.Name == name then
                return child
            end
        end
        if recursive then
            for _, child in self:GetDescendants() do
                if child.Name == name then
                    return child
                end
            end
        end
        return self.Children[name]
    end
    function object:GetFullName()
        return (if self.Parent and self.Parent.GetFullName then self.Parent:GetFullName() .. "." else "")
            .. (self.Name or self.ClassName)
    end
    function object:FindFirstChildWhichIsA(class, recursive)
        for _, child in (if recursive then self:GetDescendants() else self:GetChildren()) do
            if child:IsA(class) then
                return child
            end
        end
        return nil
    end
    function object:SetAttribute(key, value)
        self.Attributes[key] = value
    end
    function object:FireAllClients(moment, userId, payload)
        table.insert(presentation, { Moment = moment, UserId = userId, Payload = payload })
        if self.OnClientEvent then
            self.OnClientEvent:Fire(moment, userId, payload)
        end
    end
    function object:Invoke(...)
        return self.OnInvoke(...)
    end
    function object:Emit() end
    function object:GetAttribute(key)
        return self.Attributes[key]
    end
    function object:Destroy()
        if self.Destroyed then
            return
        end
        self.Destroying:Fire()
        for _, child in self:GetChildren() do
            child:Destroy()
        end
        self.Parent = nil
        self.Destroyed = true
        self.AncestryChanged:Fire()
    end
    return object
end
local shared = { Constants = {}, Types = "Types", Events = instance("Folder") }
for name in sources do
    shared.Constants[name] = name
end
local studio = false
local now = 100
local storage = instance("Folder")
local workspaceFake = {
    Raycast = function()
        return nil
    end,
    GetPartsInPart = function(_, input)
        return input.Overlaps or {}
    end,
}
local tags = {}
local services = {
    ReplicatedStorage = { Shared = shared },
    ServerStorage = storage,
    HttpService = {
        GenerateGUID = function()
            return "test-cup-id"
        end,
    },
    RunService = {
        IsStudio = function()
            return studio
        end,
    },
    Players = {},
    Debris = { AddItem = function() end },
    CollectionService = {
        AddTag = function(_, object, tag)
            tags[tag] = tags[tag] or {}
            tags[tag][object] = true
        end,
        RemoveTag = function(_, object, tag)
            if tags[tag] then
                tags[tag][object] = nil
            end
        end,
        GetTags = function(_, object)
            local result = {}
            for tag, objects in tags do
                if objects[object] then
                    table.insert(result, tag)
                end
            end
            return result
        end,
        HasTag = function(_, object, tag)
            return tags[tag] and tags[tag][object] == true
        end,
        GetTagged = function(_, tag)
            local objects = {}
            for object in tags[tag] or {} do
                table.insert(objects, object)
            end
            return objects
        end,
    },
}
local env = setmetatable({
    game = {
        GetService = function(_, name)
            return services[name]
        end,
    },
    workspace = workspaceFake,
    Vector3 = { zero = vec(0, 0, 0), yAxis = vec(0, 1, 0), new = vec },
    Color3 = {
        new = color,
        fromRGB = function(r, g, b)
            return color(r / 255, g / 255, b / 255)
        end,
    },
    Instance = { new = instance },
    CFrame = { new = frame },
    UDim2 = {
        fromOffset = function()
            return {}
        end,
        fromScale = function()
            return {}
        end,
    },
    NumberRange = {
        new = function()
            return {}
        end,
    },
    ColorSequence = {
        new = function()
            return {}
        end,
    },
    os = {
        clock = function()
            return now
        end,
    },
    RaycastParams = {
        new = function()
            return {}
        end,
    },
    Enum = { RaycastFilterType = { Exclude = "Exclude" }, Font = { GothamBold = "GothamBold" } },
    task = {
        spawn = function(fn)
            table.insert(deferred, fn)
        end,
        wait = function()
            return 10
        end,
        delay = function() end,
        defer = function(fn)
            table.insert(deferred, fn)
        end,
    },
    warn = function() end,
}, { __index = getfenv() })
local cache = {
    WorldUtil = {
        Near = function(player, target)
            return player.Near and target ~= nil
        end,
        Part = function(object)
            if object and (object.ClassName == "Model" or object.ClassName == "Folder") then
                return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
            end
            return object
        end,
        Prompt = function(root, name)
            local prompt = instance("ProximityPrompt")
            prompt.Name = name
            prompt.Parent = root
            return prompt
        end,
    },
    AudioService = {
        CreateBlendGroup = function()
            local audio = {}
            for _, name in { "dialogueSound", "notReadySound", "customerServeSound" } do
                audio[name] = { Play = function() end, Stop = function() end }
            end
            return audio
        end,
    },
}
local parent = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
local function loadModule(name)
    if cache[name] then
        return cache[name]
    end
    local chunk = assert(loadstring(sources[name], name))
    local moduleEnv = setmetatable({ script = { Parent = parent } }, { __index = env })
    setfenv(chunk, moduleEnv)
    local result = chunk()
    cache[name] = result
    return result
end
env.require = loadModule
local vfxTests = assert(loadstring(sources.BlendVFXTests))()
vfxTests({
    Sources = sources,
    Env = env,
    Instance = instance,
    Signal = signal,
    Frame = frame,
    Services = services,
    Parent = parent,
    Check = check,
})
if vfxOnly then
    print(string.format("PASS: %d blender VFX assertions (mocked Roblox boundary).", count))
    return
end
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
    movement.SetStudioJumpTier(runner, 1)
    check(
        movement.GetJumpPower(runner) == 72 and data.GetUpgrade(runner, "Jump") == 4,
        "Studio override does not change owned jump"
    )
    humanoid = spawnCharacter(true)
    check(humanoid.JumpPower == 72, "Studio override survives respawn")
    movement.SetStudioJumpTier(runner, nil)
    check(
        humanoid.JumpPower == 116 and runner:GetAttribute("StudioJumpTier") == nil,
        "Studio reset restores purchased jump"
    )
    -- Drive the real pad touch/reset handlers without changing pad geometry.
    local padWorld = instance("Folder")
    local savedWorkspace = services.Workspace
    services.Workspace = padWorld
    local savedPlayerRemoving = services.Players.PlayerRemoving
    local savedFromCharacter = services.Players.GetPlayerFromCharacter
    services.Players.PlayerRemoving = signal()
    services.Players.GetPlayerFromCharacter = function(_, character)
        return if character == runner.Character then runner else nil
    end
    env.Enum.NormalId = { Top = "Top" }
    env.Enum.SurfaceGuiSizingMode = { PixelsPerStud = "PixelsPerStud" }
    env.Enum.Material = { Neon = "Neon" }
    env.Enum.SurfaceType = { Smooth = "Smooth" }
    local oldPadNew = env.Instance.new
    env.Instance.new = function(class)
        local object = oldPadNew(class)
        object.Touched = signal()
        return object
    end
    local pads = loadModule("StudioJumpTestService")
    pads.Init(movementDeps)
    local padFolder = padWorld:FindFirstChild("StudioJumpPads")
    local foot = instance("Part")
    foot.Parent = runner.Character
    for tier, power in { 72, 94, 116 } do
        now += 0.1
        local pad = padFolder:FindFirstChild("JUMP " .. tier)
        check(pad.Size.X == 10 and pad.Size.Y == 1 and pad.Size.Z == 10, "jump pad geometry retained")
        pad.Touched:Fire(foot)
        check(
            humanoid.JumpPower == power and runner:GetAttribute("StudioJumpTier") == tier,
            "pad touch routes temporary tier through resolver"
        )
    end
    now += 0.1
    padFolder:FindFirstChild("JUMP 1").Touched:Fire(foot)
    now += 0.1
    padFolder:FindFirstChild("RESET JUMP").Touched:Fire(foot)
    check(
        humanoid.JumpPower == 116 and runner:GetAttribute("StudioJumpTier") == nil,
        "actual reset pad restores purchased jump"
    )
    env.Instance.new = oldPadNew
    services.Workspace = savedWorkspace
    services.Players.PlayerRemoving = savedPlayerRemoving
    services.Players.GetPlayerFromCharacter = savedFromCharacter
    padWorld:Destroy()
    studio = false
    check(not pcall(movement.SetStudioJumpTier, runner, 1), "live servers reject Studio override")
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
    movement.SetStudioJumpTier(runner, 2)
    check(humanoid.JumpPower == 94, "pad overwrites command jump override")
    dev.SetJumpLevel(runner, 1)
    check(humanoid.JumpPower == 72, "command overwrites pad jump override")
    movement.SetStudioJumpTier(runner, nil)
    check(
        humanoid.JumpPower == 72 and movement.GetBaseWalkSpeed(runner) == 22 and movement.GetMaxStamina(runner) == 230,
        "pad reset clears only shared jump override"
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

check(data.GetCash(p) == 0, "cash starts at zero")
local snapshot = data.GetSnapshot(p)
snapshot.Upgrades.Hand = 3
snapshot.Cash = 999
check(data.GetUpgrade(p, "Hand") == 1 and data.GetCash(p) == 0, "snapshots cannot mutate data")
check(not data.PurchaseUpgrade(p, "Hand"), "unaffordable upgrade rejected")
data.AddCash(p, 1000)
check(data.PurchaseUpgrade(p, "Hand") and data.GetCash(p) == 850, "upgrade spends exact cash")
check(not data.PurchaseUpgrade(p, "Bogus"), "invalid upgrade rejected")
check(not pcall(data.SetCash, p, 0 / 0), "NaN cash rejected")

local definitions = loadModule("Ingredients")
local worldRecords = {}
local ingredients = {
    GetDefinition = function(id)
        return definitions[id]
    end,
    GetRecord = function(object)
        return worldRecords[object]
    end,
    Resolve = function(object)
        return if worldRecords[object] then object else nil
    end,
    Consume = function(object)
        local record = worldRecords[object]
        worldRecords[object] = nil
        return record and record.Id
    end,
}
local input = { Owner = p, Overlaps = {} }
local wheel = instance("Part")
wheel.Owner = p
wheel.AssemblyAngularVelocity = vec(0, 0, 0)
local refs = { BlenderInput = input, PlayerStash = {}, StartDayButton = {}, CustomerCounter = {} }
local tycoon = {
    GetOwner = function(object)
        return object.Owner
    end,
    GetReference = function(_, id)
        return refs[id]
    end,
    AssignPlot = function()
        return {}
    end,
}
local deps = { PlayerDataService = data, IngredientService = ingredients, TycoonService = tycoon }
local inventory = loadModule("InventoryService")
deps.InventoryService = inventory
inventory.Init(deps)
inventory.AddPlayer(p)
inventory.AddPlayer(other)
for _ = 1, 5 do
    check(inventory.AddUnit(p, "Strawberry"), "add to cap")
end
check(not inventory.AddUnit(p, "Strawberry"), "stack cap enforced")
check(not inventory.AddUnit(p, "Fake"), "unknown ingredient rejected")
check(not inventory.Deposit(p, "Strawberry", 1), "abstract inventory cannot deposit without held reservation")
check(not inventory.Steal(other, p, 3), "V1 theft disabled")
check(inventory.GetStashLayout(p).Slots == 5, "normal stash layout")
data.SetEntitlement(p, "VIPStorage", true)
check(inventory.GetStashLayout(p).Protected == 2 and inventory.GetStashLayout(p).Slots == 5, "V1 layout ignores VIP")
check(data.PurchaseUpgrade(p, "StackSize") and inventory.GetStackCap(p) == 10, "earned stack upgrade")

local blend = loadModule("BlendService")
deps.BlendService = blend
blend.Init(deps)
blend.Reset(p)
local function item(id, owner)
    local object = {}
    worldRecords[object] = { Id = id, Owner = owner, Claimable = true }
    return object
end
local function loadIngredient(id)
    local object = item(id, p)
    input.Overlaps = { object }
    return blend.TryInput(p, object, input)
end
check(not blend.AddProgress(p, wheel, 10), "empty blender cannot blend")
local foreign = item("Ice", other)
input.Overlaps = { foreign }
check(not blend.TryInput(p, foreign, input) and worldRecords[foreign] ~= nil, "foreign ingredient preserved")
check(not blend.TryInput(p, {}, input), "unregistered object rejected")
local distant = item("Ice", p)
input.Overlaps = {}
check(not blend.TryInput(p, distant, input), "nonoverlapping ingredient rejected")
check(loadIngredient("Strawberry") and blend.GetSnapshot(p).State == "LOADING", "first item enters LOADING")
check(
    loadIngredient("Banana") and loadIngredient("Ice") and blend.GetSnapshot(p).State == "READY",
    "three items enter READY"
)
check(not loadIngredient("Tire"), "fourth item rejected without consumption")
check(not blend.AddProgress(p, wheel, 0 / 0), "invalid progress rejected")
check(not blend.AddProgress(other, wheel, 10), "foreign wheel rejected")
local physics = loadModule("PhysicsService")
check(physics.GetBlendDelta(wheel, 1) == 0, "stationary blade gives zero progress")
check(not blend.AddProgress(p, wheel, physics.GetBlendDelta(wheel, 1)), "stationary READY batch stays READY")
wheel.AssemblyAngularVelocity = vec(0, -2 * math.pi, 0)
check(math.abs(physics.GetRPM(wheel) - 60) < 1e-9, "RPM displays magnitude in revolutions per minute")
wheel.AssemblyAngularVelocity = vec(0, 0.001, 0)
check(physics.GetBlendDelta(wheel, 1) > 0, "slow spin has no minimum threshold")
wheel.AssemblyAngularVelocity = vec(0, 60, 0)
local spinDelta = physics.GetBlendDelta(wheel, 0.1)
wheel.AssemblyAngularVelocity = vec(0, 120, 0)
check(physics.GetBlendDelta(wheel, 0.1) == spinDelta * 2, "high spin remains linear without speed cap")
check(physics.GetBlendDelta(wheel, 0.05) * 2 == spinDelta * 2, "progress scales with elapsed time")
p.Near = false
check(blend.AddProgress(p, wheel, spinDelta), "physical spin continues when owner steps away")
check(blend.GetSnapshot(p).Progress == spinDelta, "measured delta above ten is not capped")
wheel.AssemblyAngularVelocity = vec(0, 0, 0)
check(not blend.AddProgress(p, wheel, physics.GetBlendDelta(wheel, 1)), "stopped blade cannot advance blending")
check(blend.GetSnapshot(p).Progress == spinDelta, "stopped progress remains unchanged")
blend.Reset(p)
loadIngredient("Strawberry")
loadIngredient("Banana")
loadIngredient("Ice")
p.Near = true
check(blend.AddProgress(p, wheel, 10) and blend.GetSnapshot(p).State == "BLENDING", "READY to BLENDING")
check(not loadIngredient("Tire"), "loading locked during blend")
for _ = 1, 9 do
    blend.AddProgress(p, wheel, 10)
end
local result = blend.GetSnapshot(p)
check(result.State == "COMPLETE" and result.Progress == 100, "blend completes at 100")
check(result.Result.Discovery == "Fruit Smoothie", "special multiset discovery")
check(data.GetSnapshot(p).Stats.SmoothiesMade == 1, "completion increments once")
blend.AddProgress(p, wheel, 10)
check(data.GetSnapshot(p).Stats.SmoothiesMade == 1, "repeated completion does not increment")
check(not blend.Dispense(other, wheel), "foreign dispense rejected")
check(blend.Dispense(p, wheel), "complete batch dispenses")
check(blend.GetSnapshot(p).State == "DISPENSED" and not blend.Dispense(p, wheel), "duplicate dispense rejected")
flush()
check(blend.GetSnapshot(p).State == "EMPTY", "dispensed batch resets")
check(not blend.GetCup(p, instance("Tool")), "forged tool rejected")
check(blend.ConsumeCup(p) ~= nil and blend.ConsumeCup(p) == nil, "cup consumable once")
check(loadIngredient("Tire"), "one ingredient accepted")
blend.AddProgress(p, wheel, 10)
check(blend.GetSnapshot(p).State == "BLENDING", "one ingredient seals when turning")
for _ = 1, 9 do
    blend.AddProgress(p, wheel, 10)
end
check(blend.GetSnapshot(p).Result.Discovery == nil, "nonrecipe combination remains valid")

local customer = loadModule("CustomerService")
customer.Init(deps, function() end, function()
    return true
end)
local bad = blend.GetSnapshot(p).Result
local requests = loadModule("CustomerRequests")
local function requestResult(ids)
    return { Ingredients = ids, Tags = { "Red", "Sweet", "Cold" } }
end
check(
    customer.ValidateRequest(requestResult({ "Strawberry", "Tire" }), requests[1]),
    "one Red ingredient suffices despite extras"
)
check(customer.ValidateRequest(requestResult({ "Banana" }), requests[2]), "Sweet uses metadata for Banana")
check(customer.ValidateRequest(requestResult({ "Ice" }), requests[3]), "Cold uses metadata for Ice")
check(not customer.ValidateRequest(requestResult({ "Tire" }), requests[1]), "forged result tags cannot satisfy Red")
check(not customer.ValidateRequest(requestResult({}), requests[1]), "empty smoothie fails")
check(not customer.ValidateRequest(requestResult({ "Unknown" }), requests[1]), "unknown ingredient fails closed")
local combined = { Id = "RedCold", DisplayText = "Red and cold", RequiredTags = { "Red", "Cold" }, BasePayout = 40 }
check(
    customer.ValidateRequest(requestResult({ "Strawberry", "Ice" }), combined),
    "combined request accepts tags across ingredients"
)
check(not customer.ValidateRequest(requestResult({ "Strawberry" }), combined), "combined request requires every tag")
check(customer.CalculateGrade(bad, "Sweet") == "D", "bad match receives D")
check(customer.CalculateGrade(bad, "Weird") == "A", "same smoothie matches Weird")
check(customer.CalculateGrade(result.Result, "Surprise Me") == "A", "Surprise Me rewards variety")
local normalPay = customer.CalculatePayout(p, "D")
data.SetEntitlement(p, "DoubleCash", true)
check(customer.CalculatePayout(p, "D") == normalPay * 2, "cash entitlement affects reward")
local oldRandom = math.random
-- Reaction function accepts no grade; forcing the extreme roll leaves grade unchanged.
env.math = table.clone(math)
env.math.random = function()
    return 0.99999
end
check(
    customer.SelectReaction() == "Launch" and customer.CalculateGrade(bad, "Sweet") == "D",
    "rare reaction independent of D grade"
)
env.math.random = oldRandom

local spawned, missing = 0, false
deps.CustomerService = {
    CanSpawn = function()
        return not missing, "Missing marker"
    end,
    SpawnForPlayer = function()
        spawned += 1
        return {}
    end,
    RemovePlayer = function() end,
}
local days = loadModule("GameService")
deps.GameService = days
days.Init(deps)
days.AddPlayer(p)
missing = true
check(not days.StartDay(p) and days.GetSnapshot(p).State == "PREP", "missing fixture does not start day")
missing = false
check(days.StartDay(p) and spawned == 1, "start day spawns customer")
check(not days.StartDay(p), "duplicate day start rejected")
days.CustomerServed(p, "A")
days.CustomerServed(p, "D")
days.CustomerServed(p, "B")
check(spawned == 3 and days.GetSnapshot(p).State == "FINISHED", "exactly three customers per day")
check(days.GetSnapshot(p).Grade == "B", "day grade averages grades")
check(days.StartDay(p) and days.GetSnapshot(p).Day == 2, "next day restarts cleanly")

local dev = loadModule("DevContentService")
dev.Init(deps)
storage:SetAttribute("EnableDevContent", true)
check(not dev.IsEnabled() and not dev.ResetBlender(p), "production cannot enable content API")
studio = true
storage:SetAttribute("EnableDevContent", false)
check(not dev.IsEnabled(), "Studio content opt-in required")
storage:SetAttribute("EnableDevContent", true)
check(dev.ResetBlender(p), "explicit Studio opt-in works")

-- Combat boundary: real slap validation/cooldowns, mocked character physics and drop output.
local function character(position)
    local model = instance("Model")
    local root = instance("Part")
    root.Position = position
    root.CFrame = { LookVector = vec(0, 0, -1) }
    root.AssemblyMass = 1
    function root:ApplyImpulse(impulse)
        self.LastImpulse = impulse
    end
    local humanoid = { Health = 100, Died = signal() }
    function humanoid:TakeDamage(damage)
        self.Health -= damage
    end
    model.Children.HumanoidRootPart = root
    model.Children.Humanoid = humanoid
    return model
end
p.Character = character(vec(0, 0, 0))
other.Character = character(vec(0, 0, -4))
local drops = 0
local realDrop = inventory.DropOne
inventory.DropOne = function()
    drops += 1
    return {}
end
local combat = loadModule("CombatService")
combat.Init(deps)
check(not combat.Slap(p, other), "slap requires registered hand")
local hand = combat.GrantHand(p)
hand.Parent = p.Character
check(combat.Slap(p, other), "equipped hand can slap")
check(other.Character.Children.Humanoid.Health == 85, "earned hand level sets damage")
check(other:GetAttribute("StunnedUntil") == now + 0.5, "short stun recorded")
check(not combat.Slap(p, other), "attack cooldown enforced")
now += 1
check(combat.Slap(p, other) and drops == 1, "repeat hit cannot chain-drop")
now += 4
check(combat.Slap(p, other) and drops == 2, "drop allowed after protection")
now += 1
p.Near = false
check(not combat.Slap(p, other), "slap distance gate enforced")
p.Near = true
workspaceFake.Raycast = function()
    return { Instance = instance("Part") }
end
check(not combat.Slap(p, other), "slap obstruction rejected")
workspaceFake.Raycast = function()
    return nil
end
combat.RemovePlayer(p)
check(not combat.Slap(p, other), "removed hand cannot attack")
inventory.DropOne = realDrop

-- Market lifecycle: real stock state and claim transaction, mocked spawned physical asset.
local cf = setmetatable({}, {
    __mul = function(a)
        return a
    end,
})
env.CFrame = {
    new = function()
        return cf
    end,
}
ingredients.Spawn = function(id, _at, owner, claimable)
    local object = instance("Part")
    worldRecords[object] = { Id = id, Owner = owner, Claimable = claimable }
    return object
end
local pedestal = instance("Part")
pedestal.Parent = workspaceFake
pedestal.CFrame = cf
pedestal.Size = vec(3, 2, 3)
pedestal:SetAttribute("IngredientId", "Strawberry")
local carryWorldItem = inventory.CarryWorldItem
inventory.CarryWorldItem = function(_player, object)
    return ingredients.Consume(object) ~= nil
end
local market = loadModule("MarketService")
market.Init(deps)
market.Register(pedestal)
market.Step()
check(pedestal:GetAttribute("StockIngredientId") ~= nil, "pedestal stocks one ingredient")
check(market.Claim(other, pedestal), "market claim succeeds")
check(not market.Claim(p, pedestal), "second claimant cannot duplicate stock")
market.Step()
check(pedestal:GetAttribute("StockIngredientId") == nil, "market waits for respawn")
now += 12
market.Step()
check(pedestal:GetAttribute("StockIngredientId") ~= nil, "market restocks after cooldown")
market.Unregister(pedestal)
check(not market.Claim(p, pedestal), "unregistered pedestal rejects claims")
inventory.CarryWorldItem = carryWorldItem

-- Film slice: real ingredient identity, carry/throw, customer serving and day callback.
local realIngredients = loadModule("IngredientService")
deps.IngredientService = realIngredients
deps.CustomerService = customer
customer.Init(deps, days.CustomerServed, days.IsServing)
local film = loadModule("FilmingUtil")
film.Init()
-- Run the real client startup with a fake replicated boundary and sprint controller.
do
    local remote = shared.Events:FindFirstChild("GameplayPresentation")
    film.Init()
    check(#shared.Events:GetChildren() == 1, "repeated filming Init keeps a single presentation remote")
    local connections, received = 0, 0
    local listener
    remote.OnClientEvent = {
        Connect = function(_, callback)
            connections += 1
            listener = callback
        end,
        Fire = function(_, ...)
            received += 1
            listener(...)
        end,
    }
    local fakeEvents = {
        WaitForChild = function(_, name)
            assert(name == "GameplayPresentation")
            return remote
        end,
    }
    local fakeShared = {
        WaitForChild = function(_, name)
            assert(name == "Events")
            return fakeEvents
        end,
    }
    local fakeReplicated = {
        WaitForChild = function(_, name)
            assert(name == "Shared")
            return fakeShared
        end,
    }
    local controllerChunk = assert(loadstring(sources.GameplayPresentationController, "GameplayPresentationController"))
    setfenv(
        controllerChunk,
        setmetatable({
            game = {
                GetService = function(_, name)
                    assert(name == "ReplicatedStorage")
                    return fakeReplicated
                end,
            },
        }, { __index = env })
    )
    local controller = controllerChunk()
    local sprintStarted = false
    local bootstrap = assert(loadstring(sources.ClientBootstrap, "ClientBootstrap"))
    setfenv(
        bootstrap,
        setmetatable({
            script = { Controllers = parent },
            require = function(name)
                if name == "GameplayPresentationController" then
                    return controller
                end
                if name == "StashPromptController" or name == "RareIngredientPresentationController" then
                    return { Init = function() end }
                end
                assert(name == "SprintController")
                return {
                    Init = function()
                        sprintStarted = true
                    end,
                }
            end,
        }, { __index = env })
    )
    bootstrap()
    controller.Init()
    check(sprintStarted, "presentation startup does not block sprint initialization")
    flush()
    check(connections == 1, "client bootstrap attaches exactly one presentation listener")
    for _, moment in
        {
            "BlendStarted",
            "BlendProgressChanged",
            "BlendCompleted",
            "SmoothieDispensed",
            "CustomerReaction",
            "FutureKind",
        }
    do
        check(pcall(listener, moment, p.UserId, {}), "listener safely accepts " .. moment)
    end
    check(pcall(listener, nil, nil, nil), "malformed presentation is safely ignored")
    remote:FireAllClients("FutureKind", p.UserId, {})
    check(received == 1, "server broadcast reaches client listener")
    table.remove(presentation) -- Synthetic event is not a gameplay transaction.
end
env.CFrame = {
    new = frame,
    fromMatrix = function(position, right, up, back)
        local cf = frame(position.X, position.Y, position.Z)
        cf.RightVector, cf.UpVector, cf.LookVector = right, up, back * -1
        return cf
    end,
}
p.Character.Children.HumanoidRootPart.CFrame = frame()
function p.Character.Children.Humanoid:EquipTool(tool)
    tool.Parent = p.Character
end
input.CFrame = frame()
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].Name = name
    refs[name].CFrame = frame(if name == "CustomerCounter" then 9 else 0, 0, 0)
end
for _, id in { "Strawberry", "Banana", "Watermelon", "Ice", "Blueberry", "Apple", "Noob", "Tire", "Mystery" } do
    check(
        definitions[id].Id == id and #definitions[id].Tags > 0 and definitions[id].Rarity ~= nil,
        "test ingredient metadata: " .. id
    )
end
check(dev.ResetPlot(p), "reset plot alias")
check(not dev.PrepareCombination(p, { "Ice", "Ice", "Ice", "Ice" }), "dev rejects four units")
check(dev.PrepareCombination(p, { "Strawberry", "Tire", "Noob" }), "prepare physical filming props")
check(blend.GetSnapshot(p).State == "EMPTY", "prepare stages props without ingesting")
local staged = {}
for _, object in allInstances do
    if realIngredients.GetRecord(object) then
        table.insert(staged, object)
    end
end
check(#staged == 3, "prepare stages exactly three genuine world units")
check(
    not dev.PrepareCombination(p, { "Fake" }) and realIngredients.GetRecord(staged[1]) ~= nil,
    "invalid preparation preserves existing scene"
)
check(not inventory.CarryWorldItem(other, staged[1]), "foreign pickup rejected")
check(inventory.CarryWorldItem(p, staged[1]), "physical pickup reserves one unit")
check(
    not realIngredients.GetRecord(staged[1]) and not inventory.CarryWorldItem(p, staged[1]),
    "pickup consumes original once"
)
check(not inventory.CarryWorldItem(p, staged[2]), "one held ingredient at a time")
local heldTool
for _, object in allInstances do
    if object:IsA("Tool") and object.Parent == p.Character then
        heldTool = object
    end
end
heldTool:SetAttribute("IngredientId", "Mystery")
local thrown = inventory.ThrowHeld(p)
check(
    thrown and realIngredients.GetRecord(thrown).Id == "Strawberry",
    "throw contents use server reservation, ignore forged attributes"
)
check(not inventory.ThrowHeld(p), "replayed throw cannot duplicate")
check(
    thrown.AssemblyLinearVelocity.Z == -25 and thrown.AssemblyLinearVelocity.Y == 18,
    "server determines throw velocity"
)
input.Overlaps = { thrown }
check(blend.TryInput(p, thrown, input), "genuine thrown item ingested")
check(
    thrown.Destroyed and not blend.TryInput(p, thrown, input),
    "duplicate ingestion rejected and physical item destroyed"
)
check(not blend.Dispense(p, wheel), "LOADING cannot dispense")
check(dev.ClearBlender(p) and blend.GetSnapshot(p).State == "EMPTY", "clear blender alias resets batch")
check(dev.ResetPlot(p), "reset clears loose scene props")

-- Loose pickup uses one server authorization path for prompts, carry, and direct claims.
do
    function other.Character.Children.Humanoid:EquipTool(tool)
        tool.Parent = other.Character
    end
    local attachPickup
    local pickupChunk = assert(loadstring(sources.IngredientPickupComponent))
    setfenv(
        pickupChunk,
        setmetatable({
            script = { Parent = { Parent = { Services = parent } } },
            require = function(name)
                assert(name == "WorldUtil")
                return setmetatable({
                    BindTag = function(tag, attach)
                        assert(tag == "IngredientWorldItem")
                        attachPickup = attach
                    end,
                }, { __index = cache.WorldUtil })
            end,
        }, { __index = env })
    )
    pickupChunk().Init(deps)
    local function heldBy(player)
        for _, object in allInstances do
            if object:IsA("Tool") and object.Parent == player.Character then
                return object
            end
        end
        return nil
    end
    local stock = realIngredients.Spawn("Banana", frame(), nil, true)
    local cleanup = attachPickup(stock)
    local prompt = stock:FindFirstChild("CarryPrompt")
    check(prompt and cleanup, "unowned claimable stock gets real pickup prompt")
    p.Near = false
    prompt.Triggered:Fire(p)
    check(not heldBy(p) and realIngredients.GetRecord(stock), "prompt cannot bypass pickup distance")
    check(not inventory.ClaimWorldItem(p, stock), "direct claim shares distance authorization")
    p.Near = true
    local humanoid = p.Character.Children.Humanoid
    humanoid.Health = 0
    check(
        not inventory.CarryWorldItem(p, stock) and not inventory.ClaimWorldItem(p, stock),
        "dead player cannot carry or claim"
    )
    humanoid.Health = 100
    local initialCount = inventory.GetSnapshot(p).Carried.Banana or 0
    while inventory.AddUnit(p, "Banana") do
    end
    check(not inventory.CarryWorldItem(p, stock), "full ingredient stack cannot bypass capacity via carry")
    check(realIngredients.GetRecord(stock) and not heldBy(p), "failed carry preserves stock and held slot")
    while (inventory.GetSnapshot(p).Carried.Banana or 0) > initialCount do
        inventory.RemoveUnit(p, "Banana")
    end
    prompt.Triggered:Fire(p)
    check(heldBy(p) and not realIngredients.GetRecord(stock), "prompt claims unowned stock into equipped reservation")
    check((inventory.GetSnapshot(p).Carried.Banana or 0) == initialCount, "held unit is not also counted in inventory")
    check(
        not inventory.CarryWorldItem(other, stock) and not inventory.ClaimWorldItem(other, stock),
        "second player loses same-item contention"
    )
    check(
        not heldBy(other) and not inventory.CarryWorldItem(p, stock),
        "loser and duplicate request receive no second reservation"
    )
    local extra = realIngredients.Spawn("Banana", frame(), nil, true)
    check(
        not inventory.CarryWorldItem(p, extra) and realIngredients.GetRecord(extra),
        "unowned pickup preserves one-held limit"
    )
    extra:Destroy()
    cleanup()
    local thrownStationItem = inventory.ThrowHeld(p)
    local thrownRecord = realIngredients.GetRecord(thrownStationItem)
    check(
        thrownRecord.Owner == nil and thrownRecord.Claimable and thrownRecord.Id == "Banana",
        "station throw releases ownership of registered unit"
    )
    check(not inventory.ThrowHeld(p), "station reservation can only be thrown once")
    blend.Reset(p)
    input.Overlaps = { thrownStationItem }
    local heartbeat, detachInput = signal(), nil
    local inputChunk = assert(loadstring(sources.BlenderInputComponent))
    setfenv(
        inputChunk,
        setmetatable({
            script = { Parent = { Parent = { Services = parent } } },
            game = {
                GetService = function()
                    return { Heartbeat = heartbeat }
                end,
            },
            require = function()
                return {
                    BindTag = function(_, attach)
                        detachInput = attach(input)
                    end,
                }
            end,
        }, { __index = env })
    )
    -- This existing fake detector needs the BasePart methods used at component binding.
    function input:IsA(class)
        return class == "BasePart"
    end
    inputChunk().Init(deps)
    heartbeat:Fire(0.1)
    heartbeat:Fire(0.1)
    detachInput()
    check(
        not realIngredients.GetRecord(thrownStationItem) and #blend.GetSnapshot(p).Ingredients == 1,
        "actual BlenderInput consumes station throw exactly once"
    )
    input.Overlaps = {}
    blend.Reset(p)
    local reverseStock = realIngredients.Spawn("Banana", frame(), nil, true)
    check(inventory.CarryWorldItem(other, reverseStock), "other player can win first request")
    check(not inventory.CarryWorldItem(p, reverseStock), "reversed contention still grants exactly one winner")
    inventory.ClearHeld(other)
    local owned = realIngredients.Spawn("Banana", frame(), p, true)
    owned:SetAttribute("OwnerUserId", other.UserId)
    owned:SetAttribute("SlotIndex", 3)
    check(
        not inventory.CarryWorldItem(other, owned) and not inventory.ClaimWorldItem(other, owned),
        "foreign loose ownership cannot be bypassed with owner/slot metadata"
    )
    check(
        realIngredients.GetRecord(owned) and inventory.CarryWorldItem(p, owned),
        "existing owner retains dev-prop pickup rights"
    )
    inventory.ClearHeld(p)
    local locked = realIngredients.Spawn("Banana", frame(), nil, false)
    check(not attachPickup(locked), "nonclaimable market stock gets no carry prompt")
    check(
        not inventory.CarryWorldItem(p, locked) and not inventory.ClaimWorldItem(p, locked),
        "nonclaimable stock cannot be carried or claimed"
    )
    locked:Destroy()
    local forged = instance("Part")
    forged.Parent = workspaceFake
    forged:SetAttribute("IngredientId", "Banana")
    check(
        not attachPickup(forged) and not inventory.CarryWorldItem(p, forged),
        "unregistered decoration grants no pickup rights"
    )
end

-- Held release transactions use the real world registry and engine-style signals.
do
    local function worldItems()
        local result = {}
        for _, object in allInstances do
            if realIngredients.GetRecord(object) then
                table.insert(result, object)
            end
        end
        return result
    end
    local function carry()
        local stock = realIngredients.Spawn("Banana", frame(), nil, true)
        check(inventory.CarryWorldItem(p, stock), "drop fixture claims station stock")
        for _, object in allInstances do
            if object:IsA("Tool") and object.Parent == p.Character then
                return object
            end
        end
        error("missing held Tool")
    end
    local before = #worldItems()
    local tool = carry()
    local visible = false
    for _, part in tool:GetDescendants() do
        if part:IsA("BasePart") and part.Name ~= "Handle" and part.Transparency ~= 1 then
            visible = part.Color == definitions.Banana.BlendColor and not part.CanCollide
        end
    end
    check(visible, "fallback ingredient is visibly welded into held Tool")
    tool.Parent = p.Backpack
    tool.Unequipped:Fire()
    check(
        tool.Destroyed and #worldItems() == before + 1,
        "unequip restores exactly one world item before removing Tool"
    )
    check(not inventory.DropHeld(p), "unequip clears held reservation")
    local dropped = worldItems()[#worldItems()]
    local record = realIngredients.GetRecord(dropped)
    check(
        record.Id == "Banana" and record.Owner == nil and record.Claimable,
        "drop releases ownership and enables pickup"
    )
    check(
        dropped:GetAttribute("IngredientId") == "Banana"
            and dropped:GetAttribute("OwnerUserId") == 0
            and dropped:GetAttribute("WorldItemId") ~= nil
            and tags.IngredientWorldItem[dropped],
        "drop restores world identity and tag"
    )
    check(
        dropped.Position.Z == -3 and not dropped.Anchored and dropped.NetworkOwner == nil,
        "drop uses server physical spawn in front of character"
    )
    tool.Unequipped:Fire()
    tool.Destroying:Fire()
    p.Character.Children.Humanoid.Died:Fire()
    check(#worldItems() == before + 1, "repeated unequip/destroy/death cannot duplicate")
    check(inventory.CarryWorldItem(p, dropped), "dropped unit can be picked up again")
    tool.Unequipped:Fire()
    local reheld
    for _, object in allInstances do
        if object:IsA("Tool") and object.Parent == p.Character then
            reheld = object
        end
    end
    reheld.Activated:Fire()
    local thrownAgain = worldItems()[#worldItems()]
    check(
        thrownAgain.AssemblyLinearVelocity.Z == -25 and thrownAgain.AssemblyLinearVelocity.Y == 18,
        "click/tap activation still throws after drop and repickup; old signals do not clear new hold"
    )
    blend.Reset(p)
    input.Overlaps = { thrownAgain }
    check(
        blend.TryInput(p, thrownAgain, input) and not realIngredients.GetRecord(thrownAgain),
        "repicked dropped item is consumed by blender input"
    )
    input.Overlaps = {}
    blend.Reset(p)

    tool = carry()
    local spawn = realIngredients.Spawn
    realIngredients.Spawn = function()
        check(not inventory.DropHeld(p), "reentrant release blocked")
        return nil
    end
    tool.Parent = p.Backpack
    tool.Unequipped:Fire()
    check(
        not tool.Destroyed and #worldItems() == before,
        "failed spawn preserves Tool and does not create a world copy"
    )
    realIngredients.Spawn = function(...)
        check(not tool.Destroyed, "Tool survives until successful world restoration")
        check(not inventory.DropHeld(p), "reentrant successful release blocked")
        return spawn(...)
    end
    dropped = inventory.DropHeld(p)
    realIngredients.Spawn = spawn
    check(
        dropped and tool.Destroyed and not inventory.DropHeld(p),
        "failed release retains reservation for one successful retry"
    )
    realIngredients.Consume(dropped)

    tool = carry()
    local humanoid = p.Character.Children.Humanoid
    humanoid.Health = 0
    humanoid.Died:Fire()
    p.CharacterRemoving:Fire(p.Character)
    tool.Unequipped:Fire()
    check(
        tool.Destroyed and #worldItems() == before + 1 and not inventory.DropHeld(p),
        "death/removal signals restore one unit with no held copy"
    )
    realIngredients.Consume(worldItems()[#worldItems()])
    humanoid.Health = 100

    tool = carry()
    local oldCharacter = p.Character
    p.Character = nil
    p.CharacterRemoving:Fire(oldCharacter)
    check(
        tool.Destroyed and #worldItems() == before + 1,
        "character removal can drop using retained root when Character is nil"
    )
    realIngredients.Consume(worldItems()[#worldItems()])
    p.Character = oldCharacter

    tool = carry()
    tool:Destroy()
    check(
        #worldItems() == before + 1 and not inventory.DropHeld(p),
        "external Tool destruction restores one unit without recursive destruction"
    )
    realIngredients.Consume(worldItems()[#worldItems()])

    tool = carry()
    inventory.RemovePlayer(p)
    check(#worldItems() == before + 1 and tool.Destroyed, "disconnect restores held unit before owned-world cleanup")
    realIngredients.RemovePlayer(p) -- Matches bootstrap service cleanup ordering.
    p.CharacterRemoving:Fire(p.Character)
    tool.Unequipped:Fire()
    inventory.RemovePlayer(p)
    check(
        #worldItems() == before + 1 and not inventory.DropHeld(p),
        "disconnect cleanup preserves exactly one unowned drop"
    )
    local disconnectedDrop = worldItems()[#worldItems()]
    check(
        realIngredients.GetRecord(disconnectedDrop).Owner == nil and inventory.CarryWorldItem(other, disconnectedDrop),
        "another player can claim disconnect drop"
    )
    inventory.ClearHeld(other)
    inventory.AddPlayer(p)
end

-- Both release modes let either player win the next claim, exactly once.
do
    other.Character.Children.HumanoidRootPart.CFrame = frame()
    for _, mode in { "DropHeld", "ThrowHeld" } do
        for _, winner in { other, p } do
            local loser = if winner == p then other else p
            local stock = realIngredients.Spawn("Ice", frame(), p, true)
            check(inventory.CarryWorldItem(p, stock), "owner reserves fixture for " .. mode)
            check(
                not inventory.DropHeld(other) and not inventory.ThrowHeld(other),
                "other player cannot release holder's reservation"
            )
            local loose = inventory[mode](p)
            local record = realIngredients.GetRecord(loose)
            check(
                record.Id == "Ice"
                    and record.Owner == nil
                    and record.Claimable
                    and loose:GetAttribute("OwnerUserId") == 0,
                mode .. " releases original ownership into claimable world unit"
            )
            check(not inventory[mode](p), mode .. " cannot replay release")
            check(inventory.CarryWorldItem(winner, loose), mode .. " can be claimed by either nearby player")
            check(
                not inventory.CarryWorldItem(loser, loose) and not inventory.ClaimWorldItem(loser, loose),
                mode .. " contention loser cannot obtain a second unit"
            )
            check(
                not realIngredients.GetRecord(loose) and not inventory.CarryWorldItem(winner, loose),
                mode .. " winning claim consumes the world identity once"
            )
            check(not inventory.DropHeld(loser), mode .. " losing player has no reservation")
            local releasedAgain = inventory.DropHeld(winner)
            check(releasedAgain and not inventory.DropHeld(winner), mode .. " winner holds exactly one releasable unit")
            realIngredients.Consume(releasedAgain)
        end
    end
    blend.Reset(p)
    local loose = realIngredients.Spawn("Ice", frame(), nil, true)
    input.Overlaps = {}
    check(not blend.TryInput(p, loose, input), "unowned input still requires physical overlap")
    input.Overlaps = { loose }
    local owner = input.Owner
    input.Owner = other
    check(not blend.TryInput(p, loose, input), "unowned input still requires matching plot owner")
    input.Owner = owner
    check(
        blend.TryInput(p, loose, input) and not blend.TryInput(p, loose, input),
        "claimable unowned input is consumed exactly once"
    )
    local locked = realIngredients.Spawn("Ice", frame(), nil, false)
    input.Overlaps = { locked }
    check(
        not blend.TryInput(p, locked, input) and realIngredients.GetRecord(locked),
        "nonclaimable unowned stock cannot enter blender"
    )
    realIngredients.Consume(locked)
    input.Overlaps = {}
    blend.Reset(p)
end

local function actualBlend(ids)
    blend.Reset(p)
    for _, id in ids do
        local object = realIngredients.Spawn(id, frame(), p)
        input.Overlaps = { object }
        check(blend.TryInput(p, object, input), "real registry ingestion: " .. id)
    end
    check(not blend.Dispense(p, wheel), "unfinished batch cannot dispense")
    local extra = realIngredients.Spawn("Ice", frame(), p)
    input.Overlaps = { extra }
    if #ids == 3 then
        check(
            not blend.TryInput(p, extra, input) and realIngredients.GetRecord(extra),
            "max three preserves rejected unit"
        )
    end
    realIngredients.Consume(extra)
    for _ = 1, 10 do
        blend.AddProgress(p, wheel, 10)
    end
    local smoothie = blend.GetSnapshot(p).Result
    local expected = vec(0, 0, 0)
    for _, id in ids do
        local c = definitions[id].BlendColor
        expected += vec(c.R, c.G, c.B)
    end
    expected /= #ids
    check(
        math.abs(smoothie.Color.R - expected.X) < 1e-8
            and math.abs(smoothie.Color.G - expected.Y) < 1e-8
            and math.abs(smoothie.Color.B - expected.Z) < 1e-8,
        "deterministic RGB mean includes every unit"
    )
    check(blend.Dispense(p, wheel), "actual blend dispenses once")
    flush()
    return smoothie
end
local one = actualBlend({ "Mystery" })
blend.ClearCup(p)
local two = actualBlend({ "Mystery", "Strawberry" })
blend.ClearCup(p)
local repeated = actualBlend({ "Strawberry", "Mystery" })
check(two.Color.R == repeated.Color.R and two.Color.G == repeated.Color.G, "Mystery blend color independent of order")
blend.ClearCup(p)
check(dev.SpawnCustomer(p) ~= nil and days.IsServing(p), "dev customer starts serveable day")
check(dev.SpawnCustomer(p) == customer.GetSnapshot(p).Model, "dev spawn reuses active customer")
check(customer.GetSnapshot(p).RequestId == nil and not customer.Serve(p), "arrival required before request and serving")
flush()
for index, reaction in { "Love", "Disgust", "Freeze" } do
    local smoothie = actualBlend(if index == 2 then { "Tire", "Noob" } else { "Strawberry", "Ice", "Tire" })
    local current = customer.GetSnapshot(p)
    check(current.Ready, "waypoint arrival enables serving")
    local request
    for _, definition in requests do
        if definition.Id == current.RequestId then
            request = definition
        end
    end
    check(request ~= nil, "arrival assigns configured request")
    local bubble = current.Model.PrimaryPart:FindFirstChild("OrderBubble")
    check(
        bubble.AlwaysOnTop and bubble.Adornee == current.Model:FindFirstChild("Head"),
        "order adorns head above world geometry"
    )
    check(bubble:FindFirstChildWhichIsA("TextLabel").BackgroundTransparency == 1, "order has no gray panel")
    check(
        current.Model:GetPivot().Position.X == refs.CustomerCounter.CFrame.Position.X,
        "arrival uses actual CustomerCounter destination"
    )
    check(
        bubble:FindFirstChildWhichIsA("TextLabel").Text == request.DisplayText,
        "bubble displays configured request text"
    )
    check(not customer.CanSpawn(p), "active order prevents duplicate spawn")
    local success = index ~= 2
    local grade = if success then "A" else "D"
    local payout = if success then request.BasePayout else 0
    reaction = if success then "Smile" else "Disgust"
    check(not dev.ForceReaction(p, "Fake"), "unknown reaction rejected")
    local cup
    for _, object in allInstances do
        if object.Parent == p.Backpack and object.Name == "Smoothie" then
            cup = object
        end
    end
    local authenticated = blend.GetCup(p)
    authenticated.Ingredients[1] = "Mystery"
    check(
        blend.GetCup(p).Ingredients[1] == smoothie.Ingredients[1],
        "cup snapshot cannot mutate authoritative contents"
    )
    cup.Parent = other.Backpack
    check(not blend.GetCup(p) and not blend.GetCup(other, cup), "transferred tool does not authorize either player")
    cup.Parent = p.Backpack
    cup:SetAttribute("Payout", 999999)
    cup:SetAttribute("BlendId", "forged")
    if success then
        p:SetAttribute("playerCash", 999999)
    end
    local cash = data.GetCash(p)
    p.Near = false
    check(
        not customer.Serve(p) and blend.GetCup(p) ~= nil and data.GetCash(p) == cash,
        "distant serve preserves cup and cash"
    )
    p.Near = true
    check(not customer.Serve(other), "foreign player cannot serve owner's cup/customer")
    check(customer.Serve(p, 999999), "real serve transaction succeeds")
    check(bubble.Destroyed, "order billboard destroyed on completion")
    check(
        data.GetCash(p) == cash + payout and p:GetAttribute("playerCash") == cash + payout,
        "cash payout ignores client reward and cash attributes"
    )
    check(
        p:GetAttribute("CustomerSatisfaction") == grade and p:GetAttribute("CustomerReaction") == reaction,
        "success selects positive reaction and failure selects negative reaction"
    )
    check(
        current.Model:GetAttribute("RequestId") == nil and current.Model:GetAttribute("OrderSucceeded") == success,
        "order completed on success or failure"
    )
    check(cup.Destroyed and not blend.GetCup(p) and not customer.Serve(p), "served cup cannot be replayed")
    check(#days.GetSnapshot(p).Grades == index, "GameService records authoritative completion")
    flush()
end
check(days.GetSnapshot(p).State == "FINISHED", "real three-customer loop finishes")
for _, reaction in { "Launch", "NoobTransform" } do
    dev.ResetPlot(p)
    check(
        dev.SpawnCustomer(p) ~= nil and dev.ForceReaction(p, reaction),
        "remaining filming reaction forceable: " .. reaction
    )
end
local moments = {}
for _, event in presentation do
    moments[event.Moment] = (moments[event.Moment] or 0) + 1
    check(event.UserId == p.UserId, "presentation identifies plot owner")
end
check(
    moments.BlendStarted == 6
        and moments.BlendCompleted == 6
        and moments.SmoothieDispensed == 6
        and moments.CustomerReaction == 3,
    "presentation moments emitted once per transaction"
)
check(moments.BlendProgressChanged == 12, "rapid updates emit first and final progress per batch")
local emittedResult
for _, event in presentation do
    if event.Moment == "BlendCompleted" then
        emittedResult = event.Payload
    end
end
check(
    emittedResult.Color and #emittedResult.IngredientIds == 3 and emittedResult.BlendId,
    "completion includes presentation safe result"
)
studio = false
check(
    not dev.SpawnIngredient(p, "Ice")
        and not dev.PrepareCombination(p, { "Ice" })
        and not dev.SpawnCustomer(p)
        and not dev.ForceReaction(p, "Launch")
        and not dev.ClearBlender(p)
        and not dev.ResetPlot(p),
    "all filming commands blocked in production even with opt-in"
)
local logs = 0
env.print = function()
    logs += 1
end
storage:SetAttribute("DebugFilmLoop", true)
film.Log("Blend", "hidden")
check(logs == 0, "debug output blocked in production")
studio = true
film.Log("Blend", "visible")
check(logs == 1, "single Studio debug flag enables logging")
storage:SetAttribute("DebugFilmLoop", false)
film.Log("Blend", "hidden")
check(logs == 1, "debug flag disables logging")
check(
    dev.ResetPlot(p) and not customer.GetSnapshot(p) and not blend.GetCup(p) and blend.GetSnapshot(p).State == "EMPTY",
    "reset clears customer/cup/batch"
)

-- Tag-authoritative real Plot1 lookup and read-only Studio validation.
workspaceFake.FindFirstChild = function()
    return nil
end
local realTycoon = loadModule("TycoonService")
realTycoon.Init(data)
local plot = instance("Model")
plot.Name = "Plot1"
plot.Parent = workspaceFake
local collection = services.CollectionService
collection:AddTag(plot, "PlayerPlot")
local fixtureNames = {
    BlenderInput = "InputZone",
    TurbineWheel = "Turbine Wheel",
    DispenseButton = "Button",
    StartDayButton = "Start Day",
    CustomerSpawn = "Spawn",
    CustomerCounter = "Counter",
    CustomerExit = "Exit",
    PlayerStash = "Stash",
}
local fixtureObjects = {}
for role, name in fixtureNames do
    local object = instance(if role == "PlayerStash" then "Model" else "Part")
    object.Name = name
    object.Parent = plot
    object.CanQuery = true
    collection:AddTag(object, role)
    fixtureObjects[role] = object
end
local slots = {}
for index = 1, 5 do
    local slot = instance("Part")
    slot.Name = if index <= 2 then "LockedSlot" .. index else "Slot" .. index
    slot.Parent = fixtureObjects.PlayerStash
    slot:SetAttribute("SlotIndex", index)
    slots[index] = slot
end
fixtureObjects.PlayerStash.PrimaryPart = slots[1]
check(realTycoon.AssignPlot(p) == plot, "tagged human-readable plot assigned")
deps.TycoonService = realTycoon
for role, object in fixtureObjects do
    check(
        realTycoon.GetReference(p, role) == (if role == "PlayerStash" then slots[1] else object),
        "tag lookup ignores name for " .. role
    )
end
check(dev.ValidatePlot(p), "complete human-readable Plot1 passes validation")
local outputLines = {}
env.print = function(line)
    table.insert(outputLines, line)
end
local ok, report = dev.ValidatePlot(p)
check(
    ok and outputLines[1] == "[Plot Validation] Plot1" and #report == 14,
    "validator prints concise per-role and per-slot report"
)
local function failsWith(text)
    local valid, lines = dev.ValidatePlot(p)
    for _, line in lines do
        if string.find(line, text, 1, true) then
            return not valid
        end
    end
    return false
end
local decoy = instance("Part")
decoy.Name = "BlenderInput"
decoy.Parent = plot
realTycoon.AutoTagLegacyPlot(plot)
check(
    not collection:HasTag(decoy, "BlenderInput")
        and realTycoon.GetReference(p, "BlenderInput") == fixtureObjects.BlenderInput,
    "legacy migration does not duplicate explicit role"
)
fixtureObjects.BlenderInput.Name = "Any New Name"
check(
    realTycoon.GetReference(p, "BlenderInput") == fixtureObjects.BlenderInput,
    "renaming tagged object preserves lookup"
)
collection:RemoveTag(fixtureObjects.BlenderInput, "BlenderInput")
check(
    not realTycoon.GetReference(p, "BlenderInput") and failsWith("FAIL BlenderInput - Missing"),
    "runtime does not fall back to old names"
)
check(not dev.SpawnIngredient(p, "Strawberry"), "staging requires tagged input despite a living character")
collection:AddTag(fixtureObjects.BlenderInput, "BlenderInput")
collection:AddTag(decoy, "BlenderInput")
check(
    not realTycoon.GetReference(p, "BlenderInput") and failsWith("Duplicate tags"),
    "duplicate required role rejected and reported"
)
check(not dev.PrepareCombination(p, { "Strawberry" }), "staging rejects duplicate input tags")
collection:RemoveTag(decoy, "BlenderInput")
fixtureObjects.BlenderInput.CanQuery = false
check(failsWith("CanQuery must be true"), "disabled detector querying diagnosed")
fixtureObjects.BlenderInput.CanQuery = true
collection:RemoveTag(fixtureObjects.BlenderInput, "BlenderInput")
local detectorModel = instance("Model")
detectorModel.Name = "BadDetector"
detectorModel.Parent = plot
local detectorPart = instance("Part")
detectorPart.Parent = detectorModel
detectorModel.PrimaryPart = detectorPart
collection:AddTag(detectorModel, "BlenderInput")
check(failsWith("Tag the InputZone BasePart itself"), "detector model rejected even with PrimaryPart")
check(not dev.SpawnIngredient(p, "Strawberry"), "staging rejects invalid input fixture")
collection:RemoveTag(detectorModel, "BlenderInput")
collection:AddTag(fixtureObjects.BlenderInput, "BlenderInput")
fixtureObjects.CustomerSpawn.Parent = workspaceFake
check(
    not realTycoon.GetReference(p, "CustomerSpawn") and failsWith("FAIL CustomerSpawn - Missing"),
    "foreign fixture cannot satisfy assigned plot"
)
fixtureObjects.CustomerSpawn.Parent = plot
collection:RemoveTag(fixtureObjects.CustomerExit, "CustomerExit")
local invalidMarker = instance("Folder")
invalidMarker.Parent = plot
collection:AddTag(invalidMarker, "CustomerExit")
check(failsWith("Must resolve to a BasePart"), "marker without physical part diagnosed")
collection:RemoveTag(invalidMarker, "CustomerExit")
collection:AddTag(fixtureObjects.CustomerExit, "CustomerExit")
-- Reproduce an old customer-area tag resolving to its Start Day PrimaryPart.
local customerArea = instance("Model")
customerArea.Name = "Customer Area"
customerArea.Parent = plot
fixtureObjects.StartDayButton.Parent = customerArea
fixtureObjects.CustomerCounter.Parent = customerArea
customerArea.PrimaryPart = fixtureObjects.StartDayButton
collection:AddTag(customerArea, "CustomerCounter")
check(dev.ValidatePlot(p), "Studio validator agrees with explicit customer marker precedence")
check(
    realTycoon.GetReference(p, "CustomerCounter") == fixtureObjects.CustomerCounter,
    "explicit marker wins over old container tag"
)
collection:RemoveTag(fixtureObjects.CustomerCounter, "CustomerCounter")
local unresolved, explanation = realTycoon.GetReference(p, "CustomerCounter")
check(
    not unresolved and string.find(explanation, "Customer Area", 1, true),
    "ambiguous container reports path instead of selecting Start Day"
)
fixtureObjects.CustomerCounter.Name = "CustomerCounter"
check(
    realTycoon.GetReference(p, "CustomerCounter") == fixtureObjects.CustomerCounter,
    "legacy container resolves explicit named marker instead of PrimaryPart"
)
collection:AddTag(fixtureObjects.CustomerCounter, "CustomerCounter")
collection:AddTag(fixtureObjects.StartDayButton, "CustomerCounter")
check(not realTycoon.GetReference(p, "CustomerCounter"), "two tagged parts remain a configuration error")
collection:RemoveTag(fixtureObjects.CustomerCounter, "CustomerCounter")
unresolved, explanation = realTycoon.GetReference(p, "CustomerCounter")
check(not unresolved and string.find(explanation, "Start Day", 1, true), "Start Day cannot be a customer marker")
collection:RemoveTag(fixtureObjects.StartDayButton, "CustomerCounter")
collection:RemoveTag(customerArea, "CustomerCounter")
collection:AddTag(fixtureObjects.CustomerCounter, "CustomerCounter")
fixtureObjects.StartDayButton.Parent = plot
fixtureObjects.CustomerCounter.Parent = plot
customerArea:Destroy()
if customerOnly then
    print(
        "PASS: customer request/serve loop, transparent prompt cleanup, movement target, and plot marker resolution regressions."
    )
    return
end
slots[2]:SetAttribute("SlotIndex", 1)
check(failsWith("Duplicate SlotIndex") and failsWith("FAIL SlotIndex 2"), "duplicate and missing slots diagnosed")
slots[2]:SetAttribute("SlotIndex", 2.5)
check(failsWith("integer SlotIndex"), "fractional slot rejected")
slots[2]:SetAttribute("SlotIndex", "2")
check(failsWith("integer SlotIndex"), "string slot rejected")
slots[2]:SetAttribute("SlotIndex", 2)
slots[1].Name = "Anything"
check(dev.ValidatePlot(p), "slot names never authoritative")
local invalidSlot = instance("Folder")
invalidSlot.Parent = fixtureObjects.PlayerStash
invalidSlot:SetAttribute("SlotIndex", 3)
check(failsWith("integer SlotIndex"), "attribute on non-BasePart rejected")
invalidSlot:SetAttribute("SlotIndex", nil)
local nested = instance("Model")
nested.Parent = plot
collection:AddTag(nested, "PlayerPlot")
check(failsWith("Nested plot"), "nested plot ownership ambiguity diagnosed")
collection:RemoveTag(nested, "PlayerPlot")
local legacy = instance("Model")
legacy.Name = "Legacy"
legacy.Parent = workspaceFake
local legacyInput = instance("Part")
legacyInput.Name = "BlenderInput"
legacyInput.Parent = legacy
local turbine = instance("Model")
turbine.Name = "Turbine"
turbine.Parent = legacy
local blade = instance("Part")
blade.Name = "blade"
blade.Parent = turbine
realTycoon.AutoTagLegacyPlot(legacy)
check(
    collection:HasTag(legacyInput, "BlenderInput") and collection:HasTag(blade, "TurbineWheel"),
    "legacy named fixtures still auto-tag"
)
local oldReports = #outputLines
studio = false
check(not dev.ValidatePlot(p) and #outputLines == oldReports, "validator blocked silently in production")
studio = true
storage:SetAttribute("EnableDevContent", false)
check(not dev.ValidatePlot(p) and #outputLines == oldReports, "validator requires Studio opt-in")
storage:SetAttribute("EnableDevContent", true)
check(not dev.ValidatePlot(other), "unassigned player reported without assigning or mutating scene")
check(not realTycoon.GetPlot(other), "validation does not assign plots")
check(not dev.SpawnIngredient(other, "Strawberry") and not realTycoon.GetPlot(other), "staging does not assign a plot")
fixtureObjects.BlenderInput.Parent = workspaceFake
check(not dev.SpawnIngredient(p, "Strawberry"), "staging ignores input outside assigned plot")
fixtureObjects.BlenderInput.Parent = plot
fixtureObjects.BlenderInput.CFrame = frame(20, 8, 30)
local savedCharacter = p.Character
p.Character = nil
local stagedAtInput = dev.SpawnIngredient(p, "Strawberry")
check(
    stagedAtInput ~= nil and (stagedAtInput:GetPivot().Position - vec(20, 12, 30)).Magnitude == 0,
    "staging is four studs above assigned input without a character"
)
p.Character = savedCharacter
check(dev.PrepareCombination(p, { "Tire", "Noob" }), "combination stages at assigned input")
-- Separate module caches must still operate on runtime inventory and blender state.
do
    local runtimeServices = table.clone(deps)
    runtimeServices.DevContentService = dev
    local commandCache = {}
    local function commandRequire(name)
        if not runtimeServices[name] and name ~= "StudioServices" then
            return loadModule(name)
        end
        if commandCache[name] then
            return commandCache[name]
        end
        local chunk = assert(loadstring(sources[name], "CommandBar" .. name))
        setfenv(
            chunk,
            setmetatable({
                script = { Parent = parent },
                require = function(dependency)
                    return commandRequire(dependency)
                end,
            }, { __index = env })
        )
        commandCache[name] = chunk()
        return commandCache[name]
    end
    local commandDev = commandRequire("DevContentService")
    local commandBlend = commandRequire("BlendService")
    local ok, reason = pcall(commandDev.ResetScene, p)
    check(not ok and string.find(reason, "Runtime unavailable"), "pre-bootstrap tooling fails with clear guidance")
    runtimeAccess.Publish(runtimeServices)
    check(commandDev.ResetScene(p), "tool loaded before publication can reset runtime without Init")
    storage:SetAttribute("EnableDevContent", false)
    check(not commandDev.SpawnIngredient(p, "Strawberry"), "forwarded dev commands retain opt-in gate")
    storage:SetAttribute("EnableDevContent", true)
    local strawberry = commandDev.SpawnIngredient(p, "Strawberry")
    check(
        strawberry and realIngredients.GetRecord(strawberry),
        "Command Bar spawn belongs to runtime ingredient registry"
    )
    local zone = fixtureObjects.BlenderInput
    zone.Overlaps = { strawberry }
    check(commandRequire("IngredientService").Resolve(strawberry) == strawberry, "direct resolver uses runtime records")
    check(commandRequire("TycoonService").GetOwner(zone) == p, "direct owner lookup uses runtime assignments")
    check(
        commandBlend.TryInput(p, strawberry, zone),
        "direct Command Bar TryInput uses initialized runtime dependencies"
    )
    check(blend.GetSnapshot(p).Ingredients[1] == "Strawberry", "tool ingestion updates runtime batch")
    check(not realIngredients.GetRecord(strawberry), "tool ingestion consumes runtime ingredient exactly once")
    check(not commandBlend.TryInput(p, strawberry, zone), "repeat ingestion is rejected")
    local nextIngredient = commandDev.SpawnIngredient(p, "Strawberry")
    zone.Overlaps = { nextIngredient }
    local heartbeat = signal()
    services.RunService.Heartbeat = heartbeat
    local disconnectInput
    local componentChunk = assert(loadstring(sources.BlenderInputComponent, "BlenderInputComponent"))
    setfenv(
        componentChunk,
        setmetatable({
            script = { Parent = { Parent = { Services = parent } } },
            require = function(name)
                assert(name == "WorldUtil")
                return {
                    BindTag = function(tag, attach)
                        assert(tag == "BlenderInput")
                        disconnectInput = attach(zone)
                    end,
                }
            end,
        }, { __index = env })
    )
    componentChunk().Init(runtimeServices)
    heartbeat:Fire(0.1)
    disconnectInput()
    check(
        not realIngredients.GetRecord(nextIngredient),
        "actual BlenderInput heartbeat consumes tool-spawned ingredient"
    )
    check(#commandBlend.GetSnapshot(p).Ingredients == 2, "tool snapshot sees runtime component changes")
    check(commandDev.ResetScene(p) and #blend.GetSnapshot(p).Ingredients == 0, "tool reset clears runtime batch")
    check(commandDev.ResetPlot(p), "reset alias forwards to runtime")
    check(not pcall(commandBlend.Init, runtimeServices), "tooling cannot reinitialize runtime services")
    local oldServer = services.RunService.IsServer
    services.RunService.IsServer = function()
        return false
    end
    check(not pcall(commandBlend.GetSnapshot, p), "client cannot invoke tooling bridge")
    services.RunService.IsServer = oldServer
    studio = false
    check(not pcall(commandBlend.GetSnapshot, p), "tooling bridge rejects non-Studio execution")
    studio = true
    zone.Overlaps = {}
end
realTycoon.RemovePlayer(p)
deps.TycoonService = tycoon

-- Keep Heartbeat authority precise while limiting presentation traffic.
do
    blend.Reset(p)
    local ingredient = realIngredients.Spawn("Strawberry", frame(), p)
    input.Overlaps = { ingredient }
    check(blend.TryInput(p, ingredient, input), "throttle test ingests a real ingredient")
    local firstEvent = #presentation + 1
    local accepted = true
    for _ = 1, 60 do
        now += 1 / 60
        accepted = blend.AddProgress(p, wheel, 1) and accepted
    end
    check(accepted and blend.GetSnapshot(p).Progress == 60, "all 60 RPM progress updates remain authoritative")
    local updates = 0
    local previous = 0
    for index = firstEvent, #presentation do
        local event = presentation[index]
        if event.Moment == "BlendProgressChanged" then
            updates += 1
            check(event.Payload.Progress > previous, "progress notifications contain changed payloads")
            previous = event.Payload.Progress
        end
    end
    check(updates >= 8 and updates <= 10, "one second of Heartbeats produces at most ten progress notifications")
    local beforeIdle = #presentation
    check(not blend.AddProgress(p, wheel, 0) and #presentation == beforeIdle, "idle turbine sends no progress")
    check(blend.AddProgress(p, wheel, 100), "completion is accepted inside throttle window")
    check(
        presentation[#presentation - 1].Moment == "BlendProgressChanged"
            and presentation[#presentation - 1].Payload.Progress == 100
            and presentation[#presentation].Moment == "BlendCompleted",
        "final progress is delivered immediately before completion"
    )
    local afterComplete = #presentation
    check(
        not blend.AddProgress(p, wheel, 1) and #presentation == afterComplete,
        "completed turbine sends no repeated updates"
    )
end

-- Real station component + real BindTag + real ingredient registry, with controllable time/signals.
do
    local added, removed = signal(), signal()
    local itemAdded, itemRemoved = signal(), signal()
    local stations, spawned, timers = {}, {}, {}
    local clock = 0
    local collection = {
        GetTagged = function(_, tag)
            assert(tag == "IngredientSpawn" or tag == "IngredientWorldItem")
            return table.clone(if tag == "IngredientSpawn" then stations else spawned)
        end,
        GetInstanceAddedSignal = function(_, tag)
            return if tag == "IngredientSpawn" then added else itemAdded
        end,
        GetInstanceRemovedSignal = function(_, tag)
            return if tag == "IngredientSpawn" then removed else itemRemoved
        end,
    }
    local stationEnv = setmetatable({
        game = {
            GetService = function(_, name)
                return if name == "CollectionService" then collection else services[name]
            end,
        },
        task = {
            delay = function(seconds, fn)
                local timer = { At = clock + seconds, Run = fn, Cancelled = false }
                table.insert(timers, timer)
                return timer
            end,
            cancel = function(timer)
                timer.Cancelled = true
            end,
        },
    }, { __index = env })
    local worldChunk = assert(loadstring(sources.WorldUtil))
    setfenv(worldChunk, stationEnv)
    local world = worldChunk()
    local component = assert(loadstring(sources.IngredientSpawnComponent))
    setfenv(
        component,
        setmetatable({
            script = { Parent = { Parent = { Services = parent } } },
            require = function(name)
                assert(name == "WorldUtil")
                return world
            end,
        }, { __index = stationEnv })
    )
    local function advance(seconds)
        clock += seconds
        for _, timer in table.clone(timers) do
            if not timer.Cancelled and not timer.Ran and timer.At <= clock then
                timer.Ran = true
                timer.Run()
            end
        end
    end
    local function station(id, seconds, class)
        local object = instance(class or "Part")
        object.Name = "Station"
        object.Size = vec(8, 2, 8)
        object.CFrame = frame(10, 4, 0)
        object.Parent = workspaceFake
        object:SetAttribute("IngredientId", id)
        object:SetAttribute("RespawnSeconds", seconds)
        table.insert(stations, object)
        return object
    end
    local strawberryStation = station("Strawberry", nil)
    -- Initialize both historical adapters together, as server bootstrap does. Testing
    -- IngredientPickup alone would miss a second prompt created by Dispenser.
    for _, source in { sources.DispenserComponent, sources.IngredientPickupComponent } do
        local adapter = assert(loadstring(source))
        setfenv(adapter, getfenv(component))
        adapter().Init(deps)
    end
    component().Init({
        IngredientService = {
            GetDefinition = realIngredients.GetDefinition,
            Spawn = function(...)
                local item = realIngredients.Spawn(...)
                table.insert(spawned, item)
                itemAdded:Fire(item)
                return item
            end,
        },
    })
    check(#spawned == 1, "existing station spawns immediately")
    local first = spawned[1]
    local function checkSinglePickup(item)
        local prompts = {}
        for _, child in item:GetDescendants() do
            if child:IsA("ProximityPrompt") then
                table.insert(prompts, child)
            end
        end
        check(#prompts == 1, "station item exposes exactly one player-facing interaction")
        check(
            prompts[1].Name == "CarryPrompt" and prompts[1].ActionText == "Pickup",
            "sole station interaction is physical Pickup"
        )
        return prompts[1]
    end
    local firstPrompt = checkSinglePickup(first)
    local record = realIngredients.GetRecord(first)
    check(record.Id == "Strawberry" and not record.Owner and record.Claimable, "station item is registered and unowned")
    check(first.Color == definitions.Strawberry.BlendColor, "station uses existing fallback BlendColor")
    check(first.Position.Y == 8 and first.Position.X == 10, "station spawns three studs above top")
    advance(20)
    added:Fire(strawberryStation)
    strawberryStation.AncestryChanged:Fire()
    check(#spawned == 1, "time and duplicate tag/ancestry signals do not multiply stock")
    local folder = instance("Folder")
    folder.Parent = workspaceFake
    first.Parent = folder
    first.AncestryChanged:Fire()
    advance(10)
    check(#spawned == 1, "moving ingredient within Workspace does not refill station")
    firstPrompt.Triggered:Fire(p)
    check(not realIngredients.GetRecord(first), "sole station Pickup consumes original through carry transaction")
    check(inventory.ThrowHeld(p) ~= nil, "sole station Pickup creates a throwable held reservation")
    first.AncestryChanged:Fire()
    advance(4.9)
    check(#spawned == 1, "default respawn waits five seconds")
    advance(0.1)
    check(#spawned == 2 and realIngredients.GetRecord(spawned[2]), "consume refills exactly once")
    local second = spawned[2]
    checkSinglePickup(second)
    second.Parent = nil
    second.AncestryChanged:Fire()
    check(
        second.Destroyed and not realIngredients.GetRecord(second),
        "removed stock is retired to prevent reparent duplication"
    )
    removed:Fire(strawberryStation)
    check(timers[#timers].Cancelled, "untagging cancels pending refill")
    advance(10)
    check(#spawned == 2, "detached station cannot refill")
    added:Fire(strawberryStation)
    check(#spawned == 3, "retagging starts a fresh station")
    strawberryStation.Parent = nil
    strawberryStation.AncestryChanged:Fire()
    check(spawned[3].Destroyed, "moving station out of Workspace cleans its active stock")
    strawberryStation.Parent = workspaceFake
    strawberryStation.AncestryChanged:Fire()
    check(#spawned == 4, "station re-entry rebinds once")
    strawberryStation:Destroy()
    check(spawned[4].Destroyed, "destroying station cleans active stock")
    advance(10)
    check(#spawned == 4, "cleanup destruction does not schedule a refill")
    local bananaStation = station("Banana", 2)
    local tireStation = station("Tire", 7)
    added:Fire(bananaStation)
    added:Fire(tireStation)
    spawned[5]:Destroy()
    spawned[6]:Destroy()
    advance(2)
    check(#spawned == 7 and spawned[7].Name == "Banana", "stations keep independent custom timers")
    bananaStation:Destroy()
    tireStation:Destroy()
    check(timers[#timers].Cancelled, "destroying station cancels pending timer")
    advance(10)
    check(#spawned == 7, "no late stock after station destruction")
    for _, badSeconds in { 0, -1, math.huge, 0 / 0, "fast" } do
        local bad = station("Tire", badSeconds)
        added:Fire(bad)
        spawned[#spawned]:Destroy()
        check(timers[#timers].At == clock + 5, "invalid delay falls back to five seconds")
        removed:Fire(bad)
    end
    local beforeInvalid = #spawned
    added:Fire(station("Missing", 5))
    added:Fire(station(nil, 5))
    added:Fire(station(123, 5))
    added:Fire(station("Strawberry", 5, "Model"))
    check(#spawned == beforeInvalid, "bad IDs and non-BasePart stations never spawn")
end

do
    inventory.ClearHeld(p)
    inventory.ClearHeld(other)
    inventory.AddPlayer(p)
    p.Near = true
    p.Character.Children.Humanoid.Health = 100
    local fixture = instance("Model")
    fixture.Parent = workspaceFake
    local stashSlots = {}
    for index = 1, 5 do
        local slot = instance("Part")
        slot.Size = vec(5, 1, 5)
        slot.Parent = fixture
        slot:SetAttribute("SlotIndex", index)
        stashSlots[index] = slot
    end
    local savedTycoon = deps.TycoonService
    deps.TycoonService = {
        GetPlot = function(owner)
            return if owner == p then fixture else nil
        end,
        GetFixtures = function()
            return { fixture }
        end,
        GetOwner = function()
            return p
        end,
    }
    deps.IngredientService = realIngredients
    local display = loadModule("StashPresentation")
    do
        local pad = instance("Part")
        pad:SetAttribute("SlotIndex", 3)
        pad.Position = vec(12, 7, -20)
        pad.Size = vec(0.4, 10, 10)
        pad.CFrame = frame(12, 7, -20)
        for _, sign in { 1, -1 } do
            pad.CFrame.RightVector = vec(0, sign, 0)
            pad.CFrame.UpVector = vec(-sign, 0, 0)
            for n = 1, 5 do
                display.Refresh(pad, { IngredientId = "Strawberry", Count = n, Protected = false }, realIngredients)
                local total = vec(0, 0, 0)
                local copies = pad:FindFirstChild("StashDisplay"):GetChildren()
                check(#copies == n, "rotated pad count")
                for _, copy in copies do
                    local part = copy:FindFirstChildWhichIsA("BasePart", true)
                    check(math.abs(part.Size.X - 4.4) < 0.0001, "thin local X is thickness, display size is 4.4 studs")
                    check(
                        copy.CFrame.UpVector:Dot(vec(0, 1, 0)) > 0.999,
                        "display normal points upward for either axis sign"
                    )
                    check(
                        copy.Position.Y - part.Size.Y / 2 >= 7.2 + 0.12 - 0.0001,
                        "proxy bottom clears actual top surface"
                    )
                    total += copy.Position - pad.Position
                end
                check(
                    math.abs(total.X) < 0.0001 and math.abs(total.Z) < 0.0001,
                    "all count layouts center over rotated pad"
                )
            end
        end
        pad:Destroy()
    end
    local function verifyDisplay(expected)
        display.Refresh(stashSlots[3], inventory.GetSnapshot(p).Stash[3], realIngredients)
        local folder = stashSlots[3]:FindFirstChild("StashDisplay")
        check((if folder then #folder:GetChildren() else 0) == expected, "proxy count matches server count")
        for _, child in (if folder then folder:GetDescendants() else {}) do
            check(
                not realIngredients.GetRecord(child) and not collection:HasTag(child, "IngredientWorldItem"),
                "display has no world identity"
            )
            check(not child:IsA("ProximityPrompt"), "display has no pickup prompt")
            if child:IsA("BasePart") then
                check(
                    child.Anchored and not child.CanCollide and not child.CanQuery and not child.CanTouch,
                    "display parts are inert"
                )
                check(not inventory.CarryWorldItem(p, child), "proxy pickup rejected")
            end
        end
    end
    local function carry(id)
        local world = realIngredients.Spawn(id, frame(), nil, true)
        check(inventory.CarryWorldItem(p, world), "stash fixture pickup")
    end
    for n = 1, 5 do
        carry("Strawberry")
        check(inventory.Deposit(p, "Strawberry", 3), "empty/stack deposit")
        check(not inventory.GetHeldIngredientId(p), "deposit clears held reservation")
        check(not inventory.Deposit(p, "Strawberry", 3), "repeated deposit cannot duplicate")
        check(inventory.GetSnapshot(p).Stash[3].Count == n, "exact deposit count")
        verifyDisplay(n)
    end
    carry("Strawberry")
    check(not inventory.Deposit(p, "Strawberry", 3), "sixth rejected")
    check(not inventory.Withdraw(p, 3), "withdraw requires empty hands")
    check(inventory.GetHeldIngredientId(p) == "Strawberry", "rejection preserves held unit")
    inventory.ClearHeld(p)
    check(not inventory.Withdraw(other, 3, p), "non-owner normal-slot withdrawal rejected")
    check(not inventory.CanWithdraw(other, p, 1), "protected authorization rejects non-owner")
    check(
        inventory.GetSnapshot(p).Stash[1].Protected and not inventory.GetSnapshot(p).Stash[3].Protected,
        "explicit protection even when empty"
    )
    local snapshot = inventory.GetSnapshot(p)
    snapshot.Stash[3].Count = 100
    check(inventory.GetSnapshot(p).Stash[3].Count == 5, "snapshot cannot mutate authoritative state")
    local createVisual = realIngredients.CreateVisual
    realIngredients.CreateVisual = function()
        return nil
    end
    check(
        not inventory.Withdraw(p, 3) and inventory.GetSnapshot(p).Stash[3].Count == 5,
        "failed visual leaves stack intact"
    )
    realIngredients.CreateVisual = createVisual
    local backpack = p:FindFirstChildOfClass("Backpack")
    local backpackParent = backpack.Parent
    backpack.Parent = nil
    local savedBackpack = p.Backpack
    p.Backpack = nil
    check(
        not inventory.Withdraw(p, 3) and inventory.GetSnapshot(p).Stash[3].Count == 5,
        "failed equip rolls back count"
    )
    backpack.Parent = backpackParent
    p.Backpack = savedBackpack
    local duplicate = instance("Part")
    duplicate:SetAttribute("SlotIndex", 3)
    duplicate.Parent = fixture
    check(not inventory.Withdraw(p, 3), "duplicate slot index rejected")
    duplicate:Destroy()
    p.Near = false
    check(not inventory.Withdraw(p, 3), "distant withdrawal rejected")
    p.Near = true
    p.Character.Children.Humanoid.Health = 0
    check(not inventory.Withdraw(p, 3), "dead withdrawal rejected")
    p.Character.Children.Humanoid.Health = 100
    check(inventory.Withdraw(p, 3), "withdraw one directly into hands")
    check(inventory.GetHeldIngredientId(p) == "Strawberry", "withdraw equips correct ingredient")
    verifyDisplay(4)
    check(inventory.Deposit(p, "Strawberry", 3), "withdraw redeposit conserves unit")
    check(inventory.Withdraw(p, 3), "repeat withdrawal")
    inventory.ClearHeld(p)
    carry("Banana")
    check(not inventory.Deposit(p, "Banana", 3), "different ingredient rejected")
    p.Near = false
    check(not inventory.Deposit(p, "Banana", 4), "distant deposit rejected")
    p.Near = true
    p.Character.Children.Humanoid.Health = 0
    check(not inventory.Deposit(p, "Banana", 4), "dead deposit rejected")
    p.Character.Children.Humanoid.Health = 100
    for _, index in { 0, 6, 1.5, 0 / 0 } do
        check(not inventory.Deposit(p, "Banana", index), "invalid index rejected")
    end
    inventory.ClearHeld(p)
    for n = 3, 0, -1 do
        check(inventory.Withdraw(p, 3), "withdraw exactly one")
        verifyDisplay(n)
        inventory.ClearHeld(p)
    end
    check(
        inventory.GetSnapshot(p).Stash[3].IngredientId == nil and not inventory.Withdraw(p, 3),
        "final withdrawal clears type"
    )
    carry("Banana")
    check(inventory.Deposit(p, "Banana", 3), "empty slot adopts new type")
    local templates = instance("Folder")
    templates.Name = "Ingredients"
    templates.Parent = storage
    local template = instance("Part")
    template.Name = "Banana"
    template.Size = vec(4, 3, 2)
    template.Parent = templates
    local pickup = instance("ProximityPrompt")
    pickup.Parent = template
    collection:AddTag(template, "IngredientWorldItem")
    verifyDisplay(1)
    check(not template.Destroyed and pickup.Parent == template, "display cloning preserves source template")
    templates:Destroy()
    p.CharacterRemoving:Fire(p.Character)
    check(inventory.GetSnapshot(p).Stash[3].Count == 1, "character reset preserves stash")
    inventory.RemovePlayer(p)
    display.Refresh(stashSlots[3], nil, realIngredients)
    check(
        not stashSlots[3]:FindFirstChild("StashDisplay") and next(inventory.GetSnapshot(p).Stash) == nil,
        "disconnect clears state and display"
    )
    inventory.AddPlayer(p)
    deps.TycoonService = savedTycoon
    fixture:Destroy()
end

local before = data.GetSnapshot(p).Cash
blend.RemovePlayer(p)
inventory.RemovePlayer(p)
days.RemovePlayer(p)
data.RemovePlayer(p)
check(blend.GetSnapshot(p) == nil and days.GetSnapshot(p) == nil, "player cleanup removes sessions")
data.AddPlayer(p)
check(before > 0 and data.GetCash(p) == 0, "in-memory data intentionally does not persist")
print(string.format("PASS: %d server state assertions (mocked Roblox boundary).", count))
