-- Authoritative lock/collision plus real Tycoon/Inventory integration.
cache.LockBasePresentation = {
    Bind = function()
        return { SetLocked = function() end, Update = function() end, Press = function() end, Destroy = function() end }
    end,
}
local security = loadModule("LockBaseService")
local tycoon = dependency.TycoonService
local owners, plots, buttons, walls = {}, {}, {}, {}
for i = 1, 6 do
    owners[i] = player()
    prepareCharacter(owners[i])
    plots[i] = tycoon.GetPlot(owners[i])
    buttons[i], walls[i] = securityAssets(plots[i])
end
local helper = lockObject("Part", "TurbineHelper", plots[1])
services.CollectionService:AddTag(helper, "PlayerOnlyCollision")
services.CollectionService:AddTag(buttons[1], "PlayerOnlyCollision")
loadModule("PlayerOnlyCollisionService").Init()
security.Init(dependency)
dependency.LockBaseService = security
inventory.Init(dependency)
tycoon.Init({
    SessionStarted = security.StartSession,
    MemberChanged = security.RefreshMembership,
    MemberRemoved = security.RefreshMembership,
    SessionEnded = function(id)
        security.CleanupSession(id)
        inventory.CleanupSession(id)
    end,
})
for _, owner in owners do
    security.StartSession(owner)
end
for i, plot in plots do
    check(
        not security.IsLocked(plot) and plot:GetAttribute("LockBaseLockedUntil") == 0,
        "claim remains unlocked without initial protection"
    )
    check(not walls[i].CanCollide and walls[i].Transparency == 1, "claimed inactive walls remain invisible")
    local ownerRoot = owners[i].Character:FindFirstChild("HumanoidRootPart")
    standingOn[ownerRoot.Position] = buttons[i]
    setup(security.Activate(owners[i], plot), "manual lock for collision contracts")
    standingOn[ownerRoot.Position] = nil
end
check(helper.CanCollide and helper.CollisionGroup == "PlayerOnly", "unrelated tagged helper stays collidable")
check(
    #security.DiscoverWalls(plots[1], plots[1]:FindFirstChild("LockBase")) == 1,
    "discover sibling walls without taking over turbine helper"
)
local root = owners[1].Character:FindFirstChild("HumanoidRootPart")
local enemyRoot = owners[2].Character:FindFirstChild("HumanoidRootPart")
check(not physicalCollision(walls[1], root), "owner crosses own barrier")
check(
    physicalCollision(walls[1], enemyRoot) and physicalCollision(walls[2], root),
    "outsiders including other owners are blocked"
)
check(
    not physicalCollision(walls[1], { CollisionGroup = "Default" })
        and not physicalCollision(walls[1], { CollisionGroup = "Ingredients" }),
    "NPCs and loose items pass through security"
)
standingOn[root.Position] = buttons[1]
check(
    not security.Activate(owners[1], plots[1]) and plots[1]:GetAttribute("LockBaseLockedUntil") == now + 60,
    "active lock cannot be extended"
)
check(not security.Activate(owners[2], plots[1]), "outsider cannot activate another plot")
standingOn[root.Position] = nil
now += 60
heartbeat:Fire(0.1)
check(not security.IsLocked(plots[1]) and not walls[1].CanCollide, "deadline automatically unlocks walls")
standingOn[root.Position] = buttons[1]
check(security.Activate(owners[1], plots[1]), "manual lock available immediately after expiration")
local deadline = now + 60
check(plots[1]:GetAttribute("LockBaseLockedUntil") == deadline, "manual duration is 60 seconds")
for _ = 1, 5 do
    check(not security.Activate(owners[1], plots[1]), "repeated contacts cannot extend manual lock")
end
check(plots[1]:GetAttribute("LockBaseLockedUntil") == deadline, "deadline remains stable")
for i = 2, 6 do
    check(not security.IsLocked(plots[i]) and not walls[i].CanCollide, "six plots maintain independent states")
end
local teammate = player()
prepareCharacter(teammate)
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owners[1], tycoon.GetRequestContext(owners[1])), "join locked plot")
local teammateRoot = teammate.Character:FindFirstChild("HumanoidRootPart")
check(not physicalCollision(walls[1], teammateRoot), "new teammate crosses active walls immediately")
carry(owners[1], "Milk")
setup(inventory.Deposit(owners[1], "Milk", 1), "seed member stash access")
check(press(teammate, "TAKE", 1, owners[1]), "teammate keeps protected stash access during lock")
inventory.ClearHeld(teammate)
local broadBody = lockObject("Part", "UpperTorso", teammate.Character)
broadBody.Size, broadBody.CollisionGroup = vec(6, 4, 3), "Players"
teammate.Character.DescendantAdded:Fire(broadBody)
check(not physicalCollision(walls[1], broadBody), "wide/replaced avatar parts receive member exemptions")
setup(tycoon.LeaveTeam(teammate, tycoon.GetRequestContext(teammate)), "remove teammate")
check(
    physicalCollision(walls[1], teammateRoot) and physicalCollision(walls[1], broadBody),
    "teammate removal immediately revokes all body access"
)
local oldCharacter = owners[1].Character
security.RemoveCharacter(owners[1])
local replacement = player()
owners[1].Character = replacement.Character
prepareCharacter(owners[1])
security.ApplyCharacter(owners[1], owners[1].Character)
local replacementRoot = owners[1].Character:FindFirstChild("HumanoidRootPart")
check(
    not physicalCollision(walls[1], replacementRoot) and physicalCollision(walls[1], root),
    "respawn restores only current-character access"
)
standingOn[root.Position] = nil
-- Locked TAKE must preserve both sides; safe-slot permissions remain separate.
carry(owners[1], "Banana")
setup(inventory.Deposit(owners[1], "Banana", 3), "seed exposed stash")
local stored = slot(owners[1], 3).Ingredients[1].ItemId
check(not press(owners[2], "TAKE", 3, owners[1]), "locked-base theft rejected")
check(
    slot(owners[1], 3).Count == 1
        and slot(owners[1], 3).Ingredients[1].ItemId == stored
        and inventory.GetCarryCount(owners[2]) == 0,
    "rejected theft preserves exact inventory"
)
check(press(owners[1], "TAKE", 3), "owner retains normal stash access while locked")
setup(inventory.Deposit(owners[1], "Banana", 3), "restore exposed unit")
now = deadline
heartbeat:Fire(0.1)
check(press(owners[2], "TAKE", 3, owners[1]), "unlocked theft uses normal rules")
inventory.ClearHeld(owners[2])
carry(owners[1], "Banana")
setup(inventory.Deposit(owners[1], "Banana", 1), "seed permanently protected slot")
check(not press(owners[2], "TAKE", 1, owners[1]), "permanently protected stash remains protected when unlocked")
-- Race: security activates during visual creation, before actual slot reservation.
carry(owners[1], "Milk")
setup(inventory.Deposit(owners[1], "Milk", 3), "seed commit race")
now += 200
standingOn[replacementRoot.Position] = buttons[1]
local createVisual = dependency.IngredientService.CreateVisual
dependency.IngredientService.CreateVisual = function(...)
    local visual = createVisual(...)
    setup(security.Activate(owners[1], plots[1]), "activate during TAKE preparation")
    return visual
end
check(
    not inventory.Withdraw(owners[2], 3, owners[1])
        and slot(owners[1], 3).Count == 1
        and inventory.GetCarryCount(owners[2]) == 0,
    "commit recheck rejects theft without consuming stored unit"
)
dependency.IngredientService.CreateVisual = createVisual
standingOn[replacementRoot.Position] = nil
local oldId = tycoon.GetSessionId(owners[1])
tycoon.RemovePlayer(owners[1])
check(not walls[1].CanCollide and not security.IsLocked(plots[1]), "release disables walls and security")
check(not security.Activate(owners[1], plots[1]), "stale former member cannot activate")
setup(tycoon.AssignPlot(owners[1], plots[1]) ~= nil, "reclaim same plot")
check(not security.IsLocked(plots[1]), "reclaim remains unlocked")
standingOn[replacementRoot.Position] = buttons[1]
setup(security.Activate(owners[1], plots[1]), "manual lock new session")
standingOn[replacementRoot.Position] = nil
local newDeadline = plots[1]:GetAttribute("LockBaseLockedUntil")
security.CleanupSession(oldId)
check(
    security.IsLocked(plots[1]) and plots[1]:GetAttribute("LockBaseLockedUntil") == newDeadline,
    "stale session cleanup cannot unlock new manual lock"
)
now += 59
heartbeat:Fire(0.1)
check(security.IsLocked(plots[1]), "new session keeps its own manual deadline")
now += 1
heartbeat:Fire(0.1)
check(not security.IsLocked(plots[1]), "manual lock expires independently")
-- Actual Reject standing verification and contact latch, not a client request.
replacementRoot.AssemblyLinearVelocity = vec(0, 3, 0)
standingOn[replacementRoot.Position] = buttons[1]
check(not security.Activate(owners[1], plots[1]), "jumping contact cannot activate security")
replacementRoot.AssemblyLinearVelocity = vec(0, 0, 0)
standingOn[replacementRoot.Position] = nil
check(not security.Activate(owners[1], plots[1]), "nearby player without button support cannot activate")
standingOn[replacementRoot.Position] = buttons[1]
heartbeat:Fire(0.1)
check(security.IsLocked(plots[1]), "grounded physical contact activates immediately")
now += 60
heartbeat:Fire(0.1)
check(not security.IsLocked(plots[1]), "standing on plate through expiration cannot relock automatically")
standingOn[replacementRoot.Position] = nil
heartbeat:Fire(0.1)
standingOn[replacementRoot.Position] = buttons[1]
heartbeat:Fire(0.1)
check(security.IsLocked(plots[1]), "step off and back on reactivates without cooldown")
standingOn[replacementRoot.Position] = nil
-- Late-authored walls adopt the current state, with exemptions before collision.
local lateWall = lockObject("Part", "Wall", plots[1])
services.CollectionService:AddTag(lateWall, "PlayerOnlyCollision")
tagAdded.PlayerOnlyCollision:Fire(lateWall)
heartbeat:Fire(0.1)
check(
    lateWall.CanCollide and not physicalCollision(lateWall, replacementRoot) and physicalCollision(lateWall, enemyRoot),
    "late wall discovery preserves member/outsider security"
)
local nestedWall = lockObject("Part", "UnnamedBarrier", plots[1]:FindFirstChild("LockBase"))
services.CollectionService:AddTag(nestedWall, "PlayerOnlyCollision")
local explicitWall = lockObject("Part", "UnnamedSibling", plots[1])
explicitWall:SetAttribute("LockBaseWall", true)
services.CollectionService:AddTag(explicitWall, "PlayerOnlyCollision")
check(
    #security.DiscoverWalls(plots[1], plots[1]:FindFirstChild("LockBase")) == 4,
    "discover both nested walls and explicitly associated sibling walls"
)
now += 60
heartbeat:Fire(0.1)
-- Owner departure promotes teammate in the existing session; security resets.
setup(tycoon.JoinSession(teammate, owners[1], tycoon.GetRequestContext(owners[1])), "rejoin for owner handoff")
standingOn[teammateRoot.Position] = buttons[1]
setup(security.Activate(teammate, plots[1]), "teammate manually activates shared security")
standingOn[teammateRoot.Position] = nil
tycoon.RemovePlayer(owners[1])
check(
    tycoon.GetOwner(plots[1]) == teammate and not security.IsLocked(plots[1]) and not walls[1].CanCollide,
    "ownership handoff resets lock without changing plot membership authority"
)
print("PASS LockBase gameplay/integration", count, "contracts", setupCount, "setup checks")
