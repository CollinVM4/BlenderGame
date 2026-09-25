--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Constants.Upgrades)
local PlayerDataService = {}
local records: { [Player]: Types.PersonalPlayerData } = {}
local runtime: any
function PlayerDataService.BindRuntimeAuthority(authority: any)
    runtime = authority
end
local entitlements: { [Player]: { [string]: boolean } } = {}

local function data(player: Player): Types.PersonalPlayerData
    assert(records[player], "PlayerDataService: player is not initialized")
    return records[player]
end
function PlayerDataService.AddPlayer(player: Player)
    records[player] = {
        Upgrades = {
            CarryCapacity = 1,
            StackSize = 1,
        },
        Discoveries = {},
        Stats = { CustomersServed = 0, SmoothiesMade = 0, PlayersSlapped = 0, IngredientsStolen = 0 },
    }
    entitlements[player] = { VIPStorage = false, DoubleCash = false }
    player:SetAttribute("playerCash", 0)
    player:SetAttribute("HasSmoothie", false)
    player:SetAttribute("CarryCapacity", Upgrades.CarryCapacity[1].Value)
    player:SetAttribute("CarryCapacityLevel", 0)
    for _, id in { "MovementSpeed", "Jump", "SprintStamina" } do
        player:SetAttribute(id .. "Level", 0)
    end
end
function PlayerDataService.GetSnapshot(player: Player): Types.PlayerData
    local source = data(player)
    return {
        Cash = PlayerDataService.GetCash(player),
        Upgrades = {
            Hand = PlayerDataService.GetUpgrade(player, "Hand"),
            CarryCapacity = PlayerDataService.GetUpgrade(player, "CarryCapacity"),
            StackSize = PlayerDataService.GetUpgrade(player, "StackSize"),
            BlendSpeed = PlayerDataService.GetUpgrade(player, "BlendSpeed"),
            Payout = PlayerDataService.GetUpgrade(player, "Payout"),
            MovementSpeed = PlayerDataService.GetUpgrade(player, "MovementSpeed"),
            Jump = PlayerDataService.GetUpgrade(player, "Jump"),
            SprintStamina = PlayerDataService.GetUpgrade(player, "SprintStamina"),
        },
        Discoveries = table.clone(source.Discoveries),
        Stats = table.clone(source.Stats),
    }
end
-- Compatibility projection only: no personal cash or shared-upgrade copies are stored.
function PlayerDataService.GetCash(player: Player): number
    return if runtime then runtime.GetCash(player) else 0
end
function PlayerDataService.SetCash(player: Player, amount: number): number
    assert(runtime, "Session authority is not bound")
    return runtime.SetCash(player, amount)
end
function PlayerDataService.AddCash(player: Player, amount: number): number
    assert(runtime, "Session authority is not bound")
    return runtime.AddCash(player, amount)
end
function PlayerDataService.GetUpgrade(player: Player, id: string): number
    if id ~= "CarryCapacity" and id ~= "StackSize" then
        return if runtime then runtime.GetUpgrade(player, id) else 1
    end
    return (data(player).Upgrades :: any)[id] or 1
end
function PlayerDataService.PurchaseUpgrade(
    player: Player,
    id: string,
    requestedLevel: number?,
    context: any
): (boolean, string?)
    if not runtime then
        return false, "NoSession"
    end
    if runtime.IsSharedUpgrade(id) then
        return runtime.PurchaseUpgrade(player, id, requestedLevel, context)
    end
    if id ~= "CarryCapacity" and id ~= "StackSize" then
        return false, "InvalidUpgrade"
    end
    local levels = (Upgrades :: any)[id]
    local nextLevel = PlayerDataService.GetUpgrade(player, id) + 1
    if requestedLevel ~= nextLevel then
        return false, "InvalidLevel"
    end
    local definition = levels[nextLevel]
    if not definition then
        return false, "MaxLevel"
    end
    return runtime.PurchasePersonalUpgrade(player, context, definition.Cost, function()
        (data(player).Upgrades :: any)[id] = nextLevel
        if id == "CarryCapacity" then
            player:SetAttribute("CarryCapacity", definition.Value)
            player:SetAttribute("CarryCapacityLevel", nextLevel - 1)
        end
    end)
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
return require(script.Parent.StudioServices).Wrap("PlayerDataService", PlayerDataService)
