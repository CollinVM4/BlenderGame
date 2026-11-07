--!strict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local Effects = {}
local RarityStyle = require(script.Parent.IngredientPickupPromptStyle)
local Artwork = require(Shared.Constants.ScrapbookArtwork)
local MuncherArtwork = require(Shared.Constants.MuncherArtwork)
local useImages = MuncherArtwork.IsReady()
-- Retained only while the asset handoff blocks the production switch.
local Cache = if useImages then nil else require(script.Parent.MuncherPreviewCache)
local Preloader = require(script.Parent.MuncherImagePreloader)
Effects.UsesImages = useImages
local Ingredients = require(Shared.Constants.Ingredients)
local RunService = game:GetService("RunService")
local bindings: { [any]: any } = {}
local interestSerial = 0

function Effects.Cancel(model: Instance)
    for _, binding in bindings do
        if binding.Model == model then
            binding.Reset()
            if useImages then
                binding.CancelledSequence = model:GetAttribute("Sequence")
            end
            binding.Nearby = false
        end
    end
end

-- Heartbeat-only idle preparation, shared across every bound machine.
function Effects.SetNearby(model: Instance, nearby: boolean)
    if useImages then
        return
    end
    for _, binding in bindings do
        if binding.Model == model then
            binding.Nearby = nearby
        end
    end
end

function Effects.Warm(now: number)
    if not Cache then
        return
    end
    local requests = {}
    local blocked = false
    for _, binding in bindings do
        local model = binding.Model
        blocked = blocked or binding.Gui.Enabled or model:GetAttribute("Phase") == "Processing"
        local tier = model:GetAttribute("InputTier") or binding.Tier or 1
        local sequence = model:GetAttribute("Sequence")
        if sequence ~= binding.Sequence then
            binding.Sequence, binding.Output = sequence, nil
        end
        local output = model:GetAttribute("OutputId") or binding.Output
        if tier ~= binding.Tier or output ~= binding.Output then
            interestSerial += 1
            binding.Tier, binding.Output, binding.Priority = tier, output, interestSerial
        end
        if binding.Nearby then
            if type(output) == "string" and Artwork.GetIngredient(output) == "" then
                table.insert(requests, { Id = output, Priority = binding.Priority * 100 + 99 })
            end
            for index, entry in Config.RewardPools[tier] or Config.RewardPools[1] do
                if Artwork.GetIngredient(entry.Id) == "" then
                    table.insert(requests, { Id = entry.Id, Priority = binding.Priority * 100 - index })
                end
            end
        end
    end
    Cache.Warm(requests, blocked, now)
end

function Effects.Pop(object: Instance)
    local flash = Instance.new("Highlight")
    flash.Name = "MuncherSpitPop"
    flash.Adornee, flash.FillColor = object, Style.White
    flash.FillTransparency, flash.OutlineTransparency = 0.3, 1
    flash.DepthMode = Enum.HighlightDepthMode.Occluded
    flash.Parent = object
    TweenService:Create(flash, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
    Debris:AddItem(flash, 0.2)
end

-- Stops at 1.25 / 1.40 / 1.55 seconds with the default 1.65-second chew.
function Effects.ReelStop(index: number): number
    return Config.ChewSeconds * (0.76 + (index - 1) * 0.09)
end

-- Positions stay in [-3, 2); wrap counts also handle skipped/late frames.
function Effects.AdvanceSlots(positions: { number }, previousDistance: number, distance: number): { any }
    local moved = {}
    for index, position in positions do
        local y = position + distance - previousDistance
        local wraps = math.max(0, math.floor((y + 3) / 5))
        moved[index] = { Y = y - wraps * 5, Wraps = wraps }
    end
    return moved
end

function Effects.AdvancePoolIndex(oldIndex: number, wraps: number, poolSize: number): number
    -- The old bottom is five entries after its new position above the old top.
    return (oldIndex - 1 - 5 * wraps) % poolSize + 1
end

-- Non-yielding authored-screen policy shared with the presentation controller.
function Effects.ResolveScreen(model: Instance): (BasePart?, string?)
    local function candidates(objects: { Instance }): (BasePart?, number)
        local chosen: BasePart? = nil
        local count = 0
        for _, object in objects do
            if object.Name == "DisplayScreen" and object:IsA("BasePart") then
                chosen = object
                count += 1
            end
        end
        return chosen, count
    end
    local direct, directCount = candidates(model:GetChildren())
    if directCount == 1 then
        return direct, nil
    elseif directCount > 1 then
        return nil, "ambiguous: multiple direct valid parts"
    end
    local descendants = model:GetDescendants()
    local nested, nestedCount = candidates(descendants)
    if nestedCount == 1 then
        return nested, nil
    elseif nestedCount > 1 then
        return nil, "ambiguous: multiple nested valid parts"
    end
    for _, object in descendants do
        if object.Name == "DisplayScreen" then
            return nil, "wrong-class-only: no matching BasePart"
        end
    end
    return nil, "missing: no DisplayScreen on this client"
end

local function bind(
    model: Instance,
    playerGui: PlayerGui,
    display: BasePart,
    acquire: (Instance) -> ()
): ((number, number?) -> (), () -> ())
    local saved: { [BasePart]: CFrame } = {}
    local sequence = -1
    local insertedSequence = -1
    local carrier: BasePart? = nil
    local glow: PointLight? = nil
    local reels: { any } = {}
    local stopSpin: (() -> ())? = nil
    local Audio = require(script.Parent.Parent.Controllers.GameplayAudioController)
    local pool = Config.RewardPools[1]
    local disposed = false
    local warnedOutput = false
    local reset = true
    local timing: any = nil
    local function finishTiming()
        if timing then
            local totals = if Cache
                then Cache.Snapshot()
                else { Builds = 0, Destroys = 0, Hits = 0, Misses = 0, WorstBuildMs = 0 }
            print(
                string.format(
                    "Muncher roll: builds=%d destroys=%d hits=%d misses=%d worstFrame=%.2fms worstUpdate=%.2fms warmBuildMax=%.2fms iconFallbacks=%d path=%s",
                    totals.Builds - timing.Builds,
                    totals.Destroys - timing.Destroys,
                    totals.Hits - timing.Hits,
                    totals.Misses - timing.Misses,
                    timing.WorstFrameMs,
                    timing.WorstUpdateMs,
                    totals.WorstBuildMs,
                    timing.IconFallbacks,
                    if useImages then "images" else "viewports"
                )
            )
            timing = nil
        end
    end
    local rollGui = Instance.new("SurfaceGui")
    acquire(rollGui)
    rollGui.Name, rollGui.Adornee = "MuncherReels", display
    rollGui.Active = false
    rollGui.Face = Enum.NormalId.Front
    rollGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    rollGui.PixelsPerStud = 100
    rollGui.AlwaysOnTop = false
    -- Controller owns respawn cleanup and cancels all slot content.
    rollGui.ResetOnSpawn = false
    rollGui.Enabled = false
    rollGui.Parent = playerGui
    for index = 1, 3 do
        local window = Instance.new("Frame")
        window.Parent = rollGui
        window.Active = false
        window.Name = "Reel" .. index
        window.BackgroundColor3 = Color3.fromRGB(35, 20, 45)
        window.BackgroundTransparency = 0.15
        window.BorderSizePixel = 0
        window.ClipsDescendants = true
        window.Size = UDim2.fromScale(0.29, 0.8)
        window.Position = UDim2.fromScale(0.025 + (index - 1) * 0.33, 0.1)
        local outline = Instance.new("UIStroke")
        outline.Parent = window
        outline.Thickness = 3
        local slots = {}
        for row = 1, 5 do
            local symbol = Instance.new("Frame")
            symbol.Parent = window
            symbol.Active = false
            symbol.BackgroundTransparency = 1
            symbol.Size = UDim2.fromScale(1, 1)
            symbol.Visible = false
            local image = Instance.new("ImageLabel")
            image.Parent = symbol
            image.Active = false
            image.Name = "IngredientIcon"
            image.BackgroundTransparency = 1
            image.Size = UDim2.fromScale(0.88, 0.88)
            image.Position = UDim2.fromScale(0.06, 0.06)
            image.ScaleType = Enum.ScaleType.Fit
            image.Image = ""
            local label = Instance.new("TextLabel")
            label.Name, label.Parent = "IngredientName", symbol
            label.Active, label.BackgroundTransparency = false, 1
            label.Size, label.Position = image.Size, image.Position
            Style.Apply(label, 24)
            label.TextScaled, label.TextWrapped, label.Visible = true, true, false
            label.Text = ""
            table.insert(slots, { Frame = symbol, Image = image, Label = label, Y = row - 3, Ready = false })
        end
        table.insert(reels, { Slots = slots, Outline = outline, Stopped = false, Distance = 0 })
    end
    local function clearContent(slot: any)
        if Cache then
            Cache.Release(slot)
        end
        slot.ContentSequence = nil
        slot.FallbackCounted = false
        slot.Ready = false
        slot.Frame.Visible = false
        slot.Image.Image, slot.Label.Text = "", ""
        slot.Image.Visible, slot.Label.Visible = false, false
        slot.PoolIndex = nil
        slot.Frame.Name = ""
    end
    local function assign(slot: any, poolIndex: number?, exactId: string?)
        local id = exactId or (if poolIndex then pool[poolIndex].Id else "")
        if slot.Ready and slot.Frame.Name == id then
            slot.PoolIndex = poolIndex
            return
        end
        clearContent(slot)
        slot.PoolIndex = poolIndex
        slot.Frame.Name = id
        slot.Image.ImageColor3 = Color3.new(1, 1, 1)
        slot.Label.TextColor3 = Style.White
        slot.ContentSequence = sequence
        slot.Image.Image = if useImages then MuncherArtwork.GetMuncherIngredient(id) else Artwork.GetIngredient(id)
        slot.Image.Visible = slot.Image.Image ~= ""
        if useImages or (not slot.Image.Visible and Cache and not Cache.Lease(slot, slot.Image, id)) then
            local definition = Ingredients[id]
            slot.Label.Text = if definition then definition.DisplayName else id
            slot.Label.Visible = true
        end
        slot.Ready = true
    end
    local function resetRoll()
        if reset then
            return
        end
        reset = true
        finishTiming()
        for part, at in saved do
            if part.Parent then
                part.CFrame = at
            end
        end
        table.clear(saved)
        if stopSpin then
            stopSpin()
            stopSpin = nil
        end
        rollGui.Enabled = false
        if carrier then
            carrier:Destroy()
        end
        carrier, glow = nil, nil
        for _, reel in reels do
            reel.Stopped, reel.Locked, reel.Distance = false, nil, 0
            for _, slot in reel.Slots do
                clearContent(slot)
                slot.PoolIndex = nil
            end
        end
    end
    local function cleanup()
        if disposed then
            return
        end
        resetRoll()
        disposed = true
        bindings[rollGui] = nil
        if Cache and not next(bindings) then
            Cache.Dispose()
        end
        rollGui:Destroy()
        table.clear(reels)
        sequence, insertedSequence = -1, -1
    end
    local function saveVisual()
        if next(saved) then
            return
        end
        local visual = model:FindFirstChild("Visual")
        if visual then
            local parts = visual:GetDescendants()
            table.insert(parts, visual)
            for _, part in parts do
                if part:IsA("BasePart") then
                    saved[part] = part.CFrame
                end
            end
        end
    end
    local function origin(): CFrame?
        local mouth = model:FindFirstChild("MouthOrigin", true)
        if mouth and mouth:IsA("Attachment") then
            return mouth.WorldCFrame
        end
        if mouth and mouth:IsA("BasePart") then
            return mouth.CFrame
        end
        return nil
    end
    local function animate(now: number)
        if disposed then
            return
        end
        local current = model:GetAttribute("Sequence")
        local binding = bindings[rollGui]
        if useImages and binding and binding.CancelledSequence ~= nil then
            if binding.CancelledSequence == current then
                return
            end
            binding.CancelledSequence = nil
        end
        local processing = model:GetAttribute("Phase") == "Processing"
        local start = model:GetAttribute("StartedAt")
        local age: number = Config.ChewSeconds
        if type(start) == "number" then
            age = math.max(0, now - start)
        end
        local busyAttribute = model:GetAttribute("BusyUntil")
        local busyUntil: number = if type(busyAttribute) == "number" then busyAttribute else 0
        local busy = now < busyUntil and model:GetAttribute("Purchased") == true
        local palette = (RarityStyle.RarityStyles :: any)[tostring(model:GetAttribute("OutputRarity"))]
            or RarityStyle.RarityStyles.Common
        local tierAttribute = model:GetAttribute("InputTier")
        local tier: number = if type(tierAttribute) == "number" then tierAttribute else 1
        local currentPool = Config.RewardPools[tier] or Config.RewardPools[1]
        if
            current ~= sequence
            or (processing and age < Config.ChewSeconds and (not carrier or currentPool ~= pool))
        then
            resetRoll()
            sequence = if type(current) == "number" then current else 0
            local at = origin()
            if processing and at and age < Config.ChewSeconds then
                reset = false
                if workspace:GetAttribute("MuncherPresentationTiming") == true and RunService:IsStudio() then
                    timing = if Cache then Cache.Snapshot() else { Builds = 0, Destroys = 0, Hits = 0, Misses = 0 }
                    timing.WorstFrameMs, timing.WorstUpdateMs, timing.IconFallbacks = 0, 0, 0
                end
                saveVisual()
                pool = currentPool
                local anchor = Instance.new("Part")
                anchor.Name = "MuncherLocalGlow"
                anchor.Size = Vector3.one * 0.1
                anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
                anchor.Transparency, anchor.CFrame, anchor.Parent = 1, at, workspace
                carrier = anchor
                local light = Instance.new("PointLight")
                light.Color = palette.TextColor
                light.Range, light.Brightness, light.Parent = 7, 0, anchor
                glow = light
                rollGui.Enabled = true
                for index, reel in reels do
                    reel.Stopped = age >= Effects.ReelStop(index)
                    for row, slot in reel.Slots do
                        slot.Y = row - 3
                        assign(slot, (row - 2) % #pool + 1)
                    end
                end
                if age < Effects.ReelStop(3) then
                    if insertedSequence ~= sequence then
                        insertedSequence = sequence
                        Audio.PlayMuncher("Insert", anchor)
                    end
                    stopSpin = Audio.PlayMuncher("Roll", anchor)
                end
            end
        end
        if not processing then
            if not reset then
                resetRoll()
            end
            if not busy then
                return
            end
        end
        if busy then
            reset = false
            saveVisual()
        end
        local offset = if processing then math.sin(age * 25) * 0.1 else 0
        local jitter = if busy then math.sin((busyUntil - now) * 100) * 0.08 else 0
        for part, at in saved do
            if part.Parent then
                part.CFrame = CFrame.new(jitter, offset, 0) * at
            end
        end
        if not rollGui.Enabled then
            return
        end
        local tintResult: string? = nil
        for index, reel in reels do
            local stopAt = Effects.ReelStop(index)
            local fastUntil = Config.ChewSeconds * 0.58
            local duration = stopAt - fastUntil
            local decel = math.clamp(age - fastUntil, 0, duration)
            local travel = math.min(age, fastUntil) + decel - decel * decel / (2 * duration)
            local distance = travel * (12 + index * 2) / (fastUntil + duration / 2)
            local stopped = age >= stopAt
            if not reel.Locked then
                local positions = {}
                for row, slot in reel.Slots do
                    positions[row] = slot.Y
                end
                for row, moved in Effects.AdvanceSlots(positions, reel.Distance, distance) do
                    local slot = reel.Slots[row]
                    slot.Y = moved.Y
                    if moved.Wraps > 0 then
                        assign(slot, Effects.AdvancePoolIndex(slot.PoolIndex, moved.Wraps, #pool))
                    end
                end
                reel.Distance = distance
                if stopped then
                    local closest = reel.Slots[1]
                    for _, slot in reel.Slots do
                        if math.abs(slot.Y) < math.abs(closest.Y) then
                            closest = slot
                        end
                    end
                    local output = model:GetAttribute("OutputId")
                    local outputIndex = nil
                    for poolIndex, entry in pool do
                        if entry.Id == output then
                            outputIndex = poolIndex
                            break
                        end
                    end
                    if outputIndex then
                        assign(closest, outputIndex)
                    elseif type(output) == "string" and (useImages or Ingredients[output]) then
                        assign(closest, nil, output)
                    elseif not warnedOutput then
                        warnedOutput = true
                        warn("Muncher output missing from pool in " .. model:GetFullName() .. ": " .. tostring(output))
                    end
                    closest.Y = 0
                    reel.Locked = closest
                end
            end
            if stopped and not reel.Stopped and carrier then
                reel.Stopped = true
                Audio.PlayMuncher("ReelStop", carrier)
                if index == 3 then
                    if stopSpin then
                        stopSpin()
                        stopSpin = nil
                    end
                    local result = model:GetAttribute("ResultKind")
                    if result == "Win" or result == "Lose" then
                        Audio.PlayMuncher(result, carrier)
                        tintResult = result
                    end
                end
            end
            reel.Outline.Color = palette.TextColor
        end
        for _, reel in reels do
            for _, slot in reel.Slots do
                -- Readiness is polled on the reusable label, with no asynchronous
                -- slot mutation. A previous ID/sequence cannot reveal stale art.
                if useImages and slot.ContentSequence == sequence and slot.Ready then
                    local hasImage = slot.Image.Image ~= ""
                    slot.Image.Visible = hasImage
                    slot.Label.Visible = not (hasImage and slot.Image.IsLoaded)
                end
                slot.Frame.Position = UDim2.fromScale(0, slot.Y)
                slot.Frame.Visible = slot.Ready
                    and (if reel.Stopped then reel.Locked == slot else slot.Y > -1 and slot.Y < 1)
                if useImages and timing and slot.Frame.Visible and slot.Label.Visible and not slot.FallbackCounted then
                    slot.FallbackCounted = true
                    timing.IconFallbacks += 1
                end
                if tintResult then
                    for _, icon in slot.Frame:GetChildren() do
                        if icon:IsA("ImageLabel") or icon:IsA("ViewportFrame") then
                            icon.ImageColor3 = if tintResult == "Win" then Style.Gold else Color3.fromRGB(165, 165, 165)
                            TweenService:Create(icon, TweenInfo.new(0.12), { ImageColor3 = Color3.new(1, 1, 1) }):Play()
                        elseif icon:IsA("TextLabel") then
                            icon.TextColor3 = if tintResult == "Win" then Style.Gold else Color3.fromRGB(165, 165, 165)
                            TweenService:Create(icon, TweenInfo.new(0.12), { TextColor3 = Style.White }):Play()
                        end
                    end
                end
            end
        end
        if glow then
            glow.Color = palette.TextColor
            local lockAt = Effects.ReelStop(3)
            glow.Brightness = math.clamp((age - lockAt + 0.3) / 0.3, 0, 1) * 3
        end
    end
    bindings[rollGui] = { Model = model, Gui = rollGui, Nearby = false, Reset = resetRoll }
    return function(now: number, dt: number?)
        local started = if timing or workspace:GetAttribute("MuncherPresentationTiming") == true then os.clock() else 0
        animate(now)
        if timing then
            timing.WorstUpdateMs = math.max(timing.WorstUpdateMs, (os.clock() - started) * 1000)
            timing.WorstFrameMs = math.max(timing.WorstFrameMs, (dt or 0) * 1000)
        end
    end,
        cleanup
end
-- Roll back setup allocations even when Bind cannot return its cleanup function.
function Effects.Bind(model: Instance, playerGui: PlayerGui): ((number, number?) -> (), () -> ())
    local display, reason = Effects.ResolveScreen(model)
    if not display then
        error(
            "Muncher roll requires an authored BasePart named DisplayScreen (Front face) in "
                .. model:GetFullName()
                .. ": "
                .. tostring(reason)
        )
    end
    if useImages then
        Preloader.Start()
    end
    local acquired: { Instance } = {}
    local ok, animate, cleanup = pcall(bind, model, playerGui, display, function(object)
        table.insert(acquired, object)
    end)
    if not ok then
        for _, object in acquired do
            object:Destroy()
        end
        error(tostring(animate), 0)
    end
    return animate, cleanup
end

return Effects
