--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.WingsConfig)
local HoldSensor = require(script.Parent.WingsHoldSensor)
local Banner = require(script.Parent.Parent.UI.AnnouncementBanner)
local Controller = {}
local started = false
local WingsOnboardingShown = false -- Session only; survives respawn.

type WingPose = { Offset: CFrame, Width: number }
type PoseFrame = { State: string, Pose: WingPose?, From: WingPose?, Start: number? }
local GLIDE_BLEND_SECONDS = 0.25

function Controller.SetWingPose(
    character: Model,
    pose: string,
    time: number,
    transitionFrom: WingPose?,
    transitionAlpha: number?
): WingPose?
    local clone = character:FindFirstChild("AngelWings")
    if not clone then
        return
    end
    local handle = clone:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        return
    end
    -- Supplied art is ONE rigid mesh, with no separate left/right joints.
    -- Pose its whole pair at the authored back attachment; narrow the silhouette
    -- at rest. No mesh splitting, replacement art or published animations.
    local angle, width, bank, bob = -25, 0.65, 0, 0
    if pose == "Grounded" then
        angle, width = -65, 0.45
    elseif pose == "Powered" then
        local beat = math.sin(time * math.pi * 2 * Config.PoweredFlapHz)
        angle = -10
        width = 1 - (1 - Config.PoweredFlapWidthMin) * (0.5 + 0.5 * beat)
        bank, bob = beat * 6, beat * 0.05
    elseif pose == "Gliding" then
        angle, width = math.sin(time * math.pi * 2) * Config.GlideBobAmplitudeDegrees, 1
    end
    local offset = CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(angle), 0, math.rad(bank))
    if pose == "Gliding" and transitionFrom then
        local alpha = math.clamp(transitionAlpha or 1, 0, 1)
        offset = transitionFrom.Offset:Lerp(offset, alpha)
        width = transitionFrom.Width + (width - transitionFrom.Width) * alpha
    end
    local back = handle:FindFirstChild("BodyBackAttachment")
    local rigid = handle:FindFirstChildOfClass("RigidConstraint")
    local weld = handle:FindFirstChild("AccessoryWeld")
    local motor = handle:FindFirstChild("WingMotor")
    if rigid and back and back:IsA("Attachment") then
        -- Animate a separate attachment, deriving its rest from the LIVE native
        -- attachment every frame. Never modify the original scaling anchor.
        local existingPose = handle:FindFirstChild("WingPoseAttachment")
        local a0, a1 = rigid.Attachment0, rigid.Attachment1
        local handleIs0 = a0 == back or (existingPose ~= nil and a0 == existingPose)
        local handleIs1 = a1 == back or (existingPose ~= nil and a1 == existingPose)
        local body = if handleIs0 then a1 elseif handleIs1 then a0 else nil
        if not body or not body:IsDescendantOf(character) or body:IsDescendantOf(clone) then
            return
        end
        local poseAttachment: Attachment
        if existingPose then
            if not existingPose:IsA("Attachment") then
                return
            end
            poseAttachment = existingPose
        else
            local created = Instance.new("Attachment")
            created.Name = "WingPoseAttachment"
            created.Parent = handle
            poseAttachment = created
        end
        -- body * rest * offset * back^-1 == body * rest * (back * offset^-1)^-1.
        poseAttachment.CFrame = back.CFrame * offset:Inverse()
        if handleIs0 then
            rigid.Attachment0 = poseAttachment
        else
            rigid.Attachment1 = poseAttachment
        end
    elseif weld and weld:IsA("Weld") and back and back:IsA("Attachment") then
        -- Legacy accessories attach through a Weld. Read the body's native
        -- anchor each frame so avatar scaling does not leave a cached rest stale.
        local torso = if weld.Part1 == handle then weld.Part0 else nil
        local body = torso and torso:FindFirstChild("BodyBackAttachment")
        if not body or not body:IsA("Attachment") then
            return
        end
        weld.C0, weld.C1 = body.CFrame * offset, back.CFrame
    elseif motor and motor:IsA("Motor6D") then
        -- Compatibility with accessories granted before the native setup change.
        local rest = motor:GetAttribute("WingRestC0")
        if typeof(rest) ~= "CFrame" then
            return
        end
        motor.C0 = rest * offset
    else
        return -- Streaming/native attachment may still be in progress; retry next frame.
    end
    local mesh = handle and handle:FindFirstChildOfClass("SpecialMesh")
    if mesh then
        local base = mesh:GetAttribute("WingBaseScale")
        if typeof(base) ~= "Vector3" then
            base = mesh.Scale
            mesh:SetAttribute("WingBaseScale", base)
        end
        -- Native accessory scaling changes Handle.Size. Rebase the visual scale
        -- by that ratio; never resize the Handle or cache a stale avatar size.
        local baseSize = mesh:GetAttribute("WingBaseHandleSize")
        if typeof(baseSize) == "Vector3" then
            base = (base :: Vector3) * (handle.Size / (baseSize :: Vector3))
        end
        mesh:SetAttribute("WingBaseScale", base)
        mesh:SetAttribute("WingBaseHandleSize", handle.Size)
        mesh.Scale = (base :: Vector3) * Vector3.new(width, 1, 1)
    end
    return { Offset = offset, Width = width }
end
function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
    local remote = ReplicatedStorage:WaitForChild("WingsJumpHeld") :: RemoteEvent
    local sensor = HoldSensor.Attach(playerGui, function(held)
        remote:FireServer(held)
    end)
    player.CharacterRemoving:Connect(function()
        sensor.Clear()
    end)
    local function onboard()
        local character = player.Character
        -- A confirmed grant is the registered server accessory, not Shop opening
        -- or the ownership check finishing before a character has been attached.
        if
            WingsOnboardingShown
            or player:GetAttribute("WingsOwnership") ~= "Owned"
            or not character
            or not character:FindFirstChild("AngelWings")
        then
            return
        end
        WingsOnboardingShown = true
        local surface = Banner.Create(playerGui, "WingsOnboarding")
        surface.Show("JUMP TO FLY!\n\nHold Jump in the air to flap your wings. Keep holding to glide!")
        task.delay(5, function()
            surface.Destroy()
        end)
    end
    -- Lift belongs only to this client's character; the server owns the budget
    -- and the replicated permission. Pose rendering below handles every player.
    local previousState: string? = nil
    local previousCharacter: Model? = nil
    RunService.RenderStepped:Connect(function(dt)
        local character = player.Character
        local state = player:GetAttribute("WingState")
        if character ~= previousCharacter then
            previousState = nil
            previousCharacter = character
        end
        local enteringPowered = state == "Powered" and previousState ~= "Powered"
        previousState = if typeof(state) == "string" then state else nil
        if state ~= "Powered" and state ~= "Gliding" then
            return
        end
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then
            return
        end
        local velocity = root.AssemblyLinearVelocity
        local y = velocity.Y
        if state == "Powered" then
            if enteringPowered then
                y = math.max(y, Config.PoweredEngageBurstVelocity)
            end
            if y < Config.PoweredAscentVelocity then
                y = math.min(Config.PoweredAscentVelocity, y + Config.PoweredApproachAccel * dt)
            end
        elseif y < -Config.GlideDescentVelocity then
            y = -Config.GlideDescentVelocity
        end
        if y ~= velocity.Y then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, y, velocity.Z)
        end
    end)
    -- Rendering every player's server state also handles streaming/respawn and
    -- fires onboarding on the first rendered grant, never again that session.
    local previousPoses = setmetatable({} :: { [Model]: PoseFrame }, { __mode = "k" })
    RunService.RenderStepped:Connect(function()
        local time = os.clock()
        for _, other in Players:GetPlayers() do
            local character = other.Character
            if character then
                local state = tostring(other:GetAttribute("WingState") or "Grounded")
                local frame = previousPoses[character]
                if not frame then
                    frame = { State = state, Pose = nil, From = nil, Start = nil }
                    previousPoses[character] = frame
                end
                if state == "Gliding" and frame.State == "Powered" then
                    frame.From, frame.Start = frame.Pose, time
                elseif state ~= "Gliding" then
                    frame.From, frame.Start = nil, nil
                end
                local alpha = if frame.Start then math.clamp((time - frame.Start) / GLIDE_BLEND_SECONDS, 0, 1) else 1
                frame.Pose =
                    Controller.SetWingPose(character, state, time + other.UserId % 997 / 997, frame.From, alpha)
                frame.State = state
                if alpha >= 1 then
                    frame.From, frame.Start = nil, nil
                end
            end
        end
        onboard()
    end)
end
return Controller
