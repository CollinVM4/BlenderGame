--!strict
-- Narrow request adapter for future inventory UI. No client-supplied state, positions, or awards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameplayService = {}
local nextRequest: { [Player]: number } = {}
function GameplayService.Init(services: any)
    local remote = Instance.new("RemoteEvent")
    remote.Name = "GameplayRequest"
    remote.Parent = ReplicatedStorage.Shared.Events
    remote.OnServerEvent:Connect(function(player, action, id, slot)
        local now = os.clock()
        if now < (nextRequest[player] or 0) then
            return
        end
        nextRequest[player] = now + 0.15
        if type(action) ~= "string" or #action > 32 then
            return
        end
        local validId = type(id) == "string" and #id <= 64
        local validSlot = type(slot) == "number"
            and slot == slot
            and slot >= 1
            and slot <= 10
            and slot == math.floor(slot)
        if action == "StartDay" then
            services.GameService.StartDay(player)
        elseif action == "ReleaseIngredient" and validId then
            services.InventoryService.ReleaseUnit(player, id)
        elseif action == "Deposit" and validId and validSlot then
            services.InventoryService.Deposit(player, id, slot)
        elseif action == "Withdraw" and validSlot then
            services.InventoryService.Withdraw(player, slot)
        elseif action == "PurchaseUpgrade" then
            local success, reason = false, "InvalidUpgrade"
            if validId then
                success, reason = services.PlayerDataService.PurchaseUpgrade(player, id)
            end
            if success and (id == "MovementSpeed" or id == "Jump" or id == "SprintStamina") then
                services.MovementService.RefreshPlayer(player)
            end
            remote:FireClient(player, "PurchaseUpgradeResult", {
                success = success,
                reason = if success then "Success" else reason,
                upgradeId = if validId then id else nil,
                level = if validId and reason ~= "InvalidUpgrade"
                    then services.PlayerDataService.GetUpgrade(player, id) - 1
                    else nil,
            })
        end
    end)
end
function GameplayService.RemovePlayer(player: Player)
    nextRequest[player] = nil
end
return require(script.Parent.StudioServices).Wrap("GameplayService", GameplayService)
