--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Types = require(Shared.Types)
local Presentation = require(script.Parent.Parent.UI.ScrapbookPresentation)
local Menus = require(script.Parent.Parent.UI.FramewispMenus)
local Notifications = require(script.Parent.Parent.UI.MenuNotifications)
local cleanup: (() -> ())? = nil
local Controller = {}
local started = false
local generation = 0

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

-- A single session owns replication; views can be replaced independently.
function Controller.Start(playerGui: PlayerGui, events: Instance, player: Player): () -> ()
    local state: Types.DiscoveryState = { Ingredients = {}, SpecialCustomers = {} }
    local view: Presentation.View? = nil
    local stopped = false
    local connections: { RBXScriptConnection } = {}
    local unseenCount = 0
    local stopOpened = Notifications.OnOpened("Index", function()
        unseenCount = 0
        Notifications.Set("Index", false)
    end)
    local stopView = Presentation.Observe(playerGui, state, function(nextView, root)
        view = nextView
        if root then
            Menus.Attach(root, player)
        end
    end)
    task.spawn(function()
        local added = events:WaitForChild("DiscoveryAdded", 10)
        if stopped then
            return
        end
        if not added or not added:IsA("RemoteEvent") then
            warn("[Scrapbook] DiscoveryAdded missing or not a RemoteEvent")
            return
        end
        table.insert(
            connections,
            added.OnClientEvent:Connect(function(event: Types.DiscoveryEvent)
                if stopped then
                    return
                end
                unseenCount += 1
                Notifications.Set("Index", unseenCount > 0)
                if not stopped and Controller.MergeDelta(state, event) and view then
                    view.UpdateDiscovery(event)
                end
            end)
        )
        local snapshot = events:WaitForChild("DiscoverySnapshot", 10)
        if stopped then
            return
        end
        if not snapshot or not snapshot:IsA("RemoteFunction") then
            warn("[Scrapbook] DiscoverySnapshot missing or not a RemoteFunction")
            return
        end
        local ok, result = pcall(function()
            return snapshot:InvokeServer()
        end)
        if stopped then
            return
        end
        if ok then
            Controller.MergeSnapshot(state, result)
            if view then
                view.RenderState(state)
            end
        else
            warn("[Scrapbook] DiscoverySnapshot failed: " .. tostring(result))
        end
    end)
    return function()
        if stopped then
            return
        end
        stopped = true
        stopOpened()
        Notifications.Set("Index", false)
        for _, connection in connections do
            connection:Disconnect()
        end
        stopView()
    end
end

function Controller.Init()
    if started then
        return
    end
    started = true
    generation += 1
    local currentGeneration = generation
    task.spawn(function()
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
        local events = Shared:WaitForChild("Events")
        if currentGeneration == generation then
            cleanup = Controller.Start(playerGui, events, player)
        end
    end)
end

function Controller.Destroy()
    generation += 1
    if cleanup then
        cleanup()
        cleanup = nil
    end
    started = false
end
return Controller
