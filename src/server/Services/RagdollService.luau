--!strict
-- Native Avatar Joint Upgrade R15 physics only. No combat, input, inventory or gameplay stun dependencies.
local RunService = game:GetService("RunService")
local RagdollService = {}
type JointState = {
    IsKinematic: boolean,
    MaxForce: number,
    MaxTorque: number,
    LinearStrength: number,
    LinearDamping: number,
    AngularStrength: number,
    AngularDamping: number,
}
type Joint = { Constraint: AnimationConstraint, Saved: JointState }
type Rig = {
    Humanoid: Humanoid,
    Root: AnimationConstraint,
    Joints: { Joint },
    Sockets: { BallSocketConstraint },
    TorsoCollision: { [BasePart]: boolean },
    Connections: { RBXScriptConnection },
    Active: boolean,
    PlatformStand: boolean,
    AutoRotate: boolean,
}
local rigs: { [Model]: Rig } = {}
-- Expected avatar body pairs. Root is validated separately and never modified.
local joints: { [string]: { string } } = {
    Neck = { "UpperTorso", "Head" },
    Waist = { "LowerTorso", "UpperTorso" },
    LeftShoulder = { "UpperTorso", "LeftUpperArm" },
    LeftElbow = { "LeftUpperArm", "LeftLowerArm" },
    LeftWrist = { "LeftLowerArm", "LeftHand" },
    RightShoulder = { "UpperTorso", "RightUpperArm" },
    RightElbow = { "RightUpperArm", "RightLowerArm" },
    RightWrist = { "RightLowerArm", "RightHand" },
    LeftHip = { "LowerTorso", "LeftUpperLeg" },
    LeftKnee = { "LeftUpperLeg", "LeftLowerLeg" },
    LeftAnkle = { "LeftLowerLeg", "LeftFoot" },
    RightHip = { "LowerTorso", "RightUpperLeg" },
    RightKnee = { "RightUpperLeg", "RightLowerLeg" },
    RightAnkle = { "RightLowerLeg", "RightFoot" },
}

-- Optional read-only Studio inventory, retained for inspecting runtime failures.
function RagdollService.InspectCharacter(character: Model)
    assert(RunService:IsStudio() and RunService:IsServer(), "Use the Studio Server Command Bar")
    local function path(object: Instance?): string
        return if object then object:GetFullName() else "nil"
    end
    local function property(object: Instance, name: string): string
        local ok, value = pcall(function()
            return (object :: any)[name]
        end)
        return if ok then tostring(value) else "unavailable"
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    print(
        string.format(
            "[Ragdoll] inspect character=%s rig=%s StarterPlayer.AvatarJointUpgrade=%s",
            path(character),
            if humanoid then tostring(humanoid.RigType) else "missing Humanoid",
            property(game:GetService("StarterPlayer"), "AvatarJointUpgrade")
        )
    )
    local counts: { [string]: number } = {
        AnimationConstraint = 0,
        Motor6D = 0,
        BallSocketConstraint = 0,
        NoCollisionConstraint = 0,
    }
    local discovered: { [string]: { string } } = {}
    local descendants = character:GetDescendants()
    table.sort(descendants, function(a, b)
        return a:GetFullName() < b:GetFullName()
    end)
    for _, object in descendants do
        local class = object.ClassName
        if counts[class] ~= nil then
            counts[class] += 1
        end
        local a: Instance? = nil
        local b: Instance? = nil
        if object:IsA("Motor6D") or object:IsA("NoCollisionConstraint") then
            a, b = object.Part0, object.Part1
            print(
                string.format(
                    "[Ragdoll] %s %s Part0=%s Part1=%s Enabled=%s",
                    class,
                    path(object),
                    path(a),
                    path(b),
                    tostring(object.Enabled)
                )
            )
        elseif object:IsA("Constraint") then
            local first, second = object.Attachment0, object.Attachment1
            a, b = if first then first.Parent else nil, if second then second.Parent else nil
            print(
                string.format(
                    "[Ragdoll] %s %s Attachment0=%s parent0=%s Attachment1=%s parent1=%s Enabled=%s",
                    class,
                    path(object),
                    path(first),
                    path(a),
                    path(second),
                    path(b),
                    tostring(object.Enabled)
                )
            )
            if class == "AnimationConstraint" then
                for _, name in
                    {
                        "IsKinematic",
                        "MaxForce",
                        "MaxTorque",
                        "LinearStrength",
                        "LinearDamping",
                        "AngularStrength",
                        "AngularDamping",
                    }
                do
                    print("[Ragdoll]   " .. name .. "=" .. property(object, name))
                end
            elseif object:IsA("BallSocketConstraint") then
                print(
                    string.format(
                        "[Ragdoll]   LimitsEnabled=%s UpperAngle=%s TwistLimitsEnabled=%s TwistLowerAngle=%s TwistUpperAngle=%s",
                        tostring(object.LimitsEnabled),
                        tostring(object.UpperAngle),
                        tostring(object.TwistLimitsEnabled),
                        tostring(object.TwistLowerAngle),
                        tostring(object.TwistUpperAngle)
                    )
                )
            end
        end
        if a and b and a.Parent == character and b.Parent == character then
            local key = a.Name .. "/" .. b.Name
            discovered[key] = discovered[key] or {}
            table.insert(discovered[key], class .. ":" .. object.Name)
        end
    end
    for class, count in counts do
        print(string.format("[Ragdoll] %s count=%d", class, count))
    end
    local expected = table.clone(joints)
    expected.Root = { "HumanoidRootPart", "LowerTorso" }
    for name, pair in expected do
        local forward = discovered[pair[1] .. "/" .. pair[2]] or {}
        local reverse = discovered[pair[2] .. "/" .. pair[1]] or {}
        print(
            string.format(
                "[Ragdoll] expected=%s pair=%s/%s forward=[%s] reverse=[%s]",
                name,
                pair[1],
                pair[2],
                table.concat(forward, ", "),
                table.concat(reverse, ", ")
            )
        )
    end
    print("[Ragdoll] inspection complete; no character properties changed")
end

local function capture(joint: AnimationConstraint): JointState
    return {
        IsKinematic = joint.IsKinematic,
        MaxForce = joint.MaxForce,
        MaxTorque = joint.MaxTorque,
        LinearStrength = joint.LinearStrength,
        LinearDamping = joint.LinearDamping,
        AngularStrength = joint.AngularStrength,
        AngularDamping = joint.AngularDamping,
    }
end

local function reject(reason: string): boolean
    warn("[Ragdoll] rejected jointSystem=AnimationConstraint: " .. reason)
    return false
end

-- Resolve the owning body part, including Roblox's nested JointRotation attachments.
local function bodyOf(attachment: Attachment?): BasePart?
    local object: Instance? = attachment
    while object do
        if object:IsA("BasePart") then
            return object
        end
        object = object.Parent
    end
    return nil
end

local function matches(character: Model, constraint: AnimationConstraint, pair: { string }): boolean
    local a, b = bodyOf(constraint.Attachment0), bodyOf(constraint.Attachment1)
    return a ~= nil
        and b ~= nil
        and a.Parent == character
        and b.Parent == character
        and ((a.Name == pair[1] and b.Name == pair[2]) or (a.Name == pair[2] and b.Name == pair[1]))
end

function RagdollService.IsRagdolled(character: Model): boolean
    local rig = rigs[character]
    return rig ~= nil and rig.Active
end

function RagdollService.PrepareCharacter(character: Model): boolean
    assert(RunService:IsServer(), "RagdollService is server-only")
    if rigs[character] then
        return true
    end
    local h = character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 or h.RigType ~= Enum.HumanoidRigType.R15 then
        return reject("a living R15 Humanoid is required")
    end
    local found: { [string]: AnimationConstraint } = {}
    local sockets: { [string]: BallSocketConstraint } = {}
    for _, object in character:GetDescendants() do
        if object:IsA("AnimationConstraint") and (object.Name == "Root" or joints[object.Name]) then
            local pair = if object.Name == "Root" then { "HumanoidRootPart", "LowerTorso" } else joints[object.Name]
            if not matches(character, object, pair) or not object.Enabled then
                return reject("invalid/disabled avatar AnimationConstraint " .. object.Name)
            end
            if found[object.Name] then
                return reject("duplicate avatar AnimationConstraint " .. object.Name)
            end
            found[object.Name] = object
        elseif object:IsA("BallSocketConstraint") then
            -- Validate the built-in named sockets without demanding identical attachments
            -- or rebuilding their articulation. Shoulders can use nested JointRotation.
            sockets[object.Name] = object
        end
    end
    local root = found.Root
    if not root or not root.IsKinematic then
        return reject("enabled kinematic Root AnimationConstraint required")
    end
    local rig: Rig = {
        Humanoid = h,
        Root = root,
        Joints = {},
        Sockets = {},
        TorsoCollision = {},
        Connections = {},
        Active = false,
        PlatformStand = h.PlatformStand,
        AutoRotate = h.AutoRotate,
    }
    for name in joints do
        local joint, socket = found[name], sockets[name .. "BallSocket"]
        if not joint then
            return reject("missing body AnimationConstraint " .. name)
        end
        if
            not socket
            or not socket.Enabled
            or not socket.Attachment0
            or not socket.Attachment1
            or not socket.Attachment0:IsDescendantOf(character)
            or not socket.Attachment1:IsDescendantOf(character)
        then
            return reject("missing/disabled built-in " .. name .. "BallSocket or its attachments")
        end
        table.insert(rig.Joints, { Constraint = joint, Saved = capture(joint) })
        table.insert(rig.Sockets, socket)
    end
    rigs[character] = rig
    table.insert(
        rig.Connections,
        h.Died:Connect(function()
            RagdollService.CleanupCharacter(character)
        end)
    )
    table.insert(
        rig.Connections,
        character.Destroying:Connect(function()
            RagdollService.CleanupCharacter(character)
        end)
    )
    table.insert(
        rig.Connections,
        character.AncestryChanged:Connect(function()
            if not character:IsDescendantOf(workspace) then
                RagdollService.CleanupCharacter(character)
            end
        end)
    )
    if RunService:IsStudio() then
        print("[Ragdoll] prepared rig=R15 jointSystem=AnimationConstraint bodyJoints=14 root=Root")
    end
    return true
end

function RagdollService.SetRagdolled(character: Model, enabled: boolean): boolean
    assert(RunService:IsServer(), "RagdollService is server-only")
    if enabled and not RagdollService.PrepareCharacter(character) then
        return false
    end
    local rig = rigs[character]
    if not rig or rig.Active == enabled then
        return true
    end
    local h = rig.Humanoid
    local changed = 0
    if enabled then
        -- Reject a rig changed since preparation before altering any physical state.
        if
            h.Health <= 0
            or not rig.Root:IsDescendantOf(character)
            or not rig.Root.Enabled
            or not rig.Root.IsKinematic
        then
            return reject("rig no longer has a living Humanoid and kinematic Root")
        end
        for _, joint in rig.Joints do
            if not joint.Constraint:IsDescendantOf(character) or not joint.Constraint.Enabled then
                return reject("body AnimationConstraint removed/disabled since preparation")
            end
        end
        for _, socket in rig.Sockets do
            if not socket:IsDescendantOf(character) or not socket.Enabled then
                return reject("built-in BallSocket removed/disabled since preparation")
            end
        end
        -- Refresh snapshots at each OFF -> ON edge; repeated ON cannot overwrite them.
        local upper, lower = character:FindFirstChild("UpperTorso"), character:FindFirstChild("LowerTorso")
        if not upper or not upper:IsA("BasePart") or not lower or not lower:IsA("BasePart") then
            return reject("UpperTorso and LowerTorso required for core world collision")
        end
        rig.TorsoCollision = { [upper] = upper.CanCollide, [lower] = lower.CanCollide }
        rig.PlatformStand, rig.AutoRotate = h.PlatformStand, h.AutoRotate
        for _, joint in rig.Joints do
            joint.Saved = capture(joint.Constraint)
        end
        rig.Active = true
        h.AutoRotate, h.PlatformStand = false, true
        for torso in rig.TorsoCollision do
            torso.CanCollide = true
        end
        for _, joint in rig.Joints do
            local constraint = joint.Constraint
            constraint.MaxForce, constraint.MaxTorque = 0, 0
            constraint.IsKinematic = false
            changed += 1
        end
        h:ChangeState(Enum.HumanoidStateType.Physics)
    else
        for _, joint in rig.Joints do
            local constraint, saved = joint.Constraint, joint.Saved
            if constraint.Parent then
                constraint.MaxForce, constraint.MaxTorque = saved.MaxForce, saved.MaxTorque
                constraint.LinearStrength, constraint.LinearDamping = saved.LinearStrength, saved.LinearDamping
                constraint.AngularStrength, constraint.AngularDamping = saved.AngularStrength, saved.AngularDamping
                constraint.IsKinematic = saved.IsKinematic
                changed += 1
            end
        end
        for torso, canCollide in rig.TorsoCollision do
            if torso.Parent then
                torso.CanCollide = canCollide
            end
        end
        if h.Parent then
            h.PlatformStand, h.AutoRotate = rig.PlatformStand, rig.AutoRotate
            if h.Health > 0 and not rig.PlatformStand then
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
        rig.Active = false
    end
    if RunService:IsStudio() then
        if enabled then
            print(string.format("[Ragdoll] ON changed=%d RootKinematic=%s", changed, tostring(rig.Root.IsKinematic)))
        else
            print(string.format("[Ragdoll] OFF restored=%d", changed))
        end
    end
    return true
end

function RagdollService.CleanupCharacter(character: Model)
    local rig = rigs[character]
    if not rig then
        return
    end
    RagdollService.SetRagdolled(character, false)
    rigs[character] = nil
    for _, connection in rig.Connections do
        connection:Disconnect()
    end
end

return require(script.Parent.StudioServices).Wrap("RagdollService", RagdollService)
