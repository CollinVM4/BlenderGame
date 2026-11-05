--!strict
local Players = game:GetService("Players")
local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Products = require(ReplicatedStorage.Shared.Constants.ShopProducts)
local Service = {}
local started = false

function Service.Init(services: any)
    if started then
        return
    end
    started = true
    local requestAt: { [Player]: number } = {}
    -- Session-only receipt history. Keep by UserId across departure/rejoin in this server,
    -- but neither receipts nor boost time survive a server restart until persistence lands.
    local processed: { [number]: { [string]: boolean } } = {}
    local durations = {
        [Products.Cash2x10Minutes.ProductId] = Products.Cash2x10Minutes.DurationSeconds,
        [Products.Cash2x30Minutes.ProductId] = Products.Cash2x30Minutes.DurationSeconds,
    }
    Marketplace.ProcessReceipt = function(receiptInfo)
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        local duration = durations[receiptInfo.ProductId]
        if not player or player.Parent ~= Players or not duration then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local receipts = processed[player.UserId]
        if receipts and receipts[receiptInfo.PurchaseId] then
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        -- GrantDoubleCash does not yield; mark only after its successful return.
        local ok, problem = pcall(services.PlayerDataService.GrantDoubleCash, player, duration)
        if not ok then
            warn("[CashBoost] Receipt grant deferred: " .. tostring(problem))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local grantedReceipts: { [string]: boolean } = receipts or {}
        grantedReceipts[receiptInfo.PurchaseId] = true
        processed[player.UserId] = grantedReceipts
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local remote = Instance.new("RemoteEvent")
    remote.Name, remote.Parent = "CashBoostRequest", ReplicatedStorage
    remote.OnServerEvent:Connect(function(player, action)
        local product = if action == "Purchase10"
            then Products.Cash2x10Minutes
            elseif action == "Purchase30" then Products.Cash2x30Minutes
            else nil
        if not product or player.Parent ~= Players or os.clock() < (requestAt[player] or 0) then
            return
        end
        requestAt[player] = os.clock() + 0.5
        -- Prompt only. A client request or prompt completion never grants a boost.
        local ok, problem = pcall(function()
            Marketplace:PromptProductPurchase(player, product.ProductId)
        end)
        if not ok then
            warn("[CashBoost] Purchase prompt failed: " .. tostring(problem))
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        requestAt[player] = nil
    end)
end
return Service
