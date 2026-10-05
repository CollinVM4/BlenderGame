--!strict
-- Narrow request adapter for future inventory UI. No client-supplied state, positions, or awards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameplayService = {}
local MovementService = require(script.Parent.MovementService)
local plotInteractions = setmetatable({} :: { [ProximityPrompt]: (Player, any) -> () }, { __mode = "k" })
function GameplayService.RegisterPlotInteraction(prompt: ProximityPrompt, callback: (Player, any) -> ())
    plotInteractions[prompt] = callback
    prompt:SetAttribute("SessionInteraction", true)
end
local nextRequest: { [Player]: number } = {}
-- All world/team operations enter here; submitted contexts are never repaired.
function GameplayService.HandlePlotRequest(
    services: any,
    player: Player,
    action: string,
    plot: any,
    value: any,
    context: any
): boolean
    -- Claims/joins originate exclusively from server-authored zone detection now.
    if action == "ClaimPlot" or action == "JoinTeam" then
        return false
    end
    if not MovementService.CanPerformGameplayAction(player) then
        return false
    end
    if typeof(plot) ~= "Instance" or not plot:IsDescendantOf(workspace) then
        return false
    end
    local origin = plot:FindFirstChild("PlotIdentityOrigin", true)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local position = if origin and origin:IsA("Attachment")
        then origin.WorldPosition
        elseif origin and origin:IsA("BasePart") then origin.Position
        else nil
    if not position or not root or not root:IsA("BasePart") or (root.Position - position).Magnitude > 32 then
        return false
    end
    local authority = services.TycoonService
    if authority.GetPlot(player) ~= plot or not authority.ValidateActor(player, context) then
        return false
    end
    if action == "LeaveTeam" then
        return authority.LeaveTeam(player, context)
    elseif action == "SetJoinMode" then
        return authority.SetJoinMode(player, value, context)
    elseif action == "KickTeammate" then
        for _, member in authority.GetMembers(context.PlotSessionId) do
            if member.UserId == value then
                return authority.Kick(player, member, context)
            end
        end
    end
    return false
end
function GameplayService.Init(services: any)
    local remote = Instance.new("RemoteEvent")
    remote.Name = "GameplayRequest"
    remote.Parent = ReplicatedStorage.Shared.Events
    remote.OnServerEvent:Connect(function(player, action, id, slot, context)
        -- Observe receipt before *any* adapter gate. Do not consume the one-shot
        -- CombatService flag here; it must survive through rejection or dispatch.
        local tracing = RunService:IsStudio() and action == "SwingBat"
        local function trace(message: string)
            if tracing then
                print("[BatServer] " .. message)
            end
        end
        if tracing then
            trace(
                "GameplayRequest received: SwingBat from "
                    .. player.Name
                    .. " debugArmed="
                    .. tostring(player:GetAttribute("BatDebugNextSwing"))
            )
        end
        local now = os.clock()
        if now < (nextRequest[player] or 0) then
            trace(
                string.format(
                    "request adapter rejected: gameplay throttle (%.3fs remaining)",
                    (nextRequest[player] or 0) - now
                )
            )
            if action == "SwingBat" then
                services.CombatService.TraceRejectedSwing(player, "GameplayRequest throttle")
            end
            return
        end
        nextRequest[player] = now + 0.15
        if type(action) ~= "string" or #action > 32 then
            return
        end
        if
            action == "ClaimPlot"
            or action == "JoinTeam"
            or action == "LeaveTeam"
            or action == "SetJoinMode"
            or action == "KickTeammate"
        then
            local success = GameplayService.HandlePlotRequest(services, player, action, id, slot, context)
            remote:FireClient(player, "PlotRequestResult", { success = success, action = action })
            return
        end
        if not MovementService.CanPerformGameplayAction(player) then
            trace("request adapter rejected: MovementService.IsStunned(attacker)")
            if action == "SwingBat" then
                services.CombatService.TraceRejectedSwing(player, "GameplayRequest attacker stunned")
            end
            return
        end
        if action == "SwingBat" then
            trace("request adapter accepted: SwingBat (no plot/context gate in adapter)")
            trace("calling CombatService SwingBat")
            local accepted = services.CombatService.SwingBat(player)
            trace("CombatService SwingBat returned: " .. tostring(accepted))
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
            -- Use the issued Tool identity, without coupling inventory back to combat.
            if services.CombatService.IsBatEquipped(player) then
                return
            end
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
    if RunService:IsStudio() then
        remote:SetAttribute("BatRequestTraceVersion", "input-v1")
        local named = 0
        for _, event in ReplicatedStorage.Shared.Events:GetChildren() do
            if event.Name == "GameplayRequest" then
                named += 1
            end
        end
        print(
            "[BatServer] GameplayRequest adapter ready trace=input-v1 remote="
                .. remote:GetFullName()
                .. " namedRemotes="
                .. tostring(named)
        )
    end
end
function GameplayService.RemovePlayer(player: Player)
    nextRequest[player] = nil
end
return require(script.Parent.StudioServices).Wrap("GameplayService", GameplayService)
