-- Native accessory pose/scaling boundary; does not simulate engine physics.
cache.WingsHoldSensor = {}
cache.AnnouncementBanner = {}
vector.__mul = function(a, b)
    if type(b) == "number" then
        return vec(a.X * b, a.Y * b, a.Z * b)
    end
    return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vector.__div = function(a, b)
    if type(b) == "number" then
        return vec(a.X / b, a.Y / b, a.Z / b)
    end
    return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
-- Rotation-capable CFrame math at the engine boundary, independently of joints.
local function cf(position, right, up, back)
    local value = { Position = position, RightVector = right, UpVector = up, LookVector = back * -1 }
    local function transform(v)
        return right * v.X + up * v.Y + back * v.Z
    end
    function value:Inverse()
        local function inverse(v)
            return vec(v:Dot(right), v:Dot(up), v:Dot(back))
        end
        return cf(inverse(position * -1), inverse(vec(1, 0, 0)), inverse(vec(0, 1, 0)), inverse(vec(0, 0, 1)))
    end
    function value:Lerp(other, alpha)
        return cf(
            position + (other.Position - position) * alpha,
            right + (other.RightVector - right) * alpha,
            up + (other.UpVector - up) * alpha,
            back + (other.LookVector * -1 - back) * alpha
        )
    end
    return setmetatable(value, {
        __mul = function(_, other)
            return cf(
                position + transform(other.Position),
                transform(other.RightVector),
                transform(other.UpVector),
                transform(other.LookVector * -1)
            )
        end,
    })
end
local function translate(x, y, z)
    return cf(vec(x or 0, y or 0, z or 0), vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1))
end
env.CFrame = {
    new = translate,
    Angles = function(x, y, z)
        return cf(vec(0, 0, 0), vec(1, 0, 0), vec(0, math.cos(x), math.sin(x)), vec(0, -math.sin(x), math.cos(x)))
            * cf(vec(0, 0, 0), vec(math.cos(y), 0, -math.sin(y)), vec(0, 1, 0), vec(math.sin(y), 0, math.cos(y)))
            * cf(vec(0, 0, 0), vec(math.cos(z), math.sin(z), 0), vec(-math.sin(z), math.cos(z), 0), vec(0, 0, 1))
    end,
}
env.typeof = function(value)
    if type(value) == "table" and value.Position and value.RightVector then
        return "CFrame"
    elseif type(value) == "table" and value.X and value.Y and value.Z then
        return "Vector3"
    end
    return typeof(value)
end
local function closeVector(a, b)
    return (a - b).Magnitude < 1e-6
end
local function closeFrame(a, b)
    return closeVector(a.Position, b.Position)
        and closeVector(a.RightVector, b.RightVector)
        and closeVector(a.UpVector, b.UpVector)
        and closeVector(a.LookVector, b.LookVector)
end
local controller = loadModule("WingsController")
local function rig(jointClass)
    accessoryJointClass = jointClass
    local p = subject(true)
    local clone = p.Character:FindFirstChild("AngelWings")
    local handle = clone:FindFirstChild("Handle")
    local back = handle:FindFirstChild("BodyBackAttachment")
    back.CFrame = translate(0.1, 0.2, 0.8) * env.CFrame.Angles(0, math.pi, 0)
    local torso = p.Character:FindFirstChild("UpperTorso")
    local body = torso:FindFirstChild("BodyBackAttachment")
    body.CFrame = translate(0, 0.3, 1)
    local mesh = handle:FindFirstChildOfClass("SpecialMesh")
    return p, handle, back, body, mesh
end
local function handleOffset(handle)
    local rigid = handle:FindFirstChildOfClass("RigidConstraint")
    if rigid then
        local body, posed = rigid.Attachment0, rigid.Attachment1
        if body.Parent == handle then
            body, posed = posed, body
        end
        return body.CFrame * posed.CFrame:Inverse()
    end
    local weld = handle:FindFirstChild("AccessoryWeld")
    return weld.C0 * weld.C1:Inverse()
end
for _, jointClass in { "RigidConstraint", "Weld" } do
    local p, handle, back, body, mesh = rig(jointClass)
    local anchor, bodyAnchor, size = back.CFrame, body.CFrame, handle.Size
    controller.SetWingPose(p.Character, "Grounded", 0)
    local expected = body.CFrame * env.CFrame.Angles(math.rad(-65), 0, 0) * back.CFrame:Inverse()
    check(
        closeFrame(handleOffset(handle), expected),
        jointClass .. " grounded pose moves the attached wing pair without WingMotor"
    )
    check(
        math.abs(mesh.Scale.X - 0.9) < 1e-6 and mesh.Scale.Y == 3 and mesh.Scale.Z == 4,
        "grounded fold narrows only mesh width"
    )
    controller.SetWingPose(p.Character, "Grounded", 1)
    check(math.abs(mesh.Scale.X - 0.9) < 1e-6, "repeated posing retains base scale")
    check(
        back.CFrame == anchor and body.CFrame == bodyAnchor and handle.Size == size,
        "posing preserves native anchors and handle dimensions"
    )
    -- Simulate native avatar scaling/rebuild after a pose has already rendered.
    handle.Size = handle.Size * vec(1.5, 2, 0.5)
    mesh.Scale = vec(3, 6, 2)
    back.CFrame = translate(0.15, 0.4, 0.4) * env.CFrame.Angles(0, math.pi, 0)
    body.CFrame = translate(0, 0.6, 0.5)
    controller.SetWingPose(p.Character, "Gliding", 0)
    check(closeVector(mesh.Scale, vec(3, 6, 2)), "native scaling survives a previous width pose")
    check(closeFrame(handleOffset(handle), body.CFrame * back.CFrame:Inverse()), "pose follows resized native anchors")
    local rigid = handle:FindFirstChildOfClass("RigidConstraint")
    if rigid then
        rigid.Attachment0, rigid.Attachment1 = back, body -- rebuilt in reverse endpoint order
        controller.SetWingPose(p.Character, "Grounded", 0)
        check(
            closeFrame(
                handleOffset(handle),
                body.CFrame * env.CFrame.Angles(math.rad(-65), 0, 0) * back.CFrame:Inverse()
            ),
            "rebuilt reversed constraint resumes posing"
        )
    end
end

-- Native AddAccessory scaling is retained before the first rendered pose too.
accessoryAttachHook = function(accessory)
    local handle = accessory:FindFirstChild("Handle")
    handle.Size = handle.Size * 3
    handle:FindFirstChildOfClass("SpecialMesh").Scale = vec(6, 9, 12)
end
local scaled, scaledHandle, _, _, scaledMesh = rig("RigidConstraint")
accessoryAttachHook = nil
check(closeVector(scaledMesh.Scale, vec(6, 9, 12)), "grant retains scaling applied by native AddAccessory")
controller.SetWingPose(scaled.Character, "Grounded", 0)
check(closeVector(scaledMesh.Scale, vec(2.7, 9, 12)), "first grounded pose uses the native scaled mesh as its base")

-- The single rigid pair's beat is visible through width, without new art.
local p, handle, back, body, mesh = rig("RigidConstraint")
controller.SetWingPose(p.Character, "Powered", 1 / 24)
local narrow = mesh.Scale.X
controller.SetWingPose(p.Character, "Powered", 1 / 8)
check(
    math.abs(narrow - 1.1) < 1e-6 and math.abs(mesh.Scale.X - 2) < 1e-6,
    "Powered times one twelfth apart pulse from 55 percent to full width"
)
local powered = controller.SetWingPose(p.Character, "Powered", 1 / 24)
local poweredFrame = handleOffset(handle)
controller.SetWingPose(p.Character, "Gliding", 1 / 24, powered, 0)
check(
    closeFrame(handleOffset(handle), poweredFrame) and math.abs(mesh.Scale.X - narrow) < 1e-6,
    "glide transition starts from the previous rendered pose without snapping"
)
local middle = controller.SetWingPose(p.Character, "Gliding", 1 / 24, powered, 0.5)
check(middle.Width > powered.Width and middle.Width < 1, "glide transition interpolates width")
controller.SetWingPose(p.Character, "Gliding", 1 / 24, powered, 1)
local finished = handleOffset(handle)
controller.SetWingPose(p.Character, "Gliding", 1 / 24)
check(
    closeFrame(handleOffset(handle), finished) and mesh.Scale.X == 2,
    "glide transition ends at the unchanged glide pose"
)

-- Verify the real render loop supplies the 0.25-second transition per character.
cache.WingsHoldSensor.Attach = function()
    return { Clear = function() end }
end
cache.AnnouncementBanner.Create = function()
    return { Show = function() end, Destroy = function() end }
end
local gui = instance("PlayerGui")
gui.Name, gui.Parent = "PlayerGui", p
p.WaitForChild = p.FindFirstChild
replicated.WaitForChild = replicated.FindFirstChild
services.Players.LocalPlayer = p
services.Players.GetPlayers = function()
    return { p }
end
services.RunService.RenderStepped = signal()
controller.Init()
now = 1 / 24 - p.UserId % 997 / 997
p:SetAttribute("WingState", "Powered")
services.RunService.RenderStepped:Fire(0)
local lastPoweredWidth = mesh.Scale.X
p:SetAttribute("WingState", "Gliding")
services.RunService.RenderStepped:Fire(0)
check(math.abs(mesh.Scale.X - lastPoweredWidth) < 1e-6, "render transition does not snap on entry")
now += 0.125
services.RunService.RenderStepped:Fire(0)
check(mesh.Scale.X > lastPoweredWidth and mesh.Scale.X < 2, "render transition is between poses at 0.125 seconds")
now += 0.125
services.RunService.RenderStepped:Fire(0)
check(math.abs(mesh.Scale.X - 2) < 1e-6, "render transition completes at 0.25 seconds")
