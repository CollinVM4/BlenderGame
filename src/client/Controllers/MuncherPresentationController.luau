--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local BillboardStyle = require(script.Parent.Parent.UI.WorldBillboardStyle)
local PromptPresentation = require(script.Parent.Parent.UI.InteractionPromptPresentation)
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
    if
        model:GetAttribute("Active") ~= true
        or model:GetAttribute("Phase") ~= "Idle"
        or workspace:GetServerTimeNow() < (model:GetAttribute("AvailableAt") or 0)
    then
        return "MUNCHER BUSY"
    end
    local character = player.Character
    local tools: { Instance } = if character then character:GetChildren() else {}
    for _, tool in tools do
        if tool:IsA("Tool") and tool:GetAttribute("IngredientId") == nil then
            return "NEED INGREDIENT"
        end
    end
    if player:GetAttribute("HeldItemType") ~= "Ingredient" or player:GetAttribute("HeldIngredientId") == nil then
        return "NEED INGREDIENT"
    end
    return "FEED MUNCHER"
end

local function purchaseDisplay(pad: BasePart, playerGui: PlayerGui): BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "MuncherPurchase"
    gui.Adornee = pad
    -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
    BillboardStyle.ApplyBillboard(gui, { WidthStuds = 9.1, HeightStuds = 1.7, MaxDistance = 40 })
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    for index, text in { "MUNCHER", "$100K" } do
        local label = Instance.new("TextLabel")
        label.Name = if index == 1 then "Title" else "Detail"
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
    local promptViews: { [ProximityPrompt]: () -> () } = {}
    local function hide(prompt: ProximityPrompt)
        local cleanup = promptViews[prompt]
        if cleanup then
            cleanup()
            promptViews[prompt] = nil
        end
    end
    ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        if prompt:GetAttribute("MuncherPrompt") ~= true or not prompt.Parent then
            return
        end
        hide(prompt)
        local cleanup, gui = PromptPresentation.Create(prompt, prompt.Parent :: BasePart, playerGui, inputType, {
            MaxDistance = Config.FeedDistance,
            WidthStuds = 6.9,
            Available = function()
                return prompt.Enabled
            end,
        })
        local label = gui:FindFirstChild("Action")
        if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
            Style.Apply(label :: TextLabel, 24)
        end
        promptViews[prompt] = cleanup
    end)
    ProximityPromptService.PromptHidden:Connect(hide)
    local elapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        for _, view in views do
            view.Animate(workspace:GetServerTimeNow())
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
                gui.Name = "MuncherStatus"
                BillboardStyle.ApplyBillboard(
                    gui,
                    { WidthStuds = 4.5, HeightStuds = 1.2, MaxDistance = 40, AlwaysOnTop = false, ResetOnSpawn = true }
                )
                local label = Instance.new("TextLabel")
                label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
                Style.Apply(label :: TextLabel, 24)
                label.TextScaled = true
                label.Parent, gui.Parent = gui, playerGui
                local animate, cleanup = Effects.Bind(model, playerGui)
                view = { Gui = gui, Label = label, Animate = animate, Cleanup = cleanup }
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
            local feedback = Controller.Feedback(model, plot, player)
            view.Gui.Adornee = if input and input:IsA("BasePart") then input else nil
            view.Label.Text = feedback
            view.Gui.Enabled = feedback ~= "FEED MUNCHER" and model:GetAttribute("Purchased") == true
            local prompt = input and input:FindFirstChild("FeedMuncher")
            if prompt and prompt:IsA("ProximityPrompt") then
                prompt.Enabled = feedback == "FEED MUNCHER"
                if not prompt.Enabled then
                    hide(prompt)
                end
            end
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
        for prompt in promptViews do
            if not prompt:IsDescendantOf(workspace) or not prompt.Enabled then
                hide(prompt)
            end
        end
    end)
end
return Controller
