--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Constants.Upgrades)
local PlayerDataService = {}
local records: { [Player]: Types.PlayerData } = {}
local entitlements: { [Player]: { [string]: boolean } } = {}

local function data(player: Player): Types.PlayerData
    assert(records[player], "PlayerDataService: player is not initialized")
    return records[player]
end
function PlayerDataService.AddPlayer(player: Player)
    records[player] = {
        Cash = 0,
        Upgrades = { Hand = 1, StackSize = 1, BlendSpeed = 1, Payout = 1 },
        Discoveries = {},
        Stats = { CustomersServed = 0, SmoothiesMade = 0, PlayersSlapped = 0, IngredientsStolen = 0 },
    }
    entitlements[player] = { VIPStorage = false, DoubleCash = false }
    player:SetAttribute("playerCash", 0)
    player:SetAttribute("HasSmoothie", false)
end
function PlayerDataService.GetSnapshot(player: Player): Types.PlayerData
    local source = data(player)
    return {
        Cash = source.Cash,
        Upgrades = table.clone(source.Upgrades),
        Discoveries = table.clone(source.Discoveries),
        Stats = table.clone(source.Stats),
    }
end
function PlayerDataService.GetCash(player: Player): number
    return data(player).Cash
end
function PlayerDataService.SetCash(player: Player, amount: number): number
    assert(amount == amount and math.abs(amount) < math.huge and amount >= 0, "Invalid cash")
    data(player).Cash = math.floor(amount)
    player:SetAttribute("playerCash", data(player).Cash)
    return data(player).Cash
end
function PlayerDataService.AddCash(player: Player, amount: number): number
    assert(amount >= 0, "Awards cannot subtract cash")
    return PlayerDataService.SetCash(player, data(player).Cash + amount)
end
function PlayerDataService.GetUpgrade(player: Player, id: string): number
    return (data(player).Upgrades :: any)[id] or 1
end
function PlayerDataService.PurchaseUpgrade(player: Player, id: string): (boolean, string?)
    local levels = (Upgrades :: any)[id]
    if not levels then
        return false, "Unknown upgrade"
    end
    local nextLevel = PlayerDataService.GetUpgrade(player, id) + 1
    local definition = levels[nextLevel]
    if not definition or data(player).Cash < definition.Cost then
        return false, "Max level or insufficient cash"
    end
    PlayerDataService.SetCash(player, data(player).Cash - definition.Cost)
    local ownedUpgrades = data(player).Upgrades :: any
    ownedUpgrades[id] = nextLevel
    return true
end
function PlayerDataService.HasEntitlement(player: Player, id: string): boolean
    return entitlements[player] ~= nil and entitlements[player][id] == true
end
-- Server-only boundary for a future verified MarketplaceService entitlement adapter.
function PlayerDataService.SetEntitlement(player: Player, id: string, enabled: boolean)
    assert(id == "VIPStorage" or id == "DoubleCash", "Unknown entitlement")
    entitlements[player][id] = enabled
end
function PlayerDataService.RecordDiscovery(player: Player, id: string)
    data(player).Discoveries[id] = true
end
function PlayerDataService.IncrementStat(player: Player, id: string)
    local stats = data(player).Stats :: any
    assert(stats[id] ~= nil, "Unknown stat")
    stats[id] += 1
end
function PlayerDataService.RemovePlayer(player: Player)
    -- TODO: persist a snapshot before releasing state; no DataStore writes in this skeleton.
    records[player] = nil
    entitlements[player] = nil
end
return PlayerDataService
