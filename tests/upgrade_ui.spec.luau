local count = 0
local function check(value, message)
    assert(value, message)
    count += 1
end
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, callback)
            local entry = { fn = callback, live = true }
            table.insert(callbacks, entry)
            return {
                Disconnect = function()
                    entry.live = false
                end,
            }
        end,
        Fire = function(_, ...)
            for _, callback in callbacks do
                if callback.live then
                    callback.fn(...)
                end
            end
        end,
    }
end
local function instance(class, name, parent)
    local properties = { Enabled = true, Visible = true, TextTransparency = 0 }
    local propertySignals = {}
    local object = {
        ClassName = class,
        Name = name,
        Parent = parent,
        children = {},
        DescendantAdded = signal(),
        DescendantRemoving = signal(),
        Activated = signal(),
        TextWrites = 0,
        attributes = {},
    }
    setmetatable(object, {
        __index = properties,
        __newindex = function(self, key, value)
            if key == "Text" or key == "Enabled" or key == "Visible" then
                local old = properties[key]
                properties[key] = value
                if key == "Text" then
                    self.TextWrites += 1
                end
                if old ~= value and propertySignals[key] then
                    propertySignals[key]:Fire()
                end
            else
                rawset(self, key, value)
            end
        end,
    })
    function object:IsA(want)
        return self.ClassName == want
            or (want == "GuiButton" and (self.ClassName == "TextButton" or self.ClassName == "ImageButton"))
            or (
                want == "GuiObject"
                and table.find({
                        "Frame",
                        "CanvasGroup",
                        "ScrollingFrame",
                        "TextLabel",
                        "TextButton",
                        "ImageButton",
                        "ImageLabel",
                    }, self.ClassName)
                    ~= nil
            )
    end
    function object:GetAttribute(key)
        return self.attributes[key]
    end
    function object:GetChildren()
        return table.clone(self.children)
    end
    function object:GetDescendants()
        local descendants = {}
        for _, c in self.children do
            table.insert(descendants, c)
            for _, d in c:GetDescendants() do
                table.insert(descendants, d)
            end
        end
        return descendants
    end
    function object:GetPropertyChangedSignal(name)
        propertySignals[name] = propertySignals[name] or signal()
        return propertySignals[name]
    end
    function object:FindFirstChild(want)
        for _, c in self.children do
            if c.Name == want then
                return c
            end
        end
    end
    function object:IsDescendantOf(ancestor)
        local p = self.Parent
        while p do
            if p == ancestor then
                return true
            end
            p = p.Parent
        end
        return false
    end
    if parent then
        table.insert(parent.children, object)
    end
    return object
end
local playerGui = instance("PlayerGui", "PlayerGui")
local function import()
    local objects = { [0] = playerGui }
    for _, n in exportNodes do
        objects[n[1]] = instance(n[3], n[4], objects[n[2]])
    end
    return objects[1]
end
local root
local attributes = {
    playerCash = 425,
    BatLevel = 0,
    BatPurchasedLevel = 0,
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
        return playerGui
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
    Constants = { Upgrades = "Upgrades" },
    MoneyFormat = "MoneyFormat",
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
local now = 0
local function advance(seconds)
    now += seconds
    while true do
        local index
        for i, timer in timers do
            if timer[3] <= now + 1e-9 and (not index or timer[3] < timers[index][3]) then
                index = i
            end
        end
        if not index then
            break
        end
        table.remove(timers, index)[2]()
    end
end
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
                Parent = {
                    UIRegistry = "UIRegistry",
                    Parent = { UI = { UpgradeDisplay = "UpgradeDisplay", UpgradesGui = "UpgradesGui" } },
                },
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
                defer = function(fn)
                    table.insert(timers, { 0, fn, now })
                end,
                delay = function(seconds, fn)
                    table.insert(timers, { seconds, fn, now + seconds })
                end,
            },
        }, { __index = getfenv() })
    )
    modules[name] = fn()
    return modules[name]
end
local display = load("UpgradeDisplay")
local expected = {
    Jump = { "JUMP 0", "JUMP 1", "JUMP 2", "JUMP 3" },
    MovementSpeed = { "SPEED 0", "SPEED 1", "SPEED 2", "SPEED 3" },
    SprintStamina = { "STAM 0", "STAM 1", "STAM 2", "STAM 3" },
    CarryCapacity = { "3 ITEMS", "5 ITEMS", "7 ITEMS" },
    Bat = { "NONE", "BAT", "BIG BAT", "GIANT" },
}
for _, track in display.Tracks do
    local tiers = load("Upgrades")[track.Id]
    for level = 0, #tiers - 1 do
        local row = display.Row(track.Id, level, 99999)
        check(row.Level == level, "displayed level")
        check(row.Max == (level == #tiers - 1), "max level detection")
        check(row.Price == (if level < #tiers - 1 then tiers[level + 2].Cost else nil), "next config price")
        check(row.Current == expected[track.Id][level + 1], "current presentation")
        check(row.Next == (expected[track.Id][level + 2] or "MAX"), "next presentation")
    end
end
check(display.Row("MovementSpeed", nil, nil) == nil, "wait for replication")
check(display.Row("MovementSpeed", 4, 22) == nil, "invalid level")
for _, reason in { "InvalidUpgrade", "InvalidMembership", "Busy", "Unknown" } do
    check(display.Feedback(false, reason) == "TRY AGAIN", "other failures use retry feedback")
end
check(display.Feedback(false, nil) == "TRY AGAIN", "unspecified failure uses retry feedback")
local gui = load("UpgradesGui")
check(gui.Resolve(playerGui) == nil, "wait for imported GUI")
local view
local controller = load("Controller")
if initialUi then
    root = import()
end
controller.Init()
controller.Init()
if not initialUi then
    root = import()
    playerGui.DescendantAdded:Fire(root)
end
for _, timer in table.clone(timers) do
    if timer[1] == 0 then
        timer[2]()
    end
end
view = assert(gui.Resolve(playerGui), "actual exported hierarchy resolves")

check(view.Cash.Text == "$425", "initial authoritative cash")
set("playerCash", 800)
check(view.Cash.Text == "$800", "cash replication")
check(view.Rows.Jump.Price.TextTransparency == 0.4, "unaffordable price dims")
set("playerCash", 10000)
check(
    view.Rows.Jump.Price.TextTransparency == 0 and view.Rows.Jump.BuyLabel.TextTransparency == 0,
    "cash at price restores authored text opacity"
)
set("playerCash", 800)
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
for _, id in { "MovementSpeed", "SprintStamina", "Jump", "CarryCapacity", "Bat" } do
    local before = #sent
    click(id)
    check(
        view.Rows[id].BuyLabel.Text == "..." and not view.Rows[id].Purchase.Interactable,
        "immediate pending feedback"
    )
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
    check(
        view.Rows[id].BuyLabel.Text == "NOT ENOUGH" and view.Rows[id].Purchase.Interactable,
        "insufficient cash feedback allows retry"
    )
    advance(1.49)
    check(view.Rows[id].BuyLabel.Text == "NOT ENOUGH", "cash failure lasts 1.5 seconds")
    advance(0.01)
    check(view.Rows[id].BuyLabel.Text == "BUY", "cash failure expires")
end
click("MovementSpeed")
result("MovementSpeed", true, "Success")
check(view.Rows.MovementSpeed.BuyLabel.Text == "PURCHASED!", "success feedback")
check(view.Rows.MovementSpeed.Current.Text == "SPEED 0" and view.Cash.Text == "$800", "result does not own state")
set("MovementSpeedPurchasedLevel", 1)
set("BaseWalkSpeed", 32)
check(view.Rows.MovementSpeed.Next.Text == "SPEED 2", "replication after response")
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "PURCHASED!" and not view.Rows.MovementSpeed.Purchase.Interactable,
    "replication preserves success hold"
)
local successSent = #sent
click("MovementSpeed")
check(#sent == successSent, "success guard blocks activation")
advance(0.79)
check(view.Rows.MovementSpeed.BuyLabel.Text == "PURCHASED!", "success lasts 0.8 seconds")
advance(0.01)
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "BUY" and view.Rows.MovementSpeed.Purchase.Interactable,
    "success restores next tier"
)
click("Jump")
result("Jump", false, "MaxLevel")
local before = #sent
click("Jump")
check(#sent == before and view.Rows.Jump.BuyLabel.Text == "MAX", "server max blocks request")
set("JumpPurchasedLevel", 3)
click("Jump")
check(#sent == before and view.Rows.Jump.Current.Text == "JUMP 3", "replicated max blocks request")
click("SprintStamina")
result("SprintStamina", false, "InvalidUpgrade")
check(#warnings == 1 and view.Rows.SprintStamina.BuyLabel.Text == "TRY AGAIN", "invalid upgrade stays nontechnical")
click("MovementSpeed")
local timeout = timers[#timers]
check(timeout[1] == 5, "bounded pending timeout")
timeout[2]()
check(view.Rows.MovementSpeed.BuyLabel.Text == "TRY AGAIN", "timeout recovers")
local failureTimer = timers[#timers]
remote.OnClientEvent:Fire("PurchaseUpgradeResult", {
    upgradeId = "MovementSpeed",
    success = true,
    PlotSessionId = attributes.PlotSessionId,
    MembershipRevision = attributes.PlotMembershipRevision,
})
check(view.Rows.MovementSpeed.BuyLabel.Text == "TRY AGAIN", "late response after timeout cannot show success")
before = #sent
click("MovementSpeed")
check(#sent == before + 1, "retry after timeout")
local pendingLabel = view.Rows.MovementSpeed.BuyLabel.Text
failureTimer[2]()
check(view.Rows.MovementSpeed.BuyLabel.Text == "...", "old feedback cannot overwrite pending retry")
timeout[2]()
check(
    view.Rows.MovementSpeed.BuyLabel.Text == pendingLabel and not view.Rows.MovementSpeed.Purchase.Interactable,
    "stale timer cannot clear new request"
)
print(string.format("PASS: %d upgrade UI assertions.", count))

result("MovementSpeed", true, "Success")
click("CarryCapacity")
check(sent[#sent][2] == "CarryCapacity" and sent[#sent][3] == 2, "carry requests next tier")
result("CarryCapacity", true, "Success")
set("CarryCapacityLevel", 1)
set("CarryCapacity", 5)
check(view.Rows.CarryCapacity.Current.Text == "5 ITEMS", "carry uses configured item count")
advance(0.8)
click("CarryCapacity")
check(sent[#sent][3] == 3, "carry requests third tier")
result("CarryCapacity", true, "Success")
set("CarryCapacityLevel", 2)
set("CarryCapacity", 7)
check(
    view.Rows.CarryCapacity.BuyLabel.Text == "PURCHASED!" and not view.Rows.CarryCapacity.Purchase.Interactable,
    "final tier success precedes MAX"
)
advance(0.8)
check(
    view.Rows.CarryCapacity.Current.Text == "7 ITEMS" and view.Rows.CarryCapacity.BuyLabel.Text == "MAX",
    "carry max UI"
)
print("PASS: carry upgrade integration")

set("PlotMembershipRevision", 2)
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "..."
        and view.Rows.MovementSpeed.Price.Text == ""
        and view.Rows.MovementSpeed.Current.Text == "LOADING...",
    "membership transition clears old tier and price"
)
advance(0)
remote.OnClientEvent:Fire("PurchaseUpgradeResult", {
    upgradeId = "MovementSpeed",
    success = false,
    reason = "MaxLevel",
    PlotSessionId = "test-session",
    MembershipRevision = 1,
})
check(view.Rows.MovementSpeed.BuyLabel.Text ~= "MAX", "stale response cannot lock new membership UI")
set("JumpLevel", 0)
check(view.Rows.Jump.Current.Text == "JUMP 3", "personal debug projection does not change purchased upgrade display")

set("BatLevel", nil)
set("BatPurchasedLevel", 2)
check(
    view.Rows.Bat.Current.Text == "BIG BAT" and view.Rows.Bat.Next.Text == "GIANT",
    "purchased Bat loads without effective projection"
)
check(view.Rows.Bat.Price.Text == "$500K", "Bat next config cost")
set("BatLevel", 3)
check(view.Rows.Bat.Current.Text == "BIG BAT", "effective Bat override cannot advance purchased progression")
click("MovementSpeed")
result("MovementSpeed", false, "InsufficientCash")
advance(1.5)
check(view.Rows.MovementSpeed.BuyLabel.Text == "BUY", "feedback restores BUY")
check(view.Rows.Jump.Price.Text == "" and not view.Rows.Jump.Purchase.Interactable, "MAX clears price and disables")

-- Removal disconnects old buttons immediately; replacement renders latest state.
local oldView = view
playerGui.DescendantRemoving:Fire(root)
playerGui.children = {}
root.Parent = nil
before = #sent
oldView.Rows.MovementSpeed.Purchase.Activated:Fire()
check(#sent == before, "removed GUI cannot send purchases")
set("playerCash", 125000)
root = import()
playerGui.DescendantAdded:Fire(root)
for _, timer in table.clone(timers) do
    if timer[1] == 0 then
        timer[2]()
    end
end
view = assert(gui.Resolve(playerGui))
check(
    view.Cash.Text == "$125,000" and view.Rows.Bat.Current.Text == "BIG BAT",
    "replacement renders authoritative state"
)
click("MovementSpeed")
check(#sent == before + 1, "replacement binds one purchase after repeated Init")
set("PlotMembershipRevision", 3)
advance(0)
check(view.Rows.MovementSpeed.Purchase.Interactable, "membership change clears pending")
set("PlotSessionId", "new-session")
advance(0)
check(view.Rows.MovementSpeed.BuyLabel.Text == "BUY", "session change clears feedback")
print(string.format("PASS: %d upgrade UI assertions including exported hierarchy and lifecycle.", count))

-- A replaced nested label invalidates bindings until the authored hierarchy is complete.
click("MovementSpeed")
result("MovementSpeed", true, "Success")
local oldButton = view.Rows.Bat.Purchase
local label = view.Rows.Bat.BuyLabel
playerGui.DescendantRemoving:Fire(label)
label.Parent.children = {}
label.Parent = nil
for _, timer in table.clone(timers) do
    if timer[1] == 0 then
        timer[2]()
    end
end
before = #sent
oldButton.Activated:Fire()
check(#sent == before and gui.Resolve(playerGui).Rows.Bat == nil, "incomplete card cannot purchase")
set("playerCash", 125001)
local partial = assert(gui.Resolve(playerGui))
check(
    partial.Cash.Text == "$125,001" and partial.Rows.Jump.Next.Text == "MAX",
    "missing card preserves cash and other upgrade rendering"
)
local newLabel = instance("TextLabel", "BuyLabel", oldButton)
playerGui.DescendantAdded:Fire(newLabel)
for _, timer in table.clone(timers) do
    if timer[1] == 0 then
        timer[2]()
    end
end
view = assert(gui.Resolve(playerGui))
check(view.Rows.Bat.BuyLabel.Text == "BUY", "nested replacement rerenders")
oldButton.Activated:Fire()
check(
    #sent == before + 1 and sent[#sent][2] == "Bat" and sent[#sent][3] == 4,
    "nested replacement binds exactly one next-tier purchase"
)
print(string.format("PASS: %d total upgrade UI behavioral assertions.", count))

-- Reimports can change the generated wrapper name and retain Figma suffixes.
local function flushDeferred()
    local deferred = timers
    timers = {}
    for _, timer in deferred do
        if timer[1] == 0 then
            timer[2]()
        else
            table.insert(timers, timer)
        end
    end
end
local function taggedImport(asScreenGui)
    local imported = import()
    imported.Name = "Framewisp_NEW_REFERENCE"
    local desktop = imported:FindFirstChild("Be a Blender! Desktop")
    local content = desktop:FindFirstChild("Be a Blender! DesktopContent")
    local destination = if asScreenGui then imported else desktop
    if asScreenGui then
        imported.Name = "Be a Blender! Desktop"
        imported.children = {}
        desktop.Parent = nil
    else
        desktop.children = {}
    end
    for _, c in content:GetChildren() do
        c.Parent = destination
        table.insert(destination.children, c)
    end
    content.Parent = nil
    local panel = destination:FindFirstChild("Upgrades")
    panel.Name = "Upgrades_panel"
    local scroll = panel:FindFirstChild("UpgradeScroll")
    scroll.Name = "UpgradeScroll_scroll"
    local list = scroll:FindFirstChild("UpgradeList")
    list.Name = "UpgradeList_list"
    for _, card in list:GetChildren() do
        local button = card:FindFirstChild("Buy")
        if button then
            button.Name = "Buy_button_smooth"
        end
    end
    return imported
end
result("Bat", true, "Success")
advance(0.8)
for _, asScreenGui in { false, true, false } do
    oldView = view
    playerGui.DescendantRemoving:Fire(root)
    playerGui.children = {}
    root.Parent = nil
    before = #sent
    oldView.Rows.Bat.Purchase.Activated:Fire()
    check(#sent == before, "old tagged import button disconnected immediately")
    set("playerCash", 9849250)
    root = taggedImport(asScreenGui)
    playerGui.DescendantAdded:Fire(root)
    flushDeferred()
    view = assert(gui.Resolve(playerGui), "tagged reimport with fresh wrapper resolves")
    check(view.Cash.Text == "$9,849,250", "tagged replacement immediately renders full cash")
    for _, track in display.Tracks do
        local levelAttribute = track.Id .. (if track.Id == "CarryCapacity" then "Level" else "PurchasedLevel")
        local state = display.Row(track.Id, attributes[levelAttribute])
        check(view.Rows[track.Id].Current.Text == state.Current, "all replacement cards immediately render state")
    end
    local writes = view.Cash.TextWrites
    set("playerCash", 9849251)
    check(
        view.Cash.Text == "$9,849,251" and view.Cash.TextWrites == writes + 1,
        "cash mutation renders new label once after repeated replacement"
    )
    oldView.Rows.Bat.Purchase.Activated:Fire()
    check(#sent == before, "old button stays disconnected after fresh binding")
    click("Bat")
    check(#sent == before + 1, "fresh tagged button sends exactly one purchase")
    result("Bat", true, "Success")
    advance(0.8)
end
set("MovementSpeedPurchasedLevel", 2)
check(view.Rows.MovementSpeed.Current.Text == "SPEED 2", "post-reimport upgrade replication reaches new card")

-- A disabled obsolete copy is ignored; two active copies cannot be guessed apart.
local duplicate = import()
duplicate.Enabled = false
playerGui.DescendantAdded:Fire(duplicate)
flushDeferred()
check(gui.Resolve(playerGui).Root == root, "disabled obsolete duplicate cannot win root selection")
local activeButton = view.Rows.Bat.Purchase
duplicate.Enabled = true
flushDeferred()
check(gui.Resolve(playerGui) == nil, "ambiguous active duplicate pauses binding")
before = #sent
activeButton.Activated:Fire()
check(#sent == before, "ambiguity disconnects prior purchases")
duplicate.Enabled = false
flushDeferred()
view = assert(gui.Resolve(playerGui))
check(view.Root == root and view.Cash.Text == "$9,849,251", "disabling duplicate resumes and rerenders current root")
click("MovementSpeed")
check(#sent == before + 1, "duplicate recovery binds a single purchase handler")
result("MovementSpeed", true, "Success")
set("MovementSpeedPurchasedLevel", 3)
check(
    view.Rows.MovementSpeed.Current.Text == "SPEED 3" and view.Rows.MovementSpeed.Next.Text == "MAX",
    "purchase replication after duplicate recovery updates new card"
)
local desktop = root:FindFirstChild("Be a Blender! Desktop")
desktop.Visible = false
flushDeferred()
check(gui.Resolve(playerGui) == nil, "hidden desktop is not selected")
desktop.Visible = true
flushDeferred()
check(gui.Resolve(playerGui).Cash.Text == "$9,849,251", "desktop visibility recovery renders current cash")
print(string.format("PASS: %d total upgrade UI assertions including tagged reimports and duplicate protection.", count))

-- Feedback survives replication refreshes, but belongs only to its membership/request.
advance(0.8)
set("MovementSpeedPurchasedLevel", nil)
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "..." and not view.Rows.MovementSpeed.Purchase.Interactable,
    "uninitialized button waits for attributes"
)
set("MovementSpeedPurchasedLevel", 0)
click("MovementSpeed")
set("MovementSpeedPurchasedLevel", 1)
check(view.Rows.MovementSpeed.BuyLabel.Text == "...", "tier replication cannot confirm success")
result("MovementSpeed", true, "Success")
local oldSuccessTimer = timers[#timers]
set("PlotSessionId", "third-session")
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "..." and view.Rows.MovementSpeed.Price.Text == "",
    "membership revokes success and old price immediately"
)
set("MovementSpeedPurchasedLevel", 0)
set("PlotMembershipRevision", 4)
advance(0)
check(
    view.Rows.MovementSpeed.Current.Text == "SPEED 0" and view.Rows.MovementSpeed.BuyLabel.Text == "BUY",
    "membership renders current replicated projection"
)
click("MovementSpeed")
result("MovementSpeed", true, "Success")
oldSuccessTimer[2]()
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "PURCHASED!" and not view.Rows.MovementSpeed.Purchase.Interactable,
    "old membership expiry cannot erase newer success"
)
advance(0.8)
click("MovementSpeed")
result("MovementSpeed", false, "Busy")
advance(1.49)
check(view.Rows.MovementSpeed.BuyLabel.Text == "TRY AGAIN", "other failure lasts 1.5 seconds")
advance(0.01)
check(view.Rows.MovementSpeed.BuyLabel.Text == "BUY", "other failure expires")
click("MovementSpeed")
advance(4.99)
check(view.Rows.MovementSpeed.BuyLabel.Text == "...", "request remains pending until existing five-second timeout")
advance(0.01)
check(
    view.Rows.MovementSpeed.BuyLabel.Text == "TRY AGAIN" and view.Rows.MovementSpeed.Purchase.Interactable,
    "timeout enables retry"
)
advance(1.5)
check(view.Rows.MovementSpeed.BuyLabel.Text == "BUY", "timeout feedback expires after 1.5 seconds")
print(string.format("PASS: %d total upgrade UI assertions including purchase feedback timing.", count))

-- Semantic identities support a renamed design without changing controller paths.
advance(2)
playerGui.DescendantRemoving:Fire(root)
playerGui.children = {}
root.Parent = nil
root = import()
local semanticDesktop = root:FindFirstChild("Be a Blender! Desktop")
local content = semanticDesktop:FindFirstChild("Be a Blender! DesktopContent")
semanticDesktop.attributes.BlenderUI = "Desktop"
semanticDesktop.Name = "New Design"
content.attributes.BlenderUI = "Content"
content.Name = "Content V2"
local semanticPanel = content:FindFirstChild("Upgrades")
semanticPanel.attributes.BlenderUI = "Panel:Upgrades"
semanticPanel.Name = "Upgrade Window"
local scroll = semanticPanel:FindFirstChild("UpgradeScroll")
scroll.attributes.BlenderUI = "UpgradeScroll"
scroll.Name = "Viewport"
local list = scroll:FindFirstChild("UpgradeList")
list.attributes.BlenderUI = "UpgradeList"
list.Name = "Rows"
for _, track in display.Tracks do
    local card = list:FindFirstChild(track.Id .. "Card")
    card.attributes.BlenderUI = "Upgrade:" .. track.Id
    card.Name = "Card " .. track.Id
    card.ClassName = "Frame" -- Both prior Frames and current CanvasGroups work.
    local level = card:FindFirstChild("LevelContainer")
    for _, parent in { card, level, card:FindFirstChild("Buy") } do
        for _, control in parent:GetChildren() do
            control.attributes.BlenderUI = control.Name
            control.Name = "Custom " .. control.Name
        end
    end
end
local cashContainer = content:FindFirstChild("TOP"):FindFirstChild("CashDisplay")
local cashLabel = cashContainer:FindFirstChild("{Coins}")
cashLabel.attributes.BlenderUI = "Cash"
cashLabel.Name = "Balance"
playerGui.DescendantAdded:Fire(root)
flushDeferred()
view = assert(gui.Resolve(playerGui))
check(
    view.Cash.Text == load("MoneyFormat").Full(attributes.playerCash) and view.Rows.Bat.Current.Text == "BIG BAT",
    "semantic design restores latest state"
)
local requestCount = #sent
click("MovementSpeed")
check(#sent == requestCount + 1, "semantic purchase sends one existing request")
result("MovementSpeed", false, "InsufficientCash")
advance(1.5)
-- Cash removal affects the HUD locally; upgrade actions continue to bind.
playerGui.DescendantRemoving:Fire(cashLabel)
cashContainer.children = {}
cashLabel.Parent = nil
flushDeferred()
view = assert(gui.Resolve(playerGui))
check(view.Cash == nil and view.Rows.Bat ~= nil, "missing cash does not disable upgrades")
requestCount = #sent
click("MovementSpeed")
check(#sent == requestCount + 1, "missing cash control preserves server purchase path")
result("MovementSpeed", false, "Busy")
local newCash = instance("TextLabel", "Cash", cashContainer)
playerGui.DescendantAdded:Fire(newCash)
flushDeferred()
view = assert(gui.Resolve(playerGui))
check(
    view.Cash.Text == load("MoneyFormat").Full(attributes.playerCash),
    "replacement cash label restores balance without mutation"
)
print("PASS: independent cash/card recovery, affordability and semantic design bindings")
