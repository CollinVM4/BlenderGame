--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Display = require(script.Parent.Parent.UI.UpgradeDisplay)
local Gui = require(script.Parent.Parent.UI.UpgradesGui)
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
        local view = Gui.Create(playerGui)
        local remote: RemoteEvent? = nil
        local pending: string? = nil
        local generation = 0
        local feedback: { [string]: string } = {}
        local feedbackVersion: { [string]: number } = {}
        local serverMax: { [string]: boolean } = {}

        local function numberAttribute(name: string): number?
            local value = player:GetAttribute(name)
            return if typeof(value) == "number" then value else nil
        end
        local function rowState(track: { Id: string, Name: string, Attribute: string })
            return Display.Row(track.Id, numberAttribute(track.Id .. "Level"), numberAttribute(track.Attribute))
        end
        local function refresh()
            local cash = numberAttribute("playerCash")
            view.Cash.Text = if cash then "$ " .. tostring(cash) else "$ —"
            for _, track in Display.Tracks do
                local row = view.Rows[track.Id]
                local state = rowState(track)
                local isMax = serverMax[track.Id] or (state ~= nil and state.Max)
                local enabled = remote ~= nil and pending == nil and state ~= nil and not isMax
                row.Level.Text = if state then "Level " .. tostring(state.Level) else "Loading…"
                row.Stat.Text = if state then state.Stat else "—"
                row.Purchase.Text = if pending == track.Id
                    then "BUYING…"
                    elseif isMax then "MAX"
                    elseif feedback[track.Id] then feedback[track.Id]
                    elseif state and state.Price then "$" .. tostring(state.Price) .. " UPGRADE"
                    else "LOADING…"
                row.Purchase.Interactable = enabled
                row.Purchase.AutoButtonColor = enabled
                row.Purchase.BackgroundColor3 = if enabled
                    then Color3.fromRGB(57, 119, 83)
                    else Color3.fromRGB(66, 76, 90)
            end
        end
        local function showFeedback(id: string, message: string)
            local version = (feedbackVersion[id] or 0) + 1
            feedbackVersion[id] = version
            feedback[id] = message
            task.delay(2, function()
                if feedbackVersion[id] == version then
                    feedback[id] = nil
                    refresh()
                end
            end)
        end
        player:GetAttributeChangedSignal("playerCash"):Connect(refresh)
        for _, track in Display.Tracks do
            player:GetAttributeChangedSignal(track.Id .. "Level"):Connect(function()
                serverMax[track.Id] = nil
                refresh()
            end)
            if track.Attribute ~= track.Id .. "Level" then
                player:GetAttributeChangedSignal(track.Attribute):Connect(refresh)
            end
            view.Rows[track.Id].Purchase.Activated:Connect(function()
                local state = rowState(track)
                local request = remote
                if not request or pending or not state or state.Max or serverMax[track.Id] then
                    return
                end
                pending = track.Id
                generation += 1
                local token = generation
                refresh()
                request:FireServer("PurchaseUpgrade", track.Id)
                -- The shared server throttle can drop a request without a response.
                task.delay(5, function()
                    if generation == token and pending == track.Id then
                        pending = nil
                        showFeedback(track.Id, "PLEASE TRY AGAIN")
                        refresh()
                    end
                end)
            end)
        end
        refresh()
        local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
        local request = events:WaitForChild("GameplayRequest")
        assert(request:IsA("RemoteEvent"), "GameplayRequest must be a RemoteEvent")
        request.OnClientEvent:Connect(function(action: any, result: any)
            if action ~= "PurchaseUpgradeResult" or type(result) ~= "table" then
                return
            end
            if result.reason == "InvalidUpgrade" then
                warn("Upgrade purchase rejected: InvalidUpgrade")
            end
            local id = result.upgradeId
            if type(id) ~= "string" or not view.Rows[id] or type(result.success) ~= "boolean" then
                return
            end
            if pending == id then
                pending = nil
                generation += 1
            end
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
