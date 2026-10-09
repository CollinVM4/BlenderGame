--!strict
-- Future Framewisp entry points. All authority stays in IceGunService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Marketplace = game:GetService("MarketplaceService")
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
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

function Adapter.Init()
    if started then
        return
    end
    started = true
    Players.LocalPlayer:GetAttributeChangedSignal("IceGunOwnership"):Connect(function()
        fetchPrice()
        changed:Fire(Adapter.GetSnapshot())
    end)
    Players.LocalPlayer:GetAttributeChangedSignal("IceGunEquipped"):Connect(function()
        changed:Fire(Adapter.GetSnapshot())
    end)
    fetchPrice()
end

return Adapter
