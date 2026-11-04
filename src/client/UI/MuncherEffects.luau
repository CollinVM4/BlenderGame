--!strict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local Effects = {}
local RarityStyle = require(script.Parent.IngredientPickupPromptStyle)
local Artwork = require(Shared.Constants.ScrapbookArtwork)
local Viewport = require(script.Parent.IngredientViewport)

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

function Effects.Bind(model: Instance, playerGui: PlayerGui): ((number) -> (), () -> ())
    local saved: { [BasePart]: CFrame } = {}
    local sequence = -1
    local insertedSequence = -1
    local carrier: BasePart? = nil
    local glow: PointLight? = nil
    local reels: { any } = {}
    local stopSpin: (() -> ())? = nil
    local Audio = require(script.Parent.Parent.Controllers.GameplayAudioController)
    local queue: { [any]: boolean } = {}
    local pool = Config.RewardPools[1]
    local disposed = false
    local warnedOutput = false
    local display = model:FindFirstChild("DisplayScreen", true)
    assert(
        display and display:IsA("BasePart"),
        "Muncher roll requires an authored BasePart named DisplayScreen (Front face) in " .. model:GetFullName()
    )
    local rollGui = Instance.new("SurfaceGui")
    rollGui.Name, rollGui.Adornee = "MuncherReels", display
    rollGui.Active = false
    rollGui.Face = Enum.NormalId.Front
    rollGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    rollGui.PixelsPerStud = 100
    rollGui.AlwaysOnTop = false
    rollGui.ResetOnSpawn = true
    rollGui.Enabled = false
    rollGui.Parent = playerGui
    for index = 1, 3 do
        local window = Instance.new("Frame")
        window.Active = false
        window.Name = "Reel" .. index
        window.BackgroundColor3 = Color3.fromRGB(35, 20, 45)
        window.BackgroundTransparency = 0.15
        window.BorderSizePixel = 0
        window.ClipsDescendants = true
        window.Size = UDim2.fromScale(0.29, 0.8)
        window.Position = UDim2.fromScale(0.025 + (index - 1) * 0.33, 0.1)
        window.Parent = rollGui
        local outline = Instance.new("UIStroke")
        outline.Thickness = 3
        outline.Parent = window
        local slots = {}
        for row = 1, 5 do
            local symbol = Instance.new("Frame")
            symbol.Active = false
            symbol.BackgroundTransparency = 1
            symbol.Size = UDim2.fromScale(1, 1)
            symbol.Visible = false
            symbol.Parent = window
            local image = Instance.new("ImageLabel")
            image.Active = false
            image.Name = "IngredientIcon"
            image.BackgroundTransparency = 1
            image.Size = UDim2.fromScale(0.88, 0.88)
            image.Position = UDim2.fromScale(0.06, 0.06)
            image.ScaleType = Enum.ScaleType.Fit
            image.Image = ""
            image.Parent = symbol
            table.insert(slots, { Frame = symbol, Image = image, Y = row - 3, Ready = false })
        end
        table.insert(reels, { Slots = slots, Outline = outline, Stopped = false, Distance = 0 })
    end
    local function clearContent(slot: any)
        queue[slot] = nil
        if slot.Cleanup then
            slot.Cleanup()
            slot.Cleanup = nil
        end
        slot.Ready = false
        slot.Frame.Visible = false
    end
    local function assign(slot: any, poolIndex: number)
        if slot.PoolIndex == poolIndex and (slot.Ready or queue[slot]) then
            return
        end
        clearContent(slot)
        slot.PoolIndex = poolIndex
        slot.Frame.Name = pool[poolIndex].Id
        slot.Image.ImageColor3 = Color3.new(1, 1, 1)
        slot.Image.Image = Artwork.GetIngredient(slot.Frame.Name)
        if slot.Image.Image ~= "" then
            slot.Ready = true
        else
            queue[slot] = true
        end
    end
    local function resetRoll()
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
        table.clear(queue)
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
        rollGui:Destroy()
        table.clear(reels)
        table.clear(queue)
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
    return function(now: number)
        if disposed then
            return
        end
        local current = model:GetAttribute("Sequence")
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
        if current ~= sequence or (processing and not carrier and age < Config.ChewSeconds) then
            resetRoll()
            sequence = if type(current) == "number" then current else 0
            local at = origin()
            if processing and at and age < Config.ChewSeconds then
                saveVisual()
                local tierAttribute = model:GetAttribute("InputTier")
                local tier: number = if type(tierAttribute) == "number" then tierAttribute else 1
                pool = Config.RewardPools[tier] or Config.RewardPools[1]
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
            if rollGui.Enabled or carrier or not busy then
                resetRoll()
            end
            if not busy then
                return
            end
        end
        if busy then
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
        -- One deduplicated queue per view. Locked/visible content wins over hidden work.
        local pending = {}
        for slot in queue do
            table.insert(pending, slot)
        end
        local function priority(slot: any): number
            for _, reel in reels do
                if reel.Locked == slot then
                    return -3
                end
            end
            if slot.Y > -1 and slot.Y < 1 then
                return -2
            end
            return if slot.Y == -1 then -1 else 0
        end
        table.sort(pending, function(a, b)
            local pa, pb = priority(a), priority(b)
            return if pa == pb then a.Y < b.Y else pa < pb
        end)
        for index = 1, math.min(2, #pending) do
            local slot = pending[index]
            queue[slot] = nil
            slot.Cleanup = Viewport.Create(slot.Image, slot.Frame.Name)
            slot.Ready = slot.Cleanup ~= nil
        end
        for _, reel in reels do
            for _, slot in reel.Slots do
                slot.Frame.Position = UDim2.fromScale(0, slot.Y)
                slot.Frame.Visible = slot.Ready
                    and (if reel.Stopped then reel.Locked == slot else slot.Y > -1 and slot.Y < 1)
                if tintResult then
                    for _, icon in slot.Frame:GetChildren() do
                        if icon:IsA("ImageLabel") or icon:IsA("ViewportFrame") then
                            icon.ImageColor3 = if tintResult == "Win" then Style.Gold else Color3.fromRGB(165, 165, 165)
                            TweenService:Create(icon, TweenInfo.new(0.12), { ImageColor3 = Color3.new(1, 1, 1) }):Play()
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
    end,
        cleanup
end
return Effects
