--!strict
-- Authored Shop entry points. All authority stays in IceGunService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Marketplace = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
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
    local ownership = Players.LocalPlayer:GetAttribute("IceGunOwnership") or "Loading"
    return {
        Ownership = ownership,
        Owned = ownership == "Owned",
        Equipped = ownership == "Owned" and Players.LocalPlayer:GetAttribute("IceGunEquipped") == true,
        Price = price,
        PriceText = if price then tostring(price) .. " ROBUX" else "PRICE UNAVAILABLE",
        CanBuy = ownership == "Unowned" and forSale == true,
        CanEquip = ownership == "Owned",
    }
end

local function fetchPrice()
    if fetching or Config.IceGunGamePassId <= 0 or os.clock() < nextPriceAt then
        return
    end
    fetching = true
    nextPriceAt = os.clock() + 30
    task.spawn(function()
        -- Query on the client so PriceInRobux reflects this player's localized price.
        local ok, info = pcall(function()
            return Marketplace:GetProductInfoAsync(Config.IceGunGamePassId, Enum.InfoType.GamePass)
        end)
        fetching = false
        price = if ok and typeof(info.PriceInRobux) == "number" then info.PriceInRobux else nil
        forSale = if ok then info.IsForSale == true else nil
        changed:Fire(Adapter.GetSnapshot())
    end)
end

local function request(action: string)
    local remote = ReplicatedStorage:FindFirstChild("IceGunRequest")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(action)
    end
end

function Adapter.Refresh()
    local ownership = Adapter.GetSnapshot().Ownership
    if ownership == "Loading" or ownership == "Unavailable" then
        request("Refresh")
    end
    fetchPrice()
end

function Adapter.RequestPurchase()
    request("Purchase")
end

function Adapter.RequestEquip()
    request("Equip")
end

function Adapter.Resolve(panel: Instance): { Buy: GuiButton }?
    local scroll = Registry.Child(panel, "IceGun:Scroll", { "ShopScroll" }, "GuiObject")
    local list = Registry.Child(scroll, "IceGun:List", { "ShopList" }, "GuiObject")
    local card = Registry.Child(list, "IceGun:Card", { "Ice Gun" }, "Frame")
    local content = Registry.Child(card, "IceGun:Content", { "Ice GunContent" }, "CanvasGroup")
    local buy = Registry.Child(content, "IceGun:Buy", { "Buy" }, "GuiButton")
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
                warn("[IceGun] Authored Shop card/Buy/price missing or ambiguous.")
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
    Players.LocalPlayer:GetAttributeChangedSignal("IceGunOwnership"):Connect(function()
        fetchPrice()
        changed:Fire(Adapter.GetSnapshot())
    end)
    Players.LocalPlayer:GetAttributeChangedSignal("IceGunEquipped"):Connect(function()
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
