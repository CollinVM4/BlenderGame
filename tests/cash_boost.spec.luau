-- Receipt/grant contracts, separate from payout integration and Shop presentation.
local data = loadModule("PlayerDataService")
local replicated = instance("Folder")
replicated.Shared = shared
services.ReplicatedStorage = replicated
local player = instance("Player")
player.UserId, player.Parent = 42, services.Players
services.Players.PlayerRemoving = signal()
services.Players.GetPlayerByUserId = function(_, id)
    return if id == player.UserId and player.Parent == services.Players then player else nil
end
data.AddPlayer(player)
env.Enum.ProductPurchaseDecision = { NotProcessedYet = "retry", PurchaseGranted = "granted" }
local prompts = {}
services.MarketplaceService = {
    PromptProductPurchase = function(_, p, id)
        table.insert(prompts, { p, id })
    end,
}
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
    end
    return object
end
local service = loadModule("CashBoostService")
service.Init({ PlayerDataService = data })
local receipt = services.MarketplaceService.ProcessReceipt
local remote = services.ReplicatedStorage:FindFirstChild("CashBoostRequest")
setup(remote, "purchase remote exists")
check(
    not data.IsDoubleCashActive(player) and data.GetDoubleCashRemainingSeconds(player) == 0,
    "new player has no boost"
)
check(not pcall(data.GrantDoubleCash, player, 10), "unsupported grant duration rejected")
remote.OnServerEvent:Fire(player, "Grant")
check(#prompts == 0, "unrecognized request cannot prompt or grant")
remote.OnServerEvent:Fire(player, "Purchase10")
remote.OnServerEvent:Fire(player, "Purchase30")
check(
    #prompts == 1 and prompts[1][2] == 3728323243 and not data.IsDoubleCashActive(player),
    "10-minute request prompts once without granting"
)
now += 1
remote.OnServerEvent:Fire(player, "Purchase30")
check(
    #prompts == 2 and prompts[2][2] == 3728323462 and not data.IsDoubleCashActive(player),
    "30-minute request prompts its product without granting"
)
local info = { PlayerId = 42, ProductId = 3728323243, PurchaseId = "first" }
check(
    receipt(info) == "granted" and data.GetDoubleCashRemainingSeconds(player) == 600,
    "10-minute receipt grants exactly 600 seconds"
)
local expiry = player:GetAttribute("DoubleCashExpiresAt")
check(
    receipt(info) == "granted" and player:GetAttribute("DoubleCashExpiresAt") == expiry,
    "duplicate receipt acknowledged without extending"
)
now += 100
info.PurchaseId = "second"
check(
    receipt(info) == "granted" and player:GetAttribute("DoubleCashExpiresAt") == expiry + 600,
    "repurchase extends current expiry with 500 seconds remaining"
)
expiry += 600
info.ProductId, info.PurchaseId = 3728323462, "third"
check(
    receipt(info) == "granted" and player:GetAttribute("DoubleCashExpiresAt") == expiry + 1800,
    "30-minute purchase extends same timer"
)
info.ProductId, info.PurchaseId = 999, "unknown"
check(receipt(info) == "retry", "unknown product deferred")
local grant = data.GrantDoubleCash
data.GrantDoubleCash = function()
    error("temporary failure")
end
info.ProductId, info.PurchaseId = 3728323243, "retryable"
check(receipt(info) == "retry", "failed grant deferred")
data.GrantDoubleCash = grant
expiry = player:GetAttribute("DoubleCashExpiresAt")
check(
    receipt(info) == "granted" and player:GetAttribute("DoubleCashExpiresAt") == expiry + 600,
    "failed receipt can retry successfully exactly once"
)
check(
    receipt(info) == "granted" and player:GetAttribute("DoubleCashExpiresAt") == expiry + 600,
    "successful retry is idempotent"
)
now = player:GetAttribute("DoubleCashExpiresAt")
check(
    not data.IsDoubleCashActive(player) and data.GetDoubleCashRemainingSeconds(player) == 0,
    "boost expires at exact boundary"
)
check(data.HasEntitlement(player, "DoubleCash"), "compatibility boolean does not determine activity")
info.ProductId, info.PurchaseId = 3728323462, "after-expiry"
check(
    receipt(info) == "granted" and data.GetDoubleCashRemainingSeconds(player) == 1800,
    "inactive 30-minute purchase starts from current server time"
)
services.Players.PlayerRemoving:Fire(player)
player.Parent = nil
data.RemovePlayer(player)
check(
    receipt(info) == "retry" and data.GetDoubleCashRemainingSeconds(player) == 0,
    "absent player deferred and departure clears timer"
)
player.Parent = services.Players
data.AddPlayer(player)
check(
    receipt(info) == "granted" and not data.IsDoubleCashActive(player),
    "same-server rejoin loses time but retains receipt idempotence"
)
info.PurchaseId = "new-session-purchase"
check(
    receipt(info) == "granted" and data.GetDoubleCashRemainingSeconds(player) == 1800,
    "new receipt after rejoin grants normally"
)
print("PASS: receipt, timed grant, stacking, expiry and prompt contracts")
