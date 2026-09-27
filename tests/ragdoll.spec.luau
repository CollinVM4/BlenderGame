-- Structural contracts only: these doubles do not simulate collapse or getting up.
local ragdoll = loadModule("RagdollService")
local function standardRig()
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
    local motors = {}
    local function joint(name, a, b)
        local motor = instance("Motor6D")
        motor.Name, motor.Part0, motor.Part1, motor.Parent = name, body[a], body[b], body[b]
        motor.Enabled, motor.C0, motor.C1, motor.Transform = true, frame(), frame(), frame(5, 5, 5)
        motors[name] = motor
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
    return c, h, motors, body
end
local function sockets(c)
    local result = {}
    for _, object in c:GetDescendants() do
        if object:IsA("BallSocketConstraint") then
            table.insert(result, object)
        end
    end
    return result
end
local c, h, motors, body = standardRig()
setup(ragdoll.PrepareCharacter(c), "complete standard R15 prepares")
local prepared = sockets(c)
check(#prepared == 14 and not ragdoll.IsRagdolled(c), "fourteen joints prepared inactive")
setup(ragdoll.PrepareCharacter(c), "repeated preparation accepted")
check(#sockets(c) == 14 and sockets(c)[1] == prepared[1], "preparation reuses physical joints")
for _, socket in prepared do
    check(
        not socket.Enabled and socket.Attachment0.CFrame.Position.Magnitude == 0,
        "prepared joint is disabled and does not bake in active animation Transform"
    )
end
for cycle = 1, 3 do
    setup(ragdoll.SetRagdolled(c, true), "ragdoll on")
    setup(ragdoll.SetRagdolled(c, true), "same state on is safe")
    check(
        ragdoll.IsRagdolled(c) and h.PlatformStand and not h.AutoRotate and not h.RequiresNeck,
        "on changes only physical humanoid properties"
    )
    check(h:GetStateEnabled("GettingUp") and h:GetStateEnabled("Jumping"), "no state permissions disabled")
    local off = 0
    for name, motor in motors do
        if name ~= "Root" and not motor.Enabled then
            off += 1
        end
    end
    local enabled = 0
    for _, socket in prepared do
        if socket.Enabled then
            enabled += 1
        end
    end
    check(off == 14 and enabled == 14 and motors.Root.Enabled, "on releases all intended joints and preserves root")
    check(
        body.LeftHand.CanCollide and not body.LeftHand.Massless and not body.HumanoidRootPart.CanCollide,
        "body can contact the floor without a collidable root"
    )
    setup(ragdoll.SetRagdolled(c, false), "ragdoll off")
    setup(ragdoll.SetRagdolled(c, false), "same state off is safe")
    check(
        not ragdoll.IsRagdolled(c)
            and not h.PlatformStand
            and h.AutoRotate
            and h.RequiresNeck
            and h.State == "GettingUp",
        "off restores humanoid and requests recovery"
    )
    local restored = 0
    for _, motor in motors do
        if motor.Enabled then
            restored += 1
        end
    end
    local disabled = 0
    for _, socket in prepared do
        if not socket.Enabled then
            disabled += 1
        end
    end
    check(
        restored == 15 and disabled == 14 and sockets(c)[1] == prepared[1],
        "cycles restore motors and reuse disabled sockets"
    )
    check(
        not body.LeftHand.CanCollide and body.LeftHand.Massless and body.HumanoidRootPart.AutomaticOwner,
        "off restores body properties and automatic network ownership"
    )
end
h.AutoRotate = false
body.LeftHand.CanCollide = true
body.HumanoidRootPart:SetNetworkOwner({ Name = "manual owner" })
local owner = body.HumanoidRootPart.NetworkOwner
ragdoll.SetRagdolled(c, true)
ragdoll.CleanupCharacter(c)
check(
    not ragdoll.IsRagdolled(c)
        and #sockets(c) == 0
        and not h.PlatformStand
        and not h.AutoRotate
        and body.LeftHand.CanCollide
        and body.HumanoidRootPart.NetworkOwner == owner,
    "cleanup restores original values and releases prepared objects"
)
ragdoll.CleanupCharacter(c)
for _, ending in { "death", "removal", "destroy" } do
    local character, humanoid, joints = standardRig()
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
        not ragdoll.IsRagdolled(character) and not humanoid.PlatformStand and #sockets(character) == 0,
        ending .. " removes active service state and restores physical properties"
    )
    if ending ~= "destroy" then
        check(joints.Neck.Enabled, ending .. " restores neck motor")
    end
end
local fresh, freshHumanoid = standardRig()
ragdoll.PrepareCharacter(fresh)
check(not ragdoll.IsRagdolled(fresh) and not freshHumanoid.PlatformStand, "new life starts normal")
local malformed, _, missing = standardRig()
missing.LeftKnee:Destroy()
check(
    not ragdoll.PrepareCharacter(malformed) and #sockets(malformed) == 0,
    "incomplete R15 fails explicitly without building a partial rig"
)
local r6, r6Humanoid = standardRig()
r6Humanoid.RigType = "R6"
check(not ragdoll.SetRagdolled(r6, true) and not r6Humanoid.PlatformStand, "unsupported R6 stays untouched")
