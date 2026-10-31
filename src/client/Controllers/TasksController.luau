--!strict
local Players = game:GetService("Players")
local Gui = require(script.Parent.Parent.UI.TasksGui)
local MoneyFormat = require(game:GetService("ReplicatedStorage").Shared.MoneyFormat)
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
        local function refresh()
            local view = Gui.Resolve(playerGui)
            if not view then
                return
            end
            local function number(name: string): number
                local value = player:GetAttribute(name)
                return if typeof(value) == "number" then value else 0
            end
            local tutorial = player:GetAttribute("TasksTutorialComplete") ~= true
            local threshold = number("TasksServeThreshold")
            view.Serve.Objective.Text = if tutorial
                then "Finish the tutorial"
                else "Serve " .. threshold .. " customers"
            view.Serve.Progress.Visible = not tutorial
            view.Serve.Progress.Text = if tutorial then "" else number("TasksServeTotal") .. "/" .. threshold
            view.Serve.Reward.Text = "Reward: "
                .. MoneyFormat.Full(number(if tutorial then "TasksTutorialReward" else "TasksServeReward"))
            view.Steal.Objective.Text = "Steal " .. number("TasksStealTarget")
            view.Steal.Progress.Text = number("TasksStealProgress") .. "/" .. number("TasksStealTarget")
            view.Steal.Reward.Text = "Reward: " .. MoneyFormat.Full(number("TasksStealReward")) .. " (estimate)"
        end
        for _, name in
            {
                "TasksTutorialComplete",
                "TasksTutorialReward",
                "TasksServeThreshold",
                "TasksServeTotal",
                "TasksServeReward",
                "TasksStealTarget",
                "TasksStealProgress",
                "TasksStealReward",
            }
        do
            player:GetAttributeChangedSignal(name):Connect(refresh)
        end
        playerGui.DescendantAdded:Connect(refresh)
        playerGui.DescendantRemoving:Connect(function()
            task.defer(refresh)
        end)
        refresh()
    end)
end
return Controller
