-- Avatar capture/sanitization and graceful fallbacks use the real visual/spawn API.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
local ingredients = loadModule("IngredientService")
local item = loadModule("IngredientItem")
local geometry = loadModule("IngredientGeometry")
local head = instance("MeshPart")
head.Name, head.MeshId, head.TextureID = "Head", "dynamic-mesh", "dynamic-texture"
head.Color, head.Size = env.Color3.fromRGB(10, 20, 30), vec(2, 3, 2)
head.Anchored, head.Massless, head.CanCollide = true, true, false
head.CollisionGroup = "Characters"
local originalCharacter = instance("Model")
head.Parent = originalCharacter
local function child(class, name, parent)
    local object = instance(class)
    object.Name, object.Parent = name, parent or head
    return object
end
local surface = child("SurfaceAppearance", "Skin")
local bone = child("Bone", "FaceBone")
child("FaceControls", "FaceControls")
child("WrapTarget", "WrapTarget")
local weld = child("Weld", "NeckWeld")
weld.Part0, weld.Part1 = head, originalCharacter
local contaminants = {
    "Script",
    "LocalScript",
    "ModuleScript",
    "Motor6D",
    "WeldConstraint",
    "BallSocketConstraint",
    "Sound",
    "ParticleEmitter",
    "Trail",
    "Beam",
    "BodyVelocity",
    "ObjectValue",
    "ProximityPrompt",
    "ClickDetector",
}
for _, class in contaminants do
    child(class, class)
end
head:SetAttribute("CharacterBehavior", true)
services.CollectionService:AddTag(head, "CharacterTag")
local unit = item.New("PlayerHead", "visual-head")
local world = ingredients.Spawn("PlayerHead", frame(), nil, true, { Item = unit, VisualTemplate = head })
setup(world ~= nil, "spawn actual avatar override")
check(
    world:IsA("MeshPart")
        and world.MeshId == head.MeshId
        and world.TextureID == head.TextureID
        and world.Color == head.Color
        and world.Size == head.Size,
    "MeshPart avatar geometry, texture, color and size survive capture"
)
check(
    world:FindFirstChild("Skin")
        and world:FindFirstChild("FaceBone")
        and world:FindFirstChild("FaceControls")
        and world:FindFirstChild("WrapTarget"),
    "dynamic head rendering children survive sanitization"
)
local inert = not world:FindFirstChild("NeckWeld")
for _, class in contaminants do
    inert = inert and world:FindFirstChild(class) == nil
end
check(
    inert and not world:GetAttribute("CharacterBehavior") and #services.CollectionService:GetTags(world) == 1,
    "loose head has no character joints, references, behavior or effects"
)
check(
    not world.Anchored
        and not world.Massless
        and world.CanCollide
        and world.CanTouch
        and world.CanQuery
        and world.CollisionGroup == "Default"
        and world.NetworkOwner == nil,
    "avatar head uses normal loose ingredient physics and server network ownership"
)
check(
    head.Parent == originalCharacter
        and head.Anchored
        and head.Massless
        and head.CollisionGroup == "Characters"
        and head:FindFirstChild("NeckWeld") == weld
        and head:GetAttribute("CharacterBehavior"),
    "capture does not mutate the victim head"
)
local saved = ingredients.GetRecord(world).Item
check(
    type(saved.VisualKey) == "table" and next(saved.VisualKey) == nil,
    "item appearance descriptor contains no Instance or avatar state"
)
head.MeshId = "changed-after-death"
world.MeshId = "changed-world-proxy"
local copy = item.CopyAll({ saved })[1]
local recreated = ingredients.CreateVisual("PlayerHead", copy)
check(recreated.MeshId == "dynamic-mesh", "item copies resolve an immutable death-time appearance snapshot")
local other = instance("MeshPart")
other.MeshId = "second-victim"
local second = ingredients.Spawn("PlayerHead", frame(), nil, true, { VisualTemplate = other })
check(
    second.MeshId == "second-victim" and ingredients.CreateVisual("PlayerHead", saved).MeshId == "dynamic-mesh",
    "simultaneous heads never share or overwrite appearance"
)
local templates = instance("Folder")
templates.Name, templates.Parent = "Ingredients", storage
local fallback = instance("Part")
fallback.Name, fallback.Parent, fallback.Size = "PlayerHead", templates, vec(4, 4, 4)
head.Archivable = false
for _, invalid in { head, instance("Folder") } do
    local object = ingredients.Spawn("PlayerHead", frame(), nil, true, { VisualTemplate = invalid })
    check(
        object.Size == fallback.Size and not ingredients.GetRecord(object).Item.VisualKey,
        "unusable avatar head falls back to authored prefab"
    )
end
fallback:Destroy()
local generic = ingredients.Spawn("PlayerHead", frame(), nil, true, { VisualTemplate = head })
check(
    generic.Size.X == 1.5 and generic.Size.Y == 1.5 and generic.Size.Z == 1.5,
    "missing prefab still uses normal geometry fallback"
)
local normal = ingredients.Spawn("Banana", frame(), nil, true, { VisualTemplate = other })
check(not normal:IsA("MeshPart"), "normal ingredients ignore avatar visual overrides")
