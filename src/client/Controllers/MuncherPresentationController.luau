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

local function purchaseDisplay(pad: BasePart, playerGui: PlayerGui, acquire: (Instance) -> ()): BillboardGui
    local gui = Instance.new("BillboardGui")
    acquire(gui)
    gui.Name = "MuncherPurchase"
    -- Decorative purchase view: never consume world or Throw taps.
    gui.Active = false
    gui.Adornee = pad
    -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
    BillboardStyle.ApplyBillboard(gui, { WidthStuds = 10.9, HeightStuds = 2.0, MaxDistance = 40 })
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    for index, text in { "MUNCHER", "$100K" } do
        local label = Instance.new("TextLabel")
        label.Parent = gui
        label.Name = if index == 1 then "Title" else "Detail"
        label.Active = false
        BillboardStyle.ApplyText(label, {})
        Style.Apply(label :: TextLabel, 24, gui)
        label.Size = UDim2.fromScale(1, 0.5)
        label.Position = UDim2.fromScale(0, (index - 1) / 2)
        label.TextScaled = true
        label.Text = text
        if index == 2 then
            label.TextColor3 = Style.Gold
        end
    end
    gui.Parent = playerGui
    return gui
end

local function destroyView(view: any)
    -- Cleanup failures must not prevent disposal of the remaining resources or plots.
    if view.Cleanup then
        pcall(view.Cleanup)
    end
    for _, object in view.Owned do
        object:Destroy()
    end
end

local function eligible(model: Instance, plot: Instance): boolean
    return plot:IsDescendantOf(workspace)
        and CollectionService:HasTag(plot, "PlayerPlot")
        and plot:FindFirstChild("Muncher") == model
end

local function describe(object: Instance?): string
    return if object then object.ClassName .. " " .. object:GetFullName() else "nil"
end

local function failureDiagnostic(
    model: Instance,
    plot: Instance,
    id: number,
    original: Instance?,
    reason: string
): string
    local details = { "model#" .. id .. "=" .. describe(model), "originalLookup=" .. describe(original), reason }
    -- Ancillary engine properties are best-effort; diagnostics must never abort a scan.
    local ok, extra = pcall(function()
        local siblings, matches, listed = 0, 0, {}
        for _, child in plot:GetChildren() do
            if child.Name == "Muncher" then
                siblings += 1
            end
        end
        for _, child in model:GetDescendants() do
            if child.Name == "DisplayScreen" then
                matches += 1
                if #listed < 6 then
                    table.insert(listed, describe(child) .. " direct=" .. tostring(child.Parent == model))
                end
            end
        end
        return "Muncher siblings="
            .. siblings
            .. "; DisplayScreen matches="
            .. matches
            .. " ["
            .. table.concat(listed, "; ")
            .. (if matches > #listed then "; truncated" else "")
            .. "]"
    end)
    table.insert(details, if ok then extra else "hierarchy diagnostics unavailable")
    local properties: { [string]: () -> any } = {
        StreamingEnabled = function()
            return workspace.StreamingEnabled
        end,
        ModelStreamingMode = function()
            return if model:IsA("Model") then model.ModelStreamingMode else "n/a"
        end,
        InWorkspace = function()
            return model:IsDescendantOf(workspace)
        end,
    }
    for name, read in properties do
        local success, value = pcall(read)
        table.insert(details, name .. "=" .. (if success then tostring(value) else "unavailable"))
    end
    return "Muncher presentation: " .. table.concat(details, "; ")
end

local function refreshView(view: any, model: Instance, player: Player, playerGui: PlayerGui)
    local input = model:FindFirstChild("InputZone")
    local pad = model:FindFirstChild("PurchasePoint1")
    if view.Pad ~= pad then
        if view.Purchase then
            table.remove(view.Owned, table.find(view.Owned, view.Purchase))
            view.Purchase:Destroy()
        end
        view.Pad = pad
        view.Purchase = if pad and pad:IsA("BasePart")
            then purchaseDisplay(pad, playerGui, function(object)
                table.insert(view.Owned, object)
            end)
            else nil
    end
    if view.Purchase and pad and pad:IsA("BasePart") then
        view.Purchase.Enabled = pad.CanTouch and pad.Transparency < 1
    end
    local mouth = model:FindFirstChild("MouthOrigin", true)
    view.Gui.Adornee = if mouth and (mouth:IsA("Attachment") or mouth:IsA("BasePart"))
        then mouth
        elseif input and input:IsA("BasePart") then input
        else nil
    updateHint(view, model, player, workspace:GetServerTimeNow())
end

local function createView(model: Instance, plot: Instance, screen: BasePart, playerGui: PlayerGui, player: Player): any
    local owned: { Instance } = {}
    local view: any = { Plot = plot, Screen = screen, Owned = owned }
    local ok, problem = pcall(function()
        view.Animate, view.Cleanup = Effects.Bind(model, playerGui)
        local gui = Instance.new("BillboardGui")
        table.insert(owned, gui)
        gui.Name = "MuncherHint"
        gui.Active = false
        gui.Enabled = false
        BillboardStyle.ApplyBillboard(
            gui,
            { WidthStuds = 6.6, HeightStuds = 1.7, MaxDistance = 25, AlwaysOnTop = false, ResetOnSpawn = true }
        )
        local label = Instance.new("TextLabel")
        label.Parent = gui
        -- Decorative hint/result view: never consume world or Throw taps.
        -- UIStroke/UIPadding are UIComponents and have no Active property.
        label.Active = false
        label.BackgroundTransparency, label.Size = 1, UDim2.fromScale(1, 1)
        Style.Apply(label :: TextLabel, 24, gui)
        label.TextScaled = true
        gui.Parent = playerGui
        gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
        view.Gui, view.Label = gui, label
        refreshView(view, model, player, playerGui)
    end)
    if not ok then
        destroyView(view)
        error(tostring(problem), 0)
    end
    return view
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
    local failures: { [Instance]: { Id: number, Warned: boolean } } = {}
    local identities = setmetatable({} :: { [Instance]: number }, { __mode = "k" })
    local nextId = 0
    local function report(model: Instance, plot: Instance, original: Instance?, reason: string)
        local state = failures[model]
        if state.Warned then
            return
        end
        state.Warned = true
        local ok, diagnostic = pcall(failureDiagnostic, model, plot, state.Id, original, reason)
        warn(if ok then diagnostic else "Muncher presentation model#" .. state.Id .. ": " .. reason)
    end
    player.CharacterRemoving:Connect(function()
        for model, view in views do
            destroyView(view)
            views[model] = nil
        end
    end)
    -- Preparation shares one client budget and never runs in RenderStepped.
    RunService.Heartbeat:Connect(function()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        for model, view in views do
            local nearby = root ~= nil
                and root:IsA("BasePart")
                and (not humanoid or humanoid.Health > 0)
                and eligible(model, view.Plot)
                and model:GetAttribute("Purchased") == true
                and model:GetAttribute("Active") == true
                and (root.Position - view.Screen.Position).Magnitude <= Config.MaxDistance
            Effects.SetNearby(model, nearby)
        end
        Effects.Warm(os.clock())
    end)
    local previousCharacter = player.Character
    local elapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local alive = player.Character ~= nil and (not humanoid or humanoid.Health > 0)
        if player.Character ~= previousCharacter then
            previousCharacter = player.Character
            for model, view in views do
                destroyView(view)
                views[model] = nil
            end
        end
        if not alive then
            for model, view in views do
                updateHint(view, model, player, workspace:GetServerTimeNow())
                Effects.Cancel(model)
            end
            return
        end
        for model, view in views do
            if
                not eligible(model, view.Plot)
                or view.Screen.Name ~= "DisplayScreen"
                or not view.Screen:IsA("BasePart")
                or not view.Screen:IsDescendantOf(model)
            then
                destroyView(view)
                views[model] = nil
                continue
            end
            local now = workspace:GetServerTimeNow()
            updateHint(view, model, player, now)
            view.Animate(now, dt)
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
            if not failures[model] then
                if not identities[model] then
                    nextId += 1
                    identities[model] = nextId
                end
                failures[model] = { Id = identities[model], Warned = false }
            end
            -- Capture the old lookup at this resolution attempt, not a later snapshot.
            local original = model:FindFirstChild("DisplayScreen", true)
            local screen, reason = Effects.ResolveScreen(model)
            local view = views[model]
            if view and view.Screen ~= screen then
                destroyView(view)
                views[model], view = nil, nil
            end
            if not screen then
                report(model, plot, original, tostring(reason))
                continue
            end
            if not view then
                local ok, result = pcall(createView, model, plot, screen, playerGui, player)
                if not ok then
                    report(model, plot, original, "Bind/setup exception: " .. tostring(result))
                    continue
                end
                view = result
                views[model] = view
                continue
            end
            local ok, problem = pcall(function()
                refreshView(view, model, player, playerGui)
                return nil
            end)
            if not ok then
                destroyView(view)
                views[model] = nil
                report(model, plot, original, "View setup exception: " .. tostring(problem))
            end
        end
        for model, view in views do
            if not seen[model] then
                destroyView(view)
                views[model] = nil
            end
        end
        -- Failed models have no view, so prune their state independently.
        for model in failures do
            if not seen[model] then
                failures[model] = nil
            end
        end
    end)
end
return Controller
