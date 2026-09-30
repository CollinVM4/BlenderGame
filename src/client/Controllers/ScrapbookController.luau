--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Presentation = require(script.Parent.Parent.UI.ScrapbookPresentation)
local Controller = {}
local started = false

-- Snapshot and live events share the same monotonic merge path.
function Controller.MergeDelta(state: Types.DiscoveryState, event: Types.DiscoveryEvent): boolean
    local entries = if event.Kind == "Ingredient" then state.Ingredients else state.SpecialCustomers
    if entries[event.Id] then
        return false
    end
    entries[event.Id] = true
    return true
end

function Controller.MergeSnapshot(state: Types.DiscoveryState, snapshot: Types.DiscoveryState)
    for id, discovered in snapshot.Ingredients do
        if discovered then
            Controller.MergeDelta(state, { Kind = "Ingredient", Id = id })
        end
    end
    for id, discovered in snapshot.SpecialCustomers do
        if discovered then
            Controller.MergeDelta(state, { Kind = "SpecialCustomer", Id = id })
        end
    end
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local state: Types.DiscoveryState = { Ingredients = {}, SpecialCustomers = {} }
    local view: Presentation.View? = nil
    local isOpen = false
    local tab: Presentation.Tab = "Ingredients"
    local function refreshWindow()
        if view then
            view.SetWindow(isOpen, tab)
        end
    end
    task.spawn(function()
        local events = Shared:WaitForChild("Events", 10)
        if not events then
            warn("[Scrapbook] ReplicatedStorage.Shared.Events missing")
            return
        end
        local added = events:WaitForChild("DiscoveryAdded", 10)
        if not added or not added:IsA("RemoteEvent") then
            warn("[Scrapbook] ReplicatedStorage.Shared.Events.DiscoveryAdded missing or not a RemoteEvent")
            return
        end
        added.OnClientEvent:Connect(function(event: Types.DiscoveryEvent)
            if Controller.MergeDelta(state, event) and view then
                view.UpdateDiscovery(event)
            end
        end)
        local snapshot = events:WaitForChild("DiscoverySnapshot", 10)
        if not snapshot or not snapshot:IsA("RemoteFunction") then
            warn("[Scrapbook] ReplicatedStorage.Shared.Events.DiscoverySnapshot missing or not a RemoteFunction")
            return
        end
        local ok, result = pcall(function()
            return snapshot:InvokeServer()
        end)
        if ok then
            Controller.MergeSnapshot(state, result)
            if view then
                view.RenderState(state)
            end
        else
            warn("[Scrapbook] DiscoverySnapshot failed: " .. tostring(result))
        end
    end)
    task.spawn(function()
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
        local gui = if playerGui then playerGui:WaitForChild("ScrapbookGui", 10) else nil
        if not gui or not gui:IsA("ScreenGui") then
            warn("[Scrapbook] PlayerGui.ScrapbookGui missing or not a ScreenGui; create it in StarterGui")
            return
        end
        local ok, result = pcall(function()
            return Presentation.Create(gui, state, {
                Open = function()
                    isOpen = true
                    refreshWindow()
                end,
                Close = function()
                    isOpen = false
                    refreshWindow()
                end,
                SelectTab = function(selected: Presentation.Tab)
                    tab = selected
                    refreshWindow()
                end,
            })
        end)
        if not ok then
            warn("[Scrapbook] " .. tostring(result))
            return
        end
        view = result
        refreshWindow()
    end)
end

return Controller
