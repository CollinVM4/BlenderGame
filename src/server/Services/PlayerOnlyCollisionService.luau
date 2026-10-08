--!strict
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local PlayerOnlyCollisionService = { PlayerGroup = "Players" }
local HELPER_GROUP = "PlayerOnly"
local TAG = "PlayerOnlyCollision"
local initialized = false

local function configurePart(instance: Instance)
    if instance:IsA("BasePart") then
        instance.CollisionGroup = HELPER_GROUP
        instance.CanCollide = true
    end
end

function PlayerOnlyCollisionService.Init()
    if initialized then
        return
    end
    for _, name in { PlayerOnlyCollisionService.PlayerGroup, HELPER_GROUP } do
        if not PhysicsService:IsCollisionGroupRegistered(name) then
            PhysicsService:RegisterCollisionGroup(name)
        end
    end
    -- Only the new helper's relationships change; all existing pairs stay intact.
    -- This includes any ingredient/world-item groups authored in Studio.
    for _, group in PhysicsService:GetRegisteredCollisionGroups() do
        PhysicsService:CollisionGroupSetCollidable(HELPER_GROUP, group.name, false)
    end
    PhysicsService:CollisionGroupSetCollidable(HELPER_GROUP, PlayerOnlyCollisionService.PlayerGroup, true)
    initialized = true

    CollectionService:GetInstanceAddedSignal(TAG):Connect(configurePart)
    for _, instance in CollectionService:GetTagged(TAG) do
        configurePart(instance)
    end
end

return PlayerOnlyCollisionService
