-- Real session and inventory authority for two actors sharing one stand.
local owner, ownerHumanoid = player()
local peer, peerHumanoid = player()
local tycoon = dependency.TycoonService
tycoon.RemovePlayer(peer)
setup(tycoon.JoinSession(peer, owner, tycoon.GetRequestContext(owner)), "join teammate session")
setup(tycoon.GetSessionId(peer) == tycoon.GetSessionId(owner), "shared session")
local ownerRoot = owner.Character:FindFirstChild("HumanoidRootPart")
local peerRoot = peer.Character:FindFirstChild("HumanoidRootPart")
ownerRoot.CFrame, peerRoot.CFrame = frame(0, 5, 0), frame(20, 5, 0)
peerRoot.Size = vec(8, 0.5, 6)
for _, p in { owner, peer } do
    for _, id in { "Apple", "Ice", "Cherries" } do
        carry(p, id)
    end
end
local foreignId = tool(owner):GetAttribute("CarryItemId")
local first = inventory.ThrowHeld(peer, foreignId)
check(ingredients.GetRecord(first).Id == "Cherries", "teammate cannot choose another actor's held identity")
check(
    inventory.GetCarryCount(owner) == 3 and inventory.GetCarryCount(peer) == 2,
    "shared stand keeps independent inventories"
)
local second = inventory.ThrowHeld(owner, nil, true)
check(ingredients.GetRecord(second).Id == "Cherries", "other actor throws independently")
check(
    ingredients.GetRecord(first).Owner == nil and ingredients.GetRecord(second).Owner == nil,
    "both throws release ownership into loose world"
)
local oldBlockcast = workspaceFake.Blockcast
local blocker = peerRoot
function blocker:GetFullName()
    return "Workspace.Teammate.HumanoidRootPart"
end
workspaceFake.Blockcast = function(_, _, _, _, params)
    check(params.FilterDescendantsInstances[1] == owner.Character, "only thrower excluded from world query")
    check(not table.find(params.FilterDescendantsInstances, peer.Character), "teammate still obstructs throw path")
    return { Instance = blocker }
end
check(
    inventory.ThrowHeld(owner, nil, true) == nil and inventory.GetCarryCount(owner) == 2,
    "teammate obstruction does not destroy owned item"
)
workspaceFake.Blockcast = oldBlockcast
-- Mirror bootstrap cleanup before binding a fresh character; old carry cannot leak.
local oldCharacter = peer.Character
peerHumanoid.Health = 0
inventory.CleanupCharacter(peer)
check(inventory.GetCarryCount(peer) == 0, "respawn cleanup retires old carry reservations")
local newCharacter = instance("Model")
newCharacter.Name = "RespawnedPeer"
local newRoot = instance("Part")
newRoot.Name, newRoot.Parent, newRoot.CFrame = "HumanoidRootPart", newCharacter, frame(40, 5, 0)
newRoot.Size = vec(1, 9, 1)
local newHead = instance("Part")
newHead.Name, newHead.Parent, newHead.CFrame = "Head", newCharacter, frame(40, 14, 0)
local newHumanoid = instance("Humanoid")
newHumanoid.Parent, newHumanoid.Health, newHumanoid.Died = newCharacter, 100, signal()
function newHumanoid:EquipTool(t)
    t.Parent = newCharacter
    t.Equipped:Fire()
end
peer.Character = newCharacter
carry(peer, "Banana")
local respawnThrow = inventory.ThrowHeld(peer, nil, true)
check(
    ingredients.GetRecord(respawnThrow).Id == "Banana" and inventory.GetCarryCount(peer) == 0,
    "fresh tall character can pick up and throw"
)
check(respawnThrow:GetPivot().Position.X == 40, "respawn uses current root rather than previous character")
check(
    inventory.GetCarryCount(owner) == 2 and oldCharacter ~= peer.Character,
    "peer respawn preserves teammate inventory"
)
inventory.ClearHeld(owner)
