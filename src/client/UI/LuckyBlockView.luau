--!strict
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Constants.LuckyBlockPresentation)
local Visual = require(script.Parent.LuckyBlockVisual)
local Handoff = require(script.Parent.LuckyBlockPickupHandoff)
local View = {}
type Handle = { Show: (string, boolean) -> (), Fade: () -> (), Destroy: () -> () }
local warned: { [string]: boolean } = {}

function View.Create(position: Vector3, finalOnly: string?, pickupId: number?, pickedUpAt: number?): Handle
    local root = Instance.new("Folder")
    root.Name = "LuckyBlockRoulette"
    local anchor = Instance.new("Part")
    anchor.Name = "PresentationAnchor"
    anchor.Size = Vector3.new(0.01, 0.01, 0.01)
    anchor.Anchored, anchor.Transparency = true, 1
    anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
    anchor.CFrame = CFrame.new(position + Vector3.new(0, Config.HeightOffset, 0))
    anchor.Parent = root
    local labelGui = Instance.new("BillboardGui")
    labelGui.Name = "RewardName"
    labelGui.Adornee = anchor
    -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
    BillboardStyle.ApplyBillboard(
        labelGui,
        { WidthStuds = 4.8, HeightStuds = 0.96, MaxDistance = 45, AlwaysOnTop = false, ResetOnSpawn = true }
    )
    labelGui.StudsOffsetWorldSpace = Vector3.new(0, -Config.ModelSize / 2 - 0.35, 0)
    labelGui.AlwaysOnTop = false
    labelGui.Enabled = false
    labelGui.Active = false
    labelGui.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.25
    label.Parent = labelGui
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 226, 140)
    light.Range, light.Brightness = 8, 0
    light.Parent = anchor
    local cache = Instance.new("Folder") -- Unparented: unused silhouettes are never visible in Workspace.
    local shadows: { [string]: Model } = {}
    local sources = ReplicatedStorage:FindFirstChild(Config.VisualFolderName)
    local function clone(id: string, silhouette: boolean): Model?
        local definition = Config.Rewards[id]
        local model = Visual.Clone(sources and sources:FindFirstChild(definition.Visual), silhouette)
        if not model then
            if not warned[id] then
                warned[id] = true
                warn(
                    "[LuckyBlockRoulette] Missing usable ReplicatedStorage."
                        .. Config.VisualFolderName
                        .. "."
                        .. definition.Visual
                        .. "; using temporary text only"
                )
            end
        else
            warned[id] = nil
        end
        return model
    end
    if not finalOnly then
        for id in Config.Rewards do
            local model = clone(id, true)
            if model then
                model.Parent = cache
                shadows[id] = model
            end
        end
    end
    local tickSound, popSound = Instance.new("Sound"), Instance.new("Sound")
    tickSound.SoundId, tickSound.Volume = Config.TickSoundId, Config.TickVolume
    popSound.SoundId, popSound.Volume = Config.PopSoundId, Config.PopVolume
    for _, sound in { tickSound, popSound } do
        sound.RollOffMinDistance, sound.RollOffMaxDistance = 8, Config.NearbyDistance
        sound.Parent = anchor
    end
    local scale = Instance.new("NumberValue")
    scale.Value = 1
    scale.Parent = root
    local current: Model? = nil
    local baseScale = 1
    local beat = 0
    local disposed = false
    local fading = false
    local revealed = false
    local handedOff = false
    local awaitingHandoff = false
    local tweens: { Tween } = {}
    local connections: { RBXScriptConnection } = {}
    local function tween(object: Instance, seconds: number, properties: any): Tween
        local animation = TweenService:Create(
            object,
            TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            properties
        )
        table.insert(tweens, animation)
        animation:Play()
        return animation
    end
    table.insert(
        connections,
        scale.Changed:Connect(function()
            if current and not disposed then
                current:ScaleTo(baseScale * math.max(0.01, scale.Value))
            end
        end)
    )
    local view = {}
    local destroyNow: () -> ()
    function view.Show(id: string, silhouette: boolean)
        if disposed or not Config.Rewards[id] then
            return
        end
        if current then
            current.Parent = cache
        end
        beat += 1
        current = if silhouette
            then shadows[id]
            elseif pickupId and Handoff.Ready(pickupId) then nil
            else clone(id, false)
        if current then
            current.Parent = root
            local yaw = if silhouette then (beat - 1) * Config.BeatYawDegrees else Config.RevealYawDegrees
            current:PivotTo(
                if silhouette
                    then anchor.CFrame * CFrame.Angles(math.rad(Config.TiltDegrees), math.rad(yaw), 0)
                    else Visual.Pose(position)
            )
            baseScale = current:GetScale()
        end
        labelGui.Enabled = not silhouette or current == nil
        label.Text = if current
            then Config.Rewards[id].Name
            else (if silhouette then "Missing visual" else Config.Rewards[id].Name .. " (missing model)")
        if not silhouette and pickupId then
            revealed = true
            Handoff.Keep(
                pickupId,
                function()
                    handedOff = true
                    if current then
                        current:Destroy()
                        current = nil
                    end
                    labelGui.Enabled = false
                    if awaitingHandoff then
                        destroyNow()
                    end
                end,
                (pickedUpAt or workspace:GetServerTimeNow())
                    + Config.RevealSeconds
                    + Config.HoldSeconds
                    + Config.FadeSeconds
                    + 60
            )
        end
        if silhouette then
            scale.Value = 1
            tickSound:Stop()
            tickSound.TimePosition = 0
            tickSound:Play()
        else
            tickSound:Stop()
            popSound:Play()
            scale.Value = 0.85
            local pop = tween(scale, Config.PopSeconds, { Value = Config.PopScale })
            table.insert(
                connections,
                pop.Completed:Connect(function(playback)
                    if not disposed and not fading and playback == Enum.PlaybackState.Completed then
                        tween(scale, Config.SettleSeconds, { Value = 1 })
                    end
                end)
            )
            light.Brightness = 2
            tween(light, 0.25, { Brightness = 0 })
        end
    end
    function view.Fade()
        if disposed then
            return
        end
        fading = true
        for _, animation in tweens do
            animation:Cancel()
        end
        if pickupId and revealed then
            scale.Value = 1 -- The prize remains at its settled reveal scale.
        else
            tween(scale, Config.FadeSeconds, { Value = 0.01 })
        end
        tween(label, Config.FadeSeconds, { TextTransparency = 1, TextStrokeTransparency = 1 })
        light.Brightness = 0
    end
    destroyNow = function()
        if disposed then
            return
        end
        disposed = true
        for _, connection in connections do
            connection:Disconnect()
        end
        for _, animation in tweens do
            animation:Cancel()
        end
        tickSound:Stop()
        popSound:Stop()
        root:Destroy()
        cache:Destroy()
    end
    function view.Destroy()
        if pickupId and revealed and not handedOff and not disposed then
            awaitingHandoff = true
            view.Fade()
            tickSound:Stop()
            popSound:Stop()
            return -- Keep the prize across cancellation/death or delayed replication.
        end
        destroyNow()
    end
    root.Parent = workspace
    return view
end

return View
