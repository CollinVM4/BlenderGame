--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Gui = require(script.Parent.Parent.UI.UpgradesGui)
local Notifications = require(script.Parent.Parent.UI.MenuNotifications)
local State = require(script.Parent.TutorialAlertState)
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
        local state = State.new()
        type Pulse = { Scale: UIScale, Tween: Tween? }
        local arrows: { [GuiObject]: Pulse } = {}
        local view: Gui.View? = nil

        local function show(arrow: GuiObject?, visible: boolean)
            local pulse = if arrow then arrows[arrow] else nil
            if not arrow or not pulse then
                return
            end
            arrow.Visible = visible
            if visible and not pulse.Tween then
                pulse.Scale.Scale = 1
                local tween = TweenService:Create(
                    pulse.Scale,
                    TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Scale = 1.15 }
                )
                pulse.Tween = tween
                tween:Play()
            elseif not visible then
                if pulse.Tween then
                    pulse.Tween:Cancel()
                    pulse.Tween = nil
                end
                pulse.Scale.Scale = 1
            end
        end
        local function numberAttribute(name: string): number
            local value = player:GetAttribute(name)
            return if type(value) == "number" then value else 0
        end
        local function refresh()
            local stage = player:GetAttribute("TutorialStage")
            local output = state.Evaluate({
                TutorialActive = player:GetAttribute("TutorialActive") == true,
                Stage = if type(stage) == "string" then stage else nil,
                Cash = numberAttribute("playerCash"),
                Levels = {
                    Jump = numberAttribute("JumpPurchasedLevel"),
                    Bat = numberAttribute("BatPurchasedLevel"),
                },
                PanelOpen = Notifications.IsOpen("Upgrades"),
            })
            if view then
                show(view.MenuArrow, output.MenuVisible)
                for name, arrow in view.PanelArrows do
                    show(arrow, name == output.PanelArrow)
                end
            end
        end
        local function bind(arrow: GuiObject?)
            if not arrow or arrows[arrow] then
                return
            end
            arrow.Visible = false
            local scale = arrow:FindFirstChildOfClass("UIScale") :: UIScale?
            if not scale then
                local created = Instance.new("UIScale")
                created.Name = "TutorialAlertScale"
                created.Parent = arrow
                scale = created
            end
            local boundScale = scale :: UIScale
            boundScale.Scale = 1
            arrows[arrow] = { Scale = boundScale, Tween = nil }
        end
        for _, attribute in
            {
                "playerCash",
                "JumpPurchasedLevel",
                "BatPurchasedLevel",
                "TutorialActive",
                "TutorialStage",
            }
        do
            player:GetAttributeChangedSignal(attribute):Connect(refresh)
        end
        Notifications.OnChanged("Upgrades", refresh)
        Gui.Observe(playerGui, function(nextView)
            for arrow in arrows do
                show(arrow, false)
            end
            table.clear(arrows)
            view = nextView
            if nextView then
                bind(nextView.MenuArrow)
                for _, arrow in nextView.PanelArrows do
                    bind(arrow)
                end
            end
            refresh()
        end, function() end)
    end)
end

return Controller
