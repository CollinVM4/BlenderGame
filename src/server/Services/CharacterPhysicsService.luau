--!strict
local RunService = game:GetService("RunService")
local CharacterPhysicsService = {}

-- Enable before spawning in Studio; never prints in live servers.
local DEBUG = true
local ROOT_SIZE = Vector3.new(2, 2, 1)
-- 4 cubic studs * density 4 = 16 mass units, independent of avatar mesh volume.
local ROOT_PHYSICS = PhysicalProperties.new(4, 0.3, 0, 1, 1)
local BODY_PHYSICS = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
local BODY_NAMES: { [string]: boolean } = {}
for _, name in
    {
        "Head",
        "UpperTorso",
        "LowerTorso",
        "LeftUpperArm",
        "LeftLowerArm",
        "LeftHand",
        "RightUpperArm",
        "RightLowerArm",
        "RightHand",
        "LeftUpperLeg",
        "LeftLowerLeg",
        "LeftFoot",
        "RightUpperLeg",
        "RightLowerLeg",
        "RightFoot",
        "Torso",
        "Left Arm",
        "Right Arm",
        "Left Leg",
        "Right Leg",
    }
do
    BODY_NAMES[name] = true
end
type State = { Character: Model, Connections: { RBXScriptConnection }, Started: boolean }
local states: { [Player]: State } = {}

function CharacterPhysicsService.RemovePlayer(player: Player)
    local state = states[player]
    if state then
        for _, connection in state.Connections do
            connection:Disconnect()
        end
        states[player] = nil
    end
end

-- Called by bootstrap's existing CharacterAdded path; appearance loading must finish
-- before reading its description, otherwise Roblox can overwrite the scales later.
function CharacterPhysicsService.ApplyCharacter(player: Player, character: Model)
    if states[player] and states[player].Character == character then
        return
    end
    CharacterPhysicsService.RemovePlayer(player)
    local state: State = { Character = character, Connections = {}, Started = false }
    states[player] = state
    local function current(): boolean
        return states[player] == state and player.Character == character
    end
    local function normalizePart(instance: Instance)
        if not current() or not instance:IsA("BasePart") or not instance:IsDescendantOf(character) then
            return
        end
        -- Only avatar body parts and cosmetics are ours. Tools and server-authored
        -- gameplay parts retain their own physics, including nested Tool parts.
        if instance:FindFirstAncestorWhichIsA("Tool") then
            return
        end
        local accessory = instance:FindFirstAncestorWhichIsA("Accessory")
        if accessory and accessory.Parent == character then
            if accessory:GetAttribute("PreserveGameplayPhysics") == true then
                return
            end
            instance.Massless = true
            instance.CanCollide = false
            instance.CanTouch = false
            instance.CanQuery = false
            instance.RootPriority = -127
        elseif instance.Parent == character and instance.Name == "HumanoidRootPart" then
            instance.Size = ROOT_SIZE
            instance.Massless = false
            instance.RootPriority = 127
            instance.CustomPhysicalProperties = ROOT_PHYSICS
            instance.CanCollide = false
            instance.CanTouch = false
            instance.CanQuery = true
        elseif instance.Parent == character and BODY_NAMES[instance.Name] then
            instance.Massless = true
            instance.RootPriority = 0
            instance.CustomPhysicalProperties = BODY_PHYSICS
            -- Retain Roblox's body collision/state-machine behavior. In particular,
            -- collidable torso/head parts must keep physically driving the turbine.
            -- Forcing limb collisions adds snagging; disabling torso collisions removes pushing.
        end
    end
    local function scan()
        for _, instance in character:GetDescendants() do
            normalizePart(instance)
        end
    end
    table.insert(
        state.Connections,
        character.DescendantAdded:Connect(function(instance)
            -- Defer until a newly inserted accessory's hierarchy is fully parented.
            task.defer(normalizePart, instance)
        end)
    )
    table.insert(
        state.Connections,
        player.CharacterRemoving:Connect(function(removing)
            if removing == character and states[player] == state then
                CharacterPhysicsService.RemovePlayer(player)
            end
        end)
    )
    scan()

    local function finish(appearanceSource: string)
        if not current() or state.Started then
            return
        end
        state.Started = true
        task.spawn(function()
            local humanoid = character:WaitForChild("Humanoid", 10)
            local root = character:WaitForChild("HumanoidRootPart", 10)
            if not current() then
                return
            end
            if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
                warn("[CharacterPhysics] Missing Humanoid/root for " .. player.Name)
                return
            end
            if humanoid.RigType == Enum.HumanoidRigType.R15 then
                local ok, problem = pcall(function()
                    local description = humanoid:GetAppliedDescription()
                    -- Keep the loaded avatar's assets/cosmetics, but remove the
                    -- taller/slender body morph independently of dimensional scale.
                    -- Head is a collidable body part: its scale affects clearance too.
                    local changed = description.HeightScale ~= 1
                        or description.WidthScale ~= 1
                        or description.DepthScale ~= 1
                        or description.HeadScale ~= 1
                        or description.BodyTypeScale ~= 0
                        or description.ProportionScale ~= 0
                    description.HeightScale = 1
                    description.WidthScale = 1
                    description.DepthScale = 1
                    description.HeadScale = 1
                    description.BodyTypeScale = 0
                    description.ProportionScale = 0
                    humanoid.AutomaticScalingEnabled = true
                    if changed then
                        -- At most one application per spawn. No heartbeat reapplication.
                        local applied, reason = pcall(function()
                            humanoid:ApplyDescriptionAsync(description)
                        end)
                        description:Destroy()
                        if not applied then
                            error(tostring(reason))
                        end
                    else
                        description:Destroy()
                    end
                end)
                if not ok and current() then
                    warn(
                        "[CharacterPhysics] Scale normalization failed for " .. player.Name .. ": " .. tostring(problem)
                    )
                end
            end
            -- R6 receives mass/accessory handling but no R15 scaling or rig conversion.
            if not current() then
                return
            end
            scan() -- Description application can resize the root and replace body parts.
            -- Read back after the yielding application and a simulation step, not
            -- from the requested description. Never reapply in response to this check.
            RunService.Heartbeat:Wait()
            if not current() then
                return
            end
            if DEBUG and RunService:IsStudio() then
                local count = 0
                for _, instance in character:GetDescendants() do
                    if instance:IsA("BasePart") then
                        local accessory = instance:FindFirstAncestorWhichIsA("Accessory")
                        if
                            accessory
                            and accessory.Parent == character
                            and not instance:FindFirstAncestorWhichIsA("Tool")
                            and accessory:GetAttribute("PreserveGameplayPhysics") ~= true
                        then
                            count += 1
                        end
                    end
                end
                local function scale(name: string): string
                    local value = humanoid:FindFirstChild(name)
                    return if value and value:IsA("NumberValue") then tostring(value.Value) else "n/a"
                end
                local appliedRoot = character:FindFirstChild("HumanoidRootPart")
                if appliedRoot and appliedRoot:IsA("BasePart") then
                    local _, boundingSize = character:GetBoundingBox()
                    local final = humanoid:GetAppliedDescription()
                    local finalScales = if humanoid.RigType == Enum.HumanoidRigType.R15
                        then string.format(
                            "HeightScale=%.3f WidthScale=%.3f DepthScale=%.3f HeadScale=%.3f BodyTypeScale=%.3f ProportionScale=%.3f",
                            final.HeightScale,
                            final.WidthScale,
                            final.DepthScale,
                            final.HeadScale,
                            final.BodyTypeScale,
                            final.ProportionScale
                        )
                        else "R6 scales=n/a"
                    final:Destroy()
                    print(
                        string.format(
                            "[CharacterPhysics] FINAL player=%s rig=%s appearance=%s description={%s} liveScales(H/W/D/Head/Type/Proportion)=%s/%s/%s/%s/%s/%s boundingSize=%s rootMass=%.3f assemblyMass=%.3f cosmeticParts=%d",
                            player.Name,
                            humanoid.RigType.Name,
                            appearanceSource,
                            finalScales,
                            scale("BodyHeightScale"),
                            scale("BodyWidthScale"),
                            scale("BodyDepthScale"),
                            scale("HeadScale"),
                            scale("BodyTypeScale"),
                            scale("BodyProportionScale"),
                            tostring(boundingSize),
                            appliedRoot:GetMass(),
                            appliedRoot.AssemblyMass,
                            count
                        )
                    )
                end
            end
        end)
    end
    table.insert(
        state.Connections,
        player.CharacterAppearanceLoaded:Connect(function(loaded)
            if loaded == character then
                finish("CharacterAppearanceLoaded")
            end
        end)
    )
    -- Connect first, then check: covers appearances loaded before bootstrap as well
    -- as the event/check race. Started is set before yielding to prevent duplicates.
    if player:HasAppearanceLoaded() then
        finish("HasAppearanceLoaded")
    elseif not player.LoadCharacterAppearance then
        finish("LoadCharacterAppearance=false")
    end
end

return CharacterPhysicsService
