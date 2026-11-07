-- Presentation policy is independent of authoritative gameplay suites.
local function inactiveView(root)
    local subtree = root:GetDescendants()
    table.insert(subtree, root)
    for _, object in subtree do
        if
            object:IsA("GuiObject")
            or object:IsA("GuiBase3d")
            or object:IsA("BillboardGui")
            or object:IsA("SurfaceGui")
        then
            check(object.Active == false, root.Name .. " never consumes world or Throw taps: " .. object.ClassName)
        end
        check(not object:IsA("GuiButton"), "decorative view contains no input target")
    end
end
cache.MuncherEffects = {
    ResolveScreen = function(model)
        return model:FindFirstChild("DisplayScreen")
    end,
    Cancel = function() end,
    SetNearby = function() end,
    Warm = function() end,
    Bind = function()
        return function() end, function() end
    end,
}
cache.InteractionPromptPresentation = {}
services.RunService.Heartbeat = signal()
local controller = loadModule("MuncherPresentationController")
local config = loadModule("Muncher")
local actor = instance("Player")
actor.Character = instance("Model")
local plot = instance("Model")
local model = instance("Model")
local hintScreen = instance("Part")
hintScreen.Name, hintScreen.Parent = "DisplayScreen", model
local function feedback()
    return controller.Feedback(model, plot, actor)
end
check(feedback() == "NOT YOUR MUNCHER", "unassigned visitor has no feed action")
plot:SetAttribute("PlotSessionId", "session")
actor:SetAttribute("PlotSessionId", "session")
check(feedback() == "LOCKED", "purchase state readable")
model:SetAttribute("Purchased", true)
model:SetAttribute("Active", true)
model:SetAttribute("Phase", "Idle")
check(feedback() == "FEED ME", "eligible idle machine invites throwing even with empty hands")
actor:SetAttribute("HeldItemType", "Smoothie")
check(feedback() == "FEED ME", "hint is independent of equipped item")
for _, phase in { "Processing", "Spitting" } do
    model:SetAttribute("Phase", phase)
    check(feedback() == "", "hint hidden while busy")
    model:SetAttribute("BusyUntil", now + config.BusySeconds)
    check(feedback() == "BUSY" .. utf8.char(0x2026), "rejected attempt briefly explains busy state")
    now += config.BusySeconds
    check(feedback() == "", "busy hint expires")
end
model:SetAttribute("Phase", "Idle")
model:SetAttribute("AvailableAt", now + config.SpitSeconds)
check(feedback() == "", "hint respects spit cooldown")
now += config.SpitSeconds
check(feedback() == "FEED ME", "idle hint recovers")
model:SetAttribute("Active", false)
check(feedback() == "", "hint hidden throughout reveal")
model:SetAttribute("Active", true)
actor:SetAttribute("PlotSessionId", "other")
check(feedback() == "NOT YOUR MUNCHER", "visitor has no feed hint")
actor:SetAttribute("PlotSessionId", "session")
check(feedback() == "FEED ME", "teammate session can see hint")

-- Render the real hint and busy/banner view; decorative UI never owns input.
-- Engine hit-testing and the physical Throw loop still require mobile Studio checks.
do
    local playerGui = instance("PlayerGui")
    services.Players.LocalPlayer = actor
    actor.WaitForChild = function()
        return playerGui
    end
    local render = signal()
    services.RunService.RenderStepped = render
    services.CollectionService.GetInstanceAddedSignal = function()
        return signal()
    end
    plot.Parent, model.Parent, model.Name = workspaceFake, plot, "Muncher"
    local pad = instance("Part")
    pad.Name, pad.Parent = "PurchasePoint1", model
    pad.CanTouch, pad.Transparency = true, 0
    services.CollectionService:AddTag(plot, "PlayerPlot")
    controller.Init()
    local function inactiveHint(expected)
        render:Fire(config.ScanInterval)
        local hint = playerGui:FindFirstChild("MuncherHint")
        check(hint and hint.Enabled and hint.Active == false, "visible hint billboard is explicitly inactive")
        local label = hint:FindFirstChildOfClass("TextLabel")
        check(label.Text == expected and label.Active == false, "hint/banner label never consumes Throw taps")
        inactiveView(hint)
        local purchase = playerGui:FindFirstChild("MuncherPurchase")
        check(purchase and purchase.Enabled and purchase.Adornee == pad, "purchase view remains visible on its pad")
        check(
            purchase:FindFirstChild("Title").Text == "MUNCHER" and purchase:FindFirstChild("Detail").Text == "$100K",
            "purchase view includes title and price"
        )
        inactiveView(purchase)
        check(pad.CanTouch and pad.Transparency == 0, "informational view preserves purchase pad interaction")
    end
    inactiveHint("FEED ME")
    model:SetAttribute("Phase", "Processing")
    model:SetAttribute("BusyUntil", now + config.BusySeconds)
    inactiveHint("BUSY" .. utf8.char(0x2026))
    now += config.BusySeconds
    render:Fire(config.ScanInterval)
    check(not playerGui:FindFirstChild("MuncherHint").Enabled, "inactive busy banner keeps its expiry")
    model:SetAttribute("Phase", "Idle")
    local hint = playerGui:FindFirstChild("MuncherHint")
    local label = hint:FindFirstChildOfClass("TextLabel")
    local white = loadModule("DialogueTextStyle").White
    local sequence = 0
    local function beginResult(result)
        sequence += 1
        model:SetAttribute("Sequence", sequence)
        model:SetAttribute("ResultKind", result)
        model:SetAttribute("Phase", "Processing")
        render:Fire(0)
        check(not hint.Enabled, "new conversion immediately clears hint/result before the next scan")
    end
    local function completeResult()
        now += config.ChewSeconds
        -- Match the real idle snapshot: result is cleared before phase publication.
        model:SetAttribute("ResultKind", nil)
        model:SetAttribute("Phase", "Idle")
        model:SetAttribute("AvailableAt", now + config.SpitSeconds)
        render:Fire(0)
    end
    for _, result in { "Win", "Lose" } do
        beginResult(result)
        model:SetAttribute("Phase", "Spitting")
        render:Fire(0)
        check(not hint.Enabled, "pending spit/retry never announces output early")
        completeResult()
        local expected = if result == "Win" then "YOU WIN!" else "YOU LOSE!"
        local expectedColor = if result == "Win" then color(120 / 255, 1, 140 / 255) else color(1, 120 / 255, 120 / 255)
        check(hint.Enabled and label.Text == expected, "spawn completion shows exact " .. result .. " banner")
        check(
            label.TextColor3.R == expectedColor.R
                and label.TextColor3.G == expectedColor.G
                and label.TextColor3.B == expectedColor.B,
            "result uses requested " .. result .. " color"
        )
        check(playerGui:FindFirstChild("MuncherHint") == hint and label.TextScaled, "result reuses the scaled hint")
        now += 1.99
        render:Fire(0)
        check(label.Text == expected, "result remains visible for two seconds")
        now += 0.01
        render:Fire(0)
        check(
            hint.Enabled and label.Text == "FEED ME" and label.TextColor3 == white,
            "expiry restores idle hint and color"
        )
    end
    beginResult("Win")
    completeResult()
    beginResult("Push")
    completeResult()
    check(not hint.Enabled, "push does not override the ordinary spit cooldown")
    now += config.SpitSeconds
    render:Fire(0)
    check(hint.Enabled and label.Text == "FEED ME" and label.TextColor3 == white, "push leaves normal hint unchanged")

    beginResult("Win")
    model:SetAttribute("ResultKind", nil)
    model:SetAttribute("Phase", "Idle")
    render:Fire(0)
    check(label.Text == "FEED ME", "interruption without output never creates a banner")
    for _, reason in { "visitor", "inactive", "locked", "death" } do
        beginResult("Lose")
        completeResult()
        local humanoid = instance("Humanoid")
        humanoid.Health, humanoid.Parent = 100, actor.Character
        if reason == "visitor" then
            actor:SetAttribute("PlotSessionId", "other")
        elseif reason == "inactive" then
            model:SetAttribute("Active", false)
        elseif reason == "locked" then
            model:SetAttribute("Purchased", false)
        elseif reason == "death" then
            humanoid.Health = 0
        else
            plot.Parent = nil
        end
        render:Fire(0)
        check(not hint.Enabled, reason .. " immediately hides result")
        actor:SetAttribute("PlotSessionId", "session")
        model:SetAttribute("Active", true)
        model:SetAttribute("Purchased", true)
        humanoid:Destroy()
        plot.Parent = workspaceFake
        now += config.SpitSeconds
        render:Fire(0)
        check(
            hint.Enabled and label.Text == "FEED ME",
            reason .. " clears result without replay on eligibility recovery"
        )
    end
    beginResult("Win")
    completeResult()
    plot.Parent = nil
    render:Fire(0)
    check(
        hint.Parent == nil and playerGui:FindFirstChild("MuncherPurchase") == nil,
        "stream-away immediately disposes the result/hint and purchase views"
    )
    plot.Parent = workspaceFake
    now += config.SpitSeconds
    render:Fire(config.ScanInterval)
    hint = playerGui:FindFirstChild("MuncherHint")
    label = hint:FindFirstChildOfClass("TextLabel")
    check(hint.Enabled and label.Text == "FEED ME", "stream recovery binds a fresh view without replaying result")
    actor:SetAttribute("PlotSessionId", "other")
    beginResult("Win")
    completeResult()
    check(not hint.Enabled, "visitor observing whole conversion never gets result")
    actor:SetAttribute("PlotSessionId", "session")
    services.CollectionService:RemoveTag(plot, "PlayerPlot")
    render:Fire(config.ScanInterval)
    check(playerGui:FindFirstChild("MuncherHint") == nil, "view removal destroys the shared result/hint billboard")
    check(playerGui:FindFirstChild("MuncherPurchase") == nil, "view removal destroys purchase billboard")
    plot.Parent = nil
end

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

-- Effects use replicated phase/time/rarity only and restore authored geometry on interruption.
cache.MuncherEffects = nil
env.Vector3.one = vec(1, 1, 1)
env.TweenInfo = {
    new = function()
        return {}
    end,
}
services.TweenService = {
    Create = function()
        return { Play = function() end }
    end,
}
parent.Parent.Controllers = parent
local cues, spinStopped = {}, false
cache.GameplayAudioController = {
    PlayMuncher = function(kind)
        table.insert(cues, kind)
        return function()
            if kind == "Roll" then
                spinStopped = true
            end
        end
    end,
}
-- Any geometry preparation or attachment in the image path is a failure.
local previewCreations = 0
cache.IngredientViewport = {
    Prepare = function()
        previewCreations += 1
        error("Muncher image path attempted viewport preparation")
    end,
    Create = function()
        error("Muncher image path attempted viewport attachment")
    end,
}
local artworkConfig = loadModule("MuncherArtwork")
local rewardIds = artworkConfig.RewardIds()
check(#rewardIds == 39, "current reward union is 39 canonical IDs")
artworkConfig.Enabled = false
artworkConfig.Images = {}
check(
    #artworkConfig.Missing() == #rewardIds and not artworkConfig.IsReady(),
    "incomplete artwork fixture blocks release"
)
artworkConfig.Enabled = true
check(not artworkConfig.IsReady(), "enabling alone cannot bypass incomplete coverage")
for index, id in rewardIds do
    artworkConfig.Images[id] = "rbxassetid://" .. (100000 + index)
end
artworkConfig.Images.Apple = "rbxassetid://0"
check(table.find(artworkConfig.Missing(), "Apple") ~= nil, "coverage names an invalid image URI")
artworkConfig.Images.Apple = "rbxassetid://100001"
check(artworkConfig.IsReady(), "complete fixture coverage permits the image path")
local oldInstanceNew = env.Instance.new
env.Instance.new = function(class)
    local object = oldInstanceNew(class)
    if class == "ImageLabel" then
        object.IsLoaded = true
    end
    return object
end
local preloadJobs, preloadCalls = {}, {}
local oldTask = env.task
env.task = {
    defer = function(fn)
        table.insert(preloadJobs, fn)
    end,
    spawn = function(fn)
        table.insert(preloadJobs, fn)
    end,
    wait = function() end,
}
services.ContentProvider = {
    PreloadAsync = function(_, batch)
        check(#batch <= 4, "preload batches contain at most four images")
        table.insert(preloadCalls, batch)
        if #preloadCalls == 1 then
            error("unavailable art")
        end
    end,
}
env.Enum.ScaleType = { Fit = "Fit" }
env.Enum.NormalId = { Front = "Front" }
env.Enum.SurfaceGuiSizingMode = { PixelsPerStud = "PixelsPerStud" }
local effects = loadModule("MuncherEffects")
-- Workspace lookup uses the same live child traversal as the instance boundary.
workspaceFake.Children = {}
workspaceFake.FindFirstChild = instance("Folder").FindFirstChild
workspaceFake.GetChildren = instance("Folder").GetChildren
local effectModel = instance("Model")
local visual = instance("Model")
visual.Name, visual.Parent = "Visual", effectModel
local artwork = instance("Part")
artwork.Parent, artwork.CFrame = visual, frame(0, 4, 0)
local mouth = instance("Part")
mouth.Name, mouth.Parent = "MouthOrigin", effectModel
local display = instance("Part")
display.Name, display.Parent = "DisplayScreen", effectModel
display.CFrame, display.Size = frame(0, 6, -1), vec(6.6, 3.2, 0.1)
local displayFrame, displaySize = display.CFrame, display.Size
local guiRoot = instance("PlayerGui")
effectModel:SetAttribute("Purchased", true)
effectModel:SetAttribute("Sequence", 1)
effectModel:SetAttribute("Phase", "Processing")
effectModel:SetAttribute("StartedAt", now)
effectModel:SetAttribute("OutputRarity", "Rare")
effectModel:SetAttribute("OutputId", "Dragon_Fruit")
effectModel:SetAttribute("ResultKind", "Win")
local animate, stop = effects.Bind(effectModel, guiRoot)
animate(now)
local reels = guiRoot:FindFirstChildOfClass("SurfaceGui")
check(reels ~= nil and #reels:GetChildren() == 3, "three clipped reels replace fading heart burst")
inactiveView(reels)
check(
    reels.Adornee == display
        and reels.Face == env.Enum.NormalId.Front
        and reels.SizingMode == env.Enum.SurfaceGuiSizingMode.PixelsPerStud
        and reels.PixelsPerStud == 100
        and not reels.Active
        and not reels.AlwaysOnTop,
    "fixed roll renders on authored Front face at 100 pixels per stud"
)
for _, reel in reels:GetChildren() do
    check(reel.ClipsDescendants, "reel window clips moving ingredient symbols")
end
check(display.CFrame == displayFrame and display.Size == displaySize, "roll preserves authored display geometry")
check(guiRoot:FindFirstChildOfClass("BillboardGui") == nil, "roll never uses a camera-facing container")
local carrier = workspaceFake:FindFirstChild("MuncherLocalGlow")
local light = carrier:FindFirstChildOfClass("PointLight")
local palette = loadModule("IngredientPickupPromptStyle").RarityStyles
check(
    light.Color == palette.Rare.TextColor and cues[1] == "Insert" and cues[2] == "Roll",
    "insert and roll start once with actual rarity glow"
)
for index = 1, 3 do
    animate(now + effects.ReelStop(index) + 0.00001)
    local reel = reels:FindFirstChild("Reel" .. index)
    local stoppedVisible = 0
    for _, symbol in reel:GetChildren() do
        if symbol:IsA("Frame") and symbol.Visible then
            stoppedVisible += 1
            check(
                symbol.Name == "Dragon_Fruit" and symbol.Position.Y.Scale == 0,
                "each stopped reel lands on actual output ingredient"
            )
        end
    end
    check(stoppedVisible == 1, "each staggered stop immediately shows one true output")
    check(reel:FindFirstChildOfClass("UIStroke").Color == palette.Rare.TextColor, "output rarity outline preserved")
    check(cues[index + 2] == "ReelStop", "staggered stop produces one tick")
end
check(
    cues[6] == "Win" and spinStopped and light.Brightness == 3,
    "last lock stops spin and synchronizes chord with full glow"
)
check(effects.ReelStop(3) < config.ChewSeconds, "roll completes before unchanged chew deadline")
animate(now + config.ChewSeconds - 0.01)
check(#cues == 6, "settled reels do not replay audio")
effectModel:SetAttribute("BusyUntil", now + config.ChewSeconds + config.BusySeconds)
animate(now + config.ChewSeconds)
check(artwork.CFrame.Position.X ~= 0, "busy positional jitter layers over chewing")
effectModel:SetAttribute("Phase", "Idle")
effectModel:SetAttribute("BusyUntil", 0)
animate(now + config.ChewSeconds)
check(
    artwork.CFrame.Position.Y == 4
        and artwork.CFrame.Position.X == 0
        and not reels.Enabled
        and reels.Parent == guiRoot
        and carrier.Parent == nil,
    "interruption removes roll, glow and carrier; restores artwork"
)
-- Interrupt an actively spinning sequence, not only the completed roll.
effectModel:SetAttribute("Sequence", 2)
effectModel:SetAttribute("Phase", "Processing")
effectModel:SetAttribute("StartedAt", now)
spinStopped = false
animate(now)
local interrupted = guiRoot:FindFirstChildOfClass("SurfaceGui")
stop()
check(
    spinStopped and interrupted.Parent == nil and artwork.CFrame.Position.Y == 4,
    "mid-spin removal cancels audio and fully restores scene"
)
stop()
check(artwork.CFrame.Position.Y == 4, "cleanup remains safe when repeated")

-- A busy flash must not keep the roll alive when processing is interrupted.
animate, stop = effects.Bind(effectModel, guiRoot)
effectModel:SetAttribute("Sequence", 3)
effectModel:SetAttribute("Phase", "Processing")
effectModel:SetAttribute("StartedAt", now)
animate(now)
local busyRoll = guiRoot:FindFirstChildOfClass("SurfaceGui")
effectModel:SetAttribute("Phase", "Spitting")
effectModel:SetAttribute("BusyUntil", now + config.BusySeconds)
animate(now + 0.1)
check(
    not busyRoll.Enabled
        and busyRoll.Parent == guiRoot
        and workspaceFake:FindFirstChild("MuncherLocalGlow") == nil
        and display.Parent == effectModel,
    "interruption removes roll and carrier even during busy jitter"
)
stop()
check(
    artwork.CFrame.Position.Y == 4 and artwork.CFrame.Position.X == 0,
    "busy interruption cleanup restores rest geometry"
)

-- Every tier cycles only real candidates; all outputs and result labels lock honestly.
local catalog = loadModule("Ingredients")
local previewIds = loadModule("ScrapbookPreviews")
for tier, pool in config.RewardPools do
    for outputIndex, entry in pool do
        for _, result in { "Win", "Lose", "Push" } do
            check(previewIds[entry.Id], "every tier candidate is published by the established preview pipeline")
            local definition = catalog[entry.Id]
            effectModel:SetAttribute("Sequence", 100 + tier * 10 + outputIndex)
            effectModel:SetAttribute("Phase", "Processing")
            effectModel:SetAttribute("BusyUntil", 0)
            effectModel:SetAttribute("InputTier", tier)
            effectModel:SetAttribute("OutputId", entry.Id)
            effectModel:SetAttribute("OutputRarity", definition.Rarity)
            effectModel:SetAttribute("ResultKind", result)
            effectModel:SetAttribute("StartedAt", now)
            local update, cleanup = effects.Bind(effectModel, guiRoot)
            local before = #cues
            spinStopped = false
            update(now)
            update(now + 0.5)
            check(#cues == before + 2 and not spinStopped, "insert once; loop remains active during spin")
            local gui = guiRoot:FindFirstChildOfClass("SurfaceGui")
            for _, reel in gui:GetChildren() do
                local symbols = 0
                for _, symbol in reel:GetChildren() do
                    if symbol:IsA("Frame") then
                        symbols += 1
                        local candidate = false
                        for _, choice in pool do
                            candidate = candidate or choice.Id == symbol.Name
                        end
                        local icon = symbol:FindFirstChild("IngredientIcon")
                        check(
                            candidate
                                and icon.Image == artworkConfig.GetMuncherIngredient(symbol.Name)
                                and icon.Visible
                                and not symbol:FindFirstChildOfClass("ViewportFrame"),
                            "every spinning reward displays its own flat image"
                        )
                    end
                end
                check(symbols == 5, "five reusable slots; only real pool candidates")
            end
            update(now + effects.ReelStop(3) - 0.001)
            check(not spinStopped, "loop continues until final lock")
            update(now + effects.ReelStop(3))
            -- A skipped-frame catch-up preserves the settled exact result.
            update(now + effects.ReelStop(3))
            check(spinStopped, "loop stops at final lock")
            check(
                #cues == before + (if result == "Push" then 5 else 6),
                "push has ticks only; win/loss each have one fanfare"
            )
            if result ~= "Push" then
                check(cues[#cues] == result, "server result chooses matching final sound")
            end
            for _, reel in gui:GetChildren() do
                local visible = 0
                for _, symbol in reel:GetChildren() do
                    if symbol:IsA("Frame") and symbol.Visible then
                        visible += 1
                        check(
                            symbol.Name == entry.Id
                                and symbol.Position.Y.Scale == 0
                                and symbol:FindFirstChild("IngredientIcon").Image == artworkConfig.GetMuncherIngredient(
                                    entry.Id
                                )
                                and symbol:FindFirstChild("IngredientIcon").Visible,
                            "locked symbol equals predetermined output"
                        )
                        local icon = symbol:FindFirstChild("IngredientIcon")
                        check(
                            (result == "Push" and icon.ImageColor3.R == 1)
                                or (result == "Win" and icon.ImageColor3 == loadModule("DialogueTextStyle").Gold)
                                or (result == "Lose" and icon.ImageColor3.R == 165 / 255),
                            "minimal result accent matches server label"
                        )
                    end
                end
                check(visible == 1, "exactly one locked symbol per reel")
            end
            update(now + config.ChewSeconds - 0.001)
            cleanup()
        end
    end
end

-- Phase interruption after the first stop cannot play a stale final cue.
for _, phase in { "Idle", "Spitting" } do
    effectModel:SetAttribute("Phase", "Processing")
    effectModel:SetAttribute("StartedAt", now)
    local update, cleanup = effects.Bind(effectModel, guiRoot)
    spinStopped = false
    update(now)
    update(now + effects.ReelStop(1))
    local before = #cues
    effectModel:SetAttribute("Phase", phase)
    update(now + effects.ReelStop(3))
    check(spinStopped and #cues == before, "interruption cancels loop without stale result")
    cleanup()
end

-- Binding after final lock shows the true result without replaying stale sounds.
effectModel:SetAttribute("StartedAt", now - effects.ReelStop(3) - 0.001)
local updateLate, cleanupLate = effects.Bind(effectModel, guiRoot)
local beforeLate = #cues
updateLate(now)
check(#cues == beforeLate, "late observation never replays insert, loop or final fanfare")
cleanupLate()

-- Pure movement contracts cover ordinary frames, exact boundaries, small pools,
-- and multi-wrap jumps without constructing GUI Instances.
for _, poolSize in { 1, 2, 4, 11, 12, 16, 18 } do
    local positions, indices = { -2, -1, 0, 1, 2 }, {}
    for row = 1, 5 do
        indices[row] = (row - 2) % poolSize + 1
    end
    local previous = 0
    for _, distance in { 0, 0.01, 0.5, 1, 1.999, 2, 4.9, 5, 9.2, 18, 37.5 } do
        local moved = effects.AdvanceSlots(positions, previous, distance)
        local sorted, visible = {}, 0
        for row, movement in moved do
            local oldIndex = indices[row]
            positions[row] = movement.Y
            indices[row] = effects.AdvancePoolIndex(oldIndex, movement.Wraps, poolSize)
            local totalWraps = math.floor((row - 3 + distance + 3) / 5)
            check(
                math.abs(movement.Y - (row - 3 + distance - 5 * totalWraps)) < 0.00001
                    and indices[row] == ((row - 2 - 5 * totalWraps) % poolSize + 1),
                "absolute-distance reference agrees with incremental wrap and pool advancement"
            )
            table.insert(sorted, { Y = movement.Y, Index = indices[row] })
            if movement.Y > -1 and movement.Y < 1 then
                visible += 1
            end
        end
        table.sort(sorted, function(a, b)
            return a.Y < b.Y
        end)
        for row = 2, 5 do
            check(
                math.abs(sorted[row].Y - sorted[row - 1].Y - 1) < 0.00001
                    and sorted[row].Index == sorted[row - 1].Index % poolSize + 1,
                "wrapped slots stay one unit apart in cyclically sequential order"
            )
        end
        check(visible <= 2, "window intersects at most two moving slots")
        previous = distance
    end
end

-- Preload happens once outside updates; failed batches cannot interrupt rolls.
check(#preloadCalls == 0 and #preloadJobs == 1, "binding schedules one client preload without blocking any roll")
while #preloadJobs > 0 do
    table.remove(preloadJobs, 1)()
end
local preloaded = {}
for _, batch in preloadCalls do
    for _, uri in batch do
        check(not preloaded[uri], "each image is preloaded once")
        preloaded[uri] = true
    end
end
for _, id in rewardIds do
    check(preloaded[artworkConfig.GetMuncherIngredient(id)], "preload covers " .. id)
end

-- Slow/failed art, slot reuse and sequence interruption keep exact readable IDs.
do
    effectModel:SetAttribute("Phase", "Processing")
    effectModel:SetAttribute("StartedAt", now)
    effectModel:SetAttribute("InputTier", 1)
    effectModel:SetAttribute("OutputId", "Apple")
    local update, cleanup = effects.Bind(effectModel, guiRoot)
    local gui = guiRoot:FindFirstChildOfClass("SurfaceGui")
    for _, object in gui:GetDescendants() do
        if object:IsA("ImageLabel") then
            object.IsLoaded = false
        end
    end
    update(now)
    update(now + effects.ReelStop(3))
    for _, window in gui:GetChildren() do
        local symbol = window:FindFirstChild("Apple")
        local icon, label = symbol:FindFirstChild("IngredientIcon"), symbol:FindFirstChild("IngredientName")
        check(
            symbol.Visible
                and icon.Image == artworkConfig.GetMuncherIngredient("Apple")
                and icon.Visible
                and not icon.IsLoaded
                and label.Visible
                and label.Text == catalog.Apple.DisplayName,
            "assigned image can render before loading while the catalog name remains visible"
        )
        icon.IsLoaded = true
    end
    update(now + effects.ReelStop(3))
    for _, window in gui:GetChildren() do
        local symbol = window:FindFirstChild("Apple")
        check(
            symbol:FindFirstChild("IngredientIcon").Visible and not symbol:FindFirstChild("IngredientName").Visible,
            "ready art replaces the name on the current result"
        )
    end
    -- Same frames are reused; the old image becoming ready cannot change content.
    effectModel:SetAttribute("Sequence", 2400)
    effectModel:SetAttribute("OutputId", "Dragon_Fruit")
    for _, object in gui:GetDescendants() do
        if object:IsA("ImageLabel") then
            object.IsLoaded = false
        end
    end
    update(now)
    update(now + effects.ReelStop(3))
    for _, window in gui:GetChildren() do
        local symbol = window:FindFirstChild("Dragon_Fruit")
        check(
            symbol.Visible
                and symbol:FindFirstChild("IngredientName").Text == catalog.Dragon_Fruit.DisplayName
                and symbol:FindFirstChild("IngredientIcon").Image
                    == artworkConfig.GetMuncherIngredient("Dragon_Fruit"),
            "reused slot holds new ID and sequence while earlier image loads"
        )
    end
    effects.Cancel(effectModel)
    for _, object in gui:GetDescendants() do
        if object:IsA("ImageLabel") then
            object.IsLoaded = true
        end
    end
    update(now + effects.ReelStop(3))
    check(not gui.Enabled, "late image readiness cannot resurrect a cancelled roll")
    cleanup()
    check(#preloadJobs == 0, "multiple bindings never restart client preloading")
end

-- Timing is opt-in and emits one summary, including interrupted rolls.
do
    local oldPrint, oldStudio = env.print, services.RunService.IsStudio
    local summaries = {}
    env.print = function(message)
        table.insert(summaries, message)
    end
    services.RunService.IsStudio = function()
        return true
    end
    effectModel:SetAttribute("Phase", "Processing")
    effectModel:SetAttribute("StartedAt", now)
    effectModel:SetAttribute("InputTier", 1)
    effectModel:SetAttribute("OutputId", "Apple")
    local update, cleanup = effects.Bind(effectModel, guiRoot)
    update(now, 0.02)
    effectModel:SetAttribute("Phase", "Idle")
    update(now + 0.1, 0.02)
    check(#summaries == 0, "timing is disabled by default")
    workspaceFake:SetAttribute("MuncherPresentationTiming", true)
    effectModel:SetAttribute("Sequence", 2500)
    effectModel:SetAttribute("Phase", "Processing")
    update(now, 0.02)
    update(now + effects.ReelStop(3), 0.03)
    effectModel:SetAttribute("Phase", "Idle")
    update(now + config.ChewSeconds, 0.02)
    update(now + config.ChewSeconds, 0.02)
    check(
        #summaries == 1
            and string.find(summaries[1], "builds=0 destroys=0", 1, true)
            and string.find(summaries[1], "worstFrame=30.00ms", 1, true)
            and string.find(summaries[1], "worstUpdate=", 1, true)
            and string.find(summaries[1], "iconFallbacks=", 1, true)
            and string.find(summaries[1], "path=images", 1, true),
        "one roll summary reports preview churn and worst render delta"
    )
    effectModel:SetAttribute("Sequence", 2501)
    effectModel:SetAttribute("Phase", "Processing")
    update(now, 0.01)
    effectModel:SetAttribute("Phase", "Idle")
    update(now + 0.1, 0.01)
    check(#summaries == 2, "interruption also emits exactly one summary")
    cleanup()
    check(#summaries == 2, "cleanup never repeats a roll summary")
    workspaceFake:SetAttribute("MuncherPresentationTiming", nil)
    env.print, services.RunService.IsStudio = oldPrint, oldStudio
end

-- Even an output outside the visual pool/catalog locks exactly, with readable fallback.
do
    effectModel:SetAttribute("Sequence", 2999)
    effectModel:SetAttribute("InputTier", 4)
    effectModel:SetAttribute("OutputId", "Apple")
    effectModel:SetAttribute("Phase", "Processing")
    effectModel:SetAttribute("StartedAt", now)
    local update, cleanup = effects.Bind(effectModel, guiRoot)
    update(now)
    update(now + effects.ReelStop(3))
    for _, window in guiRoot:FindFirstChildOfClass("SurfaceGui"):GetChildren() do
        local symbol = window:FindFirstChild("Apple")
        check(
            symbol
                and symbol.Visible
                and symbol:FindFirstChild("IngredientIcon").Visible
                and symbol:FindFirstChild("IngredientIcon").Image == artworkConfig.GetMuncherIngredient("Apple"),
            "output outside expected tier uses its own exact image on all three reels"
        )
    end
    cleanup()
end

do
    local previousWarn, warnings = env.warn, {}
    env.warn = function(message)
        table.insert(warnings, message)
    end
    effectModel:SetAttribute("Sequence", 3000)
    effectModel:SetAttribute("OutputId", "missing-output")
    effectModel:SetAttribute("Phase", "Processing")
    effectModel:SetAttribute("StartedAt", now)
    local update, cleanup = effects.Bind(effectModel, guiRoot)
    for _ = 1, 8 do
        update(now)
    end
    for index = 1, 3 do
        update(now + effects.ReelStop(index))
        local window = guiRoot:FindFirstChildOfClass("SurfaceGui"):FindFirstChild("Reel" .. index)
        local visible = 0
        for _, symbol in window:GetChildren() do
            if symbol:IsA("Frame") and symbol.Visible then
                visible += 1
                check(
                    symbol.Position.Y.Scale == 0
                        and symbol.Name == "missing-output"
                        and symbol:FindFirstChild("IngredientIcon").Image == ""
                        and not symbol:FindFirstChild("IngredientIcon").Visible
                        and symbol:FindFirstChild("IngredientName").Visible
                        and symbol:FindFirstChild("IngredientName").Text == "missing-output",
                    "unknown replicated output locks exactly with name fallback"
                )
            end
        end
        check(visible == 1, "invalid output never blanks a stopped reel")
    end
    check(#warnings == 0, "unknown string result remains authoritative without pool substitution")
    cleanup()
    env.warn = previousWarn
end

-- Invalid authoring fails before creating any effects; never fall back to a billboard.
for _, invalid in { "missing", "wrong class" } do
    display.Parent = nil
    local wrong = instance("Folder")
    if invalid == "wrong class" then
        wrong.Name, wrong.Parent = "DisplayScreen", effectModel
    end
    effectModel:SetAttribute("Sequence", 4)
    effectModel:SetAttribute("Phase", "Processing")
    effectModel:SetAttribute("StartedAt", now)
    local ok, diagnostic = pcall(effects.Bind, effectModel, guiRoot)
    check(
        not ok and string.find(tostring(diagnostic), "authored BasePart named DisplayScreen (Front face)", 1, true),
        "invalid DisplayScreen raises actionable Studio diagnostic: " .. invalid
    )
    check(
        #guiRoot:GetChildren() == 0 and workspaceFake:FindFirstChild("MuncherLocalGlow") == nil,
        "invalid display stops without creating roll or glow"
    )
    wrong:Destroy()
end

-- Name AND class resolution, with deterministic insertion order in the fake tree.
do
    local root, gui = instance("Model"), instance("PlayerGui")
    local function child(class, parent)
        local object = instance(class)
        object.Name, object.Parent = "DisplayScreen", parent
        return object
    end
    local function bindsTo(expected, message)
        local _, cleanup = effects.Bind(root, gui)
        check(gui:FindFirstChild("MuncherReels").Adornee == expected, message)
        cleanup()
    end
    for _, wrongFirst in { true, false } do
        local wrong, valid
        if wrongFirst then
            wrong, valid = child("Folder", root), child("Part", root)
        else
            valid, wrong = child("Part", root), child("Folder", root)
        end
        child("Folder", wrong)
        bindsTo(valid, "unique direct Part wins over wrong-class namesakes in either insertion order")
        wrong:Destroy()
        valid:Destroy()
    end
    local nested = instance("Model")
    nested.Parent = root
    local first = child("Part", nested)
    bindsTo(first, "unique nested Part remains supported")
    local second = child("Part", nested)
    local function fails(reason)
        local before = #allInstances
        local ok, problem = pcall(effects.Bind, root, gui)
        check(
            not ok
                and string.find(tostring(problem), "authored BasePart named DisplayScreen (Front face)", 1, true)
                and string.find(tostring(problem), reason, 1, true),
            "explicit failure: " .. reason
        )
        check(#allInstances == before and #gui:GetChildren() == 0, "invalid authoring allocates no effects")
    end
    fails("multiple nested")
    local direct = child("Part", root)
    bindsTo(direct, "unique direct Part wins even over multiple nested Parts")
    local duplicate = child("Part", root)
    fails("multiple direct")
    direct:Destroy()
    duplicate:Destroy()
    nested:Destroy()
    fails("missing")
    child("Folder", root)
    fails("wrong-class-only")
end

-- Bind itself rolls back a reel GUI when setup throws before returning cleanup.
do
    local originalNew = env.Instance.new
    env.Instance.new = function(class)
        if class == "Frame" then
            error("injected reel setup failure")
        end
        return originalNew(class)
    end
    display.Parent = effectModel
    local ok, problem = pcall(effects.Bind, effectModel, guiRoot)
    env.Instance.new = originalNew
    check(
        not ok and string.find(tostring(problem), "injected reel setup failure", 1, true),
        "Bind preserves unexpected setup error"
    )
    check(#guiRoot:GetChildren() == 0, "Bind rolls back partially constructed reels")
end

-- Real controller + real effects. Explicit plot order makes scan-abort regressions deterministic.
do
    local playerGui, render = instance("PlayerGui"), signal()
    actor.WaitForChild = function()
        return playerGui
    end
    services.RunService.RenderStepped = render
    local oldGetTagged = services.CollectionService.GetTagged
    local ordered = {}
    services.CollectionService.GetTagged = function(_, tag)
        if tag == "PlayerPlot" then
            return ordered
        end
        return oldGetTagged(services.CollectionService, tag)
    end
    local function plotFixture(name, withScreen)
        local plot, model = instance("Model"), instance("Model")
        plot.Name, plot.Parent = name, workspaceFake
        model.Name, model.Parent = "Muncher", plot
        plot:SetAttribute("PlotSessionId", "session")
        model:SetAttribute("Purchased", true)
        model:SetAttribute("Active", true)
        model:SetAttribute("Phase", "Idle")
        services.CollectionService:AddTag(plot, "PlayerPlot")
        if withScreen then
            local screen = instance("Part")
            screen.Name, screen.Parent = "DisplayScreen", model
        end
        return plot, model
    end
    local badPlot, bad = plotFixture("Plot4", false)
    local goodPlot, good = plotFixture("Healthy", true)
    ordered = { badPlot, goodPlot }
    local warnings, oldWarn = {}, env.warn
    env.warn = function(message)
        table.insert(warnings, message)
    end
    cache.MuncherPresentationController = nil
    cache.MuncherEffects = effects
    local controller = loadModule("MuncherPresentationController")
    local originalBind, binds, cleanups = effects.Bind, {}, {}
    local failBind, failStyle = false, false
    effects.Bind = function(model, gui)
        binds[model] = (binds[model] or 0) + 1
        if failBind and model == bad then
            error("injected unexpected Bind error")
        end
        local animate, cleanup = originalBind(model, gui)
        return animate,
            function()
                cleanups[model] = (cleanups[model] or 0) + 1
                cleanup()
            end
    end
    local style = loadModule("DialogueTextStyle")
    local originalApply = style.Apply
    style.Apply = function(label, size, gui)
        originalApply(label, size, gui)
        if failStyle and gui and gui.Name == "MuncherHint" then
            error("injected hint setup failure")
        end
    end
    local function tick(dt)
        render:Fire(if dt == nil then config.ScanInterval else dt)
    end
    local function counts(hints, reels)
        local h, r = 0, 0
        for _, child in playerGui:GetChildren() do
            h += if child.Name == "MuncherHint" then 1 else 0
            r += if child.Name == "MuncherReels" then 1 else 0
        end
        check(h == hints and r == reels, "exact live hint/reel counts: " .. hints .. "/" .. reels)
    end
    -- Verify that this harness cannot swallow callback errors.
    local propagation = signal()
    propagation:Connect(function()
        error("signal propagation probe")
    end)
    check(not pcall(function()
        propagation:Fire()
    end), "fake signals propagate callback failures")
    controller.Init()
    tick()
    counts(1, 1)
    check(binds[good] == 1 and binds[bad] == nil, "missing first plot does not block healthy binding in the same scan")
    local warning = warnings[1]
    for _, fragment in
        {
            "model#1=Model",
            "Plot4.Muncher",
            "originalLookup=nil",
            "missing",
            "Muncher siblings=1",
            "DisplayScreen matches=0",
            "StreamingEnabled=",
            "ModelStreamingMode=",
            "InWorkspace=true",
        }
    do
        check(string.find(warning, fragment, 1, true), "failure captures " .. fragment)
    end
    for _ = 1, 5 do
        tick()
    end
    check(#warnings == 1 and binds[good] == 1, "retries warn once and stable views are reused")
    counts(1, 1)
    goodPlot.Parent = nil
    tick()
    counts(0, 0)
    check(cleanups[good] == 1, "stale healthy views clean despite earlier failed plot")
    local screen = instance("Part")
    screen.Name, screen.Parent = "DisplayScreen", bad
    tick()
    counts(1, 1)
    check(binds[bad] == 1, "adding a screen recovers without restarting")
    local oldReels = playerGui:FindFirstChild("MuncherReels")
    screen.Parent = nil
    tick(0)
    counts(0, 0)
    check(oldReels.Parent == nil and cleanups[bad] == 1, "screen removal stops effects before the next scan")
    tick()
    check(#warnings == 1, "screen disappearance does not reset warning suppression")
    screen.Parent = bad
    tick()
    counts(1, 1)
    local replacement = instance("Part")
    replacement.Name, replacement.Parent = "DisplayScreen", bad
    screen.Parent = nil
    tick()
    counts(1, 1)
    check(
        binds[bad] == 3 and cleanups[bad] == 2 and playerGui:FindFirstChild("MuncherReels").Adornee == replacement,
        "replacement rebinds exactly once"
    )
    tick()
    check(binds[bad] == 3, "stable replacement keeps its view")
    replacement.Name = "RenamedScreen"
    tick(0)
    counts(0, 0)
    replacement.Name = "DisplayScreen"
    tick()
    counts(1, 1)
    services.CollectionService:RemoveTag(badPlot, "PlayerPlot")
    ordered = {}
    tick(0)
    counts(0, 0)
    tick() -- prune failed-model state separately from views

    -- Never-bound instance is removed and rediscovered: pruning permits a fresh diagnostic.
    local neverPlot, never = plotFixture("Never", false)
    ordered = { neverPlot }
    tick()
    local firstNever = warnings[#warnings]
    never.Parent = nil
    tick()
    never.Parent = neverPlot
    tick()
    check(#warnings == 3 and warnings[3] == firstNever, "never-bound model bookkeeping is pruned when undiscovered")
    local samePath = never:GetFullName()
    never:Destroy()
    local fresh = instance("Model")
    fresh.Name, fresh.Parent = "Muncher", neverPlot
    tick()
    check(
        fresh:GetFullName() == samePath and #warnings == 4 and warnings[4] ~= warnings[3],
        "new instance at the same path gets independent identity and diagnostic"
    )
    local freshScreen = instance("Part")
    freshScreen.Name, freshScreen.Parent = "DisplayScreen", fresh
    tick()
    counts(1, 1)
    check(binds[fresh] == 1, "new instance at the same path can bind")
    -- A new preferred direct screen replaces a still-valid nested binding during scans.
    local nested = instance("Folder")
    nested.Parent = fresh
    freshScreen.Parent = nested
    tick()
    check(binds[fresh] == 1, "same screen moved deeper preserves the view")
    local direct = instance("Part")
    direct.Name, direct.Parent = "DisplayScreen", fresh
    tick()
    check(
        binds[fresh] == 2 and cleanups[fresh] == 1 and playerGui:FindFirstChild("MuncherReels").Adornee == direct,
        "scan rebinds when direct preference changes while old screen remains a descendant"
    )
    counts(1, 1)
    ordered = {}
    tick()
    counts(0, 0)

    -- Bind exceptions and post-Bind setup failures must both isolate the first plot.
    services.CollectionService:AddTag(badPlot, "PlayerPlot")
    goodPlot.Parent = workspaceFake
    ordered = { badPlot, goodPlot }
    failBind = true
    tick()
    counts(1, 1)
    check(
        string.find(warnings[#warnings], "injected unexpected Bind error", 1, true),
        "unexpected Bind error text is preserved"
    )
    local warningCount = #warnings
    for _ = 1, 3 do
        tick()
    end
    check(#warnings == warningCount, "unexpected exceptions also warn once")
    failBind, failStyle = false, true
    local beforeClean = cleanups[bad]
    tick()
    counts(1, 1)
    check(cleanups[bad] == beforeClean + 1, "post-Bind hint setup failure invokes acquired effects cleanup")
    failStyle = false
    tick()
    counts(2, 2)
    check(#warnings == warningCount, "setup recovery preserves warning suppression")
    -- Real controller roll and respawn use no viewports or warming jobs.
    local mouth = instance("Part")
    mouth.Name, mouth.Parent = "MouthOrigin", good
    good:SetAttribute("Phase", "Processing")
    good:SetAttribute("StartedAt", now)
    good:SetAttribute("InputTier", 1)
    good:SetAttribute("OutputId", "Rock")
    tick(0)
    check(previewCreations == 0, "real controller roll performs zero viewport builds")
    actor.CharacterRemoving:Fire(actor.Character)
    counts(0, 0)
    actor.Character = nil
    tick()
    services.RunService.Heartbeat:Fire(0.1)
    check(#preloadJobs == 0, "respawn never schedules preview warming or repeat preload")
    actor.Character = instance("Model")
    good:SetAttribute("Phase", "Idle")
    ordered = {}
    tick()
    counts(0, 0)
    -- Record the actual old name-only lookup, and bound the hierarchy evidence.
    local diagnosticPlot, diagnosticModel = plotFixture("Diagnostic", false)
    local wrong = instance("Folder")
    wrong.Name, wrong.Parent = "DisplayScreen", diagnosticModel
    for _ = 1, 7 do
        local namesake = instance("Folder")
        namesake.Name, namesake.Parent = "DisplayScreen", wrong
    end
    local sibling = instance("Model")
    sibling.Name, sibling.Parent = "Muncher", diagnosticPlot
    ordered = { diagnosticPlot }
    tick()
    local detail = warnings[#warnings]
    for _, fragment in
        {
            "originalLookup=Folder " .. wrong:GetFullName(),
            "wrong-class-only",
            "Muncher siblings=2",
            "DisplayScreen matches=8",
            "direct=true",
            "direct=false",
            "truncated",
        }
    do
        check(string.find(detail, fragment, 1, true), "bounded first-failure evidence includes " .. fragment)
    end
    counts(0, 0)
    ordered = {}
    tick()
    effects.Bind, style.Apply, env.warn = originalBind, originalApply, oldWarn
    services.CollectionService.GetTagged = oldGetTagged
end

check(previewCreations == 0, "entire Muncher image presentation builds zero viewports")
for _, object in allInstances do
    check(not object:IsA("ViewportFrame"), "Muncher image path never builds or attaches a viewport")
end
env.task, env.Instance.new = oldTask, oldInstanceNew
