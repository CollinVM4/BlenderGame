local badge = load("NotificationBadge")
local notifications = load("MenuNotifications")
local menus = load("FramewispMenus")
local manager = load("PanelManager")
local controller = load("ScrapbookController")
-- The upcoming export is represented only in this test fixture.
local rawImport = import
local function import()
    local root = rawImport()
    local left = descend(root, "LeftMenu")
    for _, id in { "Index", "Upgrades" } do
        local button = left:FindFirstChild(id)
        if not button:FindFirstChild("Badge") then
            instance("TextLabel", "Badge", button).Visible = true
        end
    end
    return root
end
for _, class in { "TextLabel", "ImageLabel" } do
    local button = instance("TextButton", "Synthetic")
    local host = instance(class, "Badge", button)
    host.Visible = true
    local setVisible, detach = badge.Attach(button)
    check(not host.Visible, "authored badge forced hidden on bind")
    setVisible(true)
    check(host.Visible, "authored text or image badge accepts visibility")
    detach()
    setVisible(true)
    check(not host.Visible and host.Parent == button, "detach hides and preserves authored element")
end
local missing = instance("TextButton", "Missing")
local showMissing, stopMissing = badge.Attach(missing)
showMissing(true)
stopMissing()
check(#missing:GetChildren() == 0, "missing authored badge is a no-op without fallback")

local root = import()
menus.Attach(root, player)
menus.Attach(root, player)
local nav = descend(root, "LeftMenu"):FindFirstChild("Index")
local function badgeCount(target)
    local found = 0
    for _, child in target:GetChildren() do
        if child.Name == "Badge" then
            found += 1
        end
    end
    return found
end
check(nav:IsA("TextButton") and badgeCount(nav) == 1, "real Index export resolves with one badge")
local indexBadge = nav:FindFirstChild("Badge")
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
check(not indexBadge.Visible, "discoveries received while open are already seen")
nav.Activated:Fire()
nav.Activated:Fire()
check(not indexBadge.Visible, "one open acknowledges the entire unseen count")
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Banana" })
check(indexBadge.Visible, "every protocol event increments even a duplicate payload")

notifications.Set("Upgrades", true)
local upgradeNav = descend(root, "LeftMenu"):FindFirstChild("Upgrades")
check(upgradeNav:FindFirstChild("Badge").Visible, "upgrade state reaches outer export button")

-- Replace the whole desktop; state survives, the old view becomes inert.
root.Parent = nil
root.AncestryChanged:Fire(root, nil)
check(not indexBadge.Visible, "detached desktop hides authored badge")
nav.Activated:Fire()
check(manager.GetActive() == nil, "detached navigation cannot open a panel")
local replacement = import()
playerGui.DescendantAdded:Fire(replacement)
flush()
menus.Attach(replacement, player)
local freshNav = descend(replacement, "LeftMenu"):FindFirstChild("Index")
local freshUpgrade = descend(replacement, "LeftMenu"):FindFirstChild("Upgrades")
check(
    badgeCount(freshUpgrade) == 1 and freshUpgrade:FindFirstChild("Badge").Visible,
    "upgrade badge survives desktop replacement"
)
check(
    badgeCount(freshNav) == 1 and freshNav:FindFirstChild("Badge").Visible,
    "reimport restores one badge with session unseen state"
)
freshNav.Activated:Fire()
check(not freshNav:FindFirstChild("Badge").Visible, "replacement open still acknowledges")
freshNav.Activated:Fire() -- Close before testing a new unseen discovery.
-- Replace just a navigation button inside the retained desktop.
local left = descend(replacement, "LeftMenu")
replacement.DescendantRemoving:Fire(freshNav)
freshNav.Parent = nil
local inserted = instance("TextButton", "Index", left)
instance("TextLabel", "Badge", inserted)
replacement.DescendantAdded:Fire(inserted)
check(badgeCount(inserted) == 1, "inserted replacement navigation gets one badge")
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Strawberry" })
check(inserted:FindFirstChild("Badge").Visible, "new navigation receives live discovery state")
inserted.Activated:Fire()
check(not inserted:FindFirstChild("Badge").Visible, "inserted navigation preserves open action")
freshNav = inserted
stop()
added.OnClientEvent:Fire({ Kind = "Ingredient", Id = "Grapes" })
check(not freshNav:FindFirstChild("Badge").Visible, "stopped discovery controller cannot notify")
replacement:Destroy()
print(string.format("PASS: %d notification badge rendering/discovery/reimport contracts", count))
