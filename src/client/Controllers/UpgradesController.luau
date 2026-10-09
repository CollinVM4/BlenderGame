--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Display = require(script.Parent.Parent.UI.UpgradeDisplay)
local Gui = require(script.Parent.Parent.UI.UpgradesGui)
local MoneyFormat = require(ReplicatedStorage.Shared.MoneyFormat)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    task.spawn(function()
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
        local view: Gui.View? = nil
        local remote: RemoteEvent? = nil
        local pending: string? = nil
        local generation = 0
        local membershipGeneration = 0
        local membershipUpdating = false
        local feedback: { [string]: string } = {}
        local feedbackVersion: { [string]: number } = {}
        local serverMax: { [string]: boolean } = {}

        local function numberAttribute(name: string): number?
            local value = player:GetAttribute(name)
            return if typeof(value) == "number" then value else nil
        end
        local function rowState(track: { Id: string, Name: string, Attribute: string })
            return if membershipUpdating
                then nil
                else Display.Row(
                    track.Id,
                    numberAttribute(track.Id .. (if track.Id == "CarryCapacity" then "Level" else "PurchasedLevel")),
                    numberAttribute(track.Attribute)
                )
        end
        local function refresh()
            local currentView = view
            if not currentView then
                return
            end
            local cash = numberAttribute("playerCash")
            if currentView.Cash then
                currentView.Cash.Text = if cash then MoneyFormat.Full(cash) else "$\u{2014}"
            end
            for _, track in Display.Tracks do
                local row = currentView.Rows[track.Id]
                if not row then
                    continue
                end
                local state = rowState(track)
                local isMax = serverMax[track.Id] or (state ~= nil and state.Max)
                local enabled = remote ~= nil
                    and pending == nil
                    and state ~= nil
                    and not isMax
                    and feedback[track.Id] ~= "PURCHASED!"
                local affordable = cash ~= nil and state ~= nil and state.Price ~= nil and cash >= state.Price
                -- Keep authored colors, backgrounds, typography and FX. Dim only
                -- price/BUY text, retaining server rejection feedback on activation.
                row.Price.TextTransparency = if state
                        and not isMax
                        and not affordable
                    then math.max(row.PriceTransparency, 0.4)
                    else row.PriceTransparency
                row.BuyLabel.TextTransparency = if enabled and not affordable
                    then math.max(row.BuyTransparency, 0.4)
                    else row.BuyTransparency
                row.Title.Text = track.Name
                row.Current.Text = if state then state.Current else "LOADING..."
                row.Next.Text = if isMax then "MAX" elseif state then state.Next else "-"
                row.Price.Text = if state and state.Price and not isMax then MoneyFormat.Compact(state.Price) else ""
                row.BuyLabel.Text = if remote == nil
                        or state == nil
                        or pending == track.Id
                    then "..."
                    elseif feedback[track.Id] == "PURCHASED!" then "PURCHASED!"
                    elseif isMax then "MAX"
                    elseif feedback[track.Id] then feedback[track.Id]
                    else "BUY"
                row.Purchase.Interactable = enabled
            end
        end
        local function showFeedback(id: string, message: string)
            local version = (feedbackVersion[id] or 0) + 1
            feedbackVersion[id] = version
            feedback[id] = message
            local membershipToken = membershipGeneration
            task.delay(if message == "PURCHASED!" then 0.8 else 1.5, function()
                if membershipGeneration == membershipToken and feedbackVersion[id] == version then
                    feedback[id] = nil
                    refresh()
                end
            end)
        end
        player:GetAttributeChangedSignal("playerCash"):Connect(refresh)
        local function membershipChanged()
            generation += 1
            pending = nil
            membershipGeneration += 1
            local token = membershipGeneration
            membershipUpdating = true
            table.clear(serverMax)
            table.clear(feedback)
            refresh()
            -- Membership identity is published before the upgrade projection.
            task.defer(function()
                if membershipGeneration == token then
                    membershipUpdating = false
                    refresh()
                end
            end)
        end
        player:GetAttributeChangedSignal("PlotSessionId"):Connect(membershipChanged)
        player:GetAttributeChangedSignal("PlotMembershipRevision"):Connect(membershipChanged)
        for _, track in Display.Tracks do
            player
                :GetAttributeChangedSignal(
                    track.Id .. (if track.Id == "CarryCapacity" then "Level" else "PurchasedLevel")
                )
                :Connect(function()
                    serverMax[track.Id] = nil
                    refresh()
                end)
            if track.Attribute ~= track.Id .. (if track.Id == "CarryCapacity" then "Level" else "PurchasedLevel") then
                player:GetAttributeChangedSignal(track.Attribute):Connect(refresh)
            end
        end
        Gui.Observe(playerGui, function(nextView)
            view = nextView
            refresh()
        end, function(id)
            local track
            for _, candidate in Display.Tracks do
                if candidate.Id == id then
                    track = candidate
                    break
                end
            end
            if not track or not view then
                return
            end
            local state = rowState(track)
            local request = remote
            if
                not request
                or pending
                or not state
                or state.Max
                or serverMax[track.Id]
                or feedback[track.Id] == "PURCHASED!"
            then
                return
            end
            feedbackVersion[track.Id] = (feedbackVersion[track.Id] or 0) + 1
            feedback[track.Id] = nil
            pending = track.Id
            generation += 1
            local token = generation
            refresh()
            request:FireServer("PurchaseUpgrade", track.Id, state.Level + 2, {
                PlotSessionId = player:GetAttribute("PlotSessionId"),
                MembershipRevision = player:GetAttribute("PlotMembershipRevision"),
            })
            -- The shared server throttle can drop a request without a response.
            task.delay(5, function()
                if generation == token and pending == track.Id then
                    pending = nil
                    showFeedback(track.Id, "TRY AGAIN")
                    refresh()
                end
            end)
        end)
        refresh()
        local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
        local request = events:WaitForChild("GameplayRequest")
        assert(request:IsA("RemoteEvent"), "GameplayRequest must be a RemoteEvent")
        request.OnClientEvent:Connect(function(action: any, result: any)
            if action ~= "PurchaseUpgradeResult" or type(result) ~= "table" then
                return
            end
            if
                result.PlotSessionId ~= player:GetAttribute("PlotSessionId")
                or result.MembershipRevision ~= player:GetAttribute("PlotMembershipRevision")
            then
                return
            end
            if result.reason == "InvalidUpgrade" then
                warn("Upgrade purchase rejected: InvalidUpgrade")
            end
            local id = result.upgradeId
            if type(id) ~= "string" or not Display.Row(id, 0) or type(result.success) ~= "boolean" then
                return
            end
            if pending ~= id then
                return
            end
            pending = nil
            generation += 1
            if result.reason == "MaxLevel" then
                serverMax[id] = true
            end
            showFeedback(id, Display.Feedback(result.success, result.reason))
            -- Response levels never replace replicated player state.
            refresh()
        end)
        remote = request
        refresh()
    end)
end

return Controller
