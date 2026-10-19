local badge = load("NotificationBadge")
local notifications = load("MenuNotifications")
local menus = load("FramewispMenus")
local manager = load("PanelManager")
local controller = load("ScrapbookController")
local button = instance("TextButton", "Synthetic")
button.ZIndex = 4
local art = instance("ImageLabel", "Art", button)
art.ZIndex = 9
local setVisible, detach = badge.Attach(button)
local host = button:FindFirstChild("NotificationBadge")
check(host and not host.Visible, "attach starts hidden")
check(host.Size.X.Offset == 22 and host.Size.Y.Offset == 22, "22px badge")
check(host.BackgroundTransparency == 1 and not host.Active, "transparent noninteractive host")
local mark = host:FindFirstChild("Mark")
check(mark.Text == "!" and mark.TextScaled and mark.Font == "GothamBold", "legible authored UI voice")
check(not mark.Active and mark.ZIndex > art.ZIndex, "mark sits above art without taking input")
setVisible(true)
check(host.Visible, "setter displays mark")
detach()
setVisible(true)
check(button:FindFirstChild("NotificationBadge") == nil, "detach removes mark and stale setter is inert")

local root = import()
menus.Attach(root, player)
menus.Attach(root, player)
local nav = descend(root, "LeftMenu"):FindFirstChild("Index")
local function badgeCount(target)
    local found = 0
    for _, child in target:GetChildren() do
        if child.Name == "NotificationBadge" then
            found += 1
        end
    end
    return found
end
check(nav:IsA("TextButton") and badgeCount(nav) == 1, "real Index export resolves with one badge")
local indexBadge = nav:FindFirstChild("NotificationBadge")
local events = instance("Folder", "Events")
local added = instance("RemoteEvent", "DiscoveryAdded", events)
added.OnClientEvent = signal()
local snapshot = instance("RemoteFunction", "DiscoverySnapshot", events)
snapshot.InvokeServer = function()
    -- The event emitted during the snapshot must already have a listener.
    added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Apple" })
    return { Ingredients = {}, SpecialCustomers = {} }
end
local stop = controller.Start(playerGui, events, player)
resume(jobs[1])
check(indexBadge.Visible, "event before snapshot return notifies")
nav.Activated:Fire()
check(manager.GetActive() == "Index" and not indexBadge.Visible, "open action immediately clears badge and opens panel")
nav.Activated:Fire()
check(not indexBadge.Visible, "acknowledged discoveries stay cleared after close")
added.OnClientEvent:Fire({ Kind = "SpecialCustomer", Id = "walter" })
check(indexBadge.Visible, "special customer discovery notifies")
nav.Activated:Fire()
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Banana" })
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Banana" })
check(not indexBadge.Visible, "events including duplicates remain hidden while open")
nav.Activated:Fire()
check(indexBadge.Visible, "events received while open reevaluate on close")
nav.Activated:Fire()
nav.Activated:Fire()
check(not indexBadge.Visible, "one open acknowledges the entire unseen count")
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Banana" })
check(indexBadge.Visible, "every protocol event increments even a duplicate payload")

notifications.Set("Upgrades", true)
local upgradeNav = descend(root, "LeftMenu"):FindFirstChild("Upgrades")
check(upgradeNav:FindFirstChild("NotificationBadge").Visible, "upgrade state reaches outer export button")

-- Replace the whole desktop; state survives, the old view becomes inert.
root.Parent = nil
root.AncestryChanged:Fire(root, nil)
check(nav:FindFirstChild("NotificationBadge") == nil, "detached desktop releases badge")
nav.Activated:Fire()
check(manager.GetActive() == nil, "detached navigation cannot open a panel")
local replacement = import()
playerGui.DescendantAdded:Fire(replacement)
flush()
menus.Attach(replacement, player)
local freshNav = descend(replacement, "LeftMenu"):FindFirstChild("Index")
local freshUpgrade = descend(replacement, "LeftMenu"):FindFirstChild("Upgrades")
check(
    badgeCount(freshUpgrade) == 1 and freshUpgrade:FindFirstChild("NotificationBadge").Visible,
    "upgrade badge survives desktop replacement"
)
check(
    badgeCount(freshNav) == 1 and freshNav:FindFirstChild("NotificationBadge").Visible,
    "reimport restores one badge with session unseen state"
)
freshNav.Activated:Fire()
check(not freshNav:FindFirstChild("NotificationBadge").Visible, "replacement open still acknowledges")
freshNav.Activated:Fire() -- Close before testing a new unseen discovery.
-- Replace just a navigation button inside the retained desktop.
local left = descend(replacement, "LeftMenu")
replacement.DescendantRemoving:Fire(freshNav)
freshNav.Parent = nil
local inserted = instance("TextButton", "Index", left)
replacement.DescendantAdded:Fire(inserted)
check(badgeCount(inserted) == 1, "inserted replacement navigation gets one badge")
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Strawberry" })
check(inserted:FindFirstChild("NotificationBadge").Visible, "new navigation receives live discovery state")
inserted.Activated:Fire()
check(not inserted:FindFirstChild("NotificationBadge").Visible, "inserted navigation preserves open action")
freshNav = inserted
stop()
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Grapes" })
check(not freshNav:FindFirstChild("NotificationBadge").Visible, "stopped discovery controller cannot notify")
replacement:Destroy()
print(string.format("PASS: %d notification badge rendering/discovery/reimport contracts", count))
