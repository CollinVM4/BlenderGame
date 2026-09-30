--!strict
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.BatConfig)
local GameplaySfx = require(script.Parent.GameplaySfxService)
local Knockback = require(script.Parent.BatKnockback)
local CombatService = {}
local deps: any
type Weapon = { Tool: Tool, Scale: number }
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
type Stun = { Character: Model, Until: number, ImmuneUntil: number }
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
        setRagdolled(state.Character, false)
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
-- Tool.Grip is inherited unchanged from the authored template; never rotate mesh/hitbox to fix grip.
-- Scale only the clone. Temporarily release constraints so resizing cannot move the character.
local function configure(weapon: Weapon, level: number)
    local tool = weapon.Tool
    local scale = Config.Levels[level].Scale
    local ratio = scale / weapon.Scale
    local handle = tool:FindFirstChild("Handle") :: BasePart
    local parts: { [BasePart]: CFrame } = {}
    local constraints: { WeldConstraint } = {}
    for _, object in tool:GetDescendants() do
        if object:IsA("BasePart") then
            parts[object] = handle.CFrame:ToObjectSpace(object.CFrame)
        elseif object:IsA("WeldConstraint") and object.Enabled then
            object.Enabled = false
            table.insert(constraints, object)
        end
    end
    for part, offset in parts do
        part.Size *= ratio
        part.CFrame = handle.CFrame * (CFrame.new(offset.Position * (ratio - 1)) * offset)
        part.Anchored = false
        part.CanCollide = false
        part.CanTouch = false
        part.Massless = true
    end
    for _, object in tool:GetDescendants() do
        if object:IsA("SpecialMesh") then
            object.Scale *= ratio
            object.Offset *= ratio
        elseif object:IsA("Attachment") then
            object.Position *= ratio
        elseif object:IsA("JointInstance") then
            object.C0 = CFrame.new(object.C0.Position * ratio) * object.C0.Rotation
            object.C1 = CFrame.new(object.C1.Position * ratio) * object.C1.Rotation
        end
    end
    for _, constraint in constraints do
        constraint.Enabled = true
    end
    weapon.Scale = scale
    tool:SetAttribute("BatLevel", level)
    tool.CanBeDropped = false
    local hitbox = tool:FindFirstChild("Hitbox") :: BasePart
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
            Scale = 1,
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
    equipped = equipped or resolveEquippedBat(player)
    if not equipped.Weapon then
        return "no issued Bat"
    end
    if equipped.Character ~= character or not equipped.IssuedValidation then
        return "issued Bat not equipped"
    end
    if
        not equipped.Handle
        or not equipped.Handle:IsA("BasePart")
        or not equipped.Hitbox
        or not equipped.Hitbox:IsA("BasePart")
    then
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
local function enemyRejection(attacker: Player, victim: Player): string?
    local session = deps.TycoonService.GetSessionId(victim)
    local character = alive(victim)
    local stun = stuns[victim]
    if attacker == victim then
        return "self"
    end
    if not character then
        return "target not alive"
    end
    if not session then
        return "target has no plot session"
    end
    if session == deps.TycoonService.GetSessionId(attacker) then
        return "shared plot session"
    end
    if not attacker.Neutral and not victim.Neutral and attacker.Team == victim.Team then
        return "non-neutral Roblox teammates"
    end
    if deps.MovementService.IsStunned(victim) then
        return "target stunned"
    end
    if stun and os.clock() < stun.ImmuneUntil then
        return "target immune"
    end
    return nil
end
local function hit(attacker: Player, victim: Player, duration: number)
    if enemyRejection(attacker, victim) then
        return
    end
    local character = victim.Character :: Model
    local untilTime = os.clock() + duration
    local state = { Character = character, Until = untilTime, ImmuneUntil = untilTime + Config.ImmunitySeconds }
    stuns[victim] = state
    victim:SetAttribute("StunnedUntil", untilTime)
    deps.MovementService.SetStunned(victim, true)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local attackerRoot = (attacker.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
    local away = Knockback.Direction(attackerRoot, root)
    deps.InventoryService.DropCarriedIngredients(victim, "BatStun", away)
    if setRagdolled(character, true) then
        RunService.Heartbeat:Once(function()
            local currentCharacter, currentRoot = alive(victim)
            if
                stuns[victim] ~= state
                or currentCharacter ~= character
                or currentRoot ~= root
                or not character:IsDescendantOf(workspace)
                or os.clock() >= state.Until
                or not deps.MovementService.IsStunned(victim)
            then
                return
            end
            local ok, problem = pcall(function(): boolean
                if not deps.RagdollService.IsRagdolled(character) or root.Anchored then
                    return false
                end
                Knockback.Apply(root, away)
                return true
            end)
            if not ok then
                warn("[Bat] Knockback failed: " .. tostring(problem))
            end
        end)
    end
    task.delay(duration, function()
        if stuns[victim] == state and victim.Character == character then
            setRagdolled(character, false)
            deps.MovementService.SetStunned(victim, false)
            victim:SetAttribute("StunnedUntil", 0)
        end
    end)
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
    if rejection or os.clock() < (attackAt[player] or 0) then
        trace("SwingBat rejected: " .. (rejection or "cooldown"))
        return false
    end
    trace("SwingBat accepted")
    attackAt[player] = os.clock() + Config.SwingCooldown
    local token = {}
    swings[player] = token
    local character = player.Character :: Model
    local weapon = equipped.Weapon :: Weapon
    local tool = equipped.Tool :: Tool
    local hitbox = equipped.Hitbox :: BasePart
    local _, root = alive(player)
    local position = hitbox.Position
    GameplaySfx.Emit("BatSwing", position)
    local context = deps.TycoonService.GetRequestContext(player)
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
        -- Sample the exact issued clone at impact, including authored joints/animation.
        -- configure() owns its size; clients never supply query geometry in the request.
        local hitbox = currentEquipped.Hitbox :: BasePart
        local size, at = hitbox.Size, hitbox.CFrame
        local maxRootDistance = Config.MaxRootDistance * level.Scale
        -- Replicated Tool poses are observations, not authority to hit across the map.
        if not ((at.Position - root.Position).Magnitude <= maxRootDistance) then
            trace("impact rejected: Hitbox pose exceeds sanity distance")
            swings[player] = nil
            return
        end
        trace("Hitbox=" .. hitbox:GetFullName() .. " CFrame=" .. tostring(at) .. " Size=" .. tostring(size))
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { character :: Model }
        params.RespectCanCollide = false
        params.MaxParts = 0
        local overlaps = workspace:GetPartBoundsInBox(at, size, params)
        trace("overlap parts=" .. tostring(#overlaps))
        local closest: Model? = nil
        local distance = math.huge
        local candidates: { [Model]: { Player: Player? } } = {}
        for _, part in overlaps do
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
                    elseif deps.CustomerService.CanHitCustomer(player, ancestor) then
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
            elseif deps.CustomerService.CanHitCustomer(player, target) then
                targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
            else
                enemyReason = "customer ineligible"
            end
            if target and targetRoot then
                local direction = targetRoot.Position - root.Position
                local separation = direction.Magnitude
                local forward = root.CFrame.LookVector:Dot(direction)
                local ray = RaycastParams.new()
                ray.FilterType = Enum.RaycastFilterType.Exclude
                ray.FilterDescendantsInstances = { character :: Model }
                local obstruction = workspace:Raycast(root.Position, direction, ray)
                local visible = not obstruction or obstruction.Instance:IsDescendantOf(target)
                trace(
                    string.format(
                        "candidate=%s rootDistance=%.3f sanityDistance=%s forwardDot=%.3f forward=%s LOS=%s obstruction=%s",
                        target.Name,
                        separation,
                        tostring(separation <= maxRootDistance),
                        forward,
                        tostring(forward >= 0),
                        tostring(visible),
                        if obstruction then obstruction.Instance:GetFullName() else "none"
                    )
                )
                if
                    not enemyReason
                    and separation <= maxRootDistance
                    and separation < distance
                    and forward >= 0
                    and visible
                then
                    closest, distance = target, separation
                end
            end
        end
        trace("selected=" .. (if closest then closest.Name else "no valid target"))
        if closest then
            swings[player] = nil
            local victim = Players:GetPlayerFromCharacter(closest)
            if victim then
                hit(player, victim, level.StunDuration)
                trace(
                    "SetStunned result="
                        .. tostring(deps.MovementService.IsStunned(victim))
                        .. " Stunned="
                        .. tostring(victim:GetAttribute("Stunned"))
                        .. " StunnedUntil="
                        .. tostring(victim:GetAttribute("StunnedUntil"))
                )
            else
                local targetRoot = closest:FindFirstChild("HumanoidRootPart") :: BasePart
                deps.CustomerService.HitCustomer(player, closest, {
                    Direction = Knockback.Direction(root, targetRoot),
                    Duration = level.StunDuration,
                })
            end
        end
    end
    -- Keep only one pending sample. Late callbacks expire instead of replaying
    -- missed contacts, and each live sample reads the current Tool geometry.
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
