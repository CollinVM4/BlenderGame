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

function Effects.Bind(model: Instance, playerGui: PlayerGui): ((number) -> (), () -> ())
    local saved: { [BasePart]: CFrame } = {}
    local sequence = -1
    local insertedSequence = -1
    local carrier: BasePart? = nil
    local glow: PointLight? = nil
    local rollGui: SurfaceGui? = nil
    local reels: { any } = {}
    local stopSpin: (() -> ())? = nil
    local Audio = require(script.Parent.Parent.Controllers.GameplayAudioController)
    local function restore()
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
        if rollGui then
            rollGui:Destroy()
        end
        if carrier then
            carrier:Destroy()
        end
        table.clear(reels)
        carrier, glow, rollGui = nil, nil, nil
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
            restore()
            sequence = if type(current) == "number" then current else 0
            local at = origin()
            if processing and at and age < Config.ChewSeconds then
                local display = model:FindFirstChild("DisplayScreen", true)
                assert(
                    display and display:IsA("BasePart"),
                    "Muncher roll requires an authored BasePart named DisplayScreen (Front face) in "
                        .. model:GetFullName()
                )
                saveVisual()
                local tierAttribute = model:GetAttribute("InputTier")
                local tier: number = if type(tierAttribute) == "number" then tierAttribute else 1
                local pool = Config.RewardPools[tier] or Config.RewardPools[1]
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
                local gui = Instance.new("SurfaceGui")
                gui.Name, gui.Adornee = "MuncherReels", display
                -- Decorative roll view: never consume world or Throw taps.
                gui.Active = false
                gui.Face = Enum.NormalId.Front
                gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
                gui.PixelsPerStud = 100
                gui.AlwaysOnTop = false
                gui.ResetOnSpawn = true
                gui.Parent = playerGui
                rollGui = gui
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
                    window.Parent = gui
                    local outline = Instance.new("UIStroke")
                    outline.Thickness = 3
                    outline.Color = palette.TextColor
                    outline.Parent = window
                    local symbols = {}
                    -- Build each candidate once per reel; spinning only moves cached visuals.
                    for _, entry in pool do
                        local symbol = Instance.new("Frame")
                        symbol.Active = false
                        symbol.Name = entry.Id
                        symbol.BackgroundTransparency = 1
                        symbol.Size = UDim2.fromScale(1, 1)
                        symbol.Parent = window
                        local image = Instance.new("ImageLabel")
                        image.Active = false
                        image.Name = "IngredientIcon"
                        image.BackgroundTransparency = 1
                        image.Size = UDim2.fromScale(0.88, 0.88)
                        image.Position = UDim2.fromScale(0.06, 0.06)
                        image.ScaleType = Enum.ScaleType.Fit
                        image.Image = Artwork.GetIngredient(entry.Id)
                        image.Parent = symbol
                        if image.Image == "" then
                            Viewport.Create(image, entry.Id)
                        end
                        table.insert(symbols, symbol)
                    end
                    table.insert(
                        reels,
                        { Symbols = symbols, Outline = outline, Stopped = age >= Effects.ReelStop(index) }
                    )
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
            if rollGui or carrier or not busy then
                restore()
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
        for index, reel in reels do
            local stopAt = Effects.ReelStop(index)
            local fastUntil = Config.ChewSeconds * 0.58
            local duration = stopAt - fastUntil
            local decel = math.clamp(age - fastUntil, 0, duration)
            local travel = math.min(age, fastUntil) + decel - decel * decel / (2 * duration)
            local distance = travel * (12 + index * 2) / (fastUntil + duration / 2)
            local stopped = age >= stopAt
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
                        for _, lockedReel in reels do
                            for _, symbol in lockedReel.Symbols do
                                for _, icon in symbol:GetChildren() do
                                    if icon:IsA("ImageLabel") or icon:IsA("ViewportFrame") then
                                        icon.ImageColor3 = if result == "Win"
                                            then Style.Gold
                                            else Color3.fromRGB(165, 165, 165)
                                        TweenService
                                            :Create(icon, TweenInfo.new(0.12), { ImageColor3 = Color3.new(1, 1, 1) })
                                            :Play()
                                    end
                                end
                            end
                        end
                    end
                end
            end
            local output = model:GetAttribute("OutputId")
            reel.Outline.Color = palette.TextColor
            for row, symbol in reel.Symbols do
                symbol.Visible = not stopped or symbol.Name == output
                symbol.Position = UDim2.fromScale(0, if stopped then 0 else (row - 1 + distance) % #reel.Symbols - 1)
            end
        end
        if glow then
            glow.Color = palette.TextColor
            local lockAt = Effects.ReelStop(3)
            glow.Brightness = math.clamp((age - lockAt + 0.3) / 0.3, 0, 1) * 3
        end
    end,
        restore
end
return Effects
