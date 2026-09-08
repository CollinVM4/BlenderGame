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
    local cf = { Position = vec(x or 0, y or 0, z or 0), LookVector = vec(0, 0, -1) }
    function cf:Lerp(other, alpha)
        local v = self.Position + (other.Position - self.Position) * alpha
        return frame(v.X, v.Y, v.Z)
    end
    return setmetatable(cf, {
        __mul = function(a, b)
            local v = a.Position + b.Position
            return frame(v.X, v.Y, v.Z)
        end,
    })
end
local function instance(class)
    local object = { ClassName = class, Children = {}, Attributes = {} }
    table.insert(allInstances, object)
    object.Activated = signal()
    object.Triggered = signal()
    object.Destroying = signal()
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
    Vector3 = { zero = vec(0, 0, 0), new = vec },
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
check(inventory.Deposit(p, "Strawberry", 1), "deposit protected slot")
check(not inventory.Steal(other, p, 1), "protected slot cannot be stolen")
check(inventory.Deposit(p, "Strawberry", 3) and inventory.Deposit(p, "Strawberry", 3), "stack unprotected slot")
check(inventory.Steal(other, p, 3), "steal one unit")
check(inventory.GetSnapshot(p).Stash[3].Count == 1, "stealing never takes entire stack")
check(not inventory.Steal(other, p, 3), "steal cooldown / victim protection enforced")
other.Near = false
check(not inventory.Withdraw(other, 3), "remote stash access rejected")
other.Near = true
check(inventory.GetStashLayout(p).Slots == 5, "normal stash layout")
data.SetEntitlement(p, "VIPStorage", true)
check(inventory.GetStashLayout(p).Protected == 5 and inventory.GetStashLayout(p).Slots == 10, "VIP layout")
check(not inventory.Steal(other, p, 3), "VIP protection applies to existing slots")
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
    local humanoid = { Health = 100 }
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
env.CFrame = { new = frame }
p.Character.Children.HumanoidRootPart.CFrame = frame()
function p.Character.Children.Humanoid:EquipTool(tool)
    tool.Parent = p.Character
end
input.CFrame = frame()
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerExit" } do
    refs[name] = { CFrame = frame() }
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
flush()
for index, reaction in { "Love", "Disgust", "Freeze" } do
    local smoothie = actualBlend({ "Strawberry", "Tire", "Noob" })
    local current = customer.GetSnapshot(p)
    check(current.Ready, "waypoint arrival enables serving")
    local grade = customer.CalculateGrade(smoothie, current.Preference)
    local payout = customer.CalculatePayout(p, grade)
    check(dev.ForceReaction(p, reaction), "force configured reaction " .. reaction)
    check(not dev.ForceReaction(p, "Fake"), "unknown reaction rejected")
    local cup
    for _, object in allInstances do
        if object.Parent == p.Backpack and object.Name == "Smoothie" then
            cup = object
        end
    end
    local authenticated = blend.GetCup(p)
    authenticated.Ingredients[1] = "Mystery"
    check(blend.GetCup(p).Ingredients[1] == "Strawberry", "cup snapshot cannot mutate authoritative contents")
    cup.Parent = other.Backpack
    check(not blend.GetCup(p) and not blend.GetCup(other, cup), "transferred tool does not authorize either player")
    cup.Parent = p.Backpack
    cup:SetAttribute("Payout", 999999)
    cup:SetAttribute("BlendId", "forged")
    p:SetAttribute("playerCash", 999999)
    local cash = data.GetCash(p)
    check(not customer.Serve(other), "foreign player cannot serve owner's cup/customer")
    check(customer.Serve(p, 999999), "real serve transaction succeeds")
    check(
        data.GetCash(p) == cash + payout and p:GetAttribute("playerCash") == cash + payout,
        "cash payout ignores client reward and cash attributes"
    )
    check(
        p:GetAttribute("CustomerSatisfaction") == grade and p:GetAttribute("CustomerReaction") == reaction,
        "grade independent of forced reaction"
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

local before = data.GetSnapshot(p).Cash
blend.RemovePlayer(p)
inventory.RemovePlayer(p)
days.RemovePlayer(p)
data.RemovePlayer(p)
check(blend.GetSnapshot(p) == nil and days.GetSnapshot(p) == nil, "player cleanup removes sessions")
data.AddPlayer(p)
check(before > 0 and data.GetCash(p) == 0, "in-memory data intentionally does not persist")
print(string.format("PASS: %d server state assertions (mocked Roblox boundary).", count))
