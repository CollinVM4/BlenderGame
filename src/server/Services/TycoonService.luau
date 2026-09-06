--!strict
local CollectionService = game:GetService("CollectionService")
local WorldUtil = require(script.Parent.WorldUtil)
local TycoonService = {}
local data: any
local plots: { [Player]: Instance } = {}

function TycoonService.Init(playerDataService)
    data = playerDataService
end
function TycoonService.GetPlot(player: Player): Instance?
    local plot = plots[player]
    if plot and plot:IsDescendantOf(workspace) then
        return plot
    end
    return nil
end
function TycoonService.GetOwner(object: Instance): Player?
    for player, plot in plots do
        if plot:IsDescendantOf(workspace) and (object == plot or object:IsDescendantOf(plot)) then
            return player
        end
    end
    return nil
end
function TycoonService.GetReference(player: Player, name: string): BasePart?
    local plot = TycoonService.GetPlot(player)
    if not plot then
        return nil
    end
    for _, object in CollectionService:GetTagged(name) do
        if object:IsDescendantOf(plot) then
            return WorldUtil.Part(object)
        end
    end
    return WorldUtil.Part(plot:FindFirstChild(name, true))
end
function TycoonService.AssignPlot(player: Player): Instance?
    if TycoonService.GetPlot(player) then
        return plots[player]
    end
    local candidates = CollectionService:GetTagged("PlayerPlot")
    local folder = workspace:FindFirstChild("Plots")
    if folder then
        for _, plot in folder:GetChildren() do
            if not table.find(candidates, plot) then
                table.insert(candidates, plot)
            end
        end
    end
    table.sort(candidates, function(a, b)
        return a.Name < b.Name
    end)
    for _, plot in candidates do
        if plot:IsDescendantOf(workspace) and not TycoonService.GetOwner(plot) then
            plots[player] = plot
            plot:SetAttribute("OwnerUserId", player.UserId)
            return plot
        end
    end
    warn("[TycoonService] No free PlayerPlot / workspace.Plots child for " .. player.Name)
    return nil
end
function TycoonService.RemovePlayer(player: Player)
    local plot = plots[player]
    if plot then
        plot:SetAttribute("OwnerUserId", nil)
    end
    plots[player] = nil
end
-- Compatibility with existing server callers; PlayerDataService now owns cash.
function TycoonService.GetCash(player: Player): number
    return data.GetCash(player)
end
function TycoonService.AddCash(player: Player, amount: number): number
    return data.AddCash(player, amount)
end
function TycoonService.SetCash(player: Player, amount: number): number
    return data.SetCash(player, amount)
end
return TycoonService
