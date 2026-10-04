--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Presentation = {}

function Presentation.Marker(object: Instance?): (BasePart | Attachment)?
    if object and object:IsA("BasePart") then
        return object
    elseif object and object:IsA("Attachment") then
        return object
    end
    return nil
end

function Presentation.Display(origin: BasePart | Attachment): (BillboardGui, (any, boolean?) -> ())
    local gui = Instance.new("BillboardGui")
    gui.Name = "MuncherProgress"
    gui.Adornee = origin
    gui.Size = UDim2.fromOffset(176, 80)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 0.65, 0)
    gui.MaxDistance = Config.MaxDistance
    gui.AlwaysOnTop = false
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(3, 2)
    title.Size = UDim2.fromOffset(170, 26)
    title.BackgroundTransparency = 1
    title.Text = "MUNCHER"
    Style.Apply(title, 23)
    title.Parent = gui
    local bar = Instance.new("Frame")
    bar.Name = "ProgressBar"
    bar.AnchorPoint = Vector2.new(0.5, 0.5)
    bar.Position = UDim2.fromOffset(88, 38)
    bar.Size = UDim2.fromOffset(156, 20)
    bar.BackgroundColor3 = Color3.fromRGB(42, 48, 56)
    bar.BorderSizePixel = 0
    bar.Parent = gui
    local function round(object: GuiObject)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = object
    end
    round(bar)
    local outline = Instance.new("UIStroke")
    outline.Color = Style.Dark
    outline.Thickness = 3
    outline.Parent = bar
    local rim = Instance.new("Frame")
    rim.Name = "Rim"
    rim.ZIndex = 2
    rim.Size = UDim2.fromScale(1, 1)
    rim.BackgroundTransparency = 1
    rim.Parent = bar
    round(rim)
    local highlight = Instance.new("UIStroke")
    highlight.Color = Style.White
    highlight.Thickness = 1
    highlight.Parent = rim
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BackgroundColor3 = Style.Green
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale(0, 1)
    fill.Parent = bar
    round(fill)
    local count = Instance.new("TextLabel")
    count.Name = "Count"
    count.AnchorPoint = Vector2.new(0.5, 0.5)
    count.Position = UDim2.fromOffset(88, 64)
    count.Size = UDim2.fromOffset(156, 24)
    count.BackgroundTransparency = 1
    Style.Apply(count, 20)
    count.Parent = gui
    local countScale = Instance.new("UIScale")
    countScale.Scale = 1
    countScale.Parent = count
    local barScale = Instance.new("UIScale")
    barScale.Scale = 1
    barScale.Parent = bar

    local tweens: { [string]: Tween } = {}
    local revision = 0
    local alive = true
    local previousProgress: number? = nil
    local previousTarget: number? = nil
    local function cancel(name: string)
        local tween = tweens[name]
        if tween then
            tween:Cancel()
            tweens[name] = nil
        end
    end
    local function punch(name: string, scale: UIScale, peak: number)
        cancel(name)
        scale.Scale = 1
        local tween = TweenService:Create(
            scale,
            TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
            { Scale = peak }
        )
        tweens[name] = tween
        tween:Play()
    end
    gui.Destroying:Connect(function()
        alive = false
        revision += 1
        for name in tweens do
            cancel(name)
        end
    end)
    gui.Parent = origin
    return gui,
        function(snapshot, consumed)
            if not alive then
                return
            end
            local progress = if snapshot then snapshot.Progress else nil
            local target = if snapshot then snapshot.Target else nil
            local changed = progress ~= previousProgress or target ~= previousTarget
            -- The service resets synchronously on completion. Detect it only on an
            -- accepted ingredient, using the pre-feed snapshot, never buff timing.
            local completed = consumed == true
                and previousProgress ~= nil
                and previousTarget ~= nil
                and previousProgress + 1 >= previousTarget
            local ratio = if snapshot and snapshot.Target > 0
                then math.clamp(snapshot.Progress / snapshot.Target, 0, 1)
                else 0
            count.Text = if snapshot then string.format("%d / %d", snapshot.Progress, snapshot.Target) else "0 / —"
            if changed then
                cancel("Fill")
                if snapshot and previousProgress ~= nil then
                    local tween = TweenService:Create(
                        fill,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { Size = UDim2.fromScale(ratio, 1) }
                    )
                    tweens.Fill = tween
                    tween:Play()
                else
                    fill.Size = UDim2.fromScale(ratio, 1)
                end
            end
            if consumed and snapshot then
                punch("Count", countScale, if completed then 1.18 else 1.15)
                punch("Bar", barScale, if completed then 1.07 else 1.025)
                revision += 1
                local currentRevision = revision
                title.Text = if completed then "FULL!" else "MUNCHER"
                title.TextColor3 = if completed then Style.Gold else Style.White
                if completed then
                    task.delay(0.35, function()
                        if alive and revision == currentRevision then
                            title.Text = "MUNCHER"
                            title.TextColor3 = Style.White
                        end
                    end)
                end
            elseif not snapshot then
                revision += 1
                cancel("Fill")
                cancel("Count")
                cancel("Bar")
                fill.Size = UDim2.fromScale(0, 1)
                countScale.Scale, barScale.Scale = 1, 1
                title.Text, title.TextColor3 = "MUNCHER", Style.White
            end
            previousProgress, previousTarget = progress, target
        end
end

-- Independent cosmetic copy: never register inventory or touch the Visual artwork.
function Presentation.Feed(services: any, id: string, at: CFrame, mouth: BasePart | Attachment?)
    if not mouth or not mouth:IsDescendantOf(workspace) then
        return
    end
    local destination = if mouth:IsA("Attachment") then mouth.WorldPosition else mouth.Position
    local visual = services.IngredientService.CreateVisual(id)
    if not visual then
        return
    end
    -- Schedule disposal before any subsequent cosmetic work that might fail.
    Debris:AddItem(visual, Config.TravelSeconds + 0.1)
    local parts = visual:GetDescendants()
    table.insert(parts, visual)
    for _, part in parts do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
        elseif part:IsA("ProximityPrompt") or part:IsA("Script") or part:IsA("LocalScript") then
            part:Destroy()
        end
    end
    local physical = visual :: any
    physical:PivotTo(at)
    local pivot = Instance.new("CFrameValue")
    pivot.Value = at
    local connection = pivot.Changed:Connect(function(value)
        if visual.Parent then
            physical:PivotTo(value)
        end
    end)
    visual.Destroying:Connect(function()
        connection:Disconnect()
        pivot:Destroy()
    end)
    visual.Parent = workspace
    TweenService:Create(pivot, TweenInfo.new(Config.TravelSeconds), { Value = CFrame.new(destination) }):Play()
end

return Presentation
