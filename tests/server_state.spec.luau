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
local function instance(class)
    local object = { ClassName = class, Children = {}, Attributes = {} }
    object.Activated = {
        Connect = function()
            return { Disconnect = function() end }
        end,
    }
    function object:GetDescendants()
        return {}
    end
    function object:IsDescendantOf(target)
        return self.Parent == target
    end
    function object:FindFirstChildOfClass(name)
        return self.Children[name]
    end
    function object:IsA(name)
        return name == self.ClassName or (name == "BasePart" and self.ClassName == "Part")
    end
    function object:FindFirstChild(name)
        return self.Children[name]
    end
    function object:SetAttribute(key, value)
        self.Attributes[key] = value
    end
    function object:GetAttribute(key)
        return self.Attributes[key]
    end
    function object:Destroy()
        self.Parent = nil
        self.Destroyed = true
    end
    return object
end
local shared = { Constants = {}, Types = "Types" }
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
    Debris = {},
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
    Enum = { RaycastFilterType = { Exclude = "Exclude" } },
    task = {
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
            return object
        end,
    },
    AudioService = {},
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
local function player(name)
    local p = instance("Player")
    p.Name = name
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
local wheel = { Owner = p }
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
p.Near = false
check(not blend.AddProgress(p, wheel, 10), "remote wheel rejected")
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

local before = data.GetSnapshot(p).Cash
blend.RemovePlayer(p)
inventory.RemovePlayer(p)
days.RemovePlayer(p)
data.RemovePlayer(p)
check(blend.GetSnapshot(p) == nil and days.GetSnapshot(p) == nil, "player cleanup removes sessions")
data.AddPlayer(p)
check(before > 0 and data.GetCash(p) == 0, "in-memory data intentionally does not persist")
print(string.format("PASS: %d server state assertions (mocked Roblox boundary).", count))
