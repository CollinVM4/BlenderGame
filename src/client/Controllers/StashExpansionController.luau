--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Constants = game:GetService("ReplicatedStorage").Shared.Constants
local Upgrades = require(Constants.Upgrades)
local TextStyle = require(Constants.DialogueTextStyle)
local Style = require(script.Parent.Parent.UI.WorldBillboardStyle)
local Controller = {}
function Controller.Init()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local pads: { [BasePart]: BillboardGui } = {}
    local function bind(object: Instance)
        if
            not object:IsA("BasePart")
            or object.Name ~= "PurchasePoint"
            or not object.Parent
            or object.Parent.Name ~= "UpgradeStash"
            or pads[object]
        then
            return
        end
        local gui = Instance.new("BillboardGui")
        gui.Name, gui.Adornee = "SecondStorageDisplay", object
        Style.ApplyBillboard(gui, { Width = 340, Height = 64, MaxDistance = 40 })
        gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
        local price =
            tostring(Upgrades.SecondStorage[2].Cost):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        for index, text in { "SECOND STORAGE", "$" .. price } do
            local label = Instance.new("TextLabel")
            Style.ApplyText(label, {})
            TextStyle.Apply(label, 24)
            label.Size, label.Position = UDim2.new(1, 0, 0, 32), UDim2.fromOffset(0, (index - 1) * 32)
            label.Text, label.TextColor3 = text, if index == 1 then TextStyle.White else TextStyle.Gold
            label.Parent = gui
        end
        gui.Enabled = false
        gui.Parent = playerGui
        pads[object] = gui
    end
    workspace.DescendantAdded:Connect(bind)
    for _, object in workspace:GetDescendants() do
        bind(object)
    end
    RunService.Heartbeat:Connect(function()
        for pad, gui in pads do
            if not pad:IsDescendantOf(workspace) then
                gui:Destroy()
                pads[pad] = nil
            else
                gui.Enabled = pad:GetAttribute("SecondStoragePad") == true and pad.CanTouch and pad.Transparency < 1
            end
        end
    end)
end
return Controller
