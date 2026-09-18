-- Real module; appearance signals and description application are simulated.
-- Geometry/physics results must still be verified in Studio.
env.PhysicalProperties = {
    new = function(...)
        return { ... }
    end,
}
env.Enum.HumanoidRigType = { R15 = { Name = "R15" }, R6 = { Name = "R6" } }
env.task.defer = function(fn, ...)
    local args = table.pack(...)
    table.insert(deferred, function()
        fn(table.unpack(args, 1, args.n))
    end)
end
local logs = {}
env.print = function(message)
    table.insert(logs, message)
end
local warnings = {}
env.warn = function(message)
    table.insert(warnings, message)
end
services.RunService.Heartbeat = { Wait = function() end }
studio = true

local function object(class, name, parentObject)
    local result = instance(class)
    result.Name, result.Parent = name, parentObject
    result.WaitForChild = result.FindFirstChild
    function result:FindFirstAncestorWhichIsA(kind)
        local ancestor = self.Parent
        while ancestor do
            if ancestor:IsA(kind) then
                return ancestor
            end
            ancestor = ancestor.Parent
        end
        return nil
    end
    function result:GetMass()
        return 16
    end
    result.AssemblyMass = 16
    return result
end
local targets = {
    HeightScale = 1,
    WidthScale = 1,
    DepthScale = 1,
    HeadScale = 1,
    BodyTypeScale = 0,
    ProportionScale = 0,
}
local function spawnCharacter(player, rig)
    local character = object("Model", "Character")
    character.DescendantAdded = signal()
    local humanoid = object("Humanoid", "Humanoid", character)
    humanoid.RigType = rig or env.Enum.HumanoidRigType.R15
    -- Regression: all dimensions already 1, but Body Type is 100%.
    humanoid.Description = {
        HeightScale = 1,
        WidthScale = 1,
        DepthScale = 1,
        HeadScale = 1,
        BodyTypeScale = 1,
        ProportionScale = 0.8,
        Head = 123,
        Face = 456,
        Shirt = 789,
        Pants = 987,
        HeadColor = "original",
        AccessoryBlob = "original layered clothing",
    }
    humanoid.Applications = 0
    function humanoid:GetAppliedDescription()
        local copy = table.clone(self.Description)
        copy.Destroy = function() end
        return copy
    end
    function humanoid:ApplyDescriptionAsync(description)
        check(player.Loaded or not player.LoadCharacterAppearance, "application precedes appearance loading")
        self.Applications += 1
        self.Description = table.clone(description)
        for name in targets do
            local liveName = if name == "HeightScale"
                    or name == "WidthScale"
                    or name == "DepthScale"
                    or name == "ProportionScale"
                then "Body" .. name
                else name
            local value = object("NumberValue", liveName, self)
            value.Value = description[name]
        end
    end
    local root = object("Part", "HumanoidRootPart", character)
    local torso = object("Part", "UpperTorso", character)
    torso.CanCollide = true
    local accessory = object("Accessory", "Hat", character)
    local handle = object("Part", "Handle", accessory)
    handle.CanCollide = true
    local tool = object("Tool", "GameplayTool", character)
    local toolHandle = object("Part", "Handle", tool)
    toolHandle.CanCollide, toolHandle.Massless = true, false
    player.Character = character
    return character, humanoid, root, torso, handle, toolHandle
end
local player = object("Player", "TestPlayer")
player.CharacterAppearanceLoaded, player.CharacterRemoving = signal(), signal()
player.LoadCharacterAppearance = true
function player:HasAppearanceLoaded()
    return self.Loaded == true
end
local service = loadModule("CharacterPhysicsService")
local character, humanoid, root, torso, handle, toolHandle = spawnCharacter(player)
service.ApplyCharacter(player, character)
flush()
check(humanoid.Applications == 0, "waits for appearance")
check(
    handle.Massless and not handle.CanCollide and not handle.CanTouch and not handle.CanQuery,
    "cosmetics normalized early"
)
check(torso.CanCollide and torso.Massless, "body pushing preserved")
check(toolHandle.CanCollide and not toolHandle.Massless, "tools unchanged")
player.CharacterAppearanceLoaded:Fire(object("Model", "WrongCharacter"))
flush()
check(humanoid.Applications == 0, "ignores another character's event")
player.Loaded = true
player.CharacterAppearanceLoaded:Fire(character)
player.CharacterAppearanceLoaded:Fire(character)
flush()
check(humanoid.Applications == 1, "Body Type alone triggers exactly one application")
for name, expected in targets do
    check(humanoid.Description[name] == expected, "final " .. name)
end
for _, name in { "Head", "Face", "Shirt", "Pants", "HeadColor", "AccessoryBlob" } do
    check(humanoid.Description[name] ~= nil, "preserves " .. name)
end
check(
    humanoid.Description.Head == 123 and humanoid.Description.AccessoryBlob == "original layered clothing",
    "asset identity preserved"
)
check(
    #logs == 1 and string.find(logs[1], "BodyTypeScale=0.000") and string.find(logs[1], "boundingSize="),
    "one final readback diagnostic"
)
service.ApplyCharacter(player, character)
flush()
check(humanoid.Applications == 1, "duplicate bootstrap call ignored")
local lateAccessory = object("Accessory", "LateHat", character)
local latePart = object("Part", "Handle", lateAccessory)
character.DescendantAdded:Fire(latePart)
flush()
check(latePart.Massless and not latePart.CanCollide, "late accessory normalized")

player.CharacterRemoving:Fire(character)
local replacement, replacementHumanoid = spawnCharacter(player)
service.ApplyCharacter(player, replacement) -- HasAppearanceLoaded catches missed event.
flush()
check(replacementHumanoid.Applications == 1, "already-loaded respawn normalized")
check(#logs == 2, "one diagnostic for each respawn")
local stale = object("Part", "Handle", lateAccessory)
character.DescendantAdded:Fire(stale)
flush()
check(stale.Massless == nil, "old character listeners disconnected")

local pending, pendingHumanoid = spawnCharacter(player)
service.ApplyCharacter(player, pending)
service.RemovePlayer(player)
flush()
check(pendingHumanoid.Applications == 0, "pending work cancelled on removal")
local r6, r6Humanoid = spawnCharacter(player, env.Enum.HumanoidRigType.R6)
service.ApplyCharacter(player, r6)
flush()
check(r6Humanoid.Applications == 0, "R6 never receives R15 description")

player.Loaded, player.LoadCharacterAppearance = false, false
local custom, customHumanoid = spawnCharacter(player)
customHumanoid.Description.BodyTypeScale = 0
customHumanoid.Description.ProportionScale = 0
customHumanoid.Description.HeadScale = 1.5
service.ApplyCharacter(player, custom)
flush()
check(
    customHumanoid.Applications == 1 and customHumanoid.Description.HeadScale == 1,
    "head-only mismatch normalized without appearance wait"
)
check(#warnings == 0, "no normalization failures")
print(string.format("PASS: %d character lifecycle/proportion assertions (mocked Roblox boundary).", count))
