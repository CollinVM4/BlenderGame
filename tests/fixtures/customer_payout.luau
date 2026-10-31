-- Real server serve transaction, with a one-use authoritative cup boundary.
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
local customer = loadModule("CustomerService")
local data = loadModule("PlayerDataService")
bindTestData(data)
local owner = instance("Player")
owner.Name, owner.UserId, owner.Near = "PayoutOwner", 42, true
data.AddPlayer(owner)
assignTestSession(owner)
local plot = instance("Model")
local refs = {}
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].CFrame = frame()
end
local config = loadModule("CustomerRequests")
local originalDefinitions = table.clone(config.Definitions)
table.clear(config.Definitions)
config.SpecialCustomerChance = 0
config.RegularWildcardChance = 0
config.Definitions[1] = {
    Id = "Blue",
    DisplayText = "Blue please!",
    RequiredTags = { "Blue" },
    BasePayout = 250,
    MinJumpTier = 0,
    GoodResponse = "Thanks!",
    BadResponse = "Not blue!",
}
local cup, completed, consumed = nil, 0, 0
local nestedServe = false
local announcements = loadModule("AnnouncementService")
announcements.Init({ IngredientService = loadModule("IngredientService") })
local announcementsSent = {}
shared.Events:FindFirstChild("RareIngredientSpawned").FireAllClients = function(_, payload)
    table.insert(announcementsSent, payload)
end
owner.DisplayName = "Payout Display"

local luckyFactors = {}
customer.Init({
    LuckyBlockService = {
        GetCashMultiplier = function(player)
            return luckyFactors[player] or 1
        end,
    },
    AnnouncementService = announcements,
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(callback)
        end,
    },
    PlayerDataService = data,
    TycoonService = setmetatable({
        GetReference = function(_, name)
            return refs[name]
        end,
    }, { __index = sessionTestAuthority }),
    BlendService = {
        ConsumeCup = function()
            local result = cup
            if result then
                cup = nil
                consumed += 1
                nestedServe = customer.Serve(owner)
            end
            return result
        end,
    },
}, function()
    completed += 1
end)
