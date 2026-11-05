-- Shop presentation contract against the real authored instance tree.
local nodes, panel = {}, nil
local originalText = {}
for _, row in exportNodes do
    local item = instance(row[3])
    item.Name, item.Text = row[4], row[5]
    nodes[row[1]] = item
    item.Parent = nodes[row[2]]
    originalText[item] = row[5]
    if row[3] == "Frame" and row[4] == "Shop" then
        panel = item
    end
end
setup(panel ~= nil, "authored Shop panel exists")
local p = instance("Player")
services.Players.LocalPlayer = p
local calls, remoteCalls, opened = {}, {}, {}
local sale = true
services.MarketplaceService = {
    GetProductInfoAsync = function(_, id, infoType)
        table.insert(calls, { id, infoType })
        -- Deliberately different from authored prices: display must remain unchanged.
        return { PriceInRobux = 321, IsForSale = sale }
    end,
}
env.Enum.InfoType = { GamePass = "GamePass", Product = "Product" }
cache.MenuNotifications = {
    OnOpened = function(id, fn)
        setup(id == "Shop", "only Shop registers purchase refresh")
        table.insert(opened, fn)
    end,
}
local gui = instance("PlayerGui")
gui.Name, gui.Parent = "PlayerGui", p
gui.DescendantAdded = signal()
p.WaitForChild = p.FindFirstChild
for _, row in exportNodes do
    if row[2] == 0 then
        nodes[row[1]].Parent = gui
    end
end
local replicated = instance("Folder")
replicated.Shared = shared
services.ReplicatedStorage = replicated
for _, name in { "WingsRequest", "IceGunRequest", "CashBoostRequest" } do
    local remote = instance("RemoteEvent")
    remote.Name, remote.Parent = name, replicated
    function remote:FireServer(action)
        table.insert(remoteCalls, { name, action })
    end
end
local wings = loadModule("WingsShopAdapter")
local ice = loadModule("IceGunShopAdapter")
local cash = loadModule("CashBoostShopAdapter")
local registry = loadModule("UIRegistry")
check(registry.PanelId(panel) == "Shop", "export Shop matches actual panel registry")
local w, i, c = wings.Resolve(panel), ice.Resolve(panel), cash.Resolve(panel)
setup(w and i and c, "all three authored cards resolve")
check(
    w.Buy.Parent.Name == "Angel WingsContent" and i.Buy.Parent.Name == "Ice GunContent",
    "pass buttons bind through exact authored Content layers"
)
check(c.Buy10.Name == "Buy10" and c.Buy30.Name == "Buy30", "cash durations resolve distinct authored controls")
-- An ambiguous authored control must never bind an arbitrary sibling.
local duplicate = instance("TextButton")
duplicate.Name, duplicate.Parent = "Buy10", c.Buy10.Parent
check(cash.Resolve(panel) == nil, "duplicate Buy10 fails closed")
duplicate:Destroy()
p:SetAttribute("WingsOwnership", "Unowned")
p:SetAttribute("IceGunOwnership", "Unowned")
for _, adapter in { wings, ice, cash } do
    adapter.Init()
end
flush()
check(
    w.Buy.Active and w.Buy.Selectable and i.Buy.Active and i.Buy.Selectable and c.Buy10.Active and c.Buy30.Active,
    "live availability enables all authored Buy controls"
)
local queried = {}
for _, call in calls do
    queried[call[1]] = call[2]
end
check(queried[2021642550] == "GamePass" and queried[2022020489] == "GamePass", "pass prices use GamePass lookup")
check(queried[3728323243] == "Product" and queried[3728323462] == "Product", "consumable prices use Product lookup")
for _, fn in opened do
    fn()
end
flush()
check(#calls == 4, "Shop reopen respects 30-second price cache")
for _, button in { w.Buy, i.Buy, c.Buy10, c.Buy30 } do
    button.Activated:Fire()
end
local intents = {}
for _, call in remoteCalls do
    intents[call[1] .. ":" .. call[2]] = true
end
check(
    intents["WingsRequest:Purchase"]
        and intents["IceGunRequest:Purchase"]
        and intents["CashBoostRequest:Purchase10"]
        and intents["CashBoostRequest:Purchase30"],
    "each authored button sends matching purchase intent"
)
p:SetAttribute("WingsOwnership", "Owned")
p:SetAttribute("IceGunOwnership", "Owned")
p:SetAttribute("IceGunEquipped", true)
p:SetAttribute("DoubleCashExpiresAt", now + 600)
for _, name in { "WingsOwnership", "IceGunOwnership", "IceGunEquipped", "DoubleCashExpiresAt" } do
    p:GetAttributeChangedSignal(name):Fire()
end
flush()
check(
    not w.Buy.Active and not w.Buy.Selectable and not i.Buy.Active and not i.Buy.Selectable,
    "ownership disables pass purchases"
)
check(
    c.Buy10.Active and c.Buy30.Active and cash.GetSnapshot().Active,
    "active repeatable boost keeps both Buy buttons available"
)
now += 601
check(
    not cash.GetSnapshot().Active and cash.GetSnapshot().RemainingSeconds == 0,
    "client snapshot uses server-time expiry"
)
now += 30
sale = false
for _, adapter in { wings, ice, cash } do
    adapter.Refresh()
end
flush()
check(#calls == 8 and not c.Buy10.Active and not c.Buy30.Active, "cache expiry refreshes live sale state")
for item, text in originalText do
    check(item.Text == text, "authored text unchanged: " .. item.Name)
end
check(wings.GetSnapshot().Equipped == nil, "wings exposes no equip toggle")
print("PASS: actual-export Shop text preservation, state and purchase wiring")
