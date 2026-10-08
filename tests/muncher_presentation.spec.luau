-- Suite-local clock/tweens: exercise interruption and settling, not real rendering.
local animations, delays = {}, {}
local visualTime = 0
env.UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}
env.Enum.EasingStyle = { Quad = "Quad" }
env.Enum.EasingDirection = { Out = "Out" }
env.TweenInfo = {
    new = function(seconds, _, _, _, reverses)
        return { Seconds = seconds, Reverses = reverses }
    end,
}
services.TweenService = {
    Create = function(_, object, info, goals)
        local tween = { Object = object, Info = info, Goals = goals, Starts = {} }
        tween.Completed = {
            Once = function(_, callback)
                tween.OnComplete = callback
            end,
        }
        function tween:Play()
            self.At = visualTime
            for key in self.Goals do
                self.Starts[key] = self.Object[key]
            end
            table.insert(animations, self)
        end
        function tween:Cancel()
            self.Cancelled = true
        end
        return tween
    end,
}
env.task.delay = function(seconds, callback)
    table.insert(delays, { At = visualTime + seconds, Callback = callback })
end
local function step(seconds)
    visualTime += seconds
    for _, tween in animations do
        if not tween.Cancelled and not tween.Done then
            local alpha = math.min((visualTime - tween.At) / tween.Info.Seconds, if tween.Info.Reverses then 2 else 1)
            tween.Done = alpha == (if tween.Info.Reverses then 2 else 1)
            alpha = if alpha > 1 then 2 - alpha else alpha
            for key, goal in tween.Goals do
                local start = tween.Starts[key]
                tween.Object[key] = if alpha == 1
                    then goal
                    elseif alpha == 0 then start
                    elseif type(goal) == "number" then start + (goal - start) * alpha
                    else env.UDim2.fromScale(start.X.Scale + (goal.X.Scale - start.X.Scale) * alpha, goal.Y.Scale)
            end
            if tween.Done and tween.OnComplete then
                local callback = tween.OnComplete
                tween.OnComplete = nil
                callback()
            end
        end
    end
    local pending = delays
    delays = {}
    for _, delay in pending do
        if delay.At <= visualTime then
            delay.Callback()
        else
            table.insert(delays, delay)
        end
    end
end
local presentation = loadModule("MuncherPresentation")
local origin = instance("Attachment")
origin.Parent = workspaceFake
local gui, update = presentation.Display(origin)
check(
    gui.Adornee == origin and gui.MaxDistance == 36 and not gui.AlwaysOnTop,
    "compact progress display uses its authored origin and world occlusion"
)
check(gui:FindFirstChild("Title").Font == env.Enum.Font.FredokaOne, "world UI uses shared Fredoka style")
update({ Progress = 17, Target = 25 })
check(gui:FindFirstChild("Count").Text == "17 / 25", "accepted progress displayed immediately")
local bar = gui:FindFirstChild("ProgressBar")
local fill = bar:FindFirstChild("Fill")
check(
    fill:FindFirstChildWhichIsA("UICorner").CornerRadius.Scale == 1
        and bar:FindFirstChildWhichIsA("UICorner").CornerRadius.Scale == 1,
    "track and green fill each have full capsule corners"
)
local countScale = gui:FindFirstChild("Count"):FindFirstChildWhichIsA("UIScale")
local barScale = bar:FindFirstChildWhichIsA("UIScale")
update({ Progress = 18, Target = 25 }, true)
check(fill.Size.X.Scale == 17 / 25, "fill starts from its current visual percentage")
step(0.09)
check(countScale.Scale == 1.15 and barScale.Scale == 1.025, "successful feed punches count and subtly bumps bar")
check(fill.Size.X.Scale > 17 / 25 and fill.Size.X.Scale < 18 / 25, "fill animates toward progress")
update({ Progress = 19, Target = 25 }, true)
update({ Progress = 20, Target = 25 }, true)
step(0.21)
check(fill.Size.X.Scale == 20 / 25, "rapid feeds settle at latest authoritative fraction")
check(countScale.Scale == 1 and barScale.Scale == 1, "rapid punches return to normal scale")
update({ Progress = 24, Target = 25 })
update({ Progress = 0, Target = 25 }, true)
check(gui:FindFirstChild("Title").Text == "FULL!", "accepted completion reacts despite synchronous goal reset")
check(gui:FindFirstChild("Count").Text == "0 / 25", "completion never delays new authoritative target")
step(0.09)
check(countScale.Scale == 1.18 and barScale.Scale == 1.07, "completion response is stronger than a normal feed")
update({ Progress = 1, Target = 25 }, true)
step(0.4)
check(
    gui:FindFirstChild("Title").Text == "FULL!" and fill.Size.X.Scale == 1 / 25,
    "feed during completion preserves FULL while progress converges immediately"
)
step(0.4)
check(gui:FindFirstChild("Title").Text == "MUNCHER", "completion hold eventually ends despite intervening feeds")
update({ Progress = 24, Target = 25 })
update({ Progress = 0, Target = 25 }, true)
step(0.4)
check(gui:FindFirstChild("Title").Text == "FULL!", "completion remains perceptible when the next goal is identical")
step(0.5)
check(gui:FindFirstChild("Title").Text == "MUNCHER", "completion title returns even when next goal is identical")
update({ Progress = 200, Target = 25 })
step(0.21)
check(fill.Size.X.Scale == 1, "display clamps overfull percentage")
update({ Progress = -1, Target = 25 })
step(0.21)
check(fill.Size.X.Scale == 0, "display clamps negative percentage")
update({ Progress = 0, Target = 25 })
check(gui:FindFirstChild("Count").Text == "0 / 25", "completed appetite shows fresh target")
update(nil)
check(gui:FindFirstChild("Count").Text == "0 / —", "released plot clears display")
step(0.5)
check(fill.Size.X.Scale == 0 and countScale.Scale == 1 and barScale.Scale == 1, "release cancels pending presentation")
update({ Progress = 24, Target = 25 })
update({ Progress = 0, Target = 25 }, true)
gui:Destroy()
step(0.5)
update({ Progress = 1, Target = 25 }, true)
check(
    presentation.Marker(instance("Folder")) == nil and presentation.Marker(nil) == nil,
    "missing or malformed markers are safe"
)
do
    local titleGui, render = presentation.Display(origin)
    local title = titleGui:FindFirstChild("Title")
    local count = titleGui:FindFirstChild("Count")
    render({ Progress = 0, Target = 25 })
    check(title.Text == "MUNCHER", "idle title is MUNCHER")
    render({ Progress = 1, Target = 25 }, true)
    check(title.Text == "YUM!" and count.Text == "1 / 25", "accepted feed immediately enters YUM and updates progress")
    render({ Progress = 1, Target = 25 }) -- The component also publishes after intake.
    step(0.5)
    check(title.Text == "YUM!", "YUM survives idle rendering and remains visible for half a second")
    step(0.06)
    check(title.Text == "MUNCHER", "YUM returns to idle after its hold")

    render({ Progress = 2, Target = 25 }, true)
    step(0.2)
    render({ Progress = 3, Target = 25 }, true)
    step(0.36)
    check(title.Text == "YUM!", "old YUM callback cannot clear a refreshed YUM")
    step(0.2)
    check(title.Text == "MUNCHER", "refreshed YUM ends half a second after the latest feed")

    render({ Progress = 24, Target = 25 }, true)
    step(0.2)
    render({ Progress = 0, Target = 25 }, true)
    check(
        title.Text == "FULL!" and count.Text == "0 / 25",
        "completion takes priority while new target is immediately valid"
    )
    render({ Progress = 0, Target = 25 })
    step(0.36) -- The preceding YUM timer has now fired.
    check(title.Text == "FULL!", "stale YUM callback and goal-reset render cannot clear FULL")
    render({ Progress = 1, Target = 25 }, true)
    step(0.4)
    check(
        title.Text == "FULL!" and count.Text == "1 / 25",
        "normal feeding cannot replace perceptible FULL or delay progress"
    )
    step(0.1)
    check(title.Text == "MUNCHER", "FULL returns to idle after its own hold")

    -- A new completion also owns a new generation, independent of the old hold.
    render({ Progress = 24, Target = 25 })
    render({ Progress = 0, Target = 25 }, true)
    step(0.4)
    render({ Progress = 24, Target = 25 })
    render({ Progress = 0, Target = 25 }, true)
    step(0.46)
    check(title.Text == "FULL!", "older FULL callback cannot end a newer completion hold")
    step(0.4)
    check(title.Text == "MUNCHER", "latest completion hold ends normally")

    for progress = 1, 10 do
        render({ Progress = progress, Target = 25 }, true)
        render({ Progress = progress, Target = 25 })
        step(0.1)
        check(title.Text == "YUM!", "rapid feeds refresh title without stale callback corruption")
    end
    step(0.46)
    check(
        title.Text == "MUNCHER" and count.Text == "10 / 25",
        "rapid feeding settles with immediate authoritative count"
    )
    render({ Progress = 11, Target = 25 }, true)
    step(0.2)
    render(nil)
    check(title.Text == "MUNCHER", "release immediately clears temporary title")
    render({ Progress = 1, Target = 25 }, true)
    step(0.36)
    check(title.Text == "YUM!", "released generation cannot clear new session feedback")
    step(0.2)
    check(title.Text == "MUNCHER", "new session title returns normally")
    render({ Progress = 24, Target = 25 })
    render({ Progress = 0, Target = 25 }, true)
    titleGui:Destroy()
    step(0.9)
    check(title.Text == "FULL!", "destroyed display cannot be mutated by a pending title callback")
end
-- Missing fixtures do not stop attachment; adding them later repairs intake and UI.
local cleanup
local activeOwner = nil
local acceptedProgress = 0
cache.WorldUtil.BindTag = function(_, attach)
    local plot = instance("Model")
    plot.Name, plot.Parent = "Plot", workspaceFake
    cleanup = attach(plot)
    local model = instance("Model")
    model.Name, model.Parent = "Muncher", plot
    local visual = instance("Model")
    visual.Name, visual.Parent = "Visual", model
    local pad = instance("Part")
    pad.Name, pad.Parent, pad.Transparency, pad.CanCollide = "PurchasePoint1", model, 0, true
    pad.Touched = signal()
    local pot = instance("Part")
    pot.Name, pot.Parent, pot.Anchored = "Potted Plant", visual, false
    local input = instance("Part")
    input.Name, input.Parent, input.CanCollide = "InputZone", model, true
    local legacyPrompt = instance("ProximityPrompt")
    legacyPrompt.Name, legacyPrompt.Parent = "FeedMuncher", input
    local display = instance("Part")
    display.Name, display.Parent = "DisplayOrigin", model
    heartbeat:Fire(0.1)
    check(
        not input.CanCollide and not input.CanTouch and input.CanQuery and input.Transparency == 1,
        "intake repaired after late fixtures arrive and cannot block players"
    )
    check(display:FindFirstChild("MuncherProgress") ~= nil, "late display marker receives progress UI")
    check(input:FindFirstChildWhichIsA("ProximityPrompt", true) == nil, "Muncher intake has no manual Feed prompt")
    check(
        pot.Parent == visual and pot.Anchored and pot.CFrame.Position.Y == -6,
        "unbought artwork stays in original hierarchy and starts six studs below rest"
    )
    check(pad.CFrame.Position.Y == 0 and pad.Transparency == 0, "purchase pad stays at authored accessible position")
    check(not display:FindFirstChild("MuncherProgress").Enabled, "unbought display is inactive")
    local item = instance("Part")
    input.Overlaps = { item, item }
    activeOwner = {}
    heartbeat:Fire(0.1)
    check(
        pot.CFrame.Position.Y == 0 and pad.CFrame.Position.Y == 0 and pad.Transparency == 1,
        "reveal places multipart artwork at rest and hides stationary pad"
    )
    local displayGui = display:FindFirstChild("MuncherProgress")
    check(
        displayGui:FindFirstChild("Count").Text == "1 / 25",
        "physical intake publishes one accepted progress for duplicate overlap parts"
    )
    step(0.09)
    local scale = displayGui:FindFirstChild("Count"):FindFirstChildWhichIsA("UIScale")
    check(math.abs(scale.Scale - 1.15) < 0.000001, "accepted physical intake triggers count feedback")
    step(0.2)
    heartbeat:Fire(0.1)
    step(0.09)
    check(scale.Scale == 1 and acceptedProgress == 1, "rejected or idle intake does not retrigger feedback or progress")
end
local component = loadModule("MuncherComponent")
component.Init({
    TycoonService = {
        GetOwner = function()
            return activeOwner
        end,
    },
    MuncherService = {
        GetSnapshot = function()
            return {
                Progress = acceptedProgress,
                Target = 25,
                Purchased = true,
                Active = true,
                ReadyAt = -1,
                BuffExpiresAt = 0,
            }
        end,
        CompleteReveal = function()
            return true
        end,
        TryFeed = function(_, _, item)
            if item:GetAttribute("Consumed") then
                return false
            end
            item:SetAttribute("Consumed", true)
            acceptedProgress += 1
            return true
        end,
    },
    IngredientService = {
        Resolve = function(item)
            return item
        end,
        GetRecord = function()
            return nil
        end,
    },
})
cleanup()

-- Controlled reveal handles multipart/nested artwork and excludes the pad.
do
    local model = instance("Model")
    model.Parent = workspaceFake
    local visual = instance("Model")
    visual.Name, visual.Parent = "Visual", model
    local nested = instance("Model")
    nested.Parent = visual
    local first, second = instance("Part"), instance("Part")
    first.Parent, second.Parent = visual, nested
    first.CFrame, second.CFrame = frame(3, 10, 4), frame(5, 14, 8)
    first.CanCollide, second.CanCollide = true, true
    local pad = instance("Part")
    pad.Name, pad.Parent, pad.CFrame = "PurchasePoint1", model, frame(0, 2, 0)
    local marker = instance("Attachment")
    marker.Name, marker.Parent, marker.WorldCFrame = "MouthOrigin", model, frame(0, 15, 0)
    local move, restore = loadModule("MuncherReveal").Bind(model)
    check(
        first.CFrame.Position.Y == 4 and second.CFrame.Position.Y == 8 and marker.WorldCFrame.Position.Y == 9,
        "all artwork and free markers start six studs below authored rest"
    )
    check(
        first.Anchored and second.Anchored and not first.CanCollide,
        "moving assembly is anchored with collision disabled"
    )
    local revealState = { Purchased = true, ReadyAt = now + 0.95 }
    now += 0.475
    check(
        not move(revealState) and math.abs(first.CFrame.Position.Y - 8.5) < 0.0001,
        "smooth Quad-Out midpoint does not activate intake early"
    )
    check(
        math.abs(second.CFrame.Position.Y - first.CFrame.Position.Y - 4) < 0.0001 and pad.CFrame.Position.Y == 2,
        "multipart spacing remains stable and purchase pad never moves"
    )
    now = revealState.ReadyAt
    check(
        move(revealState) and first.CFrame.Position.Y == 10 and second.CFrame.Position.Y == 14 and first.CanCollide,
        "completed reveal restores authored rest and collision"
    )
    move(nil)
    check(
        first.CFrame.Position.Y == 4 and pad.CFrame.Position.Y == 2,
        "released session returns assembly underground with pad accessible"
    )
    restore()
    check(
        first.CFrame.Position.Y == 10 and marker.WorldCFrame.Position.Y == 15,
        "component removal restores authored locations"
    )
end

-- Shared tutorial lifecycle and client countdown use real modules with a fake clock.
env.UDim2.new = function(xs, xo, ys, yo)
    return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
local tooltip = loadModule("TutorialTooltip")
local playerGui = instance("PlayerGui")
playerGui.Parent = workspaceFake
tooltip.Show(playerGui, "TooltipLifecycle", "Tutorial text")
local tooltipGui = playerGui:FindFirstChild("TooltipLifecycle")
local card = tooltipGui:FindFirstChildWhichIsA("CanvasGroup")
local label = card:FindFirstChildWhichIsA("TextLabel")
check(
    card.GroupTransparency == 1 and label.Parent == card,
    "tutorial text and outline enter inside one composited fade"
)
step(0.19)
check(
    card.GroupTransparency == 0 and tooltipGui.Parent == playerGui,
    "tutorial background and text finish entering together"
)
step(4.12)
check(
    tooltipGui.Parent == playerGui and card.GroupTransparency == 0,
    "existing ripeness tutorial hold timing is preserved"
)
step(0.2)
check(
    card.GroupTransparency > 0 and card.GroupTransparency < 1 and label.Parent == card,
    "exit keeps card, text and outline in the same fading group"
)
step(0.26)
check(tooltipGui.Parent == nil, "fade completion removes the entire tooltip together")
tooltip.Show(playerGui, "DestroyedTooltip", "Early cleanup")
playerGui:FindFirstChild("DestroyedTooltip"):Destroy()
step(5)
check(playerGui:FindFirstChild("DestroyedTooltip") == nil, "destroyed tooltip ignores pending exit work")

local localPlayer = instance("Player")
localPlayer:SetAttribute("PlotSessionId", "muncher-session")
localPlayer.WaitForChild = function()
    return playerGui
end
services.Players.LocalPlayer = localPlayer
local uiPlot = instance("Model")
uiPlot.Parent = workspaceFake
uiPlot:SetAttribute("PlotSessionId", "muncher-session")
services.CollectionService:AddTag(uiPlot, "PlayerPlot")
local uiModel = instance("Model")
uiModel.Name, uiModel.Parent = "Muncher", uiPlot
local uiOrigin = instance("Part")
uiOrigin.Name, uiOrigin.Parent = "DisplayOrigin", uiModel
parent.Parent.UI = { TutorialTooltip = "TutorialTooltip", WorldBillboardStyle = "WorldBillboardStyle" }
local purchasePad = instance("Part")
purchasePad.Name, purchasePad.Parent = "PurchasePoint1", uiModel
purchasePad.CFrame = frame(4, 0.5, 8)
purchasePad.CanTouch, purchasePad.Transparency = true, 0
loadModule("MuncherPresentationController").Init()
heartbeat:Fire(0.1)
check(playerGui:FindFirstChild("MuncherTutorial") == nil, "locked Muncher does not show tutorial")
local purchaseGui = playerGui:FindFirstChild("MuncherPurchase")
check(
    purchaseGui.Parent == playerGui
        and purchaseGui.Adornee == purchasePad
        and purchaseGui.StudsOffsetWorldSpace.Y == 2
        and purchaseGui.AlwaysOnTop
        and purchaseGui.MaxDistance == 28
        and purchaseGui.ResetOnSpawn == false,
    "purchase signage uses Farm's client canvas, pad origin, world lift and visibility conventions"
)
check(
    purchaseGui.Size.X.Scale == 0
        and purchaseGui.Size.X.Offset == 340
        and purchaseGui.Size.Y.Scale == 0
        and purchaseGui.Size.Y.Offset == 64,
    "purchase signage matches Farm fixed-pixel sizing"
)
local purchaseTitle, purchasePrice = purchaseGui:FindFirstChild("Title"), purchaseGui:FindFirstChild("Detail")
check(
    purchaseTitle.Text == "MUNCHER"
        and purchasePrice.Text == "$100K"
        and purchaseTitle.Font == env.Enum.Font.FredokaOne
        and purchasePrice.Font == env.Enum.Font.FredokaOne
        and purchaseTitle.TextSize == 24
        and purchasePrice.TextSize == 24
        and not purchaseTitle.TextScaled
        and not purchasePrice.TextScaled,
    "purchase wording and Farm Fredoka font/scaling are preserved"
)
check(
    purchaseTitle.Position.Y.Offset == 0
        and purchasePrice.Position.Y.Offset == 32
        and purchaseTitle.Size.Y.Offset == 32
        and purchasePrice.Size.Y.Offset == 32
        and purchaseTitle.TextColor3 == loadModule("DialogueTextStyle").White
        and purchasePrice.TextColor3 == loadModule("DialogueTextStyle").Gold,
    "purchase rows match Farm label layout and colors"
)
for _ = 1, 3 do
    purchasePad.CanTouch, purchasePad.Transparency = false, 1
    heartbeat:Fire(0.1)
    check(
        not purchaseGui.Enabled and purchasePad.CFrame.Position.Y == 0.5,
        "successful purchase hides stationary pad signage"
    )
    purchasePad.CanTouch, purchasePad.Transparency = true, 0
    heartbeat:Fire(0.1)
    check(
        purchaseGui.Enabled
            and playerGui:FindFirstChild("MuncherPurchase") == purchaseGui
            and purchaseGui.StudsOffsetWorldSpace.Y == 2
            and purchasePad.CFrame.Position.Y == 0.5,
        "session reset restores the same elevated label without moving the pad"
    )
end
local purchaseCount = 0
for _, child in playerGui:GetChildren() do
    if child.Name == "MuncherPurchase" then
        purchaseCount += 1
    end
end
check(
    purchaseCount == 1 and purchasePad:FindFirstChild("MuncherPurchase") == nil,
    "repeated resets never accumulate server or client purchase billboards"
)
uiModel:SetAttribute("Active", true)
uiModel:SetAttribute("ActiveBuff", "Cash125")
uiModel:SetAttribute("BuffExpiresAt", now + 300)
heartbeat:Fire(0.1)
local buffGui = playerGui:FindFirstChild("MuncherBuff")
local labels = buffGui:GetChildren()
check(
    labels[1].Text == "CASH BOOST 1.25x" and labels[2].Text == "5:00",
    "buff billboard shows existing effect and five-minute countdown"
)
check(
    buffGui.Adornee == uiOrigin and buffGui.StudsOffsetWorldSpace.Y > 0.65 and buffGui.MaxDistance == 36,
    "compact buff display sits above normal progress at authored DisplayOrigin"
)
local muncherTutorial = playerGui:FindFirstChild("MuncherTutorial")
check(
    muncherTutorial:FindFirstChildWhichIsA("CanvasGroup"):FindFirstChildWhichIsA("TextLabel").Text
        == "FEED MUNCHER to receive a temporary buff!",
    "Muncher tutorial wording is exact"
)
now += 1
heartbeat:Fire(0.1)
check(labels[2].Text == "4:59", "client countdown advances from server expiry without per-second remotes")
now += 298
heartbeat:Fire(0.1)
check(labels[2].Text == "0:01", "last second stays readable")
now += 1
heartbeat:Fire(0.1)
check(
    playerGui:FindFirstChild("MuncherBuff") == nil,
    "buff display is removed at expiry even before replicated state clears"
)
muncherTutorial:Destroy()
uiModel:SetAttribute("Active", false)
heartbeat:Fire(0.1)
uiModel:SetAttribute("Active", true)
heartbeat:Fire(0.1)
check(playerGui:FindFirstChild("MuncherTutorial") == nil, "tutorial remains one-time per player session")

purchasePad.Parent = nil
heartbeat:Fire(0.1)
check(playerGui:FindFirstChild("MuncherPurchase") == nil, "removed purchase pad cleans up client signage")
