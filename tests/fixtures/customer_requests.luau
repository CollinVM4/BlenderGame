-- Real CustomerService with the shared fake Roblox boundary.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
env.math = table.clone(math)
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
env.UDim2.fromOffset = function(x, y)
    return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
local function player(name)
    local owner = instance("Player")
    owner.Name = name
    owner.UserId = #allInstances
    owner.Parent = services.Players
    owner.Near = true
    assignTestSession(owner)
    return owner
end
local data = loadModule("PlayerDataService")
bindTestData(data)
local requestConfig = loadModule("CustomerRequests")
local requests = requestConfig.Definitions
local customer = loadModule("CustomerService")
local refs = {}
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].CFrame = frame()
end
local plots = {}
local function getPlot(owner)
    return assignTestSession(owner)
end
local function getOwner(plot)
    return sessionTestAuthority.GetOwner(plot)
end
local function requestAuthority(reference)
    return setmetatable({ GetReference = reference }, { __index = sessionTestAuthority })
end
local function setTestJump(owner, tier)
    customer.DeactivateForPlayer(owner)
    sessionTestAuthority.RemovePlayer(owner)
    assignTestSession(owner)
    sessionTestAuthority.SetCash(owner, 200000)
    for _ = 1, tier do
        setup(buyTestUpgrade(data, owner, "Jump"), "set purchased test tier")
    end
end
local function spawnFor(owner)
    local random = env.math.random
    env.math.random = math.random
    customer.ActivateForPlayer(owner)
    env.math.random = random
    return customer.SpawnForPlayer(owner)
end
customer.Init({
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(callback)
        end,
    },
    PlayerDataService = data,
    TycoonService = requestAuthority(function(_, name)
        return refs[name]
    end),
}, function() end, function()
    return true
end)
