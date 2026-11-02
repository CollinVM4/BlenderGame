local nodes, panel = {}, nil
for _, row in exportNodes do
    local item = instance(row[3])
    item.Name = row[4]
    nodes[row[1]] = item
    item.Parent = nodes[row[2]]
    if row[3] == "Frame" and row[4] == "Shop" then
        panel = item
    end
end
setup(panel ~= nil, "authored Shop panel exists")
local p = instance("Player")
services.Players.LocalPlayer = p
local calls, queriedPass, queriedType, remoteCalls = 0, nil, nil, {}
services.MarketplaceService = {
    GetProductInfoAsync = function(_, pass, infoType)
        calls += 1
        queriedPass, queriedType = pass, infoType
        return { PriceInRobux = 321, IsForSale = true }
    end,
}
env.Enum.InfoType = { GamePass = "GamePass" }
local opened
cache.MenuNotifications = {
    OnOpened = function(_, fn)
        opened = fn
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
local remote = instance("RemoteEvent")
remote.Name = "WingsRequest"
function remote:FireServer(action)
    table.insert(remoteCalls, action)
end
local replicated = instance("Folder")
replicated.Shared = shared
remote.Parent, services.ReplicatedStorage = replicated, replicated
local adapter = loadModule("WingsShopAdapter")
local view = adapter.Resolve(panel)
check(
    view ~= nil and view.Buy.Name == "Buy" and view.Label.Name == "BuyLabel" and view.Cost.Name == "RobuxCost",
    "every bound shop name resolves in the actual export"
)
for _, object in
    {
        panel:FindFirstChild("ShopScroll"),
        panel:FindFirstChild("ShopScroll"):FindFirstChild("ShopList"),
        view.Buy.Parent,
        view.Buy,
        view.Label,
        view.Cost.Parent,
        view.Cost,
    }
do
    local name = object.Name
    object.Name = "Renamed"
    check(adapter.Resolve(panel) == nil, "renaming bound " .. name .. " fails resolution")
    object.Name = name
end
p:SetAttribute("WingsOwnership", "Unowned")
adapter.Init()
flush()
check(queriedPass == 2021642550 and queriedType == "GamePass", "localized price queried on client for exact pass")
check(
    view.Cost.Text == "321 ROBUX" and adapter.GetSnapshot().PriceText == "321 ROBUX" and adapter.GetSnapshot().CanBuy,
    "live price replaces authored fallback"
)
-- Resolve through the actual registry/open path even in an imported new root.
opened()
flush()
check(
    calls == 1 and remoteCalls[#remoteCalls] == "Refresh",
    "shop open refreshes ownership while price lookup is throttled"
)
adapter.RequestPurchase()
check(remoteCalls[#remoteCalls] == "Purchase", "buy sends only server purchase intent")
p:SetAttribute("WingsOwnership", "Owned")
p:GetAttributeChangedSignal("WingsOwnership"):Fire()
local prior = #remoteCalls
adapter.RequestPurchase()
check(
    not view.Buy.Active and view.Label.Text == "Owned" and not adapter.GetSnapshot().CanBuy and #remoteCalls == prior,
    "owned snapshot disables duplicate Buy"
)
check(adapter.GetSnapshot().Equipped == nil, "wings shop exposes no equip state")
print("PASS: wings authored Shop resolution and price contracts")
