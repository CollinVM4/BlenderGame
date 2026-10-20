--!strict
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.CashFeedback)
local Audio = require(script.Parent.Parent.Controllers.GameplayAudioController)
local Hud = require(script.Parent.CashHud)
local CashTicker = require(script.Parent.CashTicker)
local Debug = require(script.Parent.CashRewardDebug)
local Animation = {}
local random = Random.new()
type Burst = { Collected: boolean }
type Icon = {
    View: ImageLabel,
    Start: number,
    Origin: Vector2,
    Spread: Vector2,
    Arc: number,
    Size: number,
    Rotation: number,
    Float: number,
    Burst: Burst,
}
type Punch = { Target: GuiObject, Scale: UIScale, Base: number, Last: number, Owned: boolean, Start: number }
local icons: { Icon } = {}
local punch: Punch? = nil
local gui: ScreenGui? = nil
local canvas: Frame? = nil
local connection: RBXScriptConnection? = nil
local playerGui: PlayerGui? = nil

local function stopPunch()
    local current = punch
    punch = nil
    if current and current.Scale.Parent then
        if current.Owned then
            current.Scale:Destroy()
        elseif math.abs(current.Scale.Scale - current.Last) < 0.0001 then
            current.Scale.Scale = current.Base
        end
    end
end

local function collect(target: GuiObject)
    local player = game:GetService("Players").LocalPlayer
    local cash = if player then player:GetAttribute("playerCash") else nil
    if type(cash) == "number" then
        CashTicker.SetTarget(cash)
    end
    -- Consecutive arrivals extend one pulse rather than accumulating scales.
    if punch and punch.Target == target then
        punch.Start = os.clock()
        return
    end
    stopPunch()
    local existing = target:FindFirstChildOfClass("UIScale")
    local scale = existing or Instance.new("UIScale")
    if not existing then
        scale.Name = "CashArrivalScale"
        scale.Parent = target
    end
    punch = {
        Target = target,
        Scale = scale,
        Base = scale.Scale,
        Last = scale.Scale,
        Owned = existing == nil,
        Start = os.clock(),
    }
end

function Animation.Clear()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    for _, icon in icons do
        icon.View:Destroy()
    end
    table.clear(icons)
    stopPunch()
    if gui then
        gui:Destroy()
    end
    gui, canvas, playerGui = nil, nil, nil
end

local function step()
    local container, layer = playerGui, canvas
    if not container or not layer or not layer:IsDescendantOf(container) then
        Animation.Clear()
        return
    end
    local now = os.clock()
    local target = Hud.Resolve(container)
    local destination = if target then Hud.Center(target, layer) else layer.AbsoluteSize / 2
    for index = #icons, 1, -1 do
        local icon = icons[index]
        local age = now - icon.Start
        local flightStart = 0.12 + icon.Float
        local duration = flightStart + 0.32
        if age >= duration then
            if target and age >= duration and not icon.Burst.Collected then
                icon.Burst.Collected = true
                collect(target)
                Audio.PlayCashFeedback("Collect")
            end
            icon.View:Destroy()
            table.remove(icons, index)
        elseif age >= 0 then
            local view = icon.View
            view.Visible = true
            local at, scale, fade = icon.Origin, 1, 0
            if age < 0.12 then
                local t = age / 0.12
                local ease = 1 - (1 - t) ^ 3
                at = icon.Origin + icon.Spread * ease
                scale = 0.3 + 0.7 * ease + math.sin(t * math.pi) * 0.25
            elseif age < flightStart then
                local t = (age - 0.12) / icon.Float
                at = icon.Origin + icon.Spread + Vector2.new(0, -6 * math.sin(t * math.pi / 2))
            else
                local t = (age - flightStart) / 0.32
                local eased = t * t
                local from = icon.Origin + icon.Spread + Vector2.new(0, -6)
                local control = (from + destination) / 2 + Vector2.new(icon.Arc, -50)
                at = from * (1 - eased) ^ 2 + control * (2 * (1 - eased) * eased) + destination * eased ^ 2
                scale = 1 - 0.8 * t
                fade = math.clamp((t - 0.6) / 0.4, 0, 1)
            end
            view.Position = UDim2.fromOffset(at.X, at.Y)
            local stretch = if age < 0.12 then math.sin(age / 0.12 * math.pi) * 0.16 else 0
            view.Size = UDim2.fromOffset(icon.Size * scale * (1 + stretch), icon.Size * scale * (1 - stretch))
            view.Rotation = icon.Rotation * math.min(age / 0.12, 1)
            view.ImageTransparency = fade
        end
    end
    local current = punch
    if current then
        if
            current.Target ~= target
            or not current.Scale.Parent
            or math.abs(current.Scale.Scale - current.Last) > 0.0001
        then
            -- Yield to Framewisp if it takes ownership of the same scale.
            stopPunch()
        else
            local t = (now - current.Start) / 0.22
            if t >= 1 then
                stopPunch()
            else
                current.Last = current.Base * (1 + 0.08 * math.sin(t * math.pi))
                current.Scale.Scale = current.Last
            end
        end
    end
    if #icons == 0 and not punch then
        Animation.Clear()
    end
end

function Animation.Play(player: Player)
    if Config.Image == "" then
        Debug.Log(player, "asset failed to load: empty image; burst skipped")
        return
    end
    local container = player:FindFirstChildOfClass("PlayerGui")
    local camera = workspace.CurrentCamera
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    if not container then
        Debug.Log(player, "burst skipped: no PlayerGui")
        return
    end
    if not camera then
        Debug.Log(player, "burst skipped: no camera")
        return
    end
    if not root or not root:IsA("BasePart") then
        Debug.Log(player, "burst skipped: no character/HumanoidRootPart")
        return
    end
    local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
    local position = if torso and torso:IsA("BasePart") then torso.Position else root.Position + Vector3.new(0, 1, 0)
    local projected, onScreen = camera:WorldToScreenPoint(position)
    local target = Hud.Resolve(container)
    if not target then
        Debug.Log(
            player,
            "HUD target missing: Desktop.Content.TOP.CashDisplay.Cash/{Coins} and aliases; centered burst"
        )
    end
    if not onScreen or projected.Z <= 0 then
        Debug.Log(player, "burst skipped: off-screen character")
        return
    end
    if gui and (playerGui ~= container or not gui:IsDescendantOf(container)) then
        Animation.Clear()
    end
    local count = math.min(random:NextInteger(5, 8), Config.MaxIcons - #icons)
    if count < 5 then
        Debug.Log(player, "burst skipped: icon capacity")
        return
    end
    if not gui then
        local overlay = Instance.new("ScreenGui")
        overlay.Name = "CashRewardEffects"
        overlay.ResetOnSpawn = false
        overlay.DisplayOrder = 1000
        overlay.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
        local layer = Instance.new("Frame")
        layer.BackgroundTransparency = 1
        layer.Size = UDim2.fromScale(1, 1)
        layer.Parent = overlay
        overlay.Parent = container
        gui, canvas, playerGui = overlay, layer, container
    end
    local layer = canvas :: Frame
    local origin = if target
        then Vector2.new(projected.X, projected.Y) - layer.AbsolutePosition
        else layer.AbsoluteSize / 2
    local viewport = camera.ViewportSize
    local radius = math.clamp(math.min(viewport.X, viewport.Y) * 0.065, 22, 44)
    origin = Vector2.new(
        math.clamp(origin.X, radius, math.max(radius, layer.AbsoluteSize.X - radius)),
        math.clamp(origin.Y, radius, math.max(radius, layer.AbsoluteSize.Y - radius))
    )
    local burst: Burst = { Collected = false }
    local now = os.clock()
    local stagger = random:NextNumber(0.04, 0.05)
    for index = 1, count do
        local view = Instance.new("ImageLabel")
        view.Name = "CashIcon"
        view.Image = Config.Image
        view.BackgroundTransparency = 1
        view.AnchorPoint = Vector2.new(0.5, 0.5)
        view.Visible = false
        view.Parent = layer
        if index == 1 then
            Debug.WatchImage(player, view)
        end
        local angle = (index - 1) / count * math.pi * 2 + random:NextNumber(-0.25, 0.25)
        local spread = radius * random:NextNumber(0.65, 1)
        table.insert(icons, {
            View = view,
            Start = now + (index - 1) * stagger,
            Origin = origin,
            Spread = Vector2.new(math.cos(angle), math.sin(angle)) * spread,
            Arc = random:NextNumber(-45, 45),
            Size = random:NextNumber(25, 34),
            Rotation = random:NextNumber(-18, 18),
            Float = random:NextNumber(0.15, 0.2),
            Burst = burst,
        })
    end
    Audio.PlayCashFeedback("Pop")
    if not connection then
        connection = RunService.RenderStepped:Connect(step)
    end
end

return Animation
