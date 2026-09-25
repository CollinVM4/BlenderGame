local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, callback)
            table.insert(callbacks, callback)
        end,
        Fire = function(_, ...)
            for _, callback in callbacks do
                callback(...)
            end
        end,
    }
end
local attributes = {
    playerCash = 425,
    CarryCapacity = 3,
    PlotSessionId = "test-session",
    PlotMembershipRevision = 1,
    MovementSpeedPurchasedLevel = 0,
    SprintStaminaPurchasedLevel = 0,
    JumpPurchasedLevel = 0,
    CarryCapacityLevel = 0,
    MovementSpeedLevel = 0,
    SprintStaminaLevel = 0,
    JumpLevel = 0,
    BaseWalkSpeed = 22,
    StaminaMax = 60,
}
local signals = {}
local player = {
    WaitForChild = function()
        return {}
    end,
    GetAttribute = function(_, name)
        return attributes[name]
    end,
    GetAttributeChangedSignal = function(_, name)
        signals[name] = signals[name] or signal()
        return signals[name]
    end,
}
local function set(name, value)
    attributes[name] = value
    if signals[name] then
        signals[name]:Fire()
    end
end
local sent = {}
local remote = {
    IsA = function(_, class)
        return class == "RemoteEvent"
    end,
    OnClientEvent = signal(),
    FireServer = function(_, ...)
        table.insert(sent, { ... })
    end,
}
local events = {
    WaitForChild = function()
        return remote
    end,
}
local shared = {
    Constants = { Upgrades = "Upgrades", SprintConfig = "SprintConfig" },
    WaitForChild = function()
        return events
    end,
}
local storage = {
    Shared = shared,
    WaitForChild = function()
        return shared
    end,
}
local timers, warnings, modules = {}, {}, {}
local view = { Cash = {}, Rows = {} }
local creates = 0
modules.UpgradesGui = {
    Create = function()
        creates += 1
        for _, id in { "MovementSpeed", "SprintStamina", "Jump", "CarryCapacity" } do
            view.Rows[id] = { Level = {}, Stat = {}, Purchase = { Activated = signal() } }
        end
        return view
    end,
}
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local fn = assert(loadstring(sources[name], name))
    setfenv(
        fn,
        setmetatable({
            game = {
                GetService = function(_, service)
                    return if service == "Players" then { LocalPlayer = player } else storage
                end,
            },
            script = {
                Parent = { Parent = { UI = { UpgradeDisplay = "UpgradeDisplay", UpgradesGui = "UpgradesGui" } } },
            },
            require = load,
            Color3 = {
                fromRGB = function(...)
                    return { ... }
                end,
            },
            warn = function(message)
                table.insert(warnings, message)
            end,
            task = {
                spawn = function(fn)
                    fn()
                end,
                delay = function(seconds, fn)
                    table.insert(timers, { seconds, fn })
                end,
            },
        }, { __index = getfenv() })
    )
    modules[name] = fn()
    return modules[name]
end
local display = load("UpgradeDisplay")
for _, track in display.Tracks do
    local tiers = load("Upgrades")[track.Id]
    for level = 0, #tiers - 1 do
        local row = display.Row(track.Id, level, tiers[level + 1].Value)
        check(row.Level == level, "displayed level")
        check(row.Max == (level == #tiers - 1), "max level detection")
        check(row.Price == (if level < #tiers - 1 then tiers[level + 2].Cost else nil), "next price")
        check(
            row.Stat
                == display.Stat(track.Id, tiers[level + 1].Value)
                    .. (
                        if level < #tiers - 1
                            then " → " .. display.Stat(track.Id, tiers[level + 2].Value)
                            else (if track.Id == "CarryCapacity" then " / " .. tiers[#tiers].Value else "")
                    ),
            "next stat"
        )
    end
end
check(display.Stat("SprintStamina", 60) == "3s" and display.Stat("SprintStamina", 120) == "6s", "stamina seconds")
check(display.Row("Jump", 2, nil).Stat == "95 → 116", "jump from replicated level")
check(display.Row("MovementSpeed", nil, nil) == nil, "wait for replication")
check(display.Row("MovementSpeed", 4, 22) == nil, "invalid level")
local controller = load("Controller")
controller.Init()
controller.Init()
check(creates == 1, "idempotent init")
check(view.Cash.Text == "$ 425", "initial authoritative cash")
set("playerCash", 800)
check(view.Cash.Text == "$ 800", "cash replication")
local function click(id)
    view.Rows[id].Purchase.Activated:Fire()
end
local function result(id, success, reason)
    remote.OnClientEvent:Fire("PurchaseUpgradeResult", {
        upgradeId = id,
        success = success,
        reason = reason,
        level = 3,
        PlotSessionId = attributes.PlotSessionId,
        MembershipRevision = attributes.PlotMembershipRevision,
    })
end
for _, id in { "MovementSpeed", "SprintStamina", "Jump", "CarryCapacity" } do
    local before = #sent
    click(id)
    check(
        #sent == before + 1
            and #sent[#sent] == 4
            and sent[#sent][4].PlotSessionId == attributes.PlotSessionId
            and sent[#sent][4].MembershipRevision == attributes.PlotMembershipRevision
            and sent[#sent][3] == 2
            and sent[#sent][1] == "PurchaseUpgrade"
            and sent[#sent][2] == id,
        "exact request contract"
    )
    click(id)
    click("Jump")
    check(#sent == before + 1, "global pending guard")
    result(id, false, "InsufficientCash")
    check(view.Rows[id].Purchase.Text == "NOT ENOUGH CASH", "insufficient cash feedback")
end
click("MovementSpeed")
result("MovementSpeed", true, "Success")
check(view.Rows.MovementSpeed.Purchase.Text == "UPGRADED!", "success feedback")
check(view.Rows.MovementSpeed.Level.Text == "Level 0" and view.Cash.Text == "$ 800", "result does not own state")
set("MovementSpeedPurchasedLevel", 1)
set("BaseWalkSpeed", 32)
check(view.Rows.MovementSpeed.Stat.Text == "32 → 37", "replication after response")
result("Jump", false, "MaxLevel")
local before = #sent
click("Jump")
check(#sent == before and view.Rows.Jump.Purchase.Text == "MAX", "server max blocks request")
set("JumpPurchasedLevel", 3)
click("Jump")
check(#sent == before and view.Rows.Jump.Stat.Text == "116", "replicated max blocks request")
result("SprintStamina", false, "InvalidUpgrade")
check(#warnings == 1 and view.Rows.SprintStamina.Purchase.Text == "UNAVAILABLE", "invalid upgrade stays nontechnical")
click("MovementSpeed")
local timeout = timers[#timers]
check(timeout[1] == 5, "bounded pending timeout")
timeout[2]()
check(view.Rows.MovementSpeed.Purchase.Text == "PLEASE TRY AGAIN", "timeout recovers")
before = #sent
click("MovementSpeed")
check(#sent == before + 1, "retry after timeout")
local pendingLabel = view.Rows.MovementSpeed.Purchase.Text
timeout[2]()
check(
    view.Rows.MovementSpeed.Purchase.Text == pendingLabel and not view.Rows.MovementSpeed.Purchase.Interactable,
    "stale timer cannot clear new request"
)
print(string.format("PASS: %d upgrade UI assertions.", count))

result("MovementSpeed", true, "Success")
click("CarryCapacity")
check(sent[#sent][2] == "CarryCapacity" and sent[#sent][3] == 2, "carry requests next tier")
result("CarryCapacity", true, "Success")
set("CarryCapacityLevel", 1)
set("CarryCapacity", 5)
check(view.Rows.CarryCapacity.Level.Text == "Level 2", "carry level uses one-based label")
click("CarryCapacity")
check(sent[#sent][3] == 3, "carry requests third tier")
result("CarryCapacity", true, "Success")
set("CarryCapacityLevel", 2)
set("CarryCapacity", 7)
check(view.Rows.CarryCapacity.Stat.Text == "7 / 7" and view.Rows.CarryCapacity.Purchase.Text == "MAX", "carry max UI")
print("PASS: carry upgrade integration")

set("PlotMembershipRevision", 2)
remote.OnClientEvent:Fire("PurchaseUpgradeResult", {
    upgradeId = "MovementSpeed",
    success = false,
    reason = "MaxLevel",
    PlotSessionId = "test-session",
    MembershipRevision = 1,
})
check(view.Rows.MovementSpeed.Purchase.Text ~= "MAX", "stale response cannot lock new membership UI")
set("JumpLevel", 0)
check(view.Rows.Jump.Stat.Text == "116", "personal debug projection does not change purchased upgrade display")
