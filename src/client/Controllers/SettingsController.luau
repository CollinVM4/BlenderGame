--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gui = require(script.Parent.Parent.UI.SettingsGui)
local Music = require(script.Parent.MusicController)
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
        local function ownPlot(): Instance?
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
            for _, plot in candidates do
                if plot:IsDescendantOf(Workspace) and plot:GetAttribute("OwnerUserId") == player.UserId then
                    if found then
                        return nil -- Ambiguous replicated ownership fails closed.
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
            local plot = ownPlot()
            local mode = if plot then plot:GetAttribute("JoinMode") else nil
            for value, button in current.Modes do
                Gui.Select(button, value == mode)
            end
            if current.MusicOn then
                Gui.Select(current.MusicOn, Music.IsEnabled())
            end
            if current.MusicOff then
                Gui.Select(current.MusicOff, not Music.IsEnabled())
            end
            if current.Thumb then
                local position = current.Thumb.Position
                current.Thumb.Position = UDim2.new(Music.GetVolume(), 0, position.Y.Scale, position.Y.Offset)
            end
            if current.Status then
                if statusTitles[current.Status] == nil then
                    statusTitles[current.Status] = current.Status.Text
                end
                current.Status.Text = if failure
                    then "Plot action unavailable. Move closer or try again."
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
            local plot = ownPlot()
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
        end)
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
                table.insert(plotConnections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh))
                table.insert(plotConnections, plot:GetAttributeChangedSignal("JoinMode"):Connect(refresh))
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
