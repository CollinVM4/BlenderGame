--!strict
-- Standard R15 physics only. No combat, input, inventory or gameplay stun dependencies.
local RunService = game:GetService("RunService")
local RagdollService = {}
type Joint = { Motor: Motor6D, Socket: BallSocketConstraint, Enabled: boolean }
type Body = { CanCollide: boolean, Massless: boolean }
type Rig = {
    Humanoid: Humanoid,
    Root: BasePart,
    Joints: { Joint },
    Bodies: { [BasePart]: Body },
    Objects: { Instance },
    Connections: { RBXScriptConnection },
    Active: boolean,
    Revision: number,
    PlatformStand: boolean,
    AutoRotate: boolean,
    RequiresNeck: boolean,
    AutomaticOwner: boolean,
    Owner: Player?,
}
local rigs: { [Model]: Rig } = {}
-- Expected Part0 / Part1 pairs. Root/RootJoint and Tool grips are deliberately excluded.
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

local function trace(character: Model, rig: Rig, phase: string)
    if not RunService:IsStudio() then
        return
    end
    local disabled, enabled = 0, 0
    for _, joint in rig.Joints do
        if joint.Motor.Parent and not joint.Motor.Enabled then
            disabled += 1
        end
        if joint.Socket.Parent and joint.Socket.Enabled then
            enabled += 1
        end
    end
    print(
        string.format(
            "[Ragdoll] %s %s motorsOff=%d/14 socketsOn=%d/14 PlatformStand=%s state=%s",
            character.Name,
            phase,
            disabled,
            enabled,
            tostring(rig.Humanoid.PlatformStand),
            tostring(rig.Humanoid:GetState())
        )
    )
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
    local root = character:FindFirstChild("HumanoidRootPart")
    if not h or h.Health <= 0 or h.RigType ~= Enum.HumanoidRigType.R15 or not root or not root:IsA("BasePart") then
        return false
    end
    local found: { [string]: Motor6D } = {}
    local rootMotor: Motor6D? = nil
    for _, object in character:GetDescendants() do
        if not object:IsA("Motor6D") then
            continue
        end
        local a, b = object.Part0, object.Part1
        if not a or not b or a.Parent ~= character or b.Parent ~= character then
            continue
        end
        if a == root and b.Name == "LowerTorso" then
            rootMotor = object
        end
        local pair = joints[object.Name]
        if pair and a.Name == pair[1] and b.Name == pair[2] then
            found[object.Name] = object
        end
    end
    for name in joints do
        if not found[name] then
            if RunService:IsStudio() then
                warn("[Ragdoll] prepare rejected: missing R15 joint " .. name)
            end
            return false
        end
    end
    if not rootMotor or not rootMotor.Enabled then
        if RunService:IsStudio() then
            warn("[Ragdoll] prepare rejected: missing/enabled root connection required")
        end
        return false
    end
    local rig: Rig = {
        Humanoid = h,
        Root = root,
        Joints = {},
        Bodies = {},
        Objects = {},
        Connections = {},
        Active = false,
        Revision = 0,
        PlatformStand = h.PlatformStand,
        AutoRotate = h.AutoRotate,
        RequiresNeck = h.RequiresNeck,
        AutomaticOwner = true,
        Owner = nil,
    }
    for name, motor in found do
        local first, second = Instance.new("Attachment"), Instance.new("Attachment")
        first.Name, second.Name = "Ragdoll_" .. name, "Ragdoll_" .. name
        first.CFrame, second.CFrame = motor.C0, motor.C1
        first.Parent, second.Parent = motor.Part0, motor.Part1
        local socket = Instance.new("BallSocketConstraint")
        socket.Name = "Ragdoll_" .. name
        socket.Attachment0, socket.Attachment1 = first, second
        socket.LimitsEnabled, socket.UpperAngle = true, if name == "Neck" then 45 else 90
        socket.Enabled = false
        socket.Parent = character
        table.insert(rig.Objects, first)
        table.insert(rig.Objects, second)
        table.insert(rig.Objects, socket)
        table.insert(rig.Joints, { Motor = motor, Socket = socket, Enabled = motor.Enabled })
        for _, body in { motor.Part0, motor.Part1 } do
            if body then
                rig.Bodies[body] = { CanCollide = body.CanCollide, Massless = body.Massless }
            end
        end
    end
    -- Body parts collide with the floor, not one another. Prepared once, toggled with the rig.
    local bodies: { BasePart } = {}
    for body in rig.Bodies do
        for _, other in bodies do
            local exclusion = Instance.new("NoCollisionConstraint")
            exclusion.Name = "RagdollSelfCollision"
            exclusion.Part0, exclusion.Part1 = body, other
            exclusion.Enabled = false
            exclusion.Parent = character
            table.insert(rig.Objects, exclusion)
        end
        table.insert(bodies, body)
    end
    rig.Bodies[root] = { CanCollide = root.CanCollide, Massless = root.Massless }
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
    trace(character, rig, "prepared")
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
    local h, root = rig.Humanoid, rig.Root
    if enabled and (h.Health <= 0 or not root:CanSetNetworkOwnership()) then
        return false
    end
    trace(character, rig, if enabled then "ON before" else "OFF before")
    rig.Active = enabled
    rig.Revision += 1
    if enabled then
        rig.PlatformStand, rig.AutoRotate, rig.RequiresNeck = h.PlatformStand, h.AutoRotate, h.RequiresNeck
        rig.AutomaticOwner, rig.Owner = root:GetNetworkOwnershipAuto(), root:GetNetworkOwner()
        root:SetNetworkOwner(nil)
        h.RequiresNeck, h.AutoRotate, h.PlatformStand = false, false, true
        for _, joint in rig.Joints do
            joint.Enabled = joint.Motor.Enabled
            joint.Socket.Enabled = true
            joint.Motor.Enabled = false
        end
        for body, saved in rig.Bodies do
            saved.CanCollide, saved.Massless = body.CanCollide, body.Massless
            body.CanCollide = body ~= root
            body.Massless = false
            if body:CanSetNetworkOwnership() then
                body:SetNetworkOwner(nil)
            end
        end
        h:ChangeState(Enum.HumanoidStateType.Physics)
    else
        for _, joint in rig.Joints do
            joint.Socket.Enabled = false
            if joint.Motor.Parent then
                joint.Motor.Enabled = joint.Enabled
            end
        end
        for body, saved in rig.Bodies do
            if body.Parent then
                body.CanCollide, body.Massless = saved.CanCollide, saved.Massless
            end
        end
        if h.Parent then
            h.RequiresNeck, h.AutoRotate, h.PlatformStand = rig.RequiresNeck, rig.AutoRotate, rig.PlatformStand
            if h.Health > 0 and not rig.PlatformStand then
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
        -- Request recovery while the server still owns the character, then return ownership.
        if root.Parent and root:CanSetNetworkOwnership() then
            if rig.AutomaticOwner then
                root:SetNetworkOwnershipAuto()
            else
                root:SetNetworkOwner(rig.Owner)
            end
        end
    end
    for _, object in rig.Objects do
        if object:IsA("NoCollisionConstraint") then
            object.Enabled = enabled
        end
    end
    trace(character, rig, if enabled then "ON after" else "OFF after")
    if RunService:IsStudio() then
        local revision = rig.Revision
        task.delay(0.25, function()
            if rigs[character] == rig and rig.Revision == revision then
                trace(character, rig, "settled check")
            end
        end)
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
    for _, object in rig.Objects do
        object:Destroy()
    end
end

return require(script.Parent.StudioServices).Wrap("RagdollService", RagdollService)
