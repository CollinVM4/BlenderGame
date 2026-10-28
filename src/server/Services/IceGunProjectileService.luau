--!strict
-- Ice Ray radial blast resolver. Module name/API retained for existing tool lifecycle wiring.
-- Camera data is untrusted aim intent, never a damage target or attack origin.
-- Hits are radius-only: no cone angle, no muzzle, no line-of-sight raycast and
-- no projectile travel may gate them, so a target inside the sphere is hit
-- regardless of the direction the caster faces or what stands between them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
local Presentation = require(script.Parent.IceShotgunPresentationService)
local Service = {}
local REVISION = "ice-ray-radial-2026-10-28"
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

local function attack(player: Player, origin: Vector3, character: Model): { Presentation.Hit }
    -- Snapshot every target before creating effects or triggering death/drop
    -- callbacks, so a hit cannot change the membership of this same blast.
    local targets: { { Player: Player, Character: Model, Position: Vector3 } } = {}
    local seen: { [Player]: boolean } = {}
    for _, victim in Players:GetPlayers() do
        -- The caster is excluded here, not only by CombatService, so a future
        -- eligibility change can never turn a radial blast into self-damage.
        if victim == player or seen[victim] then
            continue
        end
        local victimCharacter = victim.Character
        local root = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
        if
            not victimCharacter
            or not root
            or not root:IsA("BasePart")
            or not root:IsDescendantOf(workspace)
            or victimCharacter:FindFirstChildOfClass("ForceField")
            or not deps.CombatService.CanDamagePlayer(player, victim, Config.TeamDamage)
        then
            continue
        end
        -- Radius only, in 3D. A NaN root position fails this comparison, so an
        -- invalid pose is excluded without a Unit/NaN crash. No direction dot
        -- product and no occlusion raycast are consulted.
        local distance = (root.Position - origin).Magnitude
        if not (distance <= Config.BlastRadius) then
            continue
        end
        seen[victim] = true
        table.insert(targets, { Player = victim, Character = victimCharacter, Position = root.Position })
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
    -- NPC customers, if the customer system is wired in: reuse their existing
    -- bat reaction (ragdoll, then return to the queue marker) without touching
    -- their order, payout or queue membership. Bad (thief/freeloader) customers
    -- stay ineligible here because CanHitCustomer requires a bat for them, so
    -- an ice blast can never reject or steal through that path. Each model is
    -- reacted to at most once per blast, and a model whose root is outside the
    -- sphere is skipped even if another of its parts intersects the query.
    local customers = deps.CustomerService
    if customers then
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { character }
        params.RespectCanCollide = false
        params.MaxParts = 0
        local reacted: { [Model]: boolean } = {}
        for _, part in workspace:GetPartBoundsInRadius(origin, Config.BlastRadius, params) do
            local ancestor: Instance? = part
            while ancestor and ancestor ~= workspace do
                if ancestor:IsA("Model") then
                    local model = ancestor :: Model
                    local root = model:FindFirstChild("HumanoidRootPart")
                    if
                        not reacted[model]
                        and not Players:GetPlayerFromCharacter(model)
                        and root
                        and root:IsA("BasePart")
                        and (root.Position - origin).Magnitude <= Config.BlastRadius
                        and customers.CanHitCustomer(player, model)
                    then
                        reacted[model] = true
                        local direction = if (root.Position - origin).Magnitude > 0
                            then (root.Position - origin).Unit
                            else Vector3.new(0, 0, -1)
                        customers.HitCustomer(player, model, {
                            Direction = direction,
                            Duration = Config.FreezeSeconds,
                        })
                    end
                    break
                end
                ancestor = ancestor.Parent
            end
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
    elseif not finite(root.Position.X) or not finite(root.Position.Y) or not finite(root.Position.Z) then
        return reject("invalid character root")
    elseif h.PlatformStand or not deps.MovementService.CanPerformGameplayAction(player) then
        return reject("gameplay action blocked")
    end
    -- The blast is centered on the caster root, so Handle/GunBarrel pose,
    -- root-to-muzzle clearance and muzzle-against-wall checks are removed:
    -- none of them can affect a radial hit, and each of them could previously
    -- block a blast that the radius alone should have landed. The issued-tool
    -- check above is the only weapon check that remains.
    -- Aim and camera data are still sanity-checked when supplied (finite
    -- vectors, unit camera direction, bounded camera position), because a
    -- malformed payload must still be rejected. They are no longer used to
    -- derive a direction, an aim distance, or world occlusion: the crosshair
    -- is activation intent only, and the server hit area is the caster sphere.
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
    end
    if now < (cooldown[player] or 0) then
        return reject("shot cooldown")
    end
    -- Entitlement permits firing before plot claim; CombatService still gates PvP.
    trace(player, "fire eligible")
    cooldown[player] = now + Config.ShotCooldown
    player:SetAttribute("IceGunCooldownEnd", workspace:GetServerTimeNow() + Config.ShotCooldown)
    local origin = root.Position
    local hits = attack(player, origin, character)
    Presentation.Emit(player, origin, hits)
    trace(player, "radial blast resolved")
    return true
end

function Service.Init(services)
    deps = services
    Presentation.Init()
    if Config.DebugLogging and RunService:IsStudio() then
        warn("[IceGun] radial blast initialized revision=" .. REVISION .. " module=" .. script:GetFullName())
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
