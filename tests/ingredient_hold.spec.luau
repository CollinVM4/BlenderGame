-- Visual-only contracts; asset blending and native equip ordering require Studio.
env.Enum.AnimationPriority = { Action = "Action", Idle = "Idle" }
local config = loadModule("CarryPresentation")
local player = instance("Player")
player.Name = "HoldTestPlayer"
player.CharacterAdded, player.CharacterRemoving = signal(), signal()
services.Players.LocalPlayer = player
services.Players.PlayerRemoving = signal()
local tracks = {}
local function character(withAnimator)
    local model = instance("Model")
    model.ChildAdded, model.DescendantAdded = signal(), signal()
    local humanoid = instance("Humanoid")
    humanoid.Parent, humanoid.Health, humanoid.Died = model, 100, signal()
    local animator = instance("Animator")
    if withAnimator then
        animator.Parent = humanoid
    end
    function animator:LoadAnimation(animation)
        local track = { IsPlaying = false, Destroyed = false, AnimationId = animation.AnimationId }
        function track:Play()
            self.IsPlaying = true
        end
        function track:Stop()
            self.IsPlaying = false
        end
        function track:Destroy()
            self.Destroyed = true
        end
        table.insert(tracks, track)
        return track
    end
    return model, humanoid, animator
end
local function tool(name, kind)
    local item = instance("Tool")
    item.Name = name
    item:SetAttribute("ItemType", kind)
    item.MarkerChanged = signal()
    function item:GetAttributeChangedSignal(attribute)
        assert(attribute == "ItemType")
        return self.MarkerChanged
    end
    return item
end
local model, humanoid = character(true)
player.Character = model
local ingredient = tool("Any display name", "Ingredient")
ingredient.Parent = model
local controller = loadModule("IngredientHoldController")
controller.Init()
check(#tracks == 0, "unset asset is inert with an equipped ingredient")
config.IngredientHoldAnimationId = "rbxassetid://test-only"
controller.Init()
controller.Init()
check(#tracks == 1 and tracks[1].IsPlaying, "existing equipped ingredient starts once")
check(tracks[1].AnimationId == config.IngredientHoldAnimationId, "uses shared animation asset")
check(tracks[1].Looped and tracks[1].Priority == "Action", "pose loops at Action priority")
local function equip(item)
    ingredient.Parent = nil
    item.Parent = model
    model.ChildAdded:Fire(item)
end
local smoothie = tool("Smoothie", nil)
equip(smoothie)
check(not tracks[1].IsPlaying and tracks[1].Destroyed and #tracks == 1, "smoothie yields immediately without pose")
for _, name in { "Bat", "IceGun", "FutureTool", "Apple" } do
    local item = tool(name, nil)
    equip(item)
    check(#tracks == 1, "non-ingredient excluded: " .. name)
    item.Parent = nil
end
smoothie.Parent = nil
equip(ingredient)
ingredient.Parent = nil
ingredient.Unequipped:Fire()
check(tracks[2].Destroyed and not tracks[2].IsPlaying, "unequip stops pose")
equip(ingredient)
ingredient.Parent = nil
ingredient.AncestryChanged:Fire()
check(tracks[3].Destroyed, "throw/reparent stops pose without Unequipped")
equip(ingredient)
ingredient:SetAttribute("ItemType", nil)
ingredient.MarkerChanged:Fire()
check(tracks[4].Destroyed, "marker removal stops pose")
ingredient:SetAttribute("ItemType", "Ingredient")
ingredient.MarkerChanged:Fire()
check(tracks[5].IsPlaying, "late marker replication starts pose")
humanoid.Health = 0
humanoid.Died:Fire()
check(tracks[5].Destroyed, "death stops pose")
player.CharacterRemoving:Fire(model)
local replacement, living, animator = character(false)
player.Character = replacement
player.CharacterAdded:Fire(replacement)
local nextTool = tool("Smoothie", "Ingredient") -- Marker, never display name, determines kind.
nextTool.Parent = replacement
replacement.ChildAdded:Fire(nextTool)
check(#tracks == 5, "does not create a client Animator when replication is late")
animator.Parent = living
replacement.DescendantAdded:Fire(animator)
check(tracks[6].IsPlaying, "replicated Animator arrival starts equipped pose")
nextTool:Destroy()
check(tracks[6].Destroyed and not tracks[6].IsPlaying, "Tool destruction stops pose")
nextTool = tool("Second", "Ingredient")
nextTool.Parent = replacement
replacement.ChildAdded:Fire(nextTool)
player.CharacterRemoving:Fire(replacement)
check(tracks[7].Destroyed, "respawn removal stops pose")
player.CharacterAdded:Fire(replacement)
check(tracks[8].IsPlaying, "replacement binds equipped tool")
services.Players.PlayerRemoving:Fire(player)
check(tracks[8].Destroyed, "leaving releases pose")
replacement.ChildAdded:Fire(nextTool)
check(#tracks == 8, "cleanup detaches callbacks")
controller.Init()
controller.Destroy()
check(tracks[9].Destroyed, "explicit teardown releases pose")

-- Run alongside the real bat controller to check ownership during handoff.
nextTool.Parent = nil
controller.Init()
local batController = loadModule("BatController")
batController.Init()
local weapon = tool("Bat", nil)
local idleAnimation = instance("Animation")
idleAnimation.Name, idleAnimation.AnimationId, idleAnimation.Parent = "IdleAnimation", "bat-test-only", weapon
weapon.Parent = replacement
replacement.ChildAdded:Fire(weapon)
local weaponTrack = tracks[#tracks]
check(weaponTrack.IsPlaying and weaponTrack.AnimationId == "bat-test-only", "bat owns its idle track")
weapon.Parent = nil
weapon.Unequipped:Fire()
nextTool.Parent = replacement
replacement.ChildAdded:Fire(nextTool)
local holdTrack = tracks[#tracks]
check(weaponTrack.Destroyed and holdTrack.IsPlaying, "bat to ingredient releases weapon pose")
nextTool.Parent = nil
nextTool.Unequipped:Fire()
smoothie.Parent = replacement
replacement.ChildAdded:Fire(smoothie)
check(holdTrack.Destroyed and not holdTrack.IsPlaying, "ingredient to smoothie releases pose with both controllers")
smoothie.Parent = nil
weapon.Parent = replacement
replacement.ChildAdded:Fire(weapon)
weaponTrack = tracks[#tracks]
controller.Destroy()
check(weaponTrack.IsPlaying and not weaponTrack.Destroyed, "ingredient teardown never stops weapon tracks")
batController.Destroy()
print("ingredient hold contracts passed")
