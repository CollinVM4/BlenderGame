-- Structural contracts only: these doubles do not simulate collapse or getting up.
local ragdoll = loadModule("RagdollService")
local function ajuRig()
    local p, h = player()
    local c = p.Character
    c.Parent = workspaceFake
    h.RigType = "R15"
    local body = {}
    for _, name in
        {
            "HumanoidRootPart",
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
        }
    do
        body[name] = c:FindFirstChild(name) or part(name, c)
    end
    local animations, sockets = {}, {}
    local function joint(name, a, b)
        local first, second = instance("Attachment"), instance("Attachment")
        first.Name, second.Name = name .. "RigAttachment", name .. "RigAttachment"
        first.Parent, second.Parent = body[a], body[b]
        first.CFrame, second.CFrame = frame(1, 2, 3), frame(4, 5, 6)
        local animation = instance("AnimationConstraint")
        animation.Name, animation.Parent = name, body[b]
        animation.Attachment0, animation.Attachment1 = first, second
        animation.Enabled, animation.IsKinematic = true, true
        animation.MaxForce, animation.MaxTorque = 0, 3000
        animation.LinearStrength, animation.LinearDamping = 12, 0.75
        animation.AngularStrength, animation.AngularDamping = 8, 0.5
        animations[name] = animation
        if name ~= "Root" then
            local socket = instance("BallSocketConstraint")
            socket.Name, socket.Parent, socket.Enabled = name .. "BallSocket", body[b], true
            if string.find(name, "Shoulder") then
                local rotation = instance("Attachment")
                rotation.Name, rotation.Parent, rotation.CFrame = "JointRotation", first, frame(7, 8, 9)
                socket.Attachment0 = rotation
            else
                socket.Attachment0 = first
            end
            socket.Attachment1 = second
            socket.LimitsEnabled, socket.UpperAngle = true, 65
            socket.TwistLimitsEnabled, socket.TwistLowerAngle, socket.TwistUpperAngle = true, -30, 35
            sockets[name] = socket
        end
    end
    joint("Root", "HumanoidRootPart", "LowerTorso")
    joint("Waist", "LowerTorso", "UpperTorso")
    joint("Neck", "UpperTorso", "Head")
    for _, side in { "Left", "Right" } do
        joint(side .. "Shoulder", "UpperTorso", side .. "UpperArm")
        joint(side .. "Elbow", side .. "UpperArm", side .. "LowerArm")
        joint(side .. "Wrist", side .. "LowerArm", side .. "Hand")
        joint(side .. "Hip", "LowerTorso", side .. "UpperLeg")
        joint(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg")
        joint(side .. "Ankle", side .. "LowerLeg", side .. "Foot")
    end
    for i = 1, 19 do
        local exclusion = instance("NoCollisionConstraint")
        exclusion.Name, exclusion.Parent, exclusion.Enabled = "NativeExclusion" .. i, c, true
        exclusion.Part0, exclusion.Part1 = body.UpperTorso, body.LeftUpperArm
    end
    return c, h, animations, body, sockets
end
local properties = {
    "IsKinematic",
    "MaxForce",
    "MaxTorque",
    "LinearStrength",
    "LinearDamping",
    "AngularStrength",
    "AngularDamping",
}
local function snapshot(object, names)
    local saved = {}
    for _, name in names do
        saved[name] = object[name]
    end
    return saved
end
local function same(object, saved)
    for name, value in saved do
        if object[name] ~= value then
            return false
        end
    end
    return true
end
-- Capture the authored native structure to verify it survives ON/OFF and cleanup.
local function nativeSnapshot(c, root)
    local saved = {}
    for _, object in c:GetDescendants() do
        if
            object:IsA("BallSocketConstraint")
            or object:IsA("NoCollisionConstraint")
            or object:IsA("Attachment")
            or object:IsA("BasePart")
            or object == root
        then
            saved[object] = snapshot(object, {
                "Parent",
                "Enabled",
                "Attachment0",
                "Attachment1",
                "Part0",
                "Part1",
                "CFrame",
                "LimitsEnabled",
                "UpperAngle",
                "TwistLimitsEnabled",
                "TwistLowerAngle",
                "TwistUpperAngle",
                "CanCollide",
                "Massless",
                "Anchored",
                "AutomaticOwner",
                "IsKinematic",
                "MaxForce",
                "MaxTorque",
                "LinearStrength",
                "LinearDamping",
                "AngularStrength",
                "AngularDamping",
            })
            if object.Name == "UpperTorso" or object.Name == "LowerTorso" then
                saved[object].CanCollide = nil -- Checked separately across active/normal transitions.
            end
        end
    end
    return saved
end
local function nativeUnchanged(saved)
    for object, values in saved do
        if object.Destroyed or not same(object, values) then
            return false
        end
    end
    return true
end
local c, h, animations, body, sockets = ajuRig()
local native = nativeSnapshot(c, animations.Root)
local originalCount = #c:GetDescendants()
setup(ragdoll.PrepareCharacter(c), "native AJU rig with nested shoulder sockets prepares without Motor6Ds")
setup(ragdoll.PrepareCharacter(c), "preparation is idempotent")
check(
    not ragdoll.IsRagdolled(c) and #c:GetDescendants() == originalCount and nativeUnchanged(native),
    "preparation creates no parallel skeleton and preserves authored physics"
)
for cycle = 1, 3 do
    -- Include non-default values, including an initially physical joint, and changes after Prepare.
    animations.Waist.MaxForce, animations.Waist.MaxTorque = 100 + cycle, 987 + cycle
    animations.LeftWrist.IsKinematic = cycle ~= 2
    body.UpperTorso.CanCollide, body.LowerTorso.CanCollide = cycle == 2, cycle == 3
    local saved = {}
    for name, animation in animations do
        saved[name] = snapshot(animation, properties)
    end
    setup(ragdoll.SetRagdolled(c, true), "ragdoll on")
    setup(ragdoll.SetRagdolled(c, true), "repeated on preserves snapshot")
    check(body.UpperTorso.CanCollide and body.LowerTorso.CanCollide, "ON enables only torso core collision")
    local limp = 0
    for name, animation in animations do
        if name ~= "Root" and not animation.IsKinematic and animation.MaxForce == 0 and animation.MaxTorque == 0 then
            limp += 1
        end
    end
    check(limp == 14 and ragdoll.IsRagdolled(c), "all fourteen body joints become unpowered and physical")
    check(
        h.PlatformStand and not h.AutoRotate and h.RequiresNeck and h.State == "Physics",
        "on uses minimal Humanoid properties and leaves RequiresNeck alone"
    )
    check(h:GetStateEnabled("GettingUp") and h:GetStateEnabled("Jumping"), "state permissions remain enabled")
    check(
        nativeUnchanged(native) and #c:GetDescendants() == originalCount,
        "root, native constraints, attachments and non-torso collision remain untouched"
    )
    setup(ragdoll.SetRagdolled(c, false), "ragdoll off")
    setup(ragdoll.SetRagdolled(c, false), "repeated off is safe")
    check(
        body.UpperTorso.CanCollide == (cycle == 2) and body.LowerTorso.CanCollide == (cycle == 3),
        "OFF restores current cycle torso collision exactly despite repeated ON"
    )
    local restored = true
    for name, animation in animations do
        restored = restored and same(animation, saved[name])
    end
    check(restored, "off restores exact seven-property snapshots, including non-default values")
    check(
        not ragdoll.IsRagdolled(c) and not h.PlatformStand and h.AutoRotate and h.State == "GettingUp",
        "off restores Humanoid and requests recovery"
    )
end
h.PlatformStand, h.AutoRotate = true, false
body.UpperTorso.CanCollide, body.LowerTorso.CanCollide = false, true
local beforeCleanup = snapshot(animations.Waist, properties)
ragdoll.SetRagdolled(c, true)
ragdoll.CleanupCharacter(c)
ragdoll.CleanupCharacter(c)
check(not body.UpperTorso.CanCollide and body.LowerTorso.CanCollide, "cleanup restores mixed torso collision values")
check(
    not ragdoll.IsRagdolled(c) and same(animations.Waist, beforeCleanup) and h.PlatformStand and not h.AutoRotate,
    "cleanup restores joints and exact pre-existing Humanoid values"
)
check(nativeUnchanged(native) and #c:GetDescendants() == originalCount, "cleanup does not destroy native rig objects")
setup(ragdoll.PrepareCharacter(c), "cleaned character can prepare independently")
ragdoll.CleanupCharacter(c)

for _, ending in { "death", "removal", "destroy" } do
    local character, humanoid, joints, bodies = ajuRig()
    local saved = snapshot(joints.Neck, properties)
    ragdoll.SetRagdolled(character, true)
    if ending == "death" then
        humanoid.Health = 0
        humanoid.Died:Fire()
    elseif ending == "removal" then
        character.Parent = nil
        character.AncestryChanged:Fire()
    else
        character:Destroy()
    end
    check(
        not ragdoll.IsRagdolled(character) and not humanoid.PlatformStand and humanoid.AutoRotate,
        ending .. " clears active state and restores Humanoid"
    )
    check(same(joints.Neck, saved), ending .. " restores AJU joint settings")
    check(not bodies.UpperTorso.CanCollide and not bodies.LowerTorso.CanCollide, ending .. " restores torso collision")
end
local fresh, freshHumanoid = ajuRig()
setup(ragdoll.SetRagdolled(fresh, true), "respawn can ragdoll independently")
ragdoll.CleanupCharacter(fresh)
check(not ragdoll.IsRagdolled(fresh) and not freshHumanoid.PlatformStand, "new life recovers independently")

for _, fault in { "body", "socket", "root", "nonkinematic-root", "R6", "legacy" } do
    local character, humanoid, joints, _, nativeSockets = ajuRig()
    if fault == "body" then
        joints.Waist:Destroy()
    elseif fault == "socket" then
        nativeSockets.LeftShoulder:Destroy()
    elseif fault == "root" then
        joints.Root:Destroy()
    elseif fault == "nonkinematic-root" then
        joints.Root.IsKinematic = false
    elseif fault == "R6" then
        humanoid.RigType = "R6"
    else
        for _, joint in joints do
            joint.ClassName = "Motor6D"
        end
    end
    local count = #character:GetDescendants()
    check(
        not ragdoll.SetRagdolled(character, true)
            and not humanoid.PlatformStand
            and joints.Neck.MaxTorque == 3000
            and #character:GetDescendants() == count,
        fault .. " fails atomically without manufacturing a fallback rig"
    )
end
local stale, staleHumanoid, _, _, staleSockets = ajuRig()
setup(ragdoll.PrepareCharacter(stale), "prepare before native socket removed")
staleSockets.Waist:Destroy()
check(
    not ragdoll.SetRagdolled(stale, true) and not staleHumanoid.PlatformStand,
    "activation rejects a removed native socket without partial state changes"
)
ragdoll.CleanupCharacter(stale)
