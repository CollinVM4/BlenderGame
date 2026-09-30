-- Queue/plot lifecycle integration; real services with deterministic engine time.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
env.math = table.clone(math)
env.math.random = function(low)
    return low or 0
end
local timers = {}
env.task.delay = function(seconds, fn)
    table.insert(timers, { At = now + seconds, Run = fn })
end
local function advance(seconds)
    local target = now + seconds
    while true do
        table.sort(timers, function(a, b)
            return a.At < b.At
        end)
        if not timers[1] or timers[1].At > target then
            break
        end
        local timer = table.remove(timers, 1)
        now = timer.At
        timer.Run()
        flush()
    end
    now = target
    flush()
end
workspaceFake.FindFirstChild = function()
    return nil
end
local owner = instance("Player")
owner.Name, owner.UserId, owner.Near = "QueueOwner", 501, true
local foreign = instance("Player")
foreign.Name, foreign.UserId, foreign.Near = "Foreign", 502, true
local plot = instance("Model")
plot.Name, plot.Parent = "Plot", workspaceFake
local refs = {}
for index, name in { "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerSpawn", "CustomerExit" } do
    local marker = instance("Part")
    marker.Name, marker.Parent, marker.CFrame = name, plot, frame(index * 10, 0, 0)
    marker.CFrame.LookVector = vec(1, 0, 0)
    refs[name] = marker
end
local customer = loadModule("CustomerService")
local tycoon = loadModule("TycoonService")
local days = loadModule("GameService")
local economy = loadModule("Economy")
local requests = loadModule("CustomerRequests")
table.clear(requests.Definitions)
requests.Definitions[1] =
    { Id = "QueueRed", DisplayText = "Something RED!", RequiredTags = { "Red" }, BasePayout = 25, MinJumpTier = 0 }
requests.SpecialCustomerChance = 0
local dialoguePlays = 0
cache.AudioService.CreateBlendGroup = function(root)
    local audio = {}
    for _, name in { "dialogueSound", "notReadySound", "customerServeSound" } do
        local sound = instance("Sound")
        sound.Parent = root
        sound.Stop = function() end
        sound.Play = function(self)
            self.IsPlaying = true
            if name == "dialogueSound" then
                dialoguePlays += 1
            end
        end
        audio[name] = sound
    end
    return audio
end
local cash, consumed, cup = 0, 0, nil
local deps = {
    CustomerService = customer,
    TycoonService = tycoon,
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(callback)
        end,
    },
    PlayerDataService = {
        GetUpgrade = function()
            return 1
        end,
        HasEntitlement = function()
            return false
        end,
        AddCash = function(_, amount)
            cash += amount
        end,
        GetCash = function()
            return cash
        end,
        IncrementStat = function() end,
    },
    BlendService = {
        ConsumeCup = function()
            local result = cup
            cup = nil
            if result then
                consumed += 1
            end
            return result
        end,
    },
}
customer.Init(deps, days.CustomerServed, function()
    return false
end) -- Legacy day gate is irrelevant.
days.Init(deps)
days.AddPlayer(owner)
tycoon.Init({ SessionStarted = customer.ActivateForPlayer, SessionEnded = customer.CleanupSession })
tycoon.AutoTagLegacyPlot(plot)
