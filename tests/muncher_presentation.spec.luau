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
update({ Progress = 17, Target = 50 })
check(gui:FindFirstChild("Count").Text == "17 / 50", "accepted progress displayed immediately")
local bar = gui:FindFirstChild("ProgressBar")
local fill = bar:FindFirstChild("Fill")
local countScale = gui:FindFirstChild("Count"):FindFirstChildWhichIsA("UIScale")
local barScale = bar:FindFirstChildWhichIsA("UIScale")
update({ Progress = 18, Target = 50 }, true)
check(fill.Size.X.Scale == 17 / 50, "fill starts from its current visual percentage")
step(0.09)
check(countScale.Scale == 1.15 and barScale.Scale == 1.025, "successful feed punches count and subtly bumps bar")
check(fill.Size.X.Scale > 17 / 50 and fill.Size.X.Scale < 18 / 50, "fill animates toward progress")
update({ Progress = 19, Target = 50 }, true)
update({ Progress = 20, Target = 50 }, true)
step(0.21)
check(fill.Size.X.Scale == 20 / 50, "rapid feeds settle at latest authoritative fraction")
check(countScale.Scale == 1 and barScale.Scale == 1, "rapid punches return to normal scale")
update({ Progress = 24, Target = 25 })
update({ Progress = 0, Target = 100 }, true)
check(gui:FindFirstChild("Title").Text == "FULL!", "accepted completion reacts despite synchronous goal reset")
check(gui:FindFirstChild("Count").Text == "0 / 100", "completion never delays new authoritative target")
step(0.09)
check(countScale.Scale == 1.18 and barScale.Scale == 1.07, "completion response is stronger than a normal feed")
update({ Progress = 1, Target = 100 }, true)
step(0.4)
check(
    gui:FindFirstChild("Title").Text == "FULL!" and fill.Size.X.Scale == 0.01,
    "feed during completion preserves FULL while progress converges immediately"
)
step(0.4)
check(gui:FindFirstChild("Title").Text == "MUNCHER", "completion hold eventually ends despite intervening feeds")
update({ Progress = 99, Target = 100 })
update({ Progress = 0, Target = 100 }, true)
step(0.4)
check(gui:FindFirstChild("Title").Text == "FULL!", "completion remains perceptible when the next goal is identical")
step(0.5)
check(gui:FindFirstChild("Title").Text == "MUNCHER", "completion title returns even when next goal is identical")
update({ Progress = 200, Target = 100 })
step(0.21)
check(fill.Size.X.Scale == 1, "display clamps overfull percentage")
update({ Progress = -1, Target = 100 })
step(0.21)
check(fill.Size.X.Scale == 0, "display clamps negative percentage")
update({ Progress = 0, Target = 100 })
check(gui:FindFirstChild("Count").Text == "0 / 100", "completed appetite shows fresh target")
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
    render({ Progress = 0, Target = 50 }, true)
    check(
        title.Text == "FULL!" and count.Text == "0 / 50",
        "completion takes priority while new target is immediately valid"
    )
    render({ Progress = 0, Target = 50 })
    step(0.36) -- The preceding YUM timer has now fired.
    check(title.Text == "FULL!", "stale YUM callback and goal-reset render cannot clear FULL")
    render({ Progress = 1, Target = 50 }, true)
    step(0.4)
    check(
        title.Text == "FULL!" and count.Text == "1 / 50",
        "normal feeding cannot replace perceptible FULL or delay progress"
    )
    step(0.1)
    check(title.Text == "MUNCHER", "FULL returns to idle after its own hold")

    -- A new completion also owns a new generation, independent of the old hold.
    render({ Progress = 49, Target = 50 })
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
    check(pot.Parent == visual and not pot.Anchored, "entire Visual artwork including pot stays untouched")
    local item = instance("Part")
    input.Overlaps = { item, item }
    activeOwner = {}
    heartbeat:Fire(0.1)
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
            return { Progress = acceptedProgress, Target = 25 }
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
