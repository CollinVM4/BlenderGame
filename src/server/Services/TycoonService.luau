--!strict
local Players = game:GetService("Players")

local TycoonService = {}

local playerCash: { [Player]: number } = {}

local function ensurePlayer(player: Player)
    if playerCash[player] == nil then
        playerCash[player] = 0
    end

    player:SetAttribute("playerCash", playerCash[player])
    player:SetAttribute("HasSmoothie", false)
end

function TycoonService.Init()
    for _, player in Players:GetPlayers() do
        ensurePlayer(player)
    end

    Players.PlayerAdded:Connect(function(player)
        ensurePlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerCash[player] = nil
    end)
end

function TycoonService.GetCash(player: Player): number
    ensurePlayer(player)
    return playerCash[player]
end

function TycoonService.AddCash(player: Player, amount: number): number
    ensurePlayer(player)
    playerCash[player] += amount
    player:SetAttribute("playerCash", playerCash[player])
    return playerCash[player]
end

function TycoonService.SetCash(player: Player, amount: number): number
    ensurePlayer(player)
    playerCash[player] = amount
    player:SetAttribute("playerCash", playerCash[player])
    return playerCash[player]
end

return TycoonService
