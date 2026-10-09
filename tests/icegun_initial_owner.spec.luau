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
function remote:FireServer(aim, origin, direction)
    requestsSent += 1
    if projectile.Fire(services.Players.LocalPlayer, aim, origin, direction) then
        accepted += 1
    end
end
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
for _ = 1, 4 do
    -- A transient nil parent during a transfer must not revoke a server-issued Tool.
    firstTool.Parent = nil
    firstTool.AncestryChanged:Fire()
    firstTool.Parent = owner:FindFirstChildOfClass("Backpack")
    firstTool.AncestryChanged:Fire()
    flush()
    moveInputTool(firstTool, owner.Character)
    local sent, launched = requestsSent, accepted
    firstTool.Activated:Fire()
    check(
        requestsSent == sent + 1 and accepted == launched + 1 and guns(owner) == 1,
        "repeated transfer/re-equip sends one usable shot"
    )
    projectile.ClearPlayer(owner)
    advance(2)
end
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
respawnTool:FindFirstChild("Handle"):FindFirstChild("GunBarrel").WorldPosition = vec(0, 1, -2)
check(not gun.IsEquipped(owner) and guns(owner) == 1, "respawn restores hotbar gun without forced equip")
moveInputTool(respawnTool, owner.Character)
before = accepted
respawnTool.Activated:Fire()
check(accepted == before + 1, "respawned owner fires immediately without pedestal")
print("PASS: Ice Gun initial-owner acquisition to server projectile")
