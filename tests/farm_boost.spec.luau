-- Unique pass contracts through real farm, inventory and shared plot sessions.
local function touch(index, member)
    rows[index].Pad.Touched:Fire(member.Character:FindFirstChild("HumanoidRootPart"))
end
local function plantRow(index, member)
    carry(member, "Apple")
    rows[index].Plant:FindFirstChild("FarmPlantPrompt").Triggered:Fire(member)
end
local function deadline(index)
    return rows[index].Object:GetAttribute("FarmGrowEnd")
end
local function products(index)
    return #farm.GetRowSnapshot(plot, index).Products
end
local function finish(member, purchased, id)
    services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(member, id or config.SpeedPassId, purchased)
end
flush()
tycoon.SetCash(owner, 1000000)
touch(1, peer)
plantRow(1, owner)
check(deadline(1) == now + 9, "absent optional pad leaves regular farming playable")
detach()

local pad = part("FarmSpeedRobux", folder)
pad.Transparency, pad.CanCollide, pad.CanTouch, pad.CanQuery = 0.2, true, true, true
local sign = instance("SurfaceGui")
sign.Name, sign.Parent, sign.Enabled = "Sign", pad, true
local label = instance("TextLabel")
label.Parent, label.Text = sign, "old copy"
local shine = instance("ParticleEmitter")
shine.Name, shine.Parent, shine.Enabled = "shine", pad, true
function shine:Clear() end
local authoredPrompt = instance("ProximityPrompt")
authoredPrompt.Parent, authoredPrompt.Enabled = pad, true
detach = attachFarm(plot)
local prompt = pad:FindFirstChild("FarmSpeedPrompt")
check(prompt and prompt.ActionText == "Buy Farm Boost" and label.Text == "2× FASTER FARM", "explicit purchase copy")
check(
    pad.Transparency == 0.2 and prompt.Enabled and sign.Enabled and shine.Enabled,
    "unlocked eligible team restores authored assembly"
)
check(not authoredPrompt.Enabled, "only managed purchase interaction is active")

prompt.Triggered:Fire(outsider)
owner.Near = false
prompt.Triggered:Fire(owner)
owner.Near = true
check(promptCount == 0, "outsiders and distant members cannot open modal")
finish(owner, true)
check(prompt.Enabled, "unsolicited success does not grant entitlement")
prompt.Triggered:Fire(owner)
prompt.Triggered:Fire(peer)
check(promptCount == 1, "only one plot purchase may be in flight")
finish(owner, true, config.SpeedPassId + 1)
check(not prompt.Enabled, "unrelated pass event cannot settle purchase")
finish(owner, false)
check(prompt.Enabled and pad.Transparency == 0.2, "cancellation releases eligibility")
promptFailure = true
prompt.Triggered:Fire(owner)
promptFailure = false
check(prompt.Enabled, "prompt error releases pending state")

local refill = economy.RefillSeconds[0]
economy.RefillSeconds[0] = 12
plantRow(1, owner)
local obsolete = timers[#timers]
check(deadline(1) == now + 36, "normal crop duration is 36 seconds")
now += 12
prompt.Triggered:Fire(peer)
finish(peer, true)
local accelerated = timers[#timers]
check(deadline(1) == now + 12, "teammate purchase preserves completed work and halves remaining time")
check(
    pad.Transparency == 1
        and not pad.CanCollide
        and not pad.CanTouch
        and not pad.CanQuery
        and not sign.Enabled
        and not shine.Enabled
        and not prompt.Enabled,
    "confirmed purchase hides entire assembly immediately"
)
obsolete.Run()
check(products(1) == 0, "replaced completion cannot harvest early")
accelerated.Run()
obsolete.Run()
accelerated.Run()
check(products(1) == 3, "completion and obsolete replays yield exactly one unchanged harvest")
touch(2, peer)
plantRow(2, owner)
check(deadline(2) == now + 18, "rows unlocked later and seeds from either member share boost")
now += 6
local boostedTimer = timers[#timers]
tycoon.RemovePlayer(peer)
check(deadline(2) == now + 24 and prompt.Enabled, "sole holder leaving restores 1x with crop progress intact")
check(products(1) == 3, "ready harvest stays ready on multiplier change")
boostedTimer.Run()
check(products(2) == 0, "obsolete fast timer cannot spawn after holder leaves")

-- Ownership follows the buyer into a new membership without a second purchase.
setup(tycoon.JoinSession(peer, owner, tycoon.GetRequestContext(owner)), "holder rejoins")
check(deadline(2) == now + 12 and not prompt.Enabled, "returning holder restores shared boost")
-- Simulate owner reconnect: the next async lookup discovers existing ownership.
tycoon.RemovePlayer(owner)
services.Players.PlayerRemoving:Fire(owner)
passOwners[owner.UserId] = true
setup(tycoon.JoinSession(owner, peer, tycoon.GetRequestContext(peer)), "second holder rejoins")
flush()
check(deadline(2) == now + 12, "two pass holders still get exactly 2x")
tycoon.RemovePlayer(peer)
check(deadline(2) == now + 12, "one of two holders leaving keeps 2x")
tycoon.RemovePlayer(owner)
check(pad.Transparency == 1 and not prompt.Enabled, "unclaimed plot is hidden and inactive")
setup(tycoon.AssignPlot(peer, plot), "holder reclaims reset plot")
check(
    not prompt.Enabled and rows[1].Object:GetAttribute("FarmState") == "LOCKED",
    "reclaimed plot resets rows and retains buyer entitlement"
)
tycoon.SetCash(peer, 20000)
touch(1, peer)
plantRow(1, peer)
check(deadline(1) == now + 18, "reclaimed plot uses new team's entitlement")
local resetTimer = timers[#timers]
tycoon.RemovePlayer(peer)
resetTimer.Run()
check(rows[1].Object:GetAttribute("FarmState") == "LOCKED", "reset invalidates pending boosted harvest")

-- Unknown/unavailable ownership hides sales, but never blocks cash rows or crops.
services.Players.PlayerRemoving:Fire(owner)
passOwners[owner.UserId], ownershipFailure = false, true
setup(tycoon.AssignPlot(owner, plot), "unknown buyer claims")
tycoon.SetCash(owner, 20000)
touch(1, owner)
check(not prompt.Enabled and pad.Transparency == 1, "pending ownership hides unlocked purchase point")
flush()
check(not prompt.Enabled and pad.Transparency == 1, "failed lookup remains hidden")
plantRow(1, owner)
check(deadline(1) == now + 36, "Marketplace outage leaves normal farm growth playable")
ownershipFailure = false
-- Run only the ownership retry; do not complete the crop.
for _, timer in table.clone(timers) do
    if timer.Seconds == config.OwnershipRetrySeconds then
        timer.Run()
    end
end
flush()
check(prompt.Enabled, "ownership retry restores eligible purchase point")

prompt.Triggered:Fire(owner)
tycoon.RemovePlayer(owner)
finish(owner, true)
setup(tycoon.AssignPlot(owner, plot), "buyer returns after canceled session")
tycoon.SetCash(owner, 20000)
touch(1, owner)
check(prompt.Enabled, "session teardown releases pending state and rejects stale purchase success")
prompt.Triggered:Fire(owner)
tycoon.RemovePlayer(owner)
setup(tycoon.AssignPlot(peer, plot), "replacement team claims during old purchase")
finish(owner, true)
tycoon.SetCash(peer, 20000)
touch(1, peer)
check(not prompt.Enabled, "replacement holder uses its own entitlement")

-- A lookup that returns after reassignment must update only the buyer's current plot.
tycoon.RemovePlayer(peer)
services.Players.PlayerRemoving:Fire(owner)
passOwners[owner.UserId] = true
setup(tycoon.AssignPlot(owner, plot), "lookup begins on old plot")
setup(tycoon.JoinSession(peer, owner, tycoon.GetRequestContext(owner)), "remaining holder joins")
-- Make peer unowned for this independent session by simulating a fresh connection.
services.Players.PlayerRemoving:Fire(peer)
passOwners[peer.UserId] = false
farm.RefreshMembership()
ownershipHook = function(id)
    if id == owner.UserId then
        ownershipHook = nil
        tycoon.RemovePlayer(owner)
        setup(
            tycoon.JoinSession(owner, outsider, tycoon.GetRequestContext(outsider)),
            "buyer switches plot while lookup yields"
        )
    end
end
flush()
flush()
tycoon.SetCash(peer, 20000)
touch(1, peer)
check(prompt.Enabled, "stale owner lookup cannot boost previous plot")
tycoon.RemovePlayer(owner)
setup(tycoon.JoinSession(owner, peer, tycoon.GetRequestContext(peer)), "buyer switches back")
check(not prompt.Enabled, "resolved entitlement follows buyer across plots")

detach()
pad:Destroy()
local malformed = instance("Folder")
malformed.Name, malformed.Parent = "FarmSpeedRobux", folder
local malformedPart = part("Decoration", malformed)
detach = attachFarm(plot)
check(malformedPart.Transparency == 1 and not malformedPart.CanCollide, "malformed optional assembly stays hidden")
check(farm.GetRowSnapshot(plot, 1) ~= nil, "malformed pad leaves farm bound")
detach()
economy.RefillSeconds[0] = refill
print("PASS: farm boost")
