--!strict
-- Presentation only: shown exclusively for a server-confirmed cooldown rejection.
local RunService = game:GetService("RunService")
local View = {}
export type Handle = { Root: TextLabel, Scale: UIScale, Connection: RBXScriptConnection? }

function View.Create(parent: Instance): Handle
    local label = Instance.new("TextLabel")
    label.Name = "IceShotgunCooldownFeedback"
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0.5, 28)
    label.Size = UDim2.fromOffset(230, 28)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextSize = 18
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Active = false
    label.Selectable = false
    label.Visible = false
    label.Parent = parent
    local outline = Instance.new("UIStroke")
    outline.Color = Color3.new(0, 0, 0)
    outline.Thickness = 2
    outline.Parent = label
    local scale = Instance.new("UIScale")
    scale.Parent = label
    return { Root = label, Scale = scale, Connection = nil }
end

function View.Hide(view: Handle)
    if view.Connection then
        view.Connection:Disconnect()
        view.Connection = nil
    end
    view.Root.Visible = false
end

function View.Show(view: Handle, remaining: number)
    View.Hide(view)
    local label = view.Root
    local outline = label:FindFirstChildOfClass("UIStroke") :: UIStroke
    label.Text = string.format("Cooldown... %.1fs left", remaining)
    label.Position = UDim2.new(0.5, 0, 0.5, 28)
    label.TextTransparency = 0
    outline.Transparency = 0
    view.Scale.Scale = 0.85
    label.Visible = true
    local startedAt = os.clock()
    view.Connection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startedAt
        if elapsed >= 0.8 then
            View.Hide(view)
            return
        end
        -- A short overshoot settles into the upward drift and fade.
        view.Scale.Scale = if elapsed < 0.1
            then 0.85 + 0.23 * elapsed / 0.1
            elseif elapsed < 0.18 then 1.08 - 0.08 * (elapsed - 0.1) / 0.08
            else 1
        label.Position = UDim2.new(0.5, 0, 0.5, 28 - 10 * elapsed / 0.8)
        local fade = math.clamp((elapsed - 0.18) / 0.62, 0, 1)
        label.TextTransparency = fade
        outline.Transparency = fade
    end)
end

function View.Destroy(view: Handle)
    View.Hide(view)
    view.Root:Destroy()
end

return View
