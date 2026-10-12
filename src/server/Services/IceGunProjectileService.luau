--!strict
-- Ice Shotgun cone resolver. Module name/API retained for existing tool lifecycle wiring.
-- Camera data is untrusted aim intent, never a damage target or attack origin.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
local Presentation = require(script.Parent.IceShotgunPresentationService)
local Service = {}
local REVISION = "ice-shotgun-2026-10-12"
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
local cooldown: { [Player]: number } = {}
local requests: { [Player]: number } = {}

local function finite(v: number): boolean
    return v == v and math.abs(v) < 1000000
end

function Service.ClearPlayer(_player: Player)
    -- Shots resolve synchronously; putting away the Tool must not reset cooldown.
end

function Service.RemovePlayer(player: Player)
    cooldown[player], requests[player] = nil, nil
    player:SetAttribute("IceGunCooldownEnd", 0)
end

local function attack(player: Player, origin: Vector3, direction: Vector3, ray: RaycastParams): { Presentation.Hit }
    local minimumDot = math.cos(math.rad(Config.ConeAngleDegrees * 0.5))
    -- Snapshot visibility before creating effects or triggering death/drop callbacks.
    local targets: { { Player: Player, Character: Model, Position: Vector3 } } = {}
    for _, victim in Players:GetPlayers() do
        local character = victim.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if
            not character
            or not root
            or not root:IsA("BasePart")
            or not root:IsDescendantOf(workspace)
            or character:FindFirstChildOfClass("ForceField")
            or not deps.CombatService.CanDamagePlayer(player, victim, Config.TeamDamage)
        then
            continue
        end
        local offset = root.Position - origin
        local distance = offset.Magnitude
        if not (distance >= 0.001 and distance <= Config.MaximumRange and direction:Dot(offset.Unit) >= minimumDot) then
            continue
        end
        local obstruction = workspace:Raycast(origin, offset, ray)
        if not obstruction or obstruction.Instance:IsDescendantOf(character) then
            table.insert(targets, { Player = victim, Character = character, Position = root.Position })
        end
    end
    local hits: { Presentation.Hit } = {}
    for _, target in targets do
        -- Revalidate current eligibility/character at damage time; never trust client targets.
        if
            deps.CombatService.DamagePlayer(
                player,
                target.Player,
                target.Character,
                Config.DirectDamage,
                Config.TeamDamage
            )
        then
            local frozen = deps.FreezeStatusService.Apply(target.Player)
            table.insert(hits, { Position = target.Position, UserId = target.Player.UserId, Frozen = frozen })
        end
    end
    return hits
end

function Service.Fire(player: Player, aim: any, cameraOrigin: any?, cameraDirection: any?): (boolean, string?)
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
    local function reject(reason: string): (boolean, string?)
        trace(player, "fire rejected: " .. reason)
        return false, reason
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
    -- four-stud clearance point. Cone visibility uses this same muzzle.
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
    if now < (cooldown[player] or 0) then
        return reject("shot cooldown")
    end
    -- Entitlement permits firing before plot claim; CombatService still gates PvP.
    trace(player, "fire eligible")
    cooldown[player] = now + Config.ShotCooldown
    player:SetAttribute("IceGunCooldownEnd", workspace:GetServerTimeNow() + Config.ShotCooldown)
    local hits = attack(player, origin, direction, ray)
    Presentation.Emit(player, origin, direction, hits)
    trace(player, "cone shot resolved")
    return true
end

function Service.Init(services)
    deps = services
    Presentation.Init()
    if Config.DebugLogging and RunService:IsStudio() then
        warn("[IceGun] shotgun initialized revision=" .. REVISION .. " module=" .. script:GetFullName())
    end
    local event = Instance.new("RemoteEvent")
    event.Name = "IceGunFire"
    event.OnServerEvent:Connect(function(player, aim, origin, direction, character)
        -- Keep selection and fire on the same reliable ordered stream. Neither
        -- path yields, so an immediate shot observes the preceding selection.
        if character ~= nil and character ~= player.Character then
            trace(player, "request rejected: stale character")
            return
        end
        if aim == "Select" then
            if character == nil then
                return
            end
            deps.IceGunService.RequestSelection(player, origin, direction)
        else
            local accepted, reason = Service.Fire(player, aim, origin, direction)
            event:FireClient(player, accepted, player.Character, player:GetAttribute("IceGunCooldownEnd") or 0, reason)
        end
    end)
    event.Parent = ReplicatedStorage
end

return Service
