--!strict
local Badge = {}

-- A transparent, non-interactive host keeps the button's hit area and FX intact.
function Badge.Attach(button: GuiButton): ((boolean) -> (), () -> ())
    local host = Instance.new("Frame")
    host.Name = "NotificationBadge"
    host.AnchorPoint = Vector2.new(1, 0)
    host.Position = UDim2.new(1, -4, 0, 4)
    host.Size = UDim2.fromOffset(22, 22)
    host.BackgroundTransparency = 1
    host.Active = false
    host.Visible = false
    local zIndex = button.ZIndex
    for _, child in button:GetDescendants() do
        if child:IsA("GuiObject") then
            zIndex = math.max(zIndex, child.ZIndex)
        end
    end
    host.ZIndex = zIndex + 1
    local label = Instance.new("TextLabel")
    label.Name = "Mark"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(220, 45, 55)
    label.BorderSizePixel = 0
    label.Text = "!"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Active = false
    label.ZIndex = host.ZIndex
    label.Parent = host
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = label
    host.Parent = button
    local detached = false
    return function(visible: boolean)
        if not detached then
            host.Visible = visible
        end
    end, function()
        detached = true
        host:Destroy()
    end
end

return Badge
