--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local BillboardStyle = require(script.Parent.Parent.UI.WorldBillboardStyle)
local Effects = require(script.Parent.Parent.UI.MuncherEffects)
local Controller = {}
local started = false

-- Pure presentation policy. Server independently validates every attempted feed.
function Controller.Feedback(model: Instance, plot: Instance, player: Player): string
    if
        plot:GetAttribute("PlotSessionId") == nil
        or plot:GetAttribute("PlotSessionId") ~= player:GetAttribute("PlotSessionId")
    then
        return "NOT YOUR MUNCHER"
    end
    if model:GetAttribute("Purchased") ~= true then
        return "LOCKED"
    end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not player.Character or (humanoid and humanoid.Health <= 0) then
        return ""
    end
    if
        model:GetAttribute("Active") ~= true
        or model:GetAttribute("Phase") ~= "Idle"
        or workspace:GetServerTimeNow() < (model:GetAttribute("AvailableAt") or 0)
    then
        return if workspace:GetServerTimeNow() < (model:GetAttribute("BusyUntil") or 0)
            then "BUSY" .. utf8.char(0x2026)
            else ""
    end
    return "FEED ME"
end

local function updateHint(view: any, model: Instance, player: Player, now: number)
    local feedback = Controller.Feedback(model, view.Plot, player)
    local phase = model:GetAttribute("Phase")
    local sequence = model:GetAttribute("Sequence")
    local availableAttribute = model:GetAttribute("AvailableAt")
    local availableAt = if type(availableAttribute) == "number" then availableAttribute else 0
    local eligible = view.Plot:IsDescendantOf(workspace)
        and model:IsDescendantOf(view.Plot)
        and view.Plot:GetAttribute("PlotSessionId") == player:GetAttribute("PlotSessionId")
        and view.Plot:GetAttribute("PlotSessionId") ~= nil
        and model:GetAttribute("Purchased") == true
        and model:GetAttribute("Active") == true
        and player.Character ~= nil
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    eligible = eligible and (not humanoid or humanoid.Health > 0)
    if not eligible or sequence ~= view.Sequence or phase ~= "Idle" then
        view.BannerUntil, view.BannerResult = nil, nil
    end
    if not eligible or sequence ~= view.Sequence then
        view.PendingResult = nil
    end
    if eligible and (phase == "Processing" or phase == "Spitting") then
        view.PendingResult = model:GetAttribute("ResultKind") or view.PendingResult
    elseif phase == "Idle" then
        -- Successful output publication advances AvailableAt; interruption does not.
        -- ResultKind is already cleared in the idle snapshot, so retain the roll's result.
        if eligible and view.PendingResult and availableAt > (view.AvailableAt or availableAt) then
            view.BannerResult = view.PendingResult
            view.BannerUntil = availableAt - Config.SpitSeconds + 2
        end
        view.PendingResult = nil
    end
    view.Sequence, view.AvailableAt = sequence, availableAt
    local result = if view.BannerUntil and now < view.BannerUntil then view.BannerResult else nil
    local banner = result == "Win" or result == "Lose"
    local visible = eligible and (banner or feedback == "FEED ME" or feedback == "BUSY" .. utf8.char(0x2026))
    if visible and not view.Gui.Enabled then
        view.ShownAt = now
    end
    view.Label.Text = if banner then (if result == "Win" then "YOU WIN!" else "YOU LOSE!") else feedback
    view.Label.TextColor3 = if banner
        then (if result == "Win" then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120))
        else Style.White
    view.Gui.Enabled = visible
end

local function purchaseDisplay(pad: BasePart, playerGui: PlayerGui): BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "MuncherPurchase"
    gui.Active = false
    gui.Adornee = pad
    -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
    BillboardStyle.ApplyBillboard(gui, { WidthStuds = 9.1, HeightStuds = 1.7, MaxDistance = 40 })
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    for index, text in { "MUNCHER", "$100K" } do
        local label = Instance.new("TextLabel")
        label.Name = if index == 1 then "Title" else "Detail"
        label.Active = false
        BillboardStyle.ApplyText(label, {})
        Style.Apply(label :: TextLabel, 24)
        label.Size = UDim2.fromScale(1, 0.5)
        label.Position = UDim2.fromScale(0, (index - 1) / 2)
        label.TextScaled = true
        label.Text = text
        if index == 2 then
            label.TextColor3 = Style.Gold
        end
        label.Parent = gui
    end
    gui.Parent = playerGui
    return gui
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
    CollectionService:GetInstanceAddedSignal("IngredientWorldItem"):Connect(function(object)
        if object:GetAttribute("MuncherReward") == true then
            Effects.Pop(object)
        end
    end)
    local views: { [Instance]: any } = {}
    local elapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        for model, view in views do
            local now = workspace:GetServerTimeNow()
            updateHint(view, model, player, now)
            view.Animate(now)
            if view.Gui.Enabled and view.ShownAt then
                local t = math.clamp((now - view.ShownAt) / 0.25, 0, 1)
                view.Label.Position = UDim2.fromScale(0, -math.sin(t * math.pi) * 0.12)
            end
        end
        elapsed += dt
        if elapsed < Config.ScanInterval then
            return
        end
        elapsed = 0
        local seen: { [Instance]: boolean } = {}
        for _, plot in CollectionService:GetTagged("PlayerPlot") do
            local model = plot:FindFirstChild("Muncher")
            if not model or not plot:IsDescendantOf(workspace) then
                continue
            end
            seen[model] = true
            local view = views[model]
            if not view then
                local gui = Instance.new("BillboardGui")
                gui.Name = "MuncherHint"
                gui.Active = false
                gui.Enabled = false
                BillboardStyle.ApplyBillboard(
                    gui,
                    { WidthStuds = 5.5, HeightStuds = 1.4, MaxDistance = 25, AlwaysOnTop = false, ResetOnSpawn = true }
                )
                local label = Instance.new("TextLabel")
                -- Decorative hint/result view: never consume world or Throw taps.
                -- UIStroke/UIPadding are UIComponents and have no Active property.
                label.Active = false
                label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
                Style.Apply(label :: TextLabel, 24)
                label.TextScaled = true
                label.Parent, gui.Parent = gui, playerGui
                gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
                local animate, cleanup = Effects.Bind(model, playerGui)
                view = { Gui = gui, Label = label, Animate = animate, Cleanup = cleanup, Plot = plot }
                views[model] = view
            end
            local input = model:FindFirstChild("InputZone")
            local pad = model:FindFirstChild("PurchasePoint1")
            if view.Pad ~= pad then
                if view.Purchase then
                    view.Purchase:Destroy()
                end
                view.Pad = pad
                view.Purchase = if pad and pad:IsA("BasePart") then purchaseDisplay(pad, playerGui) else nil
            end
            if view.Purchase then
                view.Purchase.Enabled = pad.CanTouch and pad.Transparency < 1
            end
            local mouth = model:FindFirstChild("MouthOrigin", true)
            view.Gui.Adornee = if mouth and (mouth:IsA("Attachment") or mouth:IsA("BasePart"))
                then mouth
                elseif input and input:IsA("BasePart") then input
                else nil
            updateHint(view, model, player, workspace:GetServerTimeNow())
        end
        for model, view in views do
            if not seen[model] then
                view.Cleanup()
                view.Gui:Destroy()
                if view.Purchase then
                    view.Purchase:Destroy()
                end
                views[model] = nil
            end
        end
    end)
end
return Controller
