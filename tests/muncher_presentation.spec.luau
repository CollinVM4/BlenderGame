-- Presentation policy is independent of authoritative gameplay suites.
cache.MuncherEffects = {
    Bind = function()
        return function() end, function() end
    end,
}
cache.InteractionPromptPresentation = {}
local controller = loadModule("MuncherPresentationController")
local config = loadModule("Muncher")
local actor = instance("Player")
actor.Character = instance("Model")
local plot = instance("Model")
local model = instance("Model")
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
    services.CollectionService:AddTag(plot, "PlayerPlot")
    controller.Init()
    local function inactiveHint(expected)
        render:Fire(config.ScanInterval)
        local hint = playerGui:FindFirstChild("MuncherHint")
        check(hint and hint.Enabled and hint.Active == false, "visible hint billboard is explicitly inactive")
        local label = hint:FindFirstChildOfClass("TextLabel")
        check(label.Text == expected and label.Active == false, "hint/banner label never consumes Throw taps")
        for _, descendant in hint:GetDescendants() do
            check(descendant.Active ~= true, "entire decorative subtree has no active element")
            check(not descendant:IsA("GuiButton"), "hint/banner contains no input target")
        end
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
        local expected = if result == "Win" then "FREEDOKA YOU WIN" else "FREEDOKA YOU LOOSE"
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
    for _, reason in { "visitor", "inactive", "locked", "death", "stream-away" } do
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
    actor:SetAttribute("PlotSessionId", "other")
    beginResult("Win")
    completeResult()
    check(not hint.Enabled, "visitor observing whole conversion never gets result")
    actor:SetAttribute("PlotSessionId", "session")
    services.CollectionService:RemoveTag(plot, "PlayerPlot")
    render:Fire(config.ScanInterval)
    check(playerGui:FindFirstChild("MuncherHint") == nil, "view removal destroys the shared result/hint billboard")
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
-- IngredientViewport's geometry/framing contracts live in the scrapbook suite.
cache.IngredientViewport = {
    Create = function(image, id)
        local viewport = instance("ViewportFrame")
        viewport.Name, viewport.Parent = "IngredientPreview", image.Parent
        viewport:SetAttribute("PreviewId", id)
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
    for _, symbol in reel:GetChildren() do
        if symbol:IsA("Frame") and symbol.Visible then
            check(
                symbol.Name == "Dragon_Fruit" and symbol.Position.Y.Scale == 0,
                "each stopped reel lands on actual output ingredient"
            )
        end
    end
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
    artwork.CFrame.Position.Y == 4 and artwork.CFrame.Position.X == 0 and reels.Parent == nil and carrier.Parent == nil,
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
effectModel:SetAttribute("Sequence", 3)
effectModel:SetAttribute("Phase", "Processing")
effectModel:SetAttribute("StartedAt", now)
animate(now)
local busyRoll = guiRoot:FindFirstChildOfClass("SurfaceGui")
effectModel:SetAttribute("Phase", "Spitting")
effectModel:SetAttribute("BusyUntil", now + config.BusySeconds)
animate(now + 0.1)
check(
    busyRoll.Parent == nil and workspaceFake:FindFirstChild("MuncherLocalGlow") == nil and display.Parent == effectModel,
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
                        local preview = symbol:FindFirstChildOfClass("ViewportFrame")
                        check(
                            candidate and preview:GetAttribute("PreviewId") == symbol.Name,
                            "spinning symbols render the tier output pool through IngredientViewport"
                        )
                    end
                end
                check(symbols == #pool, "complete pool; no fake symbols")
            end
            update(now + effects.ReelStop(3) - 0.001)
            check(not spinStopped, "loop continues until final lock")
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
                            symbol.Name == entry.Id and symbol.Position.Y.Scale == 0,
                            "locked symbol equals predetermined output"
                        )
                        local icon = symbol:FindFirstChildOfClass("ViewportFrame")
                        check(
                            (result == "Push" and icon.ImageColor3 == nil)
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

-- Authored PNGs take precedence over prefab previews without changing the symbol ID.
local artworkConfig = loadModule("ScrapbookArtwork")
artworkConfig.Ingredients.Apple = "fixture-authored-icon"
effectModel:SetAttribute("Phase", "Processing")
effectModel:SetAttribute("InputTier", 1)
effectModel:SetAttribute("OutputId", "Apple")
effectModel:SetAttribute("ResultKind", "Push")
effectModel:SetAttribute("StartedAt", now)
local updateBitmap, cleanupBitmap = effects.Bind(effectModel, guiRoot)
updateBitmap(now)
updateBitmap(now + effects.ReelStop(3))
for _, reel in guiRoot:FindFirstChildOfClass("SurfaceGui"):GetChildren() do
    local symbol = reel:FindFirstChild("Apple")
    check(
        symbol.Visible
            and symbol:FindFirstChild("IngredientIcon").Image == "fixture-authored-icon"
            and not symbol:FindFirstChildOfClass("ViewportFrame"),
        "locked symbol reuses authored artwork when available"
    )
end
cleanupBitmap()
artworkConfig.Ingredients.Apple = nil

-- Binding after final lock shows the true result without replaying stale sounds.
effectModel:SetAttribute("StartedAt", now - effects.ReelStop(3) - 0.001)
local updateLate, cleanupLate = effects.Bind(effectModel, guiRoot)
local beforeLate = #cues
updateLate(now)
check(#cues == beforeLate, "late observation never replays insert, loop or final fanfare")
cleanupLate()

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
    local update, cleanup = effects.Bind(effectModel, guiRoot)
    local ok, diagnostic = pcall(update, now)
    check(
        not ok and string.find(tostring(diagnostic), "authored BasePart named DisplayScreen (Front face)", 1, true),
        "invalid DisplayScreen raises actionable Studio diagnostic: " .. invalid
    )
    check(
        #guiRoot:GetChildren() == 0 and workspaceFake:FindFirstChild("MuncherLocalGlow") == nil,
        "invalid display stops without creating roll or glow"
    )
    cleanup()
    wrong:Destroy()
end
