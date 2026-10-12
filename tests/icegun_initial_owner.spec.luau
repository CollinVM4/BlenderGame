config.StudioGamePassSimulation = false
local originalClone = template.Clone
function template:Clone()
    return inputTool(originalClone(self))
end
local gun = loadModule("IceGunService")
local projectile = loadModule("IceGunProjectileService")
local combat = loadModule("CombatService")
deps.IceGunService, deps.IceGunProjectileService, deps.CombatService = gun, projectile, combat
deps.FreezeStatusService = {
    Apply = function()
        error("unassigned owner cannot freeze a victim")
    end,
}
combat.Init(deps)
projectile.Init(deps)
gun.Init(deps)
local remote = replicated:FindFirstChild("IceGunFire")
local accepted, requestsSent = 0, 0
function remote:FireServer(aim, origin, direction, character)
    if aim ~= "Select" then
        requestsSent += 1
    end
    local before = #visualProjectiles
    self.OnServerEvent:Fire(services.Players.LocalPlayer, aim, origin, direction, character)
    if #visualProjectiles > before then
        accepted += 1
    end
end
local regularFireServer = remote.FireServer
local enemy, enemyHumanoid = fighter("Enemy")
ready(enemy)
local hit = nil
workspaceFake.Raycast = function(_, _, direction)
    if direction.Magnitude < 100 then
        return hit
    end
    return nil
end
local owner, ownerHumanoid, firstTool
for _, order in
    {
        "grant-before-controller",
        "controller-before-grant",
        "Character-late",
        "Backpack-late",
        "Backpack-then-Character",
        "Character-then-Backpack",
    }
do
    local p, h = fighter(nil) -- Account ownership is independent of plot membership.
    p.CharacterAdded = signal()
    properties(p)
    ready(p)
    ownership[p.UserId] = true
    services.Players.LocalPlayer = p
    local character, backpack = p.Character, p:FindFirstChildOfClass("Backpack")
    if order == "Character-late" or order == "Backpack-then-Character" or order == "Character-then-Backpack" then
        p.Character = nil
    end
    if order == "Backpack-late" or order == "Backpack-then-Character" or order == "Character-then-Backpack" then
        backpack.Parent = nil
    end
    cache.IceGunController = nil
    local controller = loadModule("IceGunController")
    if order ~= "grant-before-controller" then
        controller.Init()
    end
    gun.AddPlayer(p)
    flush()
    if order == "Backpack-then-Character" then
        backpack.Parent = p
        p.ChildAdded:Fire(backpack)
    end
    if order == "Character-late" or order == "Backpack-then-Character" or order == "Character-then-Backpack" then
        p.Character = character
        gun.ApplyCharacter(p, character)
        p.CharacterAdded:Fire(character)
        flush()
    end
    if order == "Backpack-late" or order == "Character-then-Backpack" then
        gun.ApplyCharacter(p, character)
        flush()
        backpack.Parent = p
        p.ChildAdded:Fire(backpack)
        flush()
    end
    local tool = inputTool(backpack:FindFirstChild("IcicleGun"))
    setup(tool and guns(p) == 1, "verified owner received one Tool: " .. order)
    check(not gun.IsEquipped(p), "initial owner grant preserves normal hotbar selection: " .. order)
    if order == "grant-before-controller" then
        controller.Init()
    else
        backpack.ChildAdded:Fire(tool)
    end
    tool:FindFirstChild("Handle"):FindFirstChild("GunBarrel").WorldPosition = vec(0, 1, -2)
    moveInputTool(tool, character)
    local before = accepted
    tool.Activated:Fire()
    check(accepted == before + 1, "first hotbar selection launches server projectile without pedestal/plot: " .. order)
    hit = { Instance = enemy.Character:FindFirstChild("HumanoidRootPart"), Position = vec(0, 1, -10) }
    advance(0.2)
    hit = nil
    check(enemyHumanoid.Health == 100, "pre-claim launch preserves unassigned-player PvP immunity")
    owner, ownerHumanoid, firstTool = p, h, tool
    advance(2)
end
services.Players.LocalPlayer = owner
-- Claim alone changes PvP membership, not entitlement, issued instance or launch gates.
sessions[owner] = "OwnerPlot"
local claimedShot = accepted
firstTool.Activated:Fire()
check(
    accepted == claimedShot + 1 and gun.GetEquipped(owner) == firstTool,
    "claim without pedestal keeps initial hotbar gun launchable"
)
projectile.ClearPlayer(owner)
advance(2)
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
check(gun.RequestEquip(owner) and gun.GetEquipped(owner) == firstTool, "pedestal equips same registered instance")
owner.Character.ChildAdded:Fire(firstTool)
local before = accepted
firstTool.Activated:Fire()
check(accepted == before + 1, "pedestal equip remains usable")
projectile.ClearPlayer(owner)
advance(2)
local bat = inputTool(env.Instance.new("Tool"))
bat.Name = "Bat"
bat:SetAttribute("BatLevel", 1)
bat.Parent = owner:FindFirstChildOfClass("Backpack")
for cycle = 1, 20 do
    -- A transient nil parent during a transfer must not revoke a server-issued Tool.
    firstTool.Parent = nil
    firstTool.AncestryChanged:Fire()
    firstTool.Parent = owner:FindFirstChildOfClass("Backpack")
    firstTool.AncestryChanged:Fire()
    flush()
    moveInputTool(bat, owner.Character)
    local sentBeforeBat = requestsSent
    bat.Activated:Fire()
    check(requestsSent == sentBeforeBat, "switching to Bat sends no Ice Gun request")
    moveInputTool(bat, owner:FindFirstChildOfClass("Backpack"))
    moveInputTool(firstTool, owner.Character)
    check(gun.GetEquipped(owner) == firstTool, "same issued instance authorized on cycle " .. tostring(cycle))
    local sent, launched = requestsSent, accepted
    firstTool.Activated:Fire()
    check(
        requestsSent == sent + 1 and accepted == launched + 1 and guns(owner) == 1,
        "repeated transfer/re-equip sends one usable shot"
    )
    projectile.ClearPlayer(owner)
    advance(2)
end
-- Approximate the supplied live trace: client Character, server Backpack.
-- The engine double has one Parent, so swap views only at the remote boundary.
local serverParent = owner:FindFirstChildOfClass("Backpack")
local forwardSelection = false
function remote:FireServer(aim, origin, direction, character)
    if aim == "Select" and not forwardSelection then
        return
    end
    local tool = if aim == "Select" then origin else firstTool
    local clientParent = tool.Parent
    tool.Parent = serverParent
    regularFireServer(self, aim, origin, direction, character)
    serverParent = tool.Parent
    tool.Parent = clientParent
end
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
moveInputTool(firstTool, owner.Character)
local sentBeforeMismatch, acceptedBeforeMismatch = requestsSent, accepted
firstTool.Activated:Fire()
check(
    requestsSent == sentBeforeMismatch + 1 and accepted == acceptedBeforeMismatch,
    "client-only equip sends fire but server Backpack rejects it, matching supplied trace"
)
advance(2)
forwardSelection = true
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
moveInputTool(firstTool, owner.Character)
local beforeSelection = accepted
firstTool.Activated:Fire()
check(accepted == beforeSelection + 1, "hotbar intent establishes server equip before fire without pedestal")
projectile.ClearPlayer(owner)
advance(2)
for _ = 1, 20 do
    moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
    check(serverParent:IsA("Backpack"), "hotbar put-away reaches server")
    moveInputTool(firstTool, owner.Character)
    local sent, launched = requestsSent, accepted
    firstTool.Activated:Fire()
    check(
        requestsSent == sent + 1 and accepted == launched + 1 and guns(owner) == 1,
        "split-view hotbar re-equip sends one authorized projectile"
    )
    projectile.ClearPlayer(owner)
    advance(2)
end
-- Activation can precede engine equip notifications or follow a blocked selection.
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
firstTool.Parent = owner.Character -- Deliberately no ChildAdded/Equipped notification.
local beforeEarlyActivation = accepted
firstTool.Activated:Fire()
check(accepted == beforeEarlyActivation + 1, "activation before equip notifications establishes server selection")
projectile.ClearPlayer(owner)
advance(2)
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
movement.SetStunned(owner, true)
moveInputTool(firstTool, owner.Character)
check(serverParent:IsA("Backpack"), "blocked selection cannot equip on server")
movement.SetStunned(owner, false)
local beforeRecovery = accepted
firstTool.Activated:Fire()
check(accepted == beforeRecovery + 1, "first eligible activation retries a previously rejected selection")
projectile.ClearPlayer(owner)
advance(2)
-- Queue the single event stream while the client rapidly switches. Server
-- signals are a separate view, not synchronous client callbacks in this double.
local queued = {}
function remote:FireServer(...)
    table.insert(queued, table.pack(...))
end
local function drainSelections()
    local ancestry = firstTool.AncestryChanged
    firstTool.AncestryChanged = signal()
    local pending = queued
    queued = {}
    for _, request in pending do
        local clientParent = firstTool.Parent
        firstTool.Parent = serverParent
        regularFireServer(remote, table.unpack(request, 1, request.n))
        serverParent = firstTool.Parent
        firstTool.Parent = clientParent
    end
    firstTool.AncestryChanged = ancestry
end
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
moveInputTool(firstTool, owner.Character)
firstTool.Activated:Fire() -- No network drain between selection and activation.
moveInputTool(firstTool, owner:FindFirstChildOfClass("Backpack"))
moveInputTool(bat, owner.Character)
moveInputTool(bat, owner:FindFirstChildOfClass("Backpack"))
-- Obsolete notifications describe current state rather than old event intent.
firstTool.Equipped:Fire()
firstTool.Unequipped:Fire()
local sentBeforeQueue, launchedBeforeQueue = requestsSent, accepted
local queuedBeforeDrain = #queued
drainSelections()
check(
    requestsSent == sentBeforeQueue + 1 and accepted == launchedBeforeQueue + 1,
    "queued immediate activation observes preceding selection on the same stream"
)
check(serverParent:IsA("Backpack"), "rapid Ice Gun/Bat/empty switching ends put away on server")
check(#queued == 0 and queuedBeforeDrain == 5, "late notifications do not enqueue stale re-equips")
projectile.ClearPlayer(owner)
advance(2)
moveInputTool(firstTool, owner.Character)
firstTool.Activated:Fire()
drainSelections()
check(accepted == launchedBeforeQueue + 2, "next hotbar selection fires after rapid switching")
projectile.ClearPlayer(owner)
advance(2)
remote.FireServer = regularFireServer
local rejectedShots = #visualProjectiles
remote.OnServerEvent:Fire(owner, "Select", firstTool, false, enemy.Character)
remote.OnServerEvent:Fire(owner, vec(0, 1, -20), nil, nil, enemy.Character)
check(
    gun.IsEquipped(owner) and #visualProjectiles == rejectedShots,
    "old Character selection/fire cannot mutate current state"
)
local health = ownerHumanoid.Health
ownerHumanoid.Health = 0
check(not gun.RequestSelection(owner, firstTool, true), "dead Character cannot request equip")
ownerHumanoid.Health = health
ownerHumanoid.PlatformStand = true
check(not gun.RequestSelection(owner, firstTool, true), "PlatformStand blocks equip intent")
ownerHumanoid.PlatformStand = false
movement.SetStunned(owner, true)
check(not gun.RequestSelection(owner, firstTool, true), "action eligibility blocks equip intent")
check(gun.RequestSelection(owner, firstTool, false), "blocked owner can put weapon away without re-equipping")
movement.SetStunned(owner, false)
check(gun.RequestSelection(owner, firstTool, true), "eligible owner can select again")
local foreign = inputTool(template:Clone())
foreign.Parent = owner:FindFirstChildOfClass("Backpack")
check(not gun.RequestSelection(owner, foreign, true), "selection rejects a foreign instance")
foreign:Destroy()
local stranger = fighter(nil)
ready(stranger)
check(not gun.RequestSelection(stranger, firstTool, true), "selection rejects a nonowner/foreign player")
check(not gun.RequestSelection(owner, firstTool, "true"), "selection rejects malformed equip intent")
local actualParent = firstTool.Parent
firstTool.Parent = workspaceFake
check(not gun.RequestSelection(owner, firstTool, true), "selection cannot reclaim an unowned issued Tool")
firstTool.Parent = actualParent
-- Restore the normal shared-parent engine boundary for respawn coverage.
remote.FireServer = regularFireServer
local old = owner.Character
owner.CharacterRemoving:Fire(old)
local respawn, respawnHumanoid = fighter(nil)
owner.Character = respawn.Character
respawn.Character = nil
ready(owner)
gun.ApplyCharacter(owner, owner.Character)
flush()
local respawnTool = inputTool(owner:FindFirstChildOfClass("Backpack"):FindFirstChild("IcicleGun"))
owner.CharacterAdded:Fire(owner.Character)
check(not gun.RequestSelection(owner, firstTool, true), "retired pre-respawn instance cannot be equipped")
respawnTool:FindFirstChild("Handle"):FindFirstChild("GunBarrel").WorldPosition = vec(0, 1, -2)
check(not gun.IsEquipped(owner) and guns(owner) == 1, "respawn restores hotbar gun without forced equip")
moveInputTool(respawnTool, owner.Character)
before = accepted
respawnTool.Activated:Fire()
check(accepted == before + 1, "respawned owner fires immediately without pedestal")
print("PASS: Ice Gun initial-owner acquisition to server projectile")
