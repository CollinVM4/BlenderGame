--!strict
-- Display and intent only; grants/purchases are server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Marketplace = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Constants.WingsConfig)
local Registry = require(script.Parent.Parent.UI.UIRegistry)
local Notifications = require(script.Parent.Parent.UI.MenuNotifications)
local Adapter = {}
local changed = Instance.new("BindableEvent")
Adapter.Changed = changed.Event
local started = false
local price: number? = nil
local forSale: boolean? = nil
local fetching = false
local nextPriceAt = 0

function Adapter.GetSnapshot()
    local ownership = Players.LocalPlayer:GetAttribute("WingsOwnership") or "Loading"
    return {
        Ownership = ownership,
        Owned = ownership == "Owned",
        Price = price,
        PriceText = if price then tostring(price) .. " ROBUX" else "PRICE UNAVAILABLE",
        CanBuy = ownership == "Unowned" and forSale == true,
    }
end
local function fetchPrice()
    if fetching or Config.WingsGamePassId ~= 2021642550 or os.clock() < nextPriceAt then
        return
    end
    fetching, nextPriceAt = true, os.clock() + 30
    task.spawn(function()
        -- Client lookup preserves localized pricing; authored 299 is never a purchase price.
        local ok, info = pcall(function()
            return Marketplace:GetProductInfoAsync(Config.WingsGamePassId, Enum.InfoType.GamePass)
        end)
        fetching = false
        price = if ok
                and typeof(info) == "table"
                and typeof(info.PriceInRobux) == "number"
            then info.PriceInRobux
            else nil
        forSale = if ok and typeof(info) == "table" then info.IsForSale == true else nil
        changed:Fire(Adapter.GetSnapshot())
    end)
end
local function request(action: string)
    local remote = ReplicatedStorage:FindFirstChild("WingsRequest")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(action)
    end
end
function Adapter.Refresh()
    request("Refresh") -- Explicit shop refresh also re-verifies previously owned passes.
    fetchPrice()
end
function Adapter.RequestPurchase()
    if Adapter.GetSnapshot().CanBuy then
        request("Purchase")
    end
end
-- Every bound child is resolved through the importer's tagged-child contract,
-- scoped to this authored card. No descendant-wide Buy/RobuxCost guessing.
function Adapter.Resolve(panel: Instance): { Buy: GuiButton }?
    local scroll = Registry.Child(panel, "Wings:Scroll", { "ShopScroll" }, "GuiObject")
    local list = Registry.Child(scroll, "Wings:List", { "ShopList" }, "GuiObject")
    local card = Registry.Child(list, "Wings:Card", { "Angel Wings" }, "Frame")
    local content = Registry.Child(card, "Wings:Content", { "Angel WingsContent" }, "CanvasGroup")
    local buy = Registry.Child(content, "Wings:Buy", { "Buy" }, "GuiButton")
    if not buy then
        return nil
    end
    return { Buy = buy :: GuiButton }
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
                warn("[Wings] Authored Shop card/Buy/price missing or ambiguous.")
            end
            return
        end
        local function render()
            local snapshot = Adapter.GetSnapshot()
            view.Buy.Active, view.Buy.Selectable = snapshot.CanBuy, snapshot.CanBuy
        end
        local list: { RBXScriptConnection } = {}
        bound[panel] = list
        table.insert(list, changed.Event:Connect(render))
        table.insert(list, view.Buy.Activated:Connect(Adapter.RequestPurchase))
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
    Players.LocalPlayer:GetAttributeChangedSignal("WingsOwnership"):Connect(function()
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
