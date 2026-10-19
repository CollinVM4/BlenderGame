-- Aggregation uses real display tracks/prices and the real controller's events.
advance(6)
local notifications = load("MenuNotifications")
local badgeVisible = false
local detachBadge = notifications.Attach
-- Observe the channel at its drawing boundary (rendering is tested separately).
local badgeModule = load("NotificationBadge")
badgeModule.Attach = function()
    return function(visible)
        badgeVisible = visible
    end, function() end
end
local stopBadge = detachBadge("Upgrades", {})
local function tick()
    advance(0)
end
local function panel(open)
    notifications.PanelChanged("Upgrades", open)
end
panel(false)
for _, track in display.Tracks do
    set(
        track.Id .. (if track.Id == "CarryCapacity" then "Level" else "PurchasedLevel"),
        #load("Upgrades")[track.Id] - 1
    )
end
set("playerCash", 1e9)
tick()
check(not badgeVisible, "all maxed tracks never notify even with abundant cash")
set("JumpPurchasedLevel", 0)
local jumpPrice = display.Row("Jump", 0).Price
set("playerCash", jumpPrice - 1)
tick()
check(not badgeVisible, "unaffordable tracks never notify")
set("playerCash", jumpPrice)
tick()
check(badgeVisible, "one affordable nonmaxed track is enough")
panel(true)
check(not badgeVisible, "opening clears upgrade badge immediately")
panel(false)
set("BaseWalkSpeed", 23)
tick()
check(not badgeVisible, "unchanged acknowledged affordability stays cleared after close")
set("playerCash", jumpPrice - 1)
tick()
set("playerCash", jumpPrice)
tick()
check(badgeVisible, "crossing price again rearms upgrade notification")
panel(true)
set("playerCash", 1e9)
set("JumpPurchasedLevel", 1)
tick()
check(not badgeVisible, "new tier while open is acknowledged without flicker")
panel(false)
tick()
check(not badgeVisible, "open-panel tier remains acknowledged after close")
set("BatPurchasedLevel", 0)
tick()
check(badgeVisible, "a different newly affordable track notifies")
click("Bat")
tick()
check(not badgeVisible, "pending purchase suppresses actionable notification")
result("Bat", false, "Busy")
tick()
check(badgeVisible, "purchase rejection reevaluates affordability")
panel(true)
panel(false)
set("PlotMembershipRevision", attributes.PlotMembershipRevision + 1)
tick()
check(badgeVisible, "new membership resets affordability acknowledgement")
stopBadge()
print("PASS: upgrade badge aggregation, acknowledgement, membership and purchase state")
