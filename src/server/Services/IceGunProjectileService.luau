--!strict
-- One bounded server simulation; camera data is untrusted aim intent, never a damage target.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
local Service = {}
local REVISION = "icegun-circle-2026-10-09"
local lastDiagnostic: { [string]: number } = {}
local function trace(player: Player, stage: string)
    if not Config.DebugLogging or not RunService:IsStudio() then
        return
    end
    local key = tostring(player.UserId) .. ":" .. stage
    local now = os.clock()
    if now < (lastDiagnostic[key] or 0) then
        return
    end
    lastDiagnostic[key] = now + 1
    warn("[IceGun] " .. tostring(player.UserId) .. " " .. stage)
end

local deps: any
type Projectile = {
    Shooter: Player,
    Character: Model,
    Position: Vector3,
    Direction: Vector3,
    Travel: number,
    Expires: number,
    Ray: RaycastParams,
    Visual: BasePart,
}
local active: { [Player]: Projectile } = {}
local cooldown: { [Player]: number } = {}
local requests: { [Player]: number } = {}
local heartbeat: RBXScriptConnection? = nil

local function finite(v: number): boolean
    return v == v and math.abs(v) < 1000000
end

local function stopIfIdle()
    if next(active) == nil and heartbeat then
        heartbeat:Disconnect()
        heartbeat = nil
    end
end

function Service.ClearPlayer(player: Player)
    local shot = active[player]
    active[player] = nil
    if shot then
        shot.Visual:Destroy()
    end
    stopIfIdle()
end

function Service.RemovePlayer(player: Player)
    Service.ClearPlayer(player)
    cooldown[player], requests[player] = nil, nil
end

local function impact(shot: Projectile, result: RaycastResult)
    local ancestor: Instance? = result.Instance
    while ancestor and ancestor ~= workspace do
        if ancestor:IsA("Model") then
            local victim = Players:GetPlayerFromCharacter(ancestor)
            if victim then
                if deps.CombatService.DamagePlayer(shot.Shooter, victim, ancestor, Config.DirectDamage) then
                    deps.FreezeStatusService.Apply(victim)
                end
                break
            end
        end
        ancestor = ancestor.Parent
    end
    deps.IceGunEffects.Impact(result.Position)
end

local function step(dt: number)
    local now = os.clock()
    for player, shot in active do
        local h = shot.Character:FindFirstChildOfClass("Humanoid")
        if
            now > shot.Expires + 0.1
            or player.Parent ~= Players
            or player.Character ~= shot.Character
            or not h
            or h.Health <= 0
            or not shot.Visual.Parent
        then
            trace(player, "projectile ended: lifetime/character/visual invalid travel=" .. tostring(shot.Travel))
            Service.ClearPlayer(player)
            continue
        end
        local distance = math.min(Config.ProjectileSpeed * dt, Config.MaximumRange - shot.Travel)
        local result = workspace:Raycast(shot.Position, shot.Direction * distance, shot.Ray)
        if result then
            trace(
                player,
                "projectile impact travel="
                    .. tostring(shot.Travel)
                    .. " position="
                    .. tostring(result.Position)
                    .. " hit="
                    .. tostring(result.Instance)
            )
            -- Remove simulation before damage can synchronously trigger any lifecycle callbacks.
            Service.ClearPlayer(player)
            impact(shot, result)
        else
            shot.Travel += distance
            shot.Position += shot.Direction * distance
            shot.Visual.CFrame = CFrame.lookAt(shot.Position, shot.Position + shot.Direction)
            if shot.Travel >= Config.MaximumRange or now >= shot.Expires then
                trace(player, "projectile ended: range/lifetime travel=" .. tostring(shot.Travel))
                Service.ClearPlayer(player)
            end
        end
    end
    stopIfIdle()
end

function Service.Fire(player: Player, aim: any, cameraOrigin: any?, cameraDirection: any?): boolean
    local now = os.clock()
    trace(player, "fire remote received")
    if Config.DebugLogging and RunService:IsStudio() then
        trace(
            player,
            "request state session="
                .. tostring(deps.TycoonService.GetSessionId(player))
                .. " ownership="
                .. tostring(player:GetAttribute("IceGunOwnership"))
                .. " character="
                .. tostring(player.Character)
        )
    end
    local function reject(reason: string): boolean
        trace(player, "fire rejected: " .. reason)
        return false
    end
    -- Reject spam before inspecting geometry or touching any Marketplace API.
    if now < (requests[player] or 0) then
        return reject("request throttle")
    end
    requests[player] = now + 0.1
    if typeof(aim) ~= "Vector3" or not finite(aim.X) or not finite(aim.Y) or not finite(aim.Z) then
        return reject("malformed aim")
    end
    local tool = deps.IceGunService.GetEquipped(player)
    local character = player.Character
    local h = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if Config.DebugLogging and RunService:IsStudio() then
        trace(
            player,
            "action state allowed="
                .. tostring(deps.MovementService.CanPerformGameplayAction(player))
                .. " PlatformStand="
                .. tostring(h and h.PlatformStand)
                .. " Stunned="
                .. tostring(player:GetAttribute("Stunned"))
                .. " Frozen="
                .. tostring(player:GetAttribute("Frozen"))
        )
    end
    if tool then
        trace(player, "server equipped issue=" .. tostring(tool:GetAttribute("IceGunIssueId")))
    end
    if not tool then
        return reject("no entitled equipped issued Tool")
    elseif player.Parent ~= Players or not character or not h or h.Health <= 0 then
        return reject("invalid firing character")
    elseif not root or not root:IsA("BasePart") or not root:IsDescendantOf(workspace) then
        return reject("invalid character root")
    elseif h.PlatformStand or not deps.MovementService.CanPerformGameplayAction(player) then
        return reject("gameplay action blocked")
    elseif now < (cooldown[player] or 0) then
        return reject("shot cooldown")
    elseif active[player] then
        return reject("projectile already active")
    end
    local handle = tool:FindFirstChild("Handle")
    local barrel = handle and handle:FindFirstChild("GunBarrel")
    if not handle or not handle:IsA("BasePart") or not barrel or not barrel:IsA("Attachment") then
        return reject("missing Handle/GunBarrel")
    end
    local muzzle = barrel.WorldPosition
    if Config.DebugLogging and RunService:IsStudio() then
        trace(
            player,
            "geometry muzzle="
                .. tostring(muzzle)
                .. " root="
                .. tostring(root.Position)
                .. " camera="
                .. tostring(cameraOrigin)
                .. " direction="
                .. tostring(cameraDirection)
        )
    end
    if
        not finite(muzzle.X)
        or not finite(muzzle.Y)
        or not finite(muzzle.Z)
        or (muzzle - root.Position).Magnitude > 8
    then
        return reject("invalid server muzzle pose")
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { character }
    ray.IgnoreWater = false
    if cameraOrigin ~= nil or cameraDirection ~= nil then
        if
            typeof(cameraOrigin) ~= "Vector3"
            or typeof(cameraDirection) ~= "Vector3"
            or not finite(cameraOrigin.X)
            or not finite(cameraOrigin.Y)
            or not finite(cameraOrigin.Z)
            or not finite(cameraDirection.X)
            or not finite(cameraDirection.Y)
            or not finite(cameraDirection.Z)
            or (cameraOrigin - root.Position).Magnitude > Config.MaximumCameraDistance
            or math.abs(cameraDirection.Magnitude - 1) > 0.01
        then
            return reject("invalid camera ray")
        end
        local length = Config.MaximumRange + Config.MaximumCameraDistance
        local intent = aim - cameraOrigin
        if
            intent.Magnitude > length + 0.1
            or intent:Dot(cameraDirection) < 0
            or (intent - cameraDirection * intent:Dot(cameraDirection)).Magnitude > 0.5
        then
            return reject("aim outside camera ray")
        end
        -- Resolve world occlusion on the server, independently of the client's raycast.
        local result = workspace:Raycast(cameraOrigin, cameraDirection.Unit * length, ray)
        aim = if result then result.Position else cameraOrigin + cameraDirection.Unit * length
    end
    local offset = aim - muzzle
    if offset.Magnitude < 0.1 or offset.Magnitude > Config.MaximumRange + Config.MaximumCameraDistance + 8 then
        return reject("aim distance")
    end
    local direction = offset.Unit
    local origin = muzzle
    -- Validate the actual launch point and root-to-muzzle path, never a fabricated
    -- four-stud clearance point. Swept collision continues from this same muzzle.
    local start = root.Position + Vector3.new(0, 1, 0)
    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") and part.CanCollide then
            local localPoint = part.CFrame:PointToObjectSpace(origin)
            local half = part.Size * 0.5 + Vector3.new(0.1, 0.1, 0.1)
            if
                math.abs(localPoint.X) <= half.X
                and math.abs(localPoint.Y) <= half.Y
                and math.abs(localPoint.Z) <= half.Z
            then
                return reject("muzzle inside character collision geometry")
            end
        end
    end
    if workspace:Raycast(start, origin - start, ray) then
        return reject("root-to-muzzle obstruction")
    end
    -- Also reject a muzzle enclosed by geometry or flush against a wall.
    if workspace:Raycast(origin - direction * 0.1, direction * 0.2, ray) then
        return reject("muzzle obstruction")
    end
    -- Entitlement permits launching before plot claim; CombatService still gates PvP at impact.
    trace(player, "fire eligible")
    cooldown[player] = now + Config.ShotCooldown
    local visual = deps.IceGunEffects.CreateProjectile(CFrame.lookAt(origin, origin + direction))
    active[player] = {
        Shooter = player,
        Character = character,
        Position = origin,
        Direction = direction,
        Travel = 0,
        Expires = now + Config.ProjectileLifetime,
        Ray = ray,
        Visual = visual,
    }
    local smoke = barrel:FindFirstChild("Smoke")
    if smoke and smoke:IsA("ParticleEmitter") then
        smoke:Emit(50)
    end
    local sound = handle:FindFirstChild("Launch")
    if sound and sound:IsA("Sound") then
        sound.RollOffMaxDistance = 100
        sound:Play()
    end
    if not heartbeat then
        heartbeat = RunService.Heartbeat:Connect(step)
    end
    trace(player, "projectile spawned")
    return true
end

function Service.Init(services)
    deps = services
    if Config.DebugLogging and RunService:IsStudio() then
        warn("[IceGun] projectile initialized revision=" .. REVISION .. " module=" .. script:GetFullName())
    end
    local event = Instance.new("RemoteEvent")
    event.Name = "IceGunFire"
    event.OnServerEvent:Connect(Service.Fire)
    event.Parent = ReplicatedStorage
end

return Service
