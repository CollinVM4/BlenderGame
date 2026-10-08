-- Collision matrix contract at a fake engine boundary; physical contact needs Studio.
local registered = { Default = true, Ingredients = true, WorldItems = true, Players = true }
local matrix = {}
local function pair(a, b)
    return if a < b then a .. ":" .. b else b .. ":" .. a
end
matrix[pair("Ingredients", "Players")] = false
services.PhysicsService = {
    IsCollisionGroupRegistered = function(_, name)
        return registered[name] == true
    end,
    RegisterCollisionGroup = function(_, name)
        assert(not registered[name], "must reuse existing groups")
        registered[name] = true
    end,
    GetRegisteredCollisionGroups = function()
        local result = {}
        for name in registered do
            table.insert(result, { name = name })
        end
        return result
    end,
    CollisionGroupSetCollidable = function(_, a, b, enabled)
        matrix[pair(a, b)] = enabled
    end,
}
local function collides(a, b)
    return matrix[pair(a, b)] ~= false
end
local added = signal()
services.CollectionService.GetInstanceAddedSignal = function(_, tag)
    assert(tag == "PlayerOnlyCollision")
    return added
end
local helper = instance("Part")
helper.CollisionGroup, helper.CanCollide = "Default", false
local authored = {
    Transparency = 1,
    Anchored = true,
    Size = vec(6, 1, 6),
    CFrame = env.CFrame.new(),
    Material = "Plastic",
    Color = color(1, 0, 0),
    CanTouch = false,
    CanQuery = false,
}
for key, value in authored do
    helper[key] = value
end
local model = instance("Model")
services.CollectionService:AddTag(helper, "PlayerOnlyCollision")
services.CollectionService:AddTag(model, "PlayerOnlyCollision")
local collision = loadModule("PlayerOnlyCollisionService")
collision.Init()
check(helper.CollisionGroup == "PlayerOnly" and helper.CanCollide, "startup helper becomes a physical player surface")
for key, value in authored do
    check(helper[key] == value, "helper preserves authored " .. key)
end
check(model.CollisionGroup == nil and model.CanCollide == nil, "tagged non-parts are ignored")
check(collides("Players", "PlayerOnly"), "players collide with helpers")
for _, name in { "Default", "Ingredients", "WorldItems", "PlayerOnly" } do
    check(not collides(name, "PlayerOnly"), name .. " passes through helpers")
end
check(collides("Players", "Default"), "players retain normal world collision")
check(collides("Ingredients", "Default"), "ingredients retain normal world collision")
check(not collides("Players", "Ingredients"), "existing custom collision relationships are preserved")
local late = instance("Part")
late.CollisionGroup, late.CanCollide = "Default", false
services.CollectionService:AddTag(late, "PlayerOnlyCollision")
added:Fire(late)
check(late.CollisionGroup == "PlayerOnly" and late.CanCollide, "runtime tagged parts become player surfaces")
added:Fire(model)
print("PASS player-only collision contracts")
