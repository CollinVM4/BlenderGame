-- Presentation contracts at the existing upgrades fake Roblox boundary.
local alerts = load("TutorialAlertController")
local notifications = load("MenuNotifications")
local registry = load("UIRegistry")
local desktop = registry.Desktops(playerGui)[1]
local alertContent = registry.Content(desktop)
local leftMenu = alertContent:FindFirstChild("LeftMenu")
local alertPanel = assert(gui.Resolve(playerGui)).Panel
local alertScroll = registry.Child(alertPanel, "UpgradeScroll", { "UpgradeScroll" }, "ScrollingFrame")
local alertList = registry.Child(alertScroll, "UpgradeList", { "UpgradeList" }, "GuiObject")
local jumpCard = assert(registry.Child(alertList, "Upgrade:Jump", { "JumpCard" }, "GuiObject"))
local batCard = assert(registry.Child(alertList, "Upgrade:Bat", { "BatCard" }, "GuiObject"))
local menuArrow = registry.Child(leftMenu, "Alert", { "Alert" }, "ImageLabel")
    or instance("ImageLabel", "Alert", leftMenu)
local jumpArrow = registry.Child(jumpCard, "Jump1Alert", { "Jump1Alert" }, "ImageLabel")
    or instance("ImageLabel", "Jump1Alert", jumpCard)
local batArrow = registry.Child(batCard, "BatAlert", { "BatAlert" }, "ImageLabel")
    or instance("ImageLabel", "BatAlert", batCard)
-- Both runner modes exercise authored visibility independently of runtime state.
for _, arrow in { menuArrow, jumpArrow, batArrow } do
    arrow.Visible = initialUi
end
local authoredScale = instance("UIScale", "AuthoredScale", jumpArrow)
authoredScale.Scale = 0.8
set("playerCash", 0)
set("JumpPurchasedLevel", 0)
set("BatPurchasedLevel", 0)
set("TutorialActive", true)
set("TutorialStage", "Order")
notifications.PanelChanged("Upgrades", false)
alerts.Init()
alerts.Init()
flushDeferred()
check(not menuArrow.Visible and not jumpArrow.Visible and not batArrow.Visible, "authored arrows hidden on bind")
set("playerCash", load("Upgrades").Jump[2].Cost)
set("TutorialStage", "BuyJump")
check(menuArrow.Visible and not jumpArrow.Visible and not batArrow.Visible, "threshold shows only menu arrow")
local menuTween = alertTweens[#alertTweens]
check(
    menuTween.Playing and menuTween.Goal.Scale == 1.15 and menuTween.Info[4] == -1 and menuTween.Info[5],
    "visible arrow pulses repeatedly"
)
notifications.PanelChanged("Upgrades", true)
check(not menuArrow.Visible and jumpArrow.Visible and not batArrow.Visible, "opening switches authored arrows")
check(not menuTween.Playing and menuTween.Target.Scale == 1, "hidden menu pulse stops and restores scale")
local jumpTween = alertTweens[#alertTweens]
check(jumpTween.Playing and jumpTween.Target == authoredScale, "pulse reuses authored UIScale")
set("playerCash", 0)
check(jumpArrow.Visible and jumpTween.Playing, "spending preserves visible pulse")
notifications.PanelChanged("Upgrades", false)
check(
    menuArrow.Visible and not jumpArrow.Visible and authoredScale.Scale == 1 and not jumpTween.Playing,
    "closing restores menu and resets panel pulse"
)
-- A replacement direct child is rebound without waiting for attribute changes.
playerGui.DescendantRemoving:Fire(menuArrow)
table.remove(leftMenu.children, table.find(leftMenu.children, menuArrow))
menuArrow.Parent = nil
local replacementArrow = instance("ImageLabel", "Alert", leftMenu)
playerGui.DescendantAdded:Fire(replacementArrow)
flushDeferred()
check(not menuArrow.Visible and replacementArrow.Visible, "reimport retires old arrow and restores current beat")
set("playerCash", load("Upgrades").Bat[2].Cost)
set("JumpPurchasedLevel", 1)
set("TutorialStage", "BuyBat")
check(
    replacementArrow.Visible and not jumpArrow.Visible and not batArrow.Visible,
    "BuyBat uses closed-panel menu arrow"
)
notifications.PanelChanged("Upgrades", true)
check(
    not replacementArrow.Visible and not jumpArrow.Visible and batArrow.Visible,
    "replicated purchase hands off to Bat"
)
playerGui.DescendantRemoving:Fire(batArrow)
table.remove(batCard.children, table.find(batCard.children, batArrow))
batArrow.Parent = nil
flushDeferred()
check(not batArrow.Visible and not jumpArrow.Visible, "missing authored arrow safely clears presentation")
local replacementBat = instance("ImageLabel", "BatAlert", batCard)
playerGui.DescendantAdded:Fire(replacementBat)
flushDeferred()
check(replacementBat.Visible, "late authored arrow receives current state")
set("BatPurchasedLevel", 1)
check(
    not replacementBat.Visible and not jumpArrow.Visible and not replacementArrow.Visible,
    "purchased tracks show no Buy-stage arrow"
)
set("TutorialStage", "Complete")
check(not replacementBat.Visible and not replacementArrow.Visible, "completion hides all arrows")
for _, tween in alertTweens do
    check(not tween.Playing and tween.Target.Scale == 1, "completion and rebind stop every retired pulse")
end
print("PASS: tutorial alert visibility, pulse, panel changes and authored-arrow reimport")
