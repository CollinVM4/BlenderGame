--!strict
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.BatConfig)
local GameplaySfx = require(script.Parent.GameplaySfxService)
local Knockback = require(script.Parent.BatKnockback)
local CombatService = {}
local deps: any
type Weapon = { Tool: Tool, LengthScale: number }
type EquippedBat = {
    Character: Model?,
    Weapon: Weapon?,
    RuntimeTool: Instance?,
    Tool: Tool?,
    Handle: Instance?,
    Hitbox: Instance?,
    IsUnderCharacter: boolean,
    IssuedValidation: boolean,
}
type Stun = { Character: Model, Until: number, ImmuneUntil: number, ReleaseOwnership: (() -> ())? }
local weapons: { [Player]: Weapon? } = {}
local attackAt: { [Player]: number } = {}
local swings: { [Player]: {} } = {}
local stuns: { [Player]: Stun } = {}
local characters: { [Player]: {} } = {}
local removals: { [Player]: RBXScriptConnection } = {}
local deaths: { [Player]: RBXScriptConnection } = {}
local backpackWatches: { [Player]: RBXScriptConnection } = {}

-- Arm on the server for one request; silent by default and always disabled outside Studio.
local function swingTrace(player: Player): (string) -> ()
    local enabled = RunService:IsStudio() and player:GetAttribute("BatDebugNextSwing") == true
    if enabled then
        player:SetAttribute("BatDebugNextSwing", nil)
    end
    return function(message: string)
        if enabled then
            print("[Bat] " .. player.Name .. " " .. message)
        end
    end
end

function CombatService.TraceRejectedSwing(player: Player, reason: string)
    swingTrace(player)("SwingBat rejected: " .. reason)
end

local function alive(player: Player): (Model?, BasePart?)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if player.Parent ~= Players or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
        return nil, nil
    end
    return character, root
end
local function levelFor(player: Player): number
    return deps.TycoonService.GetUpgrade(player, "Bat") - 1
end
-- Physical failures must never strand authoritative gameplay stun.
local function setRagdolled(character: Model, enabled: boolean): boolean
    local ok, result = pcall(function()
        return deps.RagdollService.SetRagdolled(character, enabled)
    end)
    if not ok or result ~= true then
        warn("[Bat] Ragdoll " .. (if enabled then "ON" else "OFF") .. " failed: " .. tostring(result))
        return false
    end
    return true
end
local function clearStun(player: Player)
    local state = stuns[player]
    stuns[player] = nil
    if state then
        state.Character:SetAttribute("BatStunned", nil)
        state.Character:SetAttribute("BatImmuneUntil", nil)
        setRagdolled(state.Character, false)
        if state.ReleaseOwnership then
            state.ReleaseOwnership()
        end
    end
    deps.MovementService.SetStunned(player, false)
    player:SetAttribute("StunnedUntil", 0)
end
local function intact(tool: Tool): boolean
    local handle = tool:FindFirstChild("Handle")
    local hitbox = tool:FindFirstChild("Hitbox")
    return handle ~= nil and handle:IsA("BasePart") and hitbox ~= nil and hitbox:IsA("BasePart")
end
local function resolveEquippedBat(player: Player): EquippedBat
    local character = player.Character
    local runtimeTool = if character then character:FindFirstChild("Bat") else nil
    local tool: Tool? = if runtimeTool and runtimeTool:IsA("Tool") then runtimeTool :: Tool else nil
    local weapon = weapons[player]
    local isUnderCharacter = character ~= nil and runtimeTool ~= nil and runtimeTool.Parent == character
    return {
        Character = character,
        Weapon = weapon,
        RuntimeTool = runtimeTool,
        Tool = tool,
        Handle = if tool then tool:FindFirstChild("Handle") else nil,
        Hitbox = if tool then tool:FindFirstChild("Hitbox") else nil,
        IsUnderCharacter = isUnderCharacter,
        IssuedValidation = weapon ~= nil and tool ~= nil and weapon.Tool == tool and isUnderCharacter,
    }
end
local function removeWeapon(player: Player)
    local weapon: Weapon? = weapons[player]
    weapons[player] = nil
    if weapon then
        weapon.Tool:Destroy()
    end
end
local function stretch(position: Vector3, axis: Vector3, ratio: number): Vector3
    return position + axis * (position:Dot(axis) * (ratio - 1))
end

local function localDirection(frame: CFrame, axis: Vector3): Vector3
    return Vector3.new(axis:Dot(frame.RightVector), axis:Dot(frame.UpVector), -axis:Dot(frame.LookVector))
end

local function stretchSize(size: Vector3, axis: Vector3, ratio: number): Vector3
    local x, y, z = math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)
    if x > y and x > z then
        return Vector3.new(size.X * ratio, size.Y, size.Z)
    elseif y > z then
        return Vector3.new(size.X, size.Y * ratio, size.Z)
    end
    return Vector3.new(size.X, size.Y, size.Z * ratio)
end

-- Keep the Handle and Tool.Grip as the fixed pivot of the stretch.
local function configure(weapon: Weapon, level: number)
    local tool = weapon.Tool
    local scale = Config.Levels[level].LengthScale
    local ratio = scale / weapon.LengthScale
    local handle = tool:FindFirstChild("Handle") :: BasePart
    local hitbox = tool:FindFirstChild("Hitbox") :: BasePart
    local handleFrame = handle.CFrame
    local hitboxOffset = handleFrame:ToObjectSpace(hitbox.CFrame)
    local axis = hitboxOffset.LookVector
    local parts: { [BasePart]: CFrame } = {}
    local constraints: { WeldConstraint } = {}
    for _, object in tool:GetDescendants() do
        if object:IsA("BasePart") then
            parts[object] = handleFrame:ToObjectSpace(object.CFrame)
        elseif object:IsA("WeldConstraint") and object.Enabled then
            object.Enabled = false
            table.insert(constraints, object)
        end
    end
    for part, offset in parts do
        if part == hitbox then
            local base = Config.HitboxSize
            local length = base.Z * scale
            local tip = if offset.Position:Dot(axis) >= 0 then axis else axis * -1
            -- Keep the grip-side face fixed, including when the Studio asset has the old size.
            local position = offset.Position + tip * ((length - part.Size.Z) / 2)
            part.Size = Vector3.new(base.X, base.Y, length)
            part.CFrame = handleFrame * (CFrame.new(position) * offset.Rotation)
        elseif part ~= handle then
            local localAxis = localDirection(offset, axis)
            part.Size = stretchSize(part.Size, localAxis, ratio)
            part.CFrame = handleFrame * (CFrame.new(stretch(offset.Position, axis, ratio)) * offset.Rotation)
        end
        part.Anchored = false
        part.CanCollide = false
        part.CanTouch = false
        part.Massless = true
    end
    for _, object in tool:GetDescendants() do
        local parent = object.Parent
        local offset = if parent and parent:IsA("BasePart") then parts[parent] else nil
        if offset and object:IsA("SpecialMesh") then
            local localAxis = localDirection(offset, axis)
            object.Scale = stretchSize(object.Scale, localAxis, ratio)
            object.Offset = stretch(object.Offset, localAxis, ratio)
        elseif offset and object:IsA("Attachment") and parent ~= handle then
            local localAxis = localDirection(offset, axis)
            object.Position = stretch(object.Position, localAxis, ratio)
        elseif object:IsA("JointInstance") then
            -- The joint origins follow the same stretch as their connected parts.
            local part0, part1 = object.Part0, object.Part1
            local offset0, offset1 = if part0 then parts[part0] else nil, if part1 then parts[part1] else nil
            if offset0 then
                local localAxis = localDirection(offset0, axis)
                object.C0 = CFrame.new(stretch(object.C0.Position, localAxis, ratio)) * object.C0.Rotation
            end
            if offset1 then
                local localAxis = localDirection(offset1, axis)
                object.C1 = CFrame.new(stretch(object.C1.Position, localAxis, ratio)) * object.C1.Rotation
            end
        end
    end
    for _, constraint in constraints do
        constraint.Enabled = true
    end
    weapon.LengthScale = scale
    tool:SetAttribute("BatLevel", level)
    tool.CanBeDropped = false
    hitbox.Transparency = 1
    hitbox.CanQuery = false
end
function CombatService.Init(services)
    deps = services
end
function CombatService.RefreshPlayer(player: Player)
    local level = levelFor(player)
    player:SetAttribute("BatLevel", level)
    local character = alive(player)
    if not character or not Config.Levels[level] or not deps.TycoonService.GetSessionId(player) then
        removeWeapon(player)
        swings[player] = nil
        return
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return
    end
    local weapon: Weapon? = weapons[player]
    if weapon and (not intact(weapon.Tool) or (weapon.Tool.Parent ~= backpack and weapon.Tool.Parent ~= character)) then
        removeWeapon(player)
        weapon = nil
    end
    if not weapon then
        local template = ServerStorage:FindFirstChild("Bat")
        local handle = template and template:FindFirstChild("Handle")
        local hitbox = template and template:FindFirstChild("Hitbox")
        if
            not template
            or not template:IsA("Tool")
            or not template.Archivable
            or not handle
            or not handle:IsA("BasePart")
            or not hitbox
            or not hitbox:IsA("BasePart")
        then
            warn("[Bat] Expected archivable ServerStorage.Bat Tool with Handle and Hitbox BaseParts")
            return
        end
        local clone = template:Clone()
        if not intact(clone) then
            clone:Destroy()
            warn("[Bat] Handle and Hitbox must be archivable BaseParts")
            return
        end
        local created: Weapon = {
            Tool = clone,
            LengthScale = 1,
        }
        local ok, problem = pcall(function(): string?
            configure(created, level)
            return nil
        end)
        if not ok then
            clone:Destroy()
            warn("[Bat] Could not configure ServerStorage.Bat: " .. tostring(problem))
            return
        end
        weapons[player] = created
        clone.Unequipped:Connect(function()
            if weapons[player] == created then
                swings[player] = nil
            end
        end)
        local characterToken = characters[player]
        clone.Destroying:Connect(function()
            local current = weapons[player]
            if current and current.Tool == clone then
                weapons[player] = nil
                swings[player] = nil
                task.defer(function()
                    if characterToken and characters[player] == characterToken and player.Character == character then
                        CombatService.RefreshPlayer(player)
                    end
                end)
            end
        end)
        clone.Parent = backpack
    elseif weapon.Tool:GetAttribute("BatLevel") ~= level then
        local ok, problem = pcall(function(): string?
            configure(weapon, level)
            return nil
        end)
        if not ok then
            removeWeapon(player)
            warn("[Bat] Could not update Bat: " .. tostring(problem))
        end
    end
end
function CombatService.IsBatEquipped(player: Player): boolean
    return resolveEquippedBat(player).IssuedValidation
end

local function swingRejection(player: Player, equipped: EquippedBat?): string?
    local character = alive(player)
    if not character then
        return "attacker not alive"
    end
    local resolved = equipped or resolveEquippedBat(player)
    if not resolved.Weapon then
        return "no issued Bat"
    end
    if resolved.Character ~= character or not resolved.IssuedValidation then
        return "issued Bat not equipped"
    end
    local handle, hitbox = resolved.Handle, resolved.Hitbox
    if not handle or not handle:IsA("BasePart") or not hitbox or not hitbox:IsA("BasePart") then
        return "missing Handle/Hitbox"
    end
    if not Config.Levels[levelFor(player)] then
        return "Bat level locked"
    end
    if not deps.TycoonService.GetSessionId(player) then
        return "no plot session"
    end
    if not deps.MovementService.CanPerformGameplayAction(player) then
        return "attacker stunned"
    end
    return nil
end
-- Both weapons share current plot/team eligibility; their status immunity stays separate.
local function luckyBuff(player: Player, id: string): boolean
    return deps.LuckyBlockService ~= nil and deps.LuckyBlockService.IsBuffActive(player, id)
end
local function luckyImmune(player: Player): boolean
    return luckyBuff(player, "StarPower") or luckyBuff(player, "Invincibility")
end
local function playerDamageRejection(attacker: Player, victim: Player, allowTeamDamage: boolean?): string?
    if deps.ProtectionService and deps.ProtectionService.IsProtected(victim) then
        return "target protected"
    end
    if luckyImmune(victim) then
        return "target immune"
    end
    local session = deps.TycoonService.GetSessionId(victim)
    if attacker == victim then
        return "self"
    end
    if not alive(victim) then
        return "target not alive"
    end
    if not session then
        return "target has no plot session"
    end
    if not alive(attacker) or not deps.TycoonService.GetSessionId(attacker) then
        return "attacker has no living plot session"
    end
    if not allowTeamDamage and session == deps.TycoonService.GetSessionId(attacker) then
        return "shared plot session"
    end
    if not allowTeamDamage and not attacker.Neutral and not victim.Neutral and attacker.Team == victim.Team then
        return "non-neutral Roblox teammates"
    end
    return nil
end

function CombatService.CanDamagePlayer(attacker: Player, victim: Player, allowTeamDamage: boolean?): boolean
    return playerDamageRejection(attacker, victim, allowTeamDamage) == nil
end

local function forfeitProtection(player: Player)
    if deps.ProtectionService and deps.ProtectionService.IsProtected(player) then
        deps.ProtectionService.Forfeit(player)
    end
end

function CombatService.DamagePlayer(
    attacker: Player,
    victim: Player,
    character: Model,
    damage: number,
    allowTeamDamage: boolean?
): boolean
    if victim.Character ~= character or not CombatService.CanDamagePlayer(attacker, victim, allowTeamDamage) then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or character:FindFirstChildOfClass("ForceField") then
        return false
    end
    local healthBefore = humanoid.Health
    humanoid:TakeDamage(damage)
    if humanoid.Health >= healthBefore then
        return false
    end
    -- Shared successful-damage hook includes ice; bat stun also qualifies below.
    forfeitProtection(attacker)
    return true
end

local function enemyRejection(attacker: Player, victim: Player): string?
    local reason = playerDamageRejection(attacker, victim)
    if reason then
        return reason
    end
    if (victim.Character :: Model):FindFirstChildOfClass("ForceField") then
        return "target spawn protected"
    end
    local stun = stuns[victim]
    if deps.MovementService.IsStunned(victim) then
        return "target stunned"
    end
    if stun and os.clock() < stun.ImmuneUntil then
        return "target immune"
    end
    return nil
end
local function hit(attacker: Player, victim: Player, level: typeof(Config.Levels[1])): boolean
    if enemyRejection(attacker, victim) then
        return false
    end
    local duration = level.StunDuration
    local character = victim.Character :: Model
    local untilTime = os.clock() + duration
    local state: Stun = { Character = character, Until = untilTime, ImmuneUntil = untilTime + Config.ImmunitySeconds }
    stuns[victim] = state
    -- Replicated cosmetic status; existing os.clock deadlines remain authoritative.
    character:SetAttribute("BatImmuneUntil", workspace:GetServerTimeNow() + duration + Config.ImmunitySeconds)
    character:SetAttribute("BatStunned", true)
    victim:SetAttribute("StunnedUntil", untilTime)
    deps.MovementService.SetStunned(victim, true)
    forfeitProtection(attacker)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local attackerRoot = (attacker.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
    local away = Knockback.Direction(attackerRoot, root)
    deps.InventoryService.DropCarriedIngredients(victim, "BatStun", away)
    -- Own simulation before requesting Physics; release after a short launch interval.
    local owned, release = pcall(Knockback.TakeOwnership, root)
    if owned then
        state.ReleaseOwnership = release
    else
        warn("[Bat] Ownership acquisition failed: " .. tostring(release))
    end
    local ragdolled = setRagdolled(character, true)
    if ragdolled and state.ReleaseOwnership then
        RunService.Heartbeat:Once(function()
            local releaseOwnership = state.ReleaseOwnership :: () -> ()
            local currentCharacter, currentRoot = alive(victim)
            if
                stuns[victim] ~= state
                or currentCharacter ~= character
                or currentRoot ~= root
                or not character:IsDescendantOf(workspace)
                or os.clock() >= state.Until
                or not deps.MovementService.IsStunned(victim)
                or luckyImmune(victim)
                or (deps.ProtectionService and deps.ProtectionService.IsProtected(victim))
            then
                releaseOwnership()
                return
            end
            local ok, problem = pcall(function(): boolean
                if not deps.RagdollService.IsRagdolled(character) or root.Anchored then
                    return false
                end
                Knockback.Apply(root, away, level, if luckyBuff(attacker, "MegaBat") then 2 else 1)
                return true
            end)
            if not ok then
                warn("[Bat] Knockback failed: " .. tostring(problem))
            end
            if ok and problem then
                task.delay(Config.Knockback.ServerOwnershipSeconds, releaseOwnership)
            else
                releaseOwnership()
            end
        end)
    elseif state.ReleaseOwnership then
        state.ReleaseOwnership()
    end
    task.delay(duration, function()
        if stuns[victim] == state and victim.Character == character then
            setRagdolled(character, false)
            if state.ReleaseOwnership then
                state.ReleaseOwnership()
            end
            deps.MovementService.SetStunned(victim, false)
            character:SetAttribute("BatStunned", nil)
            victim:SetAttribute("StunnedUntil", 0)
        end
    end)
    -- Use the authoritative level resolved at impact. Apply last so lethal damage
    -- follows normal Humanoid death cleanup without recreating stun after Died.
    local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
    CombatService.DamagePlayer(attacker, victim, character, humanoid.MaxHealth * level.DamageFraction)
    return true
end
local function horizontal(vector: Vector3): Vector3
    return Vector3.new(vector.X, 0, vector.Z)
end

local function facingDirection(root: BasePart, fallback: Vector3): Vector3
    local facing = horizontal(root.CFrame.LookVector)
    return if facing.Magnitude > 0.01 then facing.Unit else fallback
end

-- The box query is a broad phase. Use the part's bounds for reach so an arm can
-- make tip contact even when the target's root is past the end of the swing.
local function inSwing(part: BasePart, origin: Vector3, forward: Vector3, reach: number): boolean
    local offset = origin - part.Position
    local frame = part.CFrame
    local half = part.Size / 2
    local nearest = part.Position
        - origin
        + frame.RightVector * math.clamp(offset:Dot(frame.RightVector), -half.X, half.X)
        + frame.UpVector * math.clamp(offset:Dot(frame.UpVector), -half.Y, half.Y)
        + frame.LookVector * math.clamp(offset:Dot(frame.LookVector), -half.Z, half.Z)
    local distance = horizontal(nearest).Magnitude
    if distance > reach then
        return false
    end
    if distance <= Config.CloseContactRadius then
        return true
    end
    local direction = horizontal(part.Position - origin)
    return forward:Dot(direction) >= direction.Magnitude * math.cos(math.rad(Config.SwingHalfAngle))
end

-- No target, level, duration or geometry is accepted from the requester.
function CombatService.SwingBat(player: Player): boolean
    local trace = swingTrace(player)
    local equipped = resolveEquippedBat(player)
    local function fullName(object: Instance?): string
        return if object then object:GetFullName() else "nil"
    end
    trace(
        string.format(
            "BatLevel=%s runtimeTool=%s runtimeToolParent=%s isUnderCharacter=%s handle=%s hitbox=%s issuedValidation=%s",
            tostring(levelFor(player)),
            fullName(equipped.RuntimeTool),
            fullName(if equipped.RuntimeTool then equipped.RuntimeTool.Parent else nil),
            tostring(equipped.IsUnderCharacter),
            fullName(equipped.Handle),
            fullName(equipped.Hitbox),
            tostring(equipped.IssuedValidation)
        )
    )
    local rejection = swingRejection(player, equipped)
    local _, startRoot = alive(player)
    if rejection or not startRoot or os.clock() < (attackAt[player] or 0) then
        trace("SwingBat rejected: " .. (rejection or "cooldown"))
        return false
    end
    trace("SwingBat accepted")
    attackAt[player] = os.clock() + Config.SwingCooldown * (if luckyBuff(player, "MegaBat") then 0.5 else 1)
    local token = {}
    swings[player] = token
    local character = player.Character :: Model
    local weapon = equipped.Weapon :: Weapon
    local tool = equipped.Tool :: Tool
    local hitbox = equipped.Hitbox :: BasePart
    local forward = facingDirection(startRoot, Vector3.new(0, 0, -1))
    local position = hitbox.Position
    GameplaySfx.Emit("BatSwing", position)
    local context = deps.TycoonService.GetRequestContext(player)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.RespectCanCollide = false
    params.MaxParts = 0
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { character }
    local function sampleImpact(sample: number)
        if swings[player] ~= token then
            return
        end
        local currentEquipped = resolveEquippedBat(player)
        trace("impact callback reached sample=" .. tostring(sample))
        if
            swings[player] ~= token
            or player.Character ~= character
            or currentEquipped.Weapon ~= weapon
            or currentEquipped.Tool ~= tool
            or swingRejection(player, currentEquipped) ~= nil
            or not deps.TycoonService.ValidateActor(player, context)
        then
            trace(
                "impact rejected: "
                    .. (swingRejection(player, currentEquipped) or "character/weapon/swing or membership changed")
            )
            swings[player] = nil
            return
        end
        local _, root = alive(player)
        if not root then
            swings[player] = nil
            return
        end
        local level = Config.Levels[levelFor(player)]
        local reach = Config.HitboxSize.Z * level.LengthScale
        -- A sprinting turn can change direction during the windup or between samples.
        forward = facingDirection(root, forward)
        local origin = root.Position
        local center = origin + forward * (reach / 2)
        local at = CFrame.lookAt(center, center + forward)
        local size = Vector3.new(2 * reach, Config.SwingHeight, reach)
        trace(string.format("cone reach=%.2f CFrame=%s Size=%s", reach, tostring(at), tostring(size)))
        local overlaps = workspace:GetPartBoundsInBox(at, size, params)
        trace("overlap parts=" .. tostring(#overlaps))
        local closest: Model? = nil
        local closestRoot: BasePart? = nil
        local closestDistance = math.huge
        local bestAim = -math.huge
        local candidates: { [Model]: { Player: Player? } } = {}
        for _, part in overlaps do
            if not inSwing(part, origin, forward, reach) then
                continue
            end
            local ancestor: Instance? = part
            while ancestor and ancestor ~= workspace do
                if ancestor:IsA("Model") then
                    local victim = Players:GetPlayerFromCharacter(ancestor)
                    if victim then
                        candidates[ancestor] = { Player = victim }
                        trace(
                            "candidate part="
                                .. part.Name
                                .. " character="
                                .. ancestor.Name
                                .. " player="
                                .. victim.Name
                        )
                        break
                    elseif
                        deps.CustomerService.CanHitCustomer(player, ancestor)
                        or (deps.JackedNoobService and deps.JackedNoobService.CanHit(player, ancestor))
                    then
                        candidates[ancestor] = {}
                        break
                    end
                end
                ancestor = ancestor.Parent
            end
        end
        for target, candidate in candidates do
            local victim = candidate.Player
            local targetRoot: BasePart? = nil
            local enemyReason: string? = nil
            if victim then
                local _, playerRoot = alive(victim)
                targetRoot = playerRoot
                enemyReason = enemyRejection(player, victim)
                trace(
                    "candidate="
                        .. victim.Name
                        .. " plot/team/stun/immunity="
                        .. (enemyReason or "pass")
                        .. " sessions="
                        .. tostring(deps.TycoonService.GetSessionId(player))
                        .. "/"
                        .. tostring(deps.TycoonService.GetSessionId(victim))
                )
            elseif
                deps.CustomerService.CanHitCustomer(player, target)
                or (deps.JackedNoobService and deps.JackedNoobService.CanHit(player, target))
            then
                targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
            else
                enemyReason = "NPC ineligible"
            end
            if target and targetRoot then
                local direction = targetRoot.Position - root.Position
                local targetRootDistance = direction.Magnitude
                local flat = horizontal(direction)
                local front = forward:Dot(flat)
                local aim = if flat.Magnitude > 0.01 then front / flat.Magnitude else 1
                local obstruction = workspace:Raycast(root.Position, direction, ray)
                local visible = not obstruction or obstruction.Instance:IsDescendantOf(target)
                trace(
                    string.format(
                        "candidate=%s rootDistance=%.3f aim=%.3f forward=%s LOS=%s obstruction=%s",
                        target.Name,
                        targetRootDistance,
                        aim,
                        tostring(front >= 0),
                        tostring(visible),
                        if obstruction then obstruction.Instance:GetFullName() else "none"
                    )
                )
                if not enemyReason and front >= 0 and visible then
                    if aim > bestAim or (aim == bestAim and targetRootDistance < closestDistance) then
                        closest, closestRoot = target, targetRoot
                        closestDistance, bestAim = targetRootDistance, aim
                    end
                end
            end
        end
        trace("selected=" .. (if closest then closest.Name else "no valid target"))
        if closest and closestRoot then
            swings[player] = nil
            local impact = closestRoot.Position
            local applied: boolean
            local victim = Players:GetPlayerFromCharacter(closest)
            if victim then
                applied = hit(player, victim, level)
                trace(
                    "SetStunned result="
                        .. tostring(deps.MovementService.IsStunned(victim))
                        .. " Stunned="
                        .. tostring(victim:GetAttribute("Stunned"))
                        .. " StunnedUntil="
                        .. tostring(victim:GetAttribute("StunnedUntil"))
                )
            else
                local context = {
                    Direction = Knockback.Direction(root, closestRoot),
                    Duration = level.StunDuration,
                }
                if deps.JackedNoobService and deps.JackedNoobService.CanHit(player, closest) then
                    applied = deps.JackedNoobService.Hit(player, closest, context)
                else
                    applied = deps.CustomerService.HitCustomer(player, closest, context)
                end
            end
            if applied then
                GameplaySfx.Emit("BatImpact", impact)
            end
        end
    end
    -- Keep only one pending sample. Late callbacks expire instead of replaying
    -- missed contacts, and each sample follows the attacker's current position and facing.
    local deadline = os.clock() + Config.HitActiveEnd
    local sample = 0
    local function sampleNext()
        if swings[player] ~= token then
            return
        end
        if os.clock() >= deadline then
            swings[player] = nil
            return
        end
        sample += 1
        sampleImpact(sample)
        if swings[player] == token then
            task.delay(math.min(Config.HitSampleInterval, math.max(0, deadline - os.clock())), sampleNext)
        end
    end
    task.delay(Config.HitActiveStart, sampleNext)
    return true
end
function CombatService.ApplyCharacter(player: Player, character: Model)
    local characterToken = {}
    characters[player] = characterToken
    swings[player] = nil
    attackAt[player] = nil
    clearStun(player)
    removeWeapon(player)
    if deaths[player] then
        deaths[player]:Disconnect()
        deaths[player] = nil
    end
    if backpackWatches[player] then
        backpackWatches[player]:Disconnect()
    end
    backpackWatches[player] = player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            CombatService.RefreshPlayer(player)
        end
    end)
    if removals[player] then
        removals[player]:Disconnect()
    end
    removals[player] = player.CharacterRemoving:Connect(function(removing)
        if removing == character and characters[player] == characterToken then
            characters[player] = nil
            swings[player] = nil
            clearStun(player)
        end
    end)
    task.spawn(function()
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
        if
            characters[player] ~= characterToken
            or not root
            or player.Character ~= character
            or player.Parent ~= Players
            or not humanoid
            or not humanoid:IsA("Humanoid")
        then
            return
        end
        deaths[player] = humanoid.Died:Connect(function()
            swings[player] = nil
            clearStun(player)
            removeWeapon(player)
        end)
        CombatService.RefreshPlayer(player)
    end)
end
function CombatService.RemovePlayer(player: Player)
    if removals[player] then
        removals[player]:Disconnect()
        removals[player] = nil
    end
    characters[player] = nil
    if deaths[player] then
        deaths[player]:Disconnect()
    end
    if backpackWatches[player] then
        backpackWatches[player]:Disconnect()
    end
    deaths[player], backpackWatches[player] = nil, nil
    swings[player], attackAt[player] = nil, nil
    clearStun(player)
    removeWeapon(player)
end
return require(script.Parent.StudioServices).Wrap("CombatService", CombatService)
