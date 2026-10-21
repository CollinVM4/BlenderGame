--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gui = require(script.Parent.Parent.UI.SettingsGui)
local Music = require(script.Parent.MusicController)
local PanelManager = require(script.Parent.Parent.UI.PanelManager)
local StandIdentity = require(script.Parent.StandIdentityController)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    Music.Init()
    task.spawn(function()
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
        local view: Gui.View? = nil
        local remote: RemoteEvent? = nil
        local failure = false
        local feedbackVersion = 0
        local statusTitles: { [TextLabel]: string } = setmetatable({}, { __mode = "k" }) :: any
        local function sessionPlot(): Instance?
            local candidates = CollectionService:GetTagged("PlayerPlot")
            local folder = Workspace:FindFirstChild("Plots")
            if folder then
                for _, plot in folder:GetChildren() do
                    if not table.find(candidates, plot) then
                        table.insert(candidates, plot)
                    end
                end
            end
            local found: Instance? = nil
            local sessionId = player:GetAttribute("PlotSessionId")
            for _, plot in candidates do
                if plot:IsDescendantOf(Workspace) and sessionId and plot:GetAttribute("PlotSessionId") == sessionId then
                    if found then
                        return nil -- Ambiguous replicated session fails closed.
                    end
                    found = plot
                end
            end
            if found then
                return found
            end
            for _, plot in candidates do
                if
                    plot:IsDescendantOf(Workspace)
                    and (
                        plot:GetAttribute("OwnerUserId") == player.UserId
                        or plot:GetAttribute("TeammateUserId") == player.UserId
                    )
                then
                    if found then
                        return nil -- Ambiguous replicated membership fails closed.
                    end
                    found = plot
                end
            end
            return found
        end
        local function refresh()
            local current = view
            if not current or not current.Panel.Visible then
                return
            end
            local plot = sessionPlot()
            local owner = plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
            local teammate = if plot then plot:GetAttribute("TeammateUserId") else nil
            if current.Rename then
                current.Rename.Visible, current.Rename.Active = owner, owner
            end
            local hasTeammate = owner and type(teammate) == "number"
            if current.Kick then
                current.Kick.Visible, current.Kick.Active = hasTeammate, hasTeammate
            end
            local mode = if plot then plot:GetAttribute("JoinMode") else nil
            for value, button in current.Modes do
                button.Active = owner
                Gui.Select(button, value == mode)
            end
            if current.MusicOn then
                Gui.Select(current.MusicOn, Music.IsEnabled())
            end
            if current.MusicOff then
                Gui.Select(current.MusicOff, not Music.IsEnabled())
            end
            Gui.RefreshVolume(current, Music.GetVolume())
            if current.Status then
                if statusTitles[current.Status] == nil then
                    statusTitles[current.Status] = current.Status.Text
                end
                current.Status.Text = if failure
                    then "Plot action unavailable. Try again."
                    else statusTitles[current.Status]
            end
        end
        Gui.Observe(playerGui, function(nextView)
            view = nextView
            refresh()
        end, function(mode)
            if mode ~= "Open" and mode ~= "FriendsOnly" and mode ~= "Closed" then
                return
            end
            local plot = sessionPlot()
            if not plot or not remote or plot:GetAttribute("OwnerUserId") ~= player.UserId then
                return
            end
            local captured = {
                PlotSessionId = plot:GetAttribute("PlotSessionId"),
                MembershipRevision = plot:GetAttribute("PlotMembershipRevision"),
                ClaimRevision = plot:GetAttribute("PlotClaimRevision") or 0,
            }
            remote:FireServer("SetJoinMode", plot, mode, captured)
        end, function(enabled)
            Music.SetEnabled(enabled)
            refresh()
        end, function(volume)
            Music.SetVolume(volume)
            refresh()
            return Music.GetVolume()
        end, function()
            local plot = sessionPlot()
            if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
                return
            end
            PanelManager.CloseAll()
            StandIdentity.OpenNameEditor(plot)
        end, function()
            local plot = sessionPlot()
            if not plot or not remote or plot:GetAttribute("OwnerUserId") ~= player.UserId then
                return
            end
            local teammate = plot:GetAttribute("TeammateUserId")
            if type(teammate) ~= "number" then
                return
            end
            local captured = {
                PlotSessionId = plot:GetAttribute("PlotSessionId"),
                MembershipRevision = plot:GetAttribute("PlotMembershipRevision"),
                ClaimRevision = plot:GetAttribute("PlotClaimRevision") or 0,
            }
            remote:FireServer("KickTeammate", plot, teammate, captured)
        end)
        player:GetAttributeChangedSignal("PlotSessionId"):Connect(refresh)
        player:GetAttributeChangedSignal("MusicEnabled"):Connect(refresh)
        player:GetAttributeChangedSignal("MusicVolume"):Connect(refresh)
        local plotConnections: { RBXScriptConnection } = {}
        local queued = false
        local function observePlots()
            queued = false
            for _, connection in plotConnections do
                connection:Disconnect()
            end
            table.clear(plotConnections)
            -- Watch ownership even on unowned candidates: a claim may arrive
            -- after Settings has already opened.
            local candidates = CollectionService:GetTagged("PlayerPlot")
            local folder = Workspace:FindFirstChild("Plots")
            if folder then
                for _, plot in folder:GetChildren() do
                    if not table.find(candidates, plot) then
                        table.insert(candidates, plot)
                    end
                end
            end
            for _, plot in candidates do
                for _, attribute in
                    {
                        "OwnerUserId",
                        "TeammateUserId",
                        "PlotSessionId",
                        "JoinMode",
                        "PlotMembershipRevision",
                        "PlotClaimRevision",
                    }
                do
                    table.insert(plotConnections, plot:GetAttributeChangedSignal(attribute):Connect(refresh))
                end
            end
            refresh()
        end
        local function schedule()
            if not queued then
                queued = true
                task.defer(observePlots)
            end
        end
        CollectionService:GetInstanceAddedSignal("PlayerPlot"):Connect(schedule)
        CollectionService:GetInstanceRemovedSignal("PlayerPlot"):Connect(schedule)
        Workspace.DescendantAdded:Connect(function(instance)
            if
                instance.Name == "Plots"
                or (instance.Parent and instance.Parent.Name == "Plots")
                or CollectionService:HasTag(instance, "PlayerPlot")
            then
                schedule()
            end
        end)
        Workspace.DescendantRemoving:Connect(function(instance)
            if
                instance.Name == "Plots"
                or (instance.Parent and instance.Parent.Name == "Plots")
                or CollectionService:HasTag(instance, "PlayerPlot")
            then
                schedule()
            end
        end)
        observePlots()
        task.spawn(function()
            local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
            local request = events:WaitForChild("GameplayRequest") :: RemoteEvent
            remote = request
            request.OnClientEvent:Connect(function(action, result)
                if action ~= "PlotRequestResult" or type(result) ~= "table" or result.success ~= false then
                    return
                end
                feedbackVersion += 1
                local version = feedbackVersion
                failure = true
                refresh()
                task.delay(4, function()
                    if version == feedbackVersion then
                        failure = false
                        refresh()
                    end
                end)
            end)
        end)
    end)
end

return Controller
