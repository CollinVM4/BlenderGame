--!strict
local TweenService = game:GetService("TweenService")
local Style = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local Messages = require(script.Parent.LuckyBlockMessages)
local Hud = {}
function Hud.Create(playerGui: PlayerGui)
    local gui = Instance.new("ScreenGui")
    gui.Name = "LuckyPowerups"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.DisplayOrder = 15
    local canvas = Instance.new("Frame")
    canvas.Size = UDim2.fromScale(1, 1)
    canvas.BackgroundTransparency = 1
    canvas.Parent = gui
    type Row = { Group: CanvasGroup, Label: TextLabel, Tween: Tween }
    local rows: { [string]: Row } = {}
    local function remove(id: string)
        local row = rows[id]
        row.Tween:Cancel()
        row.Group:Destroy()
        rows[id] = nil
    end
    gui.Parent = playerGui
    return {
        Gui = gui,
        Render = function(entries: { Messages.Entry })
            local wanted: { [string]: boolean } = {}
            local x, y, width, height = Messages.Layout(canvas.AbsoluteSize.X, canvas.AbsoluteSize.Y, #entries)
            for index, entry in entries do
                wanted[entry.Id] = true
                local row = rows[entry.Id]
                if not row then
                    local group = Instance.new("CanvasGroup")
                    group.Name = entry.Id
                    group.BackgroundTransparency = 1
                    group.GroupTransparency = 1
                    group.AnchorPoint = Vector2.new(0.5, 0)
                    group.Parent = canvas
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, -8, 1, -2)
                    label.Position = UDim2.fromOffset(4, 1)
                    label.BackgroundTransparency = 1
                    Style.Apply(label, 20)
                    label.TextScaled = true
                    label.Parent = group
                    -- Fade the composited row, including its thick dark outline,
                    -- using the same CanvasGroup approach as TutorialTooltip.
                    local tween = TweenService:Create(group, TweenInfo.new(0.15), { GroupTransparency = 0 })
                    row = { Group = group, Label = label, Tween = tween }
                    rows[entry.Id] = row
                    tween:Play()
                end
                row.Label.Text = entry.Text
                row.Group.Position = UDim2.fromOffset(x, y + (index - 1) * height)
                row.Group.Size = UDim2.fromOffset(width, height)
            end
            for id in rows do
                if not wanted[id] then
                    remove(id)
                end
            end
        end,
        Destroy = function()
            for id in rows do
                remove(id)
            end
            gui:Destroy()
        end,
    }
end
return Hud
