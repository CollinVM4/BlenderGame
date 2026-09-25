--!strict
-- Narrow request adapter for future inventory UI. No client-supplied state, positions, or awards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameplayService = {}
local plotInteractions = setmetatable({} :: { [ProximityPrompt]: (Player, any) -> () }, { __mode = "k" })
function GameplayService.RegisterPlotInteraction(prompt: ProximityPrompt, callback: (Player, any) -> ())
    plotInteractions[prompt] = callback
    prompt:SetAttribute("SessionInteraction", true)
end
local nextRequest: { [Player]: number } = {}
function GameplayService.Init(services: any)
    local remote = Instance.new("RemoteEvent")
    remote.Name = "GameplayRequest"
    remote.Parent = ReplicatedStorage.Shared.Events
    remote.OnServerEvent:Connect(function(player, action, id, slot, context)
        local now = os.clock()
        if now < (nextRequest[player] or 0) then
            return
        end
        nextRequest[player] = now + 0.15
        if type(action) ~= "string" or #action > 32 then
            return
        end
        if action == "PlotInteraction" then
            if
                typeof(id) == "Instance"
                and id:IsA("ProximityPrompt")
                and id.Enabled
                and id:IsDescendantOf(workspace)
                and services.TycoonService.ValidateActor(player, context)
            then
                local callback = plotInteractions[id]
                if callback then
                    callback(player, context)
                end
            end
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
        elseif action == "ThrowHeld" then
            services.InventoryService.ThrowHeld(player, id)
        elseif action == "ReleaseIngredient" and validId then
            services.InventoryService.ReleaseUnit(player, id)
        elseif action == "Deposit" and validId and validSlot then
            services.InventoryService.Deposit(player, id, slot)
        elseif action == "Withdraw" and validSlot then
            services.InventoryService.Withdraw(player, slot)
        elseif action == "PurchaseUpgrade" then
            local success, reason = false, "InvalidUpgrade"
            if validId then
                success, reason = services.PlayerDataService.PurchaseUpgrade(player, id, slot, context)
            end
            remote:FireClient(player, "PurchaseUpgradeResult", {
                PlotSessionId = if type(context) == "table" then context.PlotSessionId else nil,
                MembershipRevision = if type(context) == "table" then context.MembershipRevision else nil,
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
