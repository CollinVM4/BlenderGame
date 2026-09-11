--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    task.spawn(function()
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
        local remote = events:WaitForChild("RareIngredientSpawned")
        assert(remote:IsA("RemoteEvent"), "RareIngredientSpawned must be a RemoteEvent")
        local gui = Instance.new("ScreenGui")
        gui.Name = "RareIngredientAnnouncement"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 20
        gui.Parent = playerGui
        local banner = Instance.new("TextLabel")
        banner.AnchorPoint = Vector2.new(0.5, 0)
        banner.Position = UDim2.fromScale(0.5, 0.12)
        banner.Size = UDim2.new(0.8, 0, 0, 64)
        banner.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
        banner.BackgroundTransparency = 0.15
        banner.TextColor3 = Color3.fromRGB(255, 228, 125)
        banner.Font = Enum.Font.GothamBold
        banner.TextSize = 22
        banner.TextWrapped = true
        banner.Visible = false
        banner.Parent = gui
        local version = 0
        remote.OnClientEvent:Connect(function(payload: any)
            if
                typeof(payload) ~= "table"
                or payload.Type ~= "RareIngredientSpawned"
                or typeof(payload.DisplayName) ~= "string"
                or typeof(payload.LocationName) ~= "string"
            then
                return
            end
            version += 1
            local shown = version
            banner.Text = payload.DisplayName .. " appeared at " .. payload.LocationName .. "!"
            banner.Visible = true
            task.delay(8, function()
                if shown == version then
                    banner.Visible = false
                end
            end)
        end)
    end)
end

return Controller
