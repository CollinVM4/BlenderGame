loadModule("FilmingUtil").Init()
local tasks = loadModule("TasksService")
tasks.Init({ TycoonService = sessionTestAuthority })
tasks.AddPlayer(owner)
customer.Init({
    TasksService = tasks,
    PlayerDataService = data,
    TycoonService = setmetatable({
        GetReference = function(_, name)
            return refs[name]
        end,
    }, { __index = sessionTestAuthority }),
    BlendService = {
        GetCup = function()
            return cup
        end,
        ConsumeCup = function()
            local result = cup
            cup = nil
            return result
        end,
    },
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(callback)
        end,
    },
}, function() end)
-- Tasks counts valid rated cups independently of order fulfillment, including
-- C/D, while grading and payout keep using the real evaluator.
for index, recipe in
    {
        { "Blueberry", "Blueberry", "Blueberry" },
        { "Blueberry", "Blueberry", "Banana" },
        { "Blueberry", "Banana", "Banana" },
        { "Banana", "Banana", "Banana" },
    }
do
    customer.ActivateForPlayer(owner)
    local model = customer.SpawnForPlayer(owner)
    flush()
    cup = { Ingredients = recipe, BlendId = "task-serve-" .. index }
    local evaluation = customer.EvaluateOrder(cup, config.Definitions[1])
    setup(evaluation.IsValid, "valid rated cup qualifies")
    check(evaluation.Grade == ({ "A", "B", "C", "D" })[index], "real evaluation covers each grade")
    local before = sessionTestAuthority.GetCash(owner)
    setup(customer.Serve(owner, model), "real serve")
    check(owner:GetAttribute("TasksServeTotal") == index, "all valid grades count through Serve")
    check(
        not customer.Serve(owner, model) and owner:GetAttribute("TasksServeTotal") == index,
        "replayed customer cannot count twice"
    )
    local event = presentation[#presentation]
    check(
        event.Payload.Payout == sessionTestAuthority.GetCash(owner) - before,
        "single existing serve feedback combines order and milestone cash"
    )
    customer.DeactivateForPlayer(owner)
end
check(owner:GetAttribute("TasksServeThreshold") == 10, "real third serve advances to 3/10")
customer.ActivateForPlayer(owner)
local model = customer.SpawnForPlayer(owner)
flush()
cup = { Ingredients = { "Banana", "Banana", "Banana", "Banana" }, BlendId = "failed-task-serve" }
setup(customer.Serve(owner, model), "invalid rated cup is consumed")
check(owner:GetAttribute("TasksServeTotal") == 4, "invalid real cup excluded")
customer.DeactivateForPlayer(owner)
config.RegularWildcardChance = 1
customer.ActivateForPlayer(owner)
model = customer.SpawnForPlayer(owner)
flush()
cup = { Ingredients = { "Banana", "Banana", "Banana" }, BlendId = "wildcard-task-serve" }
setup(customer.Serve(owner, model), "fulfilled wildcard serve")
check(
    owner:GetAttribute("TasksServeTotal") == 5 and model:GetAttribute("IsWildcard"),
    "wildcard qualifies without a grade"
)

customer.DeactivateForPlayer(owner)
local function child(class, name, parent)
    local item = instance(class)
    item.Name, item.Parent = name, parent
    if class == "Humanoid" then
        item.RigType = { Name = "R15" }
    end
    return item
end
local folder = child("Folder", "CustomerNPCs", storage)
local special = child("Folder", "Special", folder)
local template = child("Model", "SpecialSource", special)
local humanoid = child("Humanoid", "Humanoid", template)
local root = child("Part", "HumanoidRootPart", template)
template.PrimaryPart = root
local clone = template.Clone
template.Clone = function(self)
    local copy = clone(self)
    copy:FindFirstChildOfClass("Humanoid").Died = signal()
    return copy
end
template:SetAttribute("CustomerId", "steak")
config.NPCs.steak.RequestId = "Blue"
config.SpecialCustomerChance = 1
config.SpecialWildcardChance = 1
now += loadModule("Economy").SpecialCustomerCooldownSeconds + 1
customer.ActivateForPlayer(owner)
model = customer.SpawnForPlayer(owner)
flush()
setup(model and model:GetAttribute("CustomerId") == "steak", "authored special encounter")
cup = { Ingredients = { "Banana", "Banana", "Banana" }, BlendId = "special-task-serve" }
setup(customer.Serve(owner, model), "fulfilled special wildcard serve")
check(owner:GetAttribute("TasksServeTotal") == 6, "special fulfilled orders use same counting hook")
customer.DeactivateForPlayer(owner)
for _, definition in originalDefinitions do
    if definition.Id == "Freeloader" then
        table.insert(config.Definitions, definition)
    end
end
sessionTestAuthority.SetCash(owner, 1000000)
setup(
    sessionTestAuthority.PurchaseUpgrade(owner, "Bat", 2, sessionTestAuthority.GetRequestContext(owner)),
    "eligible for Freeloader"
)
template:SetAttribute("CustomerId", "freeloader")
config.SpecialWildcardChance = 0
now += loadModule("Economy").SpecialCustomerCooldownSeconds + 1
customer.ActivateForPlayer(owner)
model = customer.SpawnForPlayer(owner)
flush()
setup(model and model:GetAttribute("CustomerId") == "freeloader", "Freeloader encounter")
cup = { Ingredients = { "Banana", "Banana", "Banana" }, BlendId = "freeloader-task-serve" }
setup(customer.Serve(owner, model), "real Freeloader serve")
check(owner:GetAttribute("TasksServeTotal") == 6, "real Freeloader excluded from task progress")
