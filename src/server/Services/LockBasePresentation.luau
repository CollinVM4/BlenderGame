--!strict
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.LockBaseConfig)
local TextStyle = require(Shared.Constants.DialogueTextStyle)
local Presentation = {}

function Presentation.Bind(button: BasePart?, attachment: Attachment?, visual: Model?)
    local connections: { RBXScriptConnection } = {}
    local tween: Tween? = nil
    local pressTween: Tween? = nil
    local revision = 0
    local closed = false
    local active = false
    local parts: { [BasePart]: number } = {}
    local raised = if visual then visual:GetAttribute("LockBaseRaisedPivot") else nil
    if visual and typeof(raised) ~= "CFrame" then
        raised = visual:GetPivot()
        visual:SetAttribute("LockBaseRaisedPivot", raised)
    end
    local depth = 0
    if visual then
        local box, size = visual:GetBoundingBox()
        depth = math.abs(box.RightVector.Y) * size.X
            + math.abs(box.UpVector.Y) * size.Y
            + math.abs(box.LookVector.Y) * size.Z
            + 1
        for _, child in visual:GetDescendants() do
            if child:IsA("BasePart") then
                local transparency = child:GetAttribute("LockBaseAuthoredTransparency")
                if type(transparency) ~= "number" then
                    transparency = child.Transparency
                    child:SetAttribute("LockBaseAuthoredTransparency", transparency)
                end
                parts[child] = transparency :: number
                child.Anchored = true
                child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
            end
        end
    end
    local offset = Instance.new("NumberValue")
    offset.Value = -depth
    local function move()
        if visual and typeof(raised) == "CFrame" then
            visual:PivotTo(raised + Vector3.new(0, offset.Value, 0))
        end
    end
    table.insert(connections, offset.Changed:Connect(move))
    local function visible(enabled: boolean)
        for part, transparency in parts do
            part.Transparency = if enabled then transparency else 1
        end
    end
    move()
    visible(false)

    local display: BillboardGui? = nil
    local label: TextLabel? = nil
    -- Only use the authored Button attachment; never relocate it or synthesize an anchor.
    attachment = if button then button:FindFirstChild("LockAttachment") :: Attachment? else nil
    if attachment and not attachment:IsA("Attachment") then
        attachment = nil
    end
    if attachment then
        local existing = attachment:FindFirstChild("LockBaseDisplay")
        if existing then
            existing:Destroy()
        end
        local gui = Instance.new("BillboardGui")
        gui.Name = "LockBaseDisplay"
        gui.Adornee = attachment
        gui.Size = UDim2.fromOffset(240, 90)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 65
        gui.StudsOffset = Vector3.zero
        gui.StudsOffsetWorldSpace = Vector3.zero
        gui.ResetOnSpawn = false
        gui.Enabled = false
        gui.Parent = attachment
        local text = Instance.new("TextLabel")
        text.Name = "State"
        text.Size = UDim2.fromScale(1, 1)
        text.BackgroundTransparency = 1
        text.TextTransparency = 0
        text.ZIndex = 2
        text.TextXAlignment = Enum.TextXAlignment.Center
        text.TextYAlignment = Enum.TextYAlignment.Center
        TextStyle.Apply(text, 24)
        text.TextColor3 = Color3.fromRGB(255, 95, 95)
        text.Parent = gui
        display, label = gui, text
    end
    local buttonOrigin = if button then button:GetAttribute("LockBaseButtonOrigin") else nil
    if button then
        button.Anchored = true
        -- Reject's support ray respects CanCollide. A decorative/noncollidable
        -- authored plate would otherwise always hit BlackBase or the ground.
        button.CanCollide, button.CanQuery, button.CanTouch = true, true, true
    end
    if button and typeof(buttonOrigin) ~= "CFrame" then
        buttonOrigin = button.CFrame
        button:SetAttribute("LockBaseButtonOrigin", buttonOrigin)
    end
    local api = {}
    function api.SetLocked(locked: boolean, immediate: boolean?)
        revision += 1
        local token = revision
        active = locked
        if tween then
            tween:Cancel()
            tween = nil
        end
        if locked then
            visible(true)
        end
        local target = if locked then 0 else -depth
        if immediate then
            offset.Value = target
            move()
            visible(locked)
            return
        end
        local running = TweenService:Create(
            offset,
            TweenInfo.new(
                if locked then Config.LaserRaiseDuration else Config.LaserLowerDuration,
                Enum.EasingStyle.Quart,
                Enum.EasingDirection.Out
            ),
            { Value = target }
        )
        -- One bounded completion task per transition; canceled callbacks cannot hide a new lock.
        tween = running
        task.spawn(function()
            running.Completed:Wait()
            if not closed and revision == token and not active then
                visible(false)
            end
        end)
        running:Play()
    end
    function api.Update(occupied: boolean, deadline: number, now: number)
        -- Enabled belongs to each client's distance controller. Occupancy and text replicate.
        if display and display:GetAttribute("LockBaseOccupied") ~= occupied then
            display:SetAttribute("LockBaseOccupied", occupied)
        end
        if label then
            local remaining = math.max(0, math.ceil(deadline - now))
            local text = if remaining > 0
                then string.format("LOCKED\n%d:%02d", math.floor(remaining / 60), remaining % 60)
                else "LOCK BASE"
            if label.Text ~= text then
                label.Text = text
            end
        end
    end
    function api.Press()
        if not button or typeof(buttonOrigin) ~= "CFrame" then
            return
        end
        if pressTween then
            pressTween:Cancel()
        end
        local running = TweenService:Create(
            button,
            TweenInfo.new(Config.ButtonPressDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                CFrame = buttonOrigin + Vector3.new(0, -Config.ButtonPressDepth, 0),
            }
        )
        pressTween = running
        task.spawn(function()
            running.Completed:Wait()
            if not closed and pressTween == running then
                local release = TweenService:Create(
                    button,
                    TweenInfo.new(Config.ButtonReleaseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { CFrame = buttonOrigin }
                )
                pressTween = release
                release:Play()
            end
        end)
        running:Play()
    end
    function api.Destroy()
        closed = true
        revision += 1
        if tween then
            tween:Cancel()
        end
        if pressTween then
            pressTween:Cancel()
        end
        for _, connection in connections do
            connection:Disconnect()
        end
        offset:Destroy()
        if display then
            display:Destroy()
        end
        if button and typeof(buttonOrigin) == "CFrame" then
            button.CFrame = buttonOrigin
        end
        -- Retain absolute authored metadata for safe rebinds after hierarchy changes.
        visible(false)
        if visual and typeof(raised) == "CFrame" then
            visual:PivotTo(raised + Vector3.new(0, -depth, 0))
        end
    end
    return api
end

return Presentation
