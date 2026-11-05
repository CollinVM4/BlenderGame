--!strict
-- Display and purchase intent only; Developer Products grant exclusively by server receipt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Marketplace = game:GetService("MarketplaceService")
local Products = require(ReplicatedStorage.Shared.Constants.ShopProducts)
local Registry = require(script.Parent.Parent.UI.UIRegistry)
local Notifications = require(script.Parent.Parent.UI.MenuNotifications)
local Adapter = {}
local changed = Instance.new("BindableEvent")
Adapter.Changed = changed.Event
local started = false
local prices = {
    [10] = { ProductId = Products.Cash2x10Minutes.ProductId, ForSale = false, Fetching = false, NextPriceAt = 0 },
    [30] = { ProductId = Products.Cash2x30Minutes.ProductId, ForSale = false, Fetching = false, NextPriceAt = 0 },
}
function Adapter.GetSnapshot()
    local expiry = Players.LocalPlayer:GetAttribute("DoubleCashExpiresAt")
    local remaining = if typeof(expiry) == "number" then math.max(0, expiry - workspace:GetServerTimeNow()) else 0
    return {
        Active = remaining > 0,
        RemainingSeconds = remaining,
        CanBuy10 = prices[10].ForSale,
        CanBuy30 = prices[30].ForSale,
    }
end
local function fetchPrice()
    for _, state in prices do
        if state.Fetching or os.clock() < state.NextPriceAt then
            continue
        end
        state.Fetching, state.NextPriceAt = true, os.clock() + 30
        task.spawn(function()
            local ok, info = pcall(function()
                return Marketplace:GetProductInfoAsync(state.ProductId, Enum.InfoType.Product)
            end)
            state.Fetching = false
            state.ForSale = ok and typeof(info) == "table" and info.IsForSale == true
            changed:Fire(Adapter.GetSnapshot())
        end)
    end
end
local function request(action: string)
    local remote = ReplicatedStorage:FindFirstChild("CashBoostRequest")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(action)
    end
end
function Adapter.Refresh()
    fetchPrice()
end
function Adapter.RequestPurchase10()
    if Adapter.GetSnapshot().CanBuy10 then
        request("Purchase10")
    end
end
function Adapter.RequestPurchase30()
    if Adapter.GetSnapshot().CanBuy30 then
        request("Purchase30")
    end
end
function Adapter.Resolve(panel: Instance): { Buy10: GuiButton, Buy30: GuiButton }?
    local scroll = Registry.Child(panel, "CashBoost:Scroll", { "ShopScroll" }, "GuiObject")
    local list = Registry.Child(scroll, "CashBoost:List", { "ShopList" }, "GuiObject")
    local card = Registry.Child(list, "CashBoost:Card", { "2x Cash" }, "Frame")
    local content = Registry.Child(card, "CashBoost:Content", { "2x CashContent" }, "CanvasGroup")
    local buy10 = Registry.Child(content, "CashBoost:Buy10", { "Buy10" }, "GuiButton")
    local buy30 = Registry.Child(content, "CashBoost:Buy30", { "Buy30" }, "GuiButton")
    if not buy10 or not buy30 then
        return nil
    end
    return { Buy10 = buy10 :: GuiButton, Buy30 = buy30 :: GuiButton }
end
function Adapter.Init()
    if started then
        return
    end
    started = true
    local warned = false
    local bound: { [Instance]: { RBXScriptConnection } } = {}
    local function bind(panel: Instance)
        if Registry.PanelId(panel) ~= "Shop" or bound[panel] then
            return
        end
        local view = Adapter.Resolve(panel)
        if not view then
            if not warned then
                warned = true
                warn("[CashBoost] Authored Shop card/Buy/price missing or ambiguous.")
            end
            return
        end
        local function render()
            local snapshot = Adapter.GetSnapshot()
            view.Buy10.Active, view.Buy10.Selectable = snapshot.CanBuy10, snapshot.CanBuy10
            view.Buy30.Active, view.Buy30.Selectable = snapshot.CanBuy30, snapshot.CanBuy30
        end
        local list: { RBXScriptConnection } = {}
        bound[panel] = list
        table.insert(list, changed.Event:Connect(render))
        table.insert(list, view.Buy10.Activated:Connect(Adapter.RequestPurchase10))
        table.insert(list, view.Buy30.Activated:Connect(Adapter.RequestPurchase30))
        table.insert(
            list,
            panel.Destroying:Connect(function()
                for _, connection in list do
                    connection:Disconnect()
                end
                bound[panel] = nil
            end)
        )
        render()
    end
    Players.LocalPlayer:GetAttributeChangedSignal("DoubleCashExpiresAt"):Connect(function()
        changed:Fire(Adapter.GetSnapshot())
    end)
    Notifications.OnOpened("Shop", Adapter.Refresh) -- FramewispMenus' existing panel-open path.
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local function resolve()
        for _, desktop in Registry.Desktops(playerGui) do
            local content = Registry.Content(desktop)
            if content then
                for _, panel in content:GetChildren() do
                    bind(panel)
                end
            end
        end
    end
    playerGui.DescendantAdded:Connect(function()
        task.defer(resolve)
    end)
    resolve()
    fetchPrice()
end
return Adapter
