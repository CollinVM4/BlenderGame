--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local BillboardStyle = require(script.Parent.Parent.UI.WorldBillboardStyle)
local Tooltip = require(script.Parent.Parent.UI.TutorialTooltip)
type View = { Gui: BillboardGui, Name: TextLabel, Timer: TextLabel }
local Controller = {}
local started = false

-- Same origin, canvas and text-row convention as FarmPresentationController's
-- purchase billboards: pad Adornee, PlayerGui parent, two-stud world-space lift.
local function purchaseDisplay(pad: BasePart, playerGui: PlayerGui): BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "MuncherPurchase"
    gui.Adornee = pad
    BillboardStyle.ApplyBillboard(gui, { Width = 340, Height = 64, MaxDistance = 28 })
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    for index, text in { "MUNCHER", "$100K" } do
        local label = Instance.new("TextLabel")
        label.Name = if index == 1 then "Title" else "Detail"
        BillboardStyle.ApplyText(label, {})
        Style.Apply(label, 24)
        label.Size = UDim2.new(1, 0, 0, 32)
        label.Position = UDim2.fromOffset(0, (index - 1) * 32)
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
    local shown = false
    local views: { [Instance]: View } = {}
    local purchaseViews: { [BasePart]: BillboardGui } = {}
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0
        local seen: { [Instance]: boolean } = {}
        local seenPads: { [BasePart]: boolean } = {}
        for _, plot in CollectionService:GetTagged("PlayerPlot") do
            local model = plot:FindFirstChild("Muncher")
            if not model or not plot:IsDescendantOf(workspace) then
                continue
            end
            seen[model] = true
            local pad = model:FindFirstChild("PurchasePoint1")
            if pad and pad:IsA("BasePart") then
                seenPads[pad] = true
                local purchaseGui = purchaseViews[pad]
                if not purchaseGui then
                    purchaseGui = purchaseDisplay(pad, playerGui)
                    purchaseViews[pad] = purchaseGui
                end
                -- Match Farm pad visibility; the server continues to own pad state.
                purchaseGui.Enabled = pad:IsDescendantOf(workspace) and pad.CanTouch and pad.Transparency < 1
            end
            local origin = model:FindFirstChild("DisplayOrigin")
            local active = model:GetAttribute("Active") == true
            local id = model:GetAttribute("ActiveBuff")
            local expires = model:GetAttribute("BuffExpiresAt")
            local remaining = if type(expires) == "number"
                then math.max(0, math.ceil(expires - workspace:GetServerTimeNow()))
                else 0
            local buff = nil
            for _, candidate in Config.Buffs do
                if candidate.Id == id then
                    buff = candidate
                    break
                end
            end
            local view: View? = views[model]
            if
                active
                and buff
                and remaining > 0
                and origin
                and (origin:IsA("BasePart") or origin:IsA("Attachment"))
            then
                if view and view.Gui.Adornee ~= origin then
                    view.Gui:Destroy()
                    views[model] = nil
                    view = nil
                end
                if not view then
                    local gui = Instance.new("BillboardGui")
                    gui.Name = "MuncherBuff"
                    gui.Adornee = origin
                    gui.Size = UDim2.fromOffset(190, 52)
                    gui.StudsOffsetWorldSpace = Vector3.new(0, 2.35, 0)
                    gui.MaxDistance = Config.MaxDistance
                    gui.AlwaysOnTop = false
                    local title = Instance.new("TextLabel")
                    title.BackgroundTransparency = 1
                    title.Size = UDim2.fromOffset(190, 26)
                    Style.Apply(title, 19)
                    title.TextColor3 = Style.Gold
                    title.Parent = gui
                    local timer = Instance.new("TextLabel")
                    timer.BackgroundTransparency = 1
                    timer.Position = UDim2.fromOffset(0, 26)
                    timer.Size = UDim2.fromOffset(190, 24)
                    Style.Apply(timer, 20)
                    timer.Parent = gui
                    gui.Parent = playerGui
                    view = { Gui = gui, Name = title, Timer = timer }
                    views[model] = view
                end
                assert(view)
                view.Name.Text = buff.Name
                view.Timer.Text = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
            elseif view then
                view.Gui:Destroy()
                views[model] = nil
            end
            if
                active
                and not shown
                and type(player:GetAttribute("PlotSessionId")) == "string"
                and plot:GetAttribute("PlotSessionId") == player:GetAttribute("PlotSessionId")
            then
                shown = true
                Tooltip.Show(playerGui, "MuncherTutorial", "FEED MUNCHER to receive a temporary buff!")
            end
        end
        for pad, gui in purchaseViews do
            if not seenPads[pad] then
                gui:Destroy()
                purchaseViews[pad] = nil
            end
        end
        for model, view in views do
            if not seen[model] then
                view.Gui:Destroy()
                views[model] = nil
            end
        end
    end)
end

return Controller
