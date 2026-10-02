-- Death and identity round-trip through the real ingredient/inventory/blender pipeline.
local drop = loadModule("PlayerHeadDropService")
local names = loadModule("IngredientName")
local definitions = loadModule("Ingredients")
drop.Init(dependency)
local subjects = {}
services.Players.GetPlayerFromCharacter = function(_, character)
    for p in subjects do
        if p.Character == character then
            return p
        end
    end
    return nil
end
local function subject(existing, late)
    local p, h
    if existing then
        p = existing
        p.Character = instance("Model")
        part("HumanoidRootPart", p.Character)
        part("Head", p.Character).CFrame = frame(10, 20, 30)
        h = instance("Humanoid")
        h.Health, h.Died = 100, signal()
        h.Parent = if late then nil else p.Character
    else
        p, h = player()
        p.DisplayName = "Eatandpoop"
        p.Character:FindFirstChild("Head").CFrame = frame(10, 20, 30)
    end
    p.Character.Parent = workspaceFake
    p.Character.ChildAdded = signal()
    subjects[p] = true
    drop.ApplyCharacter(p, p.Character)
    return p, h
end
local function heads(p)
    local result = {}
    for _, object in services.CollectionService:GetTagged("IngredientWorldItem") do
        if ingredients.GetRecord(object) and object:GetAttribute("SourceUserId") == p.UserId then
            table.insert(result, object)
        end
    end
    return result
end
local p, h = subject()
local sourceHead = p.Character:FindFirstChild("Head")
local mesh = instance("SpecialMesh")
mesh.Name, mesh.MeshId, mesh.TextureId, mesh.Parent = "AvatarMesh", "victim-mesh", "victim-texture", sourceHead
local face = instance("Decal")
face.Name, face.Texture, face.Parent = "face", "victim-face", sourceHead
local function looksLikeVictim(visual, message)
    local copiedMesh = visual and visual:FindFirstChild("AvatarMesh", true)
    local copiedFace = visual and visual:FindFirstChild("face", true)
    check(
        copiedMesh
            and copiedMesh.MeshId == "victim-mesh"
            and copiedMesh.TextureId == "victim-texture"
            and copiedFace
            and copiedFace.Texture == "victim-face",
        message
    )
end
drop.ApplyCharacter(p, p.Character)
check(#heads(p) == 0, "living characters and repeated binding do not drop heads")
h.Health = 0
h.Died:Fire()
h.Died:Fire()
local object = heads(p)[1]
check(#heads(p) == 1, "repeated death produces exactly one head for this character")
check(
    object:GetPivot().Position.X == 10.75 and object:GetPivot().Position.Y == 20.5,
    "drop captures head position with a small natural offset"
)
looksLikeVictim(object, "death drop clones the actual avatar head")
local unit = ingredients.GetRecord(object).Item
sourceHead:Destroy() -- Appearance must outlive the original character's head.
check(
    object:GetAttribute("IngredientId") == "PlayerHead"
        and object:GetAttribute("SourceUserId") == p.UserId
        and object:GetAttribute("SourceDisplayName") == p.DisplayName
        and object:GetAttribute("SourceUsername") == p.Name,
    "world head publishes server-owned source identity"
)
check(
    ingredients.GetRecord(object).Claimable and ingredients.GetRecord(object).Owner == nil,
    "death drop is a normal claimable loose ingredient"
)
p.CharacterRemoving:Fire(p.Character)
drop.ApplyCharacter(p, p.Character)
h.Died:Fire()
check(#heads(p) == 1, "teardown and rebinding cannot repeat a previous death")
local oldH, oldCharacter = h, p.Character
p, h = subject(p)
h.Health = 0
h.Died:Fire()
oldH.Died:Fire()
p.CharacterRemoving:Fire(oldCharacter)
check(#heads(p) == 2, "new character death drops another head while stale events do nothing")
local other, otherH = subject()
other.DisplayName = "AnotherPlayer"
otherH.Health = 0
otherH.Died:Fire()
check(
    names.Resolve("PlayerHead", "Player Head", p.UserId, p.DisplayName) == "Eatandpoop's Head"
        and names.Resolve("PlayerHead", "Player Head", other.UserId, other.DisplayName) == "AnotherPlayer's Head"
        and definitions.PlayerHead.DisplayName == "Player Head",
    "simultaneous heads retain independent names"
)
for _, invalid in { false, "", "   " } do
    check(names.Resolve("PlayerHead", "Player Head", p.UserId, invalid) == "Player Head", "invalid names use fallback")
end
check(
    names.Resolve("PlayerHead", "Player Head", nil, "Name") == "Player Head"
        and names.Resolve("Banana", "Banana", p.UserId, p.DisplayName) == "Banana",
    "missing identity and normal names stay generic"
)
local late, lateH = subject(p, true)
lateH.Parent = late.Character
late.Character.ChildAdded:Fire(lateH)
lateH.Health = 0
lateH.Died:Fire()
check(#heads(p) == 3, "late Humanoid is observed without blocking character initialization")
local alive, aliveH = subject()
alive.CharacterRemoving:Fire(alive.Character)
aliveH.Died:Fire()
check(#heads(alive) == 0, "character removal without death cannot spawn a head")
local npc = instance("Model")
npc.ChildAdded = signal()
drop.ApplyCharacter(alive, npc)
check(#heads(alive) == 0, "nonplayer character cannot create a drop")
local departing, departingH = subject()
drop.RemovePlayer(departing)
departingH.Died:Fire()
check(#heads(departing) == 0, "player removal disconnects death observation")

local carrier, thief = player(), player()
setup(inventory.CarryWorldItem(carrier, object), "pick up source head")
check(
    tool(carrier).Name == "Eatandpoop's Head" and tool(carrier):GetAttribute("SourceUserId") == p.UserId,
    "normal carry Tool resolves per-item identity"
)
looksLikeVictim(carrier.Character:FindFirstChild("IngredientCarryVisuals"), "overhead carry keeps victim appearance")
local initialDrop = inventory.DropHeld(carrier)
looksLikeVictim(initialDrop, "ordinary drop rebuilds the victim appearance")
setup(inventory.CarryWorldItem(carrier, initialDrop), "pick dropped head back up")
setup(inventory.Deposit(carrier, "PlayerHead", 3), "stash source head")
setup(inventory.Withdraw(carrier, 3), "owner takes head from stash")
looksLikeVictim(carrier.Character:FindFirstChild("IngredientCarryVisuals"), "owner withdrawal keeps victim appearance")
setup(inventory.Deposit(carrier, "PlayerHead", 3), "restash source head")
check(
    slot(carrier).Ingredients[1].SourceUserId == p.UserId
        and slot(carrier).Ingredients[1].SourceDisplayName == "Eatandpoop"
        and slot(carrier).Value == definitions.PlayerHead.Value,
    "stash keeps original identity and normal ingredient value"
)
setup(inventory.Withdraw(thief, 3, carrier), "steal source head")
check(tool(thief).Name == "Eatandpoop's Head", "stash theft preserves original name")
looksLikeVictim(thief.Character:FindFirstChild("IngredientCarryVisuals"), "theft recreates victim appearance")
local thrown = inventory.ThrowHeld(thief)
looksLikeVictim(thrown, "throw after theft keeps victim appearance")
check(
    thrown:GetAttribute("SourceUserId") == p.UserId
        and thrown:GetAttribute("SourceUsername") == p.Name
        and ingredients.GetRecord(thrown).Item.ItemId == unit.ItemId,
    "throw reconstructs world metadata from authoritative item identity"
)
local input = references[thief].BlenderInput
input.Overlaps = { thrown }
setup(blend.TryInput(thief, thrown, input), "consume source head through normal blender")
check(
    blend.GetSnapshot(thief).Ingredients[1] == "PlayerHead" and not ingredients.GetRecord(thrown),
    "head enters normal batch exactly once"
)
check(
    definitions.PlayerHead.Value > 0 and table.find(definitions.PlayerHead.Tags, "Weird") ~= nil,
    "head retains normal value and Weird tag"
)
ingredients.ClearLooseIngredients()
check(#heads(p) == 0 and #heads(other) == 0, "normal world cleanup consumes loose heads")
