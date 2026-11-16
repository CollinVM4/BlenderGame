-- One home for the four consumers' structural refresh and replacement contracts.
env.refreshCounts = {}
sources.ClaimProfile = [[
return { Wrap = function(name, callback)
    return function(...)
        refreshCounts[name] = (refreshCounts[name] or 0) + 1
        return callback(...)
    end
end }
]]
local player = instance("Player")
services.Players.LocalPlayer = player
player.WaitForChild = player.FindFirstChild
local playerGui = instance("PlayerGui")
playerGui.Name, playerGui.Parent = "PlayerGui", player
playerGui.DescendantAdded, playerGui.DescendantRemoving = signal(), signal()
local requests = {}
local replicated = instance("Folder")
replicated.Shared = shared
services.ReplicatedStorage = replicated
for _, name in { "WingsRequest", "CashBoostRequest", "IceGunRequest" } do
    local remote = instance("RemoteEvent")
    remote.Name, remote.Parent = name, replicated
    function remote:FireServer(action)
        local key = name .. ":" .. action
        requests[key] = (requests[key] or 0) + 1
    end
end
services.MarketplaceService = {
    GetProductInfoAsync = function()
        return { PriceInRobux = 321, IsForSale = true }
    end,
}
env.Enum.InfoType = { GamePass = "GamePass", Product = "Product" }
cache.MenuNotifications = { OnOpened = function() end }
player:SetAttribute("WingsOwnership", "Unowned")
player:SetAttribute("IceGunOwnership", "Unowned")
player:SetAttribute("TasksTutorialComplete", true)
player:SetAttribute("TasksServeThreshold", 10)
player:SetAttribute("TasksServeTotal", 3)
player:SetAttribute("TasksServeReward", 5000)
local tasks = loadModule("TasksController")
local wings = loadModule("WingsShopAdapter")
local cash = loadModule("CashBoostShopAdapter")
local ice = loadModule("IceGunShopAdapter")
local registry = loadModule("UIRegistry")
local taskGui = loadModule("TasksGui")
local refreshNames = { "tasks.refresh", "shop.wings.resolve", "shop.cashBoost.resolve", "shop.iceGun.resolve" }
local scans = 0
local desktops = registry.Desktops
registry.Desktops = function(container)
    scans += 1
    return desktops(container)
end
local function drain()
    while #deferred > 0 do
        flush()
    end
end
local function child(class, name, parent, role)
    local object = instance(class)
    object.Name, object.Parent, object.Visible, object.Enabled = name, parent, true, true
    if role then
        object:SetAttribute("BlenderUI", role)
    end
    return object
end
-- Explicitly model Roblox's descendant events, including subtree mounts/removals.
local function notify(event, object)
    event:Fire(object)
    for _, descendant in object:GetDescendants() do
        event:Fire(descendant)
    end
end
local function mount(object, parent)
    object.Parent = parent
    notify(playerGui.DescendantAdded, object)
end
local function detach(object)
    notify(playerGui.DescendantRemoving, object)
    object.Parent = nil
end
local function makeTasks(content, tagged)
    local panel =
        child("Frame", if tagged then "generated tasks" else "Tasks", content, if tagged then "Panel:Tasks" else nil)
    for _, name in { "ServeTask", "StealTask" } do
        local row = child("Frame", name, panel)
        for _, label in { "Objective", "Progress", "Reward" } do
            child("TextLabel", label, row)
        end
    end
    return panel
end
local function makeRoot(tagged)
    local root = child("ScreenGui", "Generated export")
    local desktop = child(
        "Frame",
        if tagged then "generated desktop" else "Be a Blender! Desktop",
        root,
        if tagged then "Desktop" else nil
    )
    local content = child(
        "Frame",
        if tagged then "generated content" else "DesktopContent",
        desktop,
        if tagged then "Content" else nil
    )
    local taskPanel = makeTasks(content, tagged)
    local shop =
        child("Frame", if tagged then "generated shop" else "Shop", content, if tagged then "Panel:Shop" else nil)
    local scroll = child("ScrollingFrame", "ShopScroll", shop)
    local list = child("Frame", "ShopList", scroll)
    for _, name in { "Angel Wings", "2x Cash", "Ice Gun" } do
        local card = child("Frame", name, list)
        local cardContent = child("CanvasGroup", name .. "Content", card)
        for _, button in (if name == "2x Cash" then { "Buy10", "Buy30" } else { "Buy" }) do
            child("TextButton", button, cardContent)
        end
    end
    return { Root = root, Content = content, Tasks = taskPanel, Shop = shop }
end
local tree = makeRoot(false)
if bindingMode == "startup" then
    tree.Root.Parent = playerGui
end
for _, consumer in { tasks, wings, cash, ice } do
    consumer.Init()
end
drain()
for _, name in refreshNames do
    check(env.refreshCounts[name] == 1, name .. " attempts initial binding")
end
local function resetCounts()
    table.clear(env.refreshCounts)
    scans = 0
end
local function expectCounts(tasksCount, shopsCount, message)
    for index, name in refreshNames do
        check(
            (env.refreshCounts[name] or 0) == (if index == 1 then tasksCount else shopsCount),
            message .. ": " .. name
        )
    end
end
local function purchaseOnce(shop, message)
    local w, c, i = wings.Resolve(shop), cash.Resolve(shop), ice.Resolve(shop)
    setup(w and c and i, "complete Shop resolves")
    for _, entry in
        {
            { w.Buy, "WingsRequest:Purchase" },
            { c.Buy10, "CashBoostRequest:Purchase10" },
            { c.Buy30, "CashBoostRequest:Purchase30" },
            { i.Buy, "IceGunRequest:Purchase" },
        }
    do
        check(entry[1].Active == true, message .. " renders current availability")
        local before = requests[entry[2]] or 0
        entry[1].Activated:Fire()
        check(requests[entry[2]] == before + 1, message .. " sends exactly one " .. entry[2])
    end
end
if bindingMode == "late" then
    resetCounts()
    mount(tree.Root, playerGui)
    expectCounts(0, 0, "structural refresh waits for defer")
    drain()
    expectCounts(1, 1, "whole late export coalesces")
end
check(taskGui.Resolve(playerGui).Serve.Progress.Text == "3/10", "Tasks binds current progress at startup or late mount")
purchaseOnce(tree.Shop, "initial binding")
resetCounts()
-- Match the measured stash burst, including misleading control names outside Desktop.
local billboard = child("BillboardGui", "StashRipeness")
mount(billboard, playerGui)
for index = 1, 228 do
    mount(child("Frame", if index % 2 == 0 then "Buy" else "Tasks"), billboard)
end
drain()
expectCounts(0, 0, "229 unrelated additions cause zero refreshes")
check(scans == 0, "stash additions cause zero desktop scans")
detach(billboard)
drain()
expectCounts(0, 0, "unrelated removal causes zero refreshes")
-- A second relevant burst must schedule again and resolve the UI at execution time.
detach(tree.Tasks)
mount(makeTasks(tree.Content, false), tree.Content)
player:SetAttribute("TasksServeTotal", 7)
drain()
expectCounts(1, 0, "Tasks replacement coalesces without refreshing shops")
check(taskGui.Resolve(playerGui).Serve.Progress.Text == "7/10", "replacement reads latest progress")
resetCounts()
player:SetAttribute("TasksServeTotal", 8)
player:GetAttributeChangedSignal("TasksServeTotal"):Fire()
check(taskGui.Resolve(playerGui).Serve.Progress.Text == "8/10", "non-structural Tasks updates remain live")
expectCounts(1, 0, "attribute update preserves existing refresh")
resetCounts()
local oldButtons = {
    wings.Resolve(tree.Shop).Buy,
    cash.Resolve(tree.Shop).Buy10,
    cash.Resolve(tree.Shop).Buy30,
    ice.Resolve(tree.Shop).Buy,
}
for _, button in oldButtons do
    local parent = button.Parent
    detach(button)
    mount(child("TextButton", button.Name), parent)
end
expectCounts(0, 0, "button replacement queues before resolving")
drain()
expectCounts(0, 1, "Shop button replacement burst coalesces")
purchaseOnce(tree.Shop, "replaced controls")
local beforeOld = table.clone(requests)
for _, button in oldButtons do
    button.Activated:Fire()
end
for key, value in requests do
    check(value == beforeOld[key], "detached controls are inert: " .. key)
end
-- Detach and reattach the same root; old controls must not accumulate handlers.
resetCounts()
detach(tree.Root)
drain()
mount(tree.Root, playerGui)
drain()
expectCounts(2, 2, "subsequent root changes can queue another refresh")
purchaseOnce(tree.Shop, "reattached export")
-- Replace a whole export using semantic roles instead of fallback root names.
resetCounts()
local oldTree = tree
detach(oldTree.Root)
tree = makeRoot(true)
mount(tree.Root, playerGui)
drain()
expectCounts(1, 1, "semantic export replacement coalesces removals and additions")
check(taskGui.Resolve(playerGui).Serve.Progress.Text == "8/10", "semantic Tasks replacement displays latest state")
purchaseOnce(tree.Shop, "semantic replacement")
beforeOld = table.clone(requests)
local oldView = wings.Resolve(oldTree.Shop)
oldView.Buy.Activated:Fire()
check(requests["WingsRequest:Purchase"] == beforeOld["WingsRequest:Purchase"], "old export no longer purchases")
-- Late controls within an already mounted panel must recover too.
resetCounts()
local view = cash.Resolve(tree.Shop)
local buttonParent = view.Buy30.Parent
detach(view.Buy30)
drain()
mount(view.Buy30, buttonParent)
drain()
expectCounts(0, 2, "incomplete card recovers on later control mount")
purchaseOnce(tree.Shop, "late required control")
player:SetAttribute("WingsOwnership", "Owned")
player:GetAttributeChangedSignal("WingsOwnership"):Fire()
check(not wings.Resolve(tree.Shop).Buy.Active, "ownership still updates replacement controls")
print("PASS: claim GUI fan-out and lifecycle (" .. bindingMode .. ")")
