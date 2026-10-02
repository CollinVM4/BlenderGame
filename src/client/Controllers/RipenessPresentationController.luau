--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").Shared
local TextStyle = require(Shared.Constants.DialogueTextStyle)
local DisplayState = require(script.Parent.Parent.UI.RipenessDisplayState)
local RadialProgress = require(script.Parent.Parent.UI.RadialProgress)
local TutorialText = require(script.Parent.Parent.UI.RipenessTutorialText)
local RipenessStyle = require(Shared.Constants.RipenessPresentation)

local Controller = {}
local started = false
local gold = RipenessStyle.IndicatorGold
local fresh = Color3.fromRGB(185, 204, 185)
local track = Color3.fromRGB(58, 68, 62)

type Pip = { Root: Frame, RadialProgress: RadialProgress.View, Center: Frame, Ripe: boolean }
type Slot = { Gui: BillboardGui?, Pips: { [string]: Pip }, Signature: string }
local function pip(parent: BillboardGui, order: number): Pip
    local root = Instance.new("Frame")
    root.Name = "RipenessPip"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(22, 22)
    root.Position = UDim2.fromOffset(18 + (order - 1) * 28, 1)
    root.Parent = parent
    local radial = RadialProgress.Create(root, gold, track)
    local center = Instance.new("Frame")
    center.Name = "Center"
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.Position = UDim2.fromOffset(11, 11)
    center.Size = UDim2.fromOffset(7, 7)
    center.BackgroundColor3 = fresh
    center.BorderSizePixel = 0
    Instance.new("UICorner", center).CornerRadius = UDim.new(1, 0)
    center.Parent = root
    return { Root = root, RadialProgress = radial, Center = center, Ripe = false }
end

local function renderPip(view: Pip, amount: number, ripe: boolean)
    view.RadialProgress.Root.Visible = not ripe
    if not ripe then
        RadialProgress.SetProgress(view.RadialProgress, amount)
    end
    view.Center.BackgroundColor3 = if ripe then gold else fresh
    view.Center.Size = if ripe then UDim2.fromOffset(15, 15) else UDim2.fromOffset(7, 7)
    if ripe and not view.Ripe then
        view.Center.Size = UDim2.fromOffset(19, 19)
        TweenService:Create(view.Center, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
            Size = UDim2.fromOffset(15, 15),
        }):Play()
    end
    view.Ripe = ripe
end

local function showTutorial(playerGui: PlayerGui)
    local gui = Instance.new("ScreenGui")
    gui.Name = "RipenessTutorial"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 15
    gui.Parent = playerGui
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.72)
    card.Size = UDim2.fromOffset(320, 78)
    card.BackgroundColor3 = TextStyle.Dark
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    card.Parent = gui
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.RichText = true
    label.TextWrapped = true
    label.Text = TutorialText.Rich()
    TextStyle.Apply(label, 20)
    label.TextWrapped = true
    label.TextTransparency = 1
    label.Parent = card
    TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.18 }):Play()
    TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
    task.delay(4.3, function()
        if not gui.Parent then
            return
        end
        TweenService:Create(card, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(label, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
        task.delay(0.5, function()
            gui:Destroy()
        end)
    end)
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
    local tutorialShown = false
    local function tutorial()
        if not tutorialShown and player:GetAttribute("RipenessTutorialShown") == true then
            tutorialShown = true
            showTutorial(playerGui)
        end
    end
    player:GetAttributeChangedSignal("RipenessTutorialShown"):Connect(tutorial)
    tutorial()

    local pads: { [BasePart]: Slot } = {}
    local boundFixtures: { [Instance]: boolean } = {}
    local function bind(pad: Instance)
        if pad:IsA("BasePart") and (pad:GetAttribute("SlotIndex") ~= nil or pad.Name:match("^Slot%d+$")) then
            pads[pad] = pads[pad] or { Pips = {}, Signature = "" }
        end
    end
    local function fixture(root: Instance)
        if boundFixtures[root] then
            return
        end
        boundFixtures[root] = true
        root.Destroying:Connect(function()
            boundFixtures[root] = nil
        end)
        for _, part in root:GetDescendants() do
            bind(part)
        end
        root.DescendantAdded:Connect(bind)
        local plot = root.Parent
        if plot then
            local expansion = plot:FindFirstChild("UpgradeStash")
            if expansion then
                for _, part in expansion:GetDescendants() do
                    bind(part)
                end
            end
            plot.DescendantAdded:Connect(function(part)
                if part.Name == "UpgradeStash" then
                    for _, child in part:GetDescendants() do
                        bind(child)
                    end
                elseif part:FindFirstAncestor("UpgradeStash") then
                    bind(part)
                end
            end)
        end
    end
    for _, root in CollectionService:GetTagged("PlayerStash") do
        fixture(root)
    end
    CollectionService:GetInstanceAddedSignal("PlayerStash"):Connect(fixture)

    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0
        local now = workspace:GetServerTimeNow()
        for pad, slot in pads do
            if not pad:IsDescendantOf(workspace) then
                if slot.Gui then
                    slot.Gui:Destroy()
                end
                pads[pad] = nil
                continue
            end
            local slotCount = pad:GetAttribute("StashCount")
            local count = if typeof(slotCount) == "number" then slotCount else 0
            if count == 0 or pad:GetAttribute("StashItemType") ~= "Ingredient" then
                if slot.Gui then
                    slot.Gui:Destroy()
                end
                slot.Gui, slot.Signature, slot.Pips = nil, "", {}
                continue
            end
            local items, key = DisplayState.Read(pad, now)
            if not slot.Gui or slot.Signature ~= key then
                local old = slot.Pips
                if slot.Gui then
                    slot.Gui:Destroy()
                end
                local gui = Instance.new("BillboardGui")
                gui.Name = "StashRipeness"
                RipenessStyle.ConfigureIndicator(gui, pad)
                gui.AlwaysOnTop = true
                gui.ResetOnSpawn = false
                gui.Parent = playerGui
                slot.Pips = {}
                for order, item in items do
                    local view = pip(gui, order)
                    view.Ripe = old[item.Id] and old[item.Id].Ripe or item.Ripe
                    slot.Pips[item.Id] = view
                end
                slot.Gui, slot.Signature = gui, key
            end
            local gui = slot.Gui
            if gui then
                local origin = RipenessStyle.ResolveOrigin(pad)
                if gui.Adornee ~= origin then
                    gui.Adornee = origin
                end
                for _, item in items do
                    local view = slot.Pips[item.Id]
                    if view then
                        renderPip(view, item.Progress, item.Ripe or item.Progress >= 1)
                    end
                end
            end
        end
    end)
end

return Controller
