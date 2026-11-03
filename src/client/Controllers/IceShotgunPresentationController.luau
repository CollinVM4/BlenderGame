--!strict
-- Local, bounded cosmetics from server-confirmed results. No aim raycasts or damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Constants.IceShotgunPresentationConfig)
local GameplayConfig = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
local Controller = {}
type Hit = { Position: Vector3, UserId: number, Frozen: boolean }
type Result = {
    Stage: "Init" | "Surge",
    Origin: Vector3,
    -- The server hit radius. The pulse is sized to exactly this value, so
    -- the visible blast and the actual hit area are the same sphere.
    Radius: number,
    ShooterUserId: number,
    ServerTime: number,
    Hits: { Hit },
}
type Blast = { Model: Model, Sphere: BasePart, Expires: number }
local held: { [number]: Blast? } = {}
local active: { Blast } = {}
local connections: { RBXScriptConnection } = {}
local started, generation = false, 0
local shotSound, frostTexture = Config.FallbackSoundId, Config.FallbackTexture
local feedback: ScreenGui? = nil
local feedbackUntil = 0

local function mobile(): boolean
    return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end
local function finite(n: any): boolean
    return typeof(n) == "number" and n == n and math.abs(n) < math.huge
end
local function vector(v: any): boolean
    return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function valid(result: any): boolean
    if
        typeof(result) ~= "table"
        or (result.Stage ~= "Init" and result.Stage ~= "Surge")
        or not vector(result.Origin)
        or not finite(result.Radius)
        or result.Radius <= 0
        or result.Radius > 128
        or not finite(result.ShooterUserId)
        or not finite(result.ServerTime)
        or typeof(result.Hits) ~= "table"
        or #result.Hits > 100
    then
        return false
    end
    local age = workspace:GetServerTimeNow() - result.ServerTime
    if age > Config.MaxEventAge or age < -0.25 then
        return false
    end
    for _, hit in result.Hits do
        if
            typeof(hit) ~= "table"
            or not vector(hit.Position)
            or not finite(hit.UserId)
            or typeof(hit.Frozen) ~= "boolean"
        then
            return false
        end
    end
    return true
end
local function part(class: string, model: Model, at: CFrame, size: Vector3): BasePart
    local p = Instance.new(class) :: BasePart
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
    p.CastShadow = false
    p.Color, p.Material, p.Transparency = Config.Blue, Enum.Material.Ice, 0.72
    p.CFrame, p.Size, p.Parent = at, size, model
    return p
end
local function tween(object: Instance, seconds: number, properties: { [string]: any })
    TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
        :Play()
end
-- A held init sphere stays at activation position until the confirmed surge.
local function pulse(model: Model, origin: Vector3): BasePart
    local sphere = part("Part", model, CFrame.new(origin), Vector3.new(2, 2, 2)) :: Part
    sphere.Name, sphere.Shape = "IceRadialPulse", Enum.PartType.Ball
    sphere.Transparency = Config.PulseStartTransparency
    return sphere
end
local function expand(blast: Blast, origin: Vector3, radius: number, fade: boolean)
    local sphere = blast.Sphere
    sphere.CFrame = CFrame.new(origin)
    tween(sphere, Config.PulseGrowSeconds, { Size = Vector3.new(radius * 2, radius * 2, radius * 2) })
    if fade then
        task.delay(Config.PulseGrowSeconds, function()
            if blast.Model.Parent then
                tween(sphere, Config.PulseFadeSeconds, { Transparency = 1 })
            end
        end)
    end
end
local function frost(parent: BasePart, count: number, angle: number)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name, emitter.Texture = "ShotgunFrost", frostTexture
    emitter.Enabled, emitter.Rate = false, 0
    emitter.Color = ColorSequence.new(Config.Blue, Config.White)
    emitter.Lifetime, emitter.Speed = NumberRange.new(0.15, 0.35), NumberRange.new(35, 60)
    emitter.EmissionDirection, emitter.SpreadAngle = Enum.NormalId.Front, Vector2.new(angle * 0.5, angle * 0.5)
    emitter.Drag, emitter.LightEmission = 4, 0.4
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
    emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
    emitter.Parent = parent
    emitter:Emit(count)
end
local function sound(parent: Instance, id: string, volume: number)
    local clip = Instance.new("Sound")
    clip.SoundId, clip.Volume = id, volume
    clip.Name = "IceRayCast"
    clip.RollOffMode = Enum.RollOffMode.InverseTapered
    clip.RollOffMinDistance, clip.RollOffMaxDistance = Config.SoundMinDistance, Config.SoundMaxDistance
    clip.PlaybackSpeed = 1
    clip.Parent = parent
    clip:Play()
    Debris:AddItem(clip, Config.SoundLifetime)
end
local function shards(model: Model, position: Vector3, count: number)
    for i = 1, count do
        local angle = i * math.pi * 2 / count
        local at = CFrame.new(position) * CFrame.Angles(i * 0.7, angle, 0.4)
        local shard = part("WedgePart", model, at, Vector3.new(0.13, 0.55, 0.22))
        shard.Name, shard.Transparency = "IceShard", 0.25
        local endPosition = position + Vector3.new(math.cos(angle) * 2, 0.8, math.sin(angle) * 2)
        tween(shard, 0.32, { CFrame = CFrame.new(endPosition) * at.Rotation, Transparency = 1 })
    end
end
local function clearFeedback()
    if feedback then
        feedback:Destroy()
    end
    feedback = nil
end
local function showFeedback(result: Result)
    local player = Players.LocalPlayer
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local shooterHit = player.UserId == result.ShooterUserId and #result.Hits > 0
    local victimHit, froze = false, false
    for _, hit in result.Hits do
        if hit.UserId == player.UserId then
            victimHit = true
        end
        froze = froze or hit.Frozen
    end
    if not gui or not (shooterHit or victimHit) then
        return
    end
    clearFeedback()
    local screen = Instance.new("ScreenGui")
    screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset = "IceShotgunHitFeedback", true, true
    screen.DisplayOrder = 9
    if victimHit then
        local flash = Instance.new("Frame")
        flash.Name, flash.Size = "FrostFlash", UDim2.fromScale(1, 1)
        flash.BackgroundColor3, flash.BackgroundTransparency = Config.Blue, 0.9
        flash.Active, flash.Parent = false, screen
        tween(flash, 0.2, { BackgroundTransparency = 1 })
    end
    if shooterHit then
        local marker = Instance.new("TextLabel")
        marker.Name, marker.Text = "ConfirmedHit", "+"
        marker.AnchorPoint, marker.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
        marker.Size, marker.BackgroundTransparency = UDim2.fromOffset(28, 28), 1
        marker.TextColor3 = if froze then Config.Blue else Config.White
        marker.Font, marker.TextSize, marker.TextStrokeTransparency = Enum.Font.GothamBold, 28, 0.4
        marker.Active, marker.Parent = false, screen
        tween(marker, 0.2, { TextTransparency = 1 })
    end
    screen.Parent = gui
    feedback, feedbackUntil = screen, os.clock() + 0.22
end
local function prune()
    local now = os.clock()
    for i = #active, 1, -1 do
        local blast = active[i]
        if now >= blast.Expires or not blast.Model.Parent then
            blast.Model:Destroy()
            for shooter, pending in held do
                if pending == blast then
                    held[shooter] = nil
                end
            end
            table.remove(active, i)
        end
    end
    if feedback and (now >= feedbackUntil or not feedback.Parent) then
        clearFeedback()
    end
end
function Controller.Play(result: any): boolean
    if not started or not valid(result) then
        return false
    end
    local camera, isMobile = workspace.CurrentCamera, mobile()
    local distance = if isMobile then Config.MobileViewDistance else Config.ViewDistance
    if not camera or (camera.CFrame.Position - result.Origin).Magnitude > distance then
        return false
    end
    showFeedback(result)
    prune()
    local blast: Blast? = held[result.ShooterUserId]
    if result.Stage == "Init" and blast then
        blast.Model:Destroy()
        prune()
        blast = nil
    end
    if not blast then
        local maximum = if isMobile then Config.MobileMaxActiveBlasts else Config.MaxActiveBlasts
        if #active >= maximum then
            return false
        end
        local model = Instance.new("Model")
        model.Name, model.Parent = "IceShotgunBlast", workspace
        local created: Blast = { Model = model, Sphere = pulse(model, result.Origin), Expires = 0 }
        table.insert(active, created)
        blast = created
    end
    assert(blast)
    local isInit = result.Stage == "Init"
    blast.Expires = os.clock() + Config.Lifetime + (if isInit then GameplayConfig.SurgeChargeSeconds else 0)
    held[result.ShooterUserId] = if isInit then blast else nil
    local model, center = blast.Model, blast.Sphere
    expand(blast, result.Origin, result.Radius, not isInit)
    frost(center, if isMobile then Config.MobileFrostCount else Config.FrostCount, 360)
    local caster = Players:GetPlayerByUserId(result.ShooterUserId)
    local root = caster and caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
    -- A dedicated emitter follows the caster; the expanding pulse is never an audio source.
    local emitter = Instance.new("Attachment")
    emitter.Name = "IceRayCastEmitter"
    emitter.Parent = if root and root:IsA("BasePart") then root else center
    sound(emitter, shotSound, Config.CastVolume)
    Debris:AddItem(emitter, Config.SoundLifetime)
    local shardCount = if isMobile then Config.MobileShardCount else Config.ShardCount
    local maxImpacts = if isMobile then Config.MobileMaxImpactEffects else Config.MaxImpactEffects
    for index, hit in result.Hits do
        if index > maxImpacts then
            break
        end
        local impact = part("Part", model, CFrame.new(hit.Position), Vector3.new(0.1, 0.1, 0.1))
        impact.Name, impact.Transparency = "IceImpact", 1
        frost(impact, if isMobile then 6 else 10, 180)
        shards(model, hit.Position, shardCount)
    end
    return true
end
function Controller.Init()
    if started then
        return
    end
    started = true
    generation += 1
    local token = generation
    table.insert(connections, RunService.Heartbeat:Connect(prune))
    table.insert(connections, Players.LocalPlayer.CharacterRemoving:Connect(clearFeedback))
    task.spawn(function()
        local remote = ReplicatedStorage.Shared.Events:WaitForChild("IceShotgunResult")
        if started and generation == token and remote:IsA("RemoteEvent") then
            table.insert(connections, remote.OnClientEvent:Connect(Controller.Play))
        end
    end)
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync(
                { Config.ShotSoundId, Config.FallbackSoundId, Config.FrostTexture },
                function(id, fetchStatus)
                    if not started or generation ~= token or fetchStatus ~= Enum.AssetFetchStatus.Success then
                        return
                    end
                    if id == Config.ShotSoundId then
                        shotSound = id
                    elseif id == Config.FrostTexture then
                        frostTexture = id
                    end
                end
            )
        end)
    end)
end
function Controller.Destroy()
    started = false
    generation += 1
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
    for _, blast in active do
        blast.Model:Destroy()
    end
    table.clear(active)
    table.clear(held)
    clearFeedback()
    shotSound, frostTexture = Config.FallbackSoundId, Config.FallbackTexture
end
return Controller
