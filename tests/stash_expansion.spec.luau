env.typeof = function(value)
    return if type(value) == "table" and value.ClassName then "Instance" else type(value)
end
env.Enum.KeyCode = { E = "E", ButtonX = "ButtonX" }
env.Enum.ProximityPromptExclusivity = { OneGlobally = "OneGlobally" }
-- Physical pad -> shared ledger -> existing stash paths, with engine boundaries mocked.
local tycoon = dependency.TycoonService
local owner, teammate, enemy = player(), player(), player()
local plot = tycoon.GetPlot(owner)
fixtures[owner].Name = "Stash"
for _, object in fixtures[owner]:GetChildren() do
    local index = object:GetAttribute("SlotIndex")
    object.Name = (if index <= 2 then "LockedSlot" else "Slot") .. index
end
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owner, tycoon.GetRequestContext(owner)), "join stash team")
local row = instance("Model")
row.Name, row.Parent = "UpgradeStash", plot
-- Attribute notifications are an engine boundary absent from the shared double.
for _, object in { plot, row } do
    local signals = {}
    local set = object.SetAttribute
    function object:GetAttributeChangedSignal(key)
        signals[key] = signals[key] or signal()
        return signals[key]
    end
    function object:SetAttribute(key, value)
        local previous = self:GetAttribute(key)
        set(self, key, value)
        if previous ~= value and signals[key] then
            signals[key]:Fire()
        end
    end
end
local pad = part("PurchasePoint", row)
pad.Touched = signal()
local base = part("base", row)
local shine = part("shine", row)
local structure = { base }
local authored = {}
for index = 6, 10 do
    -- Actual Studio names; expansion BaseParts need no local SlotIndex attributes.
    table.insert(structure, part("Slot" .. index, row))
end
for index, object in structure do
    object.CFrame = frame(index * 2, 7, 3)
    object.CanCollide, object.CanTouch, object.CanQuery = true, true, true
    authored[object] = object.CFrame
end
local padFrame, shineFrame = pad.CFrame, shine.CFrame
services.Players.GetPlayerFromCharacter = function(_, character)
    for _, p in { owner, teammate, enemy } do
        if p.Character == character then
            return p
        end
    end
    return nil
end
env.Enum.EasingStyle, env.Enum.EasingDirection = { Back = "Back" }, { Out = "Out" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
local completions = {}
services.TweenService = {
    Create = function()
        local tween = { Completed = signal(), Play = function() end, Cancel = function() end }
        table.insert(completions, tween.Completed)
        return tween
    end,
}
cache.WorldUtil.BindTag = function(_, attach)
    attach(plot)
end
loadModule("StashExpansionService").Init(dependency)
for _, object in structure do
    check(
        object.Transparency == 1 and not object.CanCollide and not object.CanTouch and not object.CanQuery,
        "base and every authored slot start hidden and noninteractive"
    )
end
check(pad.Transparency == 0 and pad.CanTouch, "direct BasePart purchase pad starts visible and touchable")
-- Exercise the actual contextual prompt binding; rendering stays outside this contract suite.
cache.StashPresentation = { Refresh = function() end, Clear = function() end }
cache.WorldUtil.BindTag = function(_, attach)
    attach(fixtures[owner])
end
local originalPrompt = cache.WorldUtil.Prompt
cache.WorldUtil.Prompt = function(...)
    local prompt = originalPrompt(...)
    prompt.Triggered = signal()
    return prompt
end
loadModule("StashComponent").Init(dependency)
local expanded = loadModule("StashSlots").Resolve(fixtures[owner], row)
check(not expanded[6]:FindFirstChild("StashPrompt").Enabled, "expanded contextual prompt starts disabled")

local function touch(p)
    pad.Touched:Fire(p.Character:FindFirstChild("HumanoidRootPart"))
end
check(inventory.GetStashLayout(owner).Slots == 5 and slot(owner, 6) == nil, "default remains five usable slots")
carry(owner, "Milk")
for index = 6, 10 do
    check(
        not inventory.Deposit(owner, "Milk", index)
            and not inventory.Withdraw(owner, index)
            and not press(owner, "TAKE", index, owner),
        "all locked expansion transfer paths reject"
    )
end
setup(inventory.Deposit(owner, "Milk", 3), "base slot still accepts ingredient")
tycoon.SetCash(owner, 399999)
touch(teammate)
check(
    tycoon.GetCash(owner) == 399999 and inventory.GetStashLayout(owner).Slots == 5,
    "insufficient cash preserves ledger and capacity"
)
tycoon.SetCash(owner, 500000)
touch(enemy)
check(
    tycoon.GetCash(owner) == 500000 and tycoon.GetUpgrade(owner, "SecondStorage") == 1,
    "nonmember touch cannot purchase"
)
check(
    not tycoon.PurchaseUpgrade(owner, "SecondStorage", 2, tycoon.GetRequestContext(owner)),
    "generic upgrade endpoint rejects physical purchase"
)
local originalSet = teammate.SetAttribute
function teammate:SetAttribute(key, value)
    originalSet(self, key, value)
    if key == "playerCash" then
        touch(owner)
    end
end
touch(teammate)
touch(owner)
check(
    tycoon.GetCash(owner) == 100000 and tycoon.GetUpgrade(teammate, "SecondStorage") == 2,
    "duplicate and reentrant touches charge exactly 400000 once"
)
check(not pad.CanTouch and pad.Transparency == 1, "purchase disables physical pad")
for _, object in structure do
    check(
        object.Transparency == 0 and object.CFrame.Position.Y == authored[object].Position.Y - 3.5,
        "purchased base and slots reveal together below their authored positions"
    )
end
check(pad.CFrame == padFrame and shine.CFrame == shineFrame, "pad and shine are excluded from reveal motion")
check(
    inventory.GetStashLayout(owner).Slots == 10 and inventory.GetStashLayout(teammate).Slots == 10,
    "purchase grants team ten-slot capacity"
)
check(not inventory.CanWithdraw(teammate, owner, 6), "slots stay unavailable until reveal completes")
for _, completed in completions do
    completed:Fire()
end
check(expanded[6]:FindFirstChild("StashPrompt").Enabled, "expanded contextual prompt enables after reveal")
for _, object in structure do
    check(object.CFrame == authored[object], "revealed structure finishes at exact authored transforms")
end
carry(owner, "Milk")
local requestContext = tycoon.GetRequestContext(owner)
requestContext.TargetSessionId, requestContext.RequestId = tycoon.GetSessionId(owner), 1
setup(
    inventory.RequestStash(owner, expanded[6]:FindFirstChild("StashPrompt"), "STORE", requestContext),
    "expanded explicit request"
)
check(slot(owner, 6).Count == 1, "authored Slot6 prompt routes to logical slot six")
setup(inventory.Withdraw(teammate, 6, owner), "empty expanded prompt test slot")
inventory.ClearHeld(teammate)
for index = 6, 10 do
    carry(owner, "Banana")
    check(inventory.Deposit(owner, "Banana", index), "existing deposit path accepts expanded slot")
    check(not slot(owner, index).Protected, "expanded slots preserve first-two-total protection rule")
    check(inventory.Withdraw(teammate, index, owner), "existing teammate withdrawal accepts expanded slot")
    inventory.ClearHeld(teammate)
end
check(
    slot(owner, 1).Protected and slot(owner, 2).Protected and not slot(owner, 3).Protected and slot(owner, 3).Count == 1,
    "base contents and protection remain unchanged"
)
-- Smoothies reuse the same expanded slot, with the original identity.
grant(owner, "expanded-smoothie")
now += 2
setup(press(owner, "STORE", 8, owner), "stash smoothie in expanded row")
check(slot(owner, 8).Smoothie.BlendId == "expanded-smoothie", "expanded smoothie identity retained")
check(inventory.Steal(enemy, owner, 8), "expanded unprotected slot uses existing theft path")
local oldContext = tycoon.GetRequestContext(owner)
tycoon.RemovePlayer(owner)
check(
    tycoon.GetUpgrade(teammate, "SecondStorage") == 2
        and inventory.GetStashLayout(teammate).Slots == 10
        and not pad.CanTouch,
    "member promotion preserves purchased row"
)
tycoon.RemovePlayer(teammate)
check(pad.CanTouch and row:GetAttribute("StashExpansionReady") == false, "final release resets expansion")
setup(tycoon.AssignPlot(owner, plot) ~= nil, "recycle plot")
check(
    inventory.GetStashLayout(owner).Slots == 5 and tycoon.GetUpgrade(owner, "SecondStorage") == 1,
    "new session starts locked"
)
check(not tycoon.PurchaseSecondStorage(owner, plot, oldContext), "old session context cannot purchase recycled plot")
for _, completed in completions do
    completed:Fire()
end
check(row:GetAttribute("StashExpansionReady") == false, "retired reveal callbacks cannot enable recycled row")

-- Releasing during an unfinished reveal must also leave the next session locked.
tycoon.SetCash(owner, 400000)
touch(owner)
tycoon.RemovePlayer(owner)
setup(tycoon.AssignPlot(owner, plot) ~= nil, "recycle during reveal")
for _, completed in completions do
    completed:Fire()
end
check(
    pad.CanTouch and row:GetAttribute("StashExpansionReady") == false and inventory.GetStashLayout(owner).Slots == 5,
    "in-flight reveal cannot unlock the next session"
)

for _, object in structure do
    check(
        object.Transparency == 1
            and not object.CanCollide
            and not object.CanTouch
            and not object.CanQuery
            and object.CFrame == authored[object],
        "release restores and hides the complete purchased structure"
    )
end
check(pad.Transparency == 0 and pad.CanTouch and pad.CFrame == padFrame, "release restores stationary purchase pad")
