--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextStyle = require(ReplicatedStorage.Shared.Constants.DialogueTextStyle)
local Config = require(ReplicatedStorage.Shared.Constants.JackedNoob)
local Controller = {}

function Controller.Init()
    local remote = ReplicatedStorage:WaitForChild("JackedNoobResponse") :: RemoteEvent
    local current: BillboardGui? = nil
    local version = 0
    remote.OnClientEvent:Connect(function(head: Instance, line: string)
        if not head:IsA("BasePart") or not head:IsDescendantOf(workspace) or type(line) ~= "string" then
            return
        end
        version += 1
        local thisVersion = version
        if current then
            current:Destroy()
        end
        local gui = Instance.new("BillboardGui")
        gui.Name = "JackedNoobResponse"
        gui.Adornee = head
        gui.Size = UDim2.fromOffset(320, 58)
        gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 1.7, 0)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 65
        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = line
        TextStyle.Apply(label, 23)
        label.TextWrapped = true
        label.TextTransparency = 1
        local outline = label:FindFirstChild("DialogueOutline") :: UIStroke
        outline.Transparency = 1
        label.Parent = gui
        gui.Parent = head
        current = gui
        TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
        TweenService:Create(outline, TweenInfo.new(0.15), { Transparency = 0 }):Play()
        task.delay(Config.DialogueSeconds - 0.3, function()
            if thisVersion ~= version or current ~= gui then
                return
            end
            TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(outline, TweenInfo.new(0.3), { Transparency = 1 }):Play()
            task.delay(0.3, function()
                if current == gui then
                    current = nil
                end
                gui:Destroy()
            end)
        end)
    end)
end

return Controller
