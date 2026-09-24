--!strict
-- CustomerService owns queue destinations; this module owns locomotion and animation.
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Movement = require(game:GetService("ReplicatedStorage").Shared.Constants.CustomerMovement)
local Placement = require(script.Parent.CustomerPlacement)
local CustomerWalk = {}
local DEFAULT_WALK = {
    R15 = "rbxassetid://507777826",
    R6 = "rbxassetid://180426354",
}
local FADE_TIME = 0.15
local WALK_WEIGHT = 1
local WALK_SPEED = 0.8
local LOAD_TIMEOUT = 5
local LOAD_POLL_INTERVAL = 0.1

-- Validate body structure only. Roblox owns the underlying animated joint representation.
local REQUIRED_PARTS = {
    R15 = {
        "HumanoidRootPart",
        "LowerTorso",
        "UpperTorso",
        "LeftUpperLeg",
        "RightUpperLeg",
        "LeftLowerLeg",
        "RightLowerLeg",
        "LeftFoot",
        "RightFoot",
    },
    R6 = { "HumanoidRootPart", "Torso", "Left Leg", "Right Leg" },
}
local OTHER_BODY_PARTS = {
    R15 = { "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand" },
    R6 = { "Head", "Left Arm", "Right Arm" },
}

local function missingParts(model: Model, rig: string): { string }
    local missing = {}
    for _, name in REQUIRED_PARTS[rig] do
        local part = model:FindFirstChild(name)
        if not part or not part:IsA("BasePart") then
            table.insert(missing, name)
        end
    end
    return missing
end

function CustomerWalk.PrepareRig(model: Model, root: BasePart)
    -- Standard body parts can animate regardless of joint type.
    -- Disconnected decorative parts retain the old anchored behavior.
    local connected: { [BasePart]: boolean } = { [root] = true }
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rig = if humanoid then humanoid.RigType.Name else ""
    if REQUIRED_PARTS[rig] and #missingParts(model, rig) == 0 then
        for _, names in { REQUIRED_PARTS[rig], OTHER_BODY_PARTS[rig] } do
            for _, name in names do
                local part = model:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    connected[part] = true
                end
            end
        end
    end
    -- Preserve existing welded accessories without treating welds as rig validation.
    local descendants = model:GetDescendants()
    local changed = true
    while changed do
        changed = false
        for _, joint in descendants do
            if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
                local a, b = joint.Part0, joint.Part1
                if a and b and a:IsDescendantOf(model) and b:IsDescendantOf(model) then
                    if connected[a] and not connected[b] then
                        connected[b], changed = true, true
                    elseif connected[b] and not connected[a] then
                        connected[a], changed = true, true
                    end
                end
            end
        end
    end
    for part in connected do
        part.Anchored = false
    end
end

-- Retain the existing non-colliding, controlled PivotTo locomotion style. These
-- constraints hold the unanchored assembly between steps and while idle, without
-- adding colliders or changing imported animation joints.
function CustomerWalk.HoldRig(model: Model, root: BasePart): (CFrame) -> ()
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- This route owns forces and orientation, as the old anchored route did.
        -- Keep the engine from enabling body collisions or fighting the pose hold.
        -- Animator playback remains explicitly owned by Create below.
        humanoid.EvaluateStateMachine = false
    end
    local attachment = Instance.new("Attachment")
    attachment.Name = "CustomerRouteAttachment"
    attachment.Parent = root
    local position = Instance.new("AlignPosition")
    position.Mode = Enum.PositionAlignmentMode.OneAttachment
    position.Attachment0 = attachment
    position.ApplyAtCenterOfMass = true
    position.RigidityEnabled = true
    position.Parent = root
    local orientation = Instance.new("AlignOrientation")
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.Attachment0 = attachment
    orientation.RigidityEnabled = true
    orientation.Parent = root
    local function pose(at: CFrame)
        model:PivotTo(at)
        position.Position = root.Position
        orientation.CFrame = root.CFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    pose(model:GetPivot())
    root.Anchored = false
    if root:CanSetNetworkOwnership() then
        root:SetNetworkOwner(nil)
    end
    return pose
end

function CustomerWalk.Cancel(record: any)
    record.MoveToken = (record.MoveToken or 0) + 1
    record.Walk.SetMoving(false)
    local humanoid = record.Model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = false
    end
end

-- Path factory and step clock are injectable engine boundaries for deterministic tests.
function CustomerWalk.Move(
    record: any,
    targets: { CFrame },
    finished: (boolean) -> (),
    adapter: any?,
    arrived: ((number) -> ())?
)
    CustomerWalk.Cancel(record)
    local token = record.MoveToken
    local model: Model = record.Model
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local createPath = if adapter
        then adapter.CreatePath
        else function()
            return PathfindingService:CreatePath(Movement.Agent)
        end
    local step = if adapter
        then adapter.Step
        else function()
            return RunService.Heartbeat:Wait()
        end
    local function valid(): boolean
        return model.Parent ~= nil and record.MoveToken == token
    end
    local function pose(at: CFrame)
        record.Pose(at)
    end
    local function clearApproach(destination: Vector3): boolean
        local start = model:GetPivot().Position
        local delta = destination - start
        if delta.Magnitude < 0.0001 then
            return true
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { model }
        params.RespectCanCollide = true
        local height = Movement.Agent.AgentHeight
        local radius = Movement.Agent.AgentRadius
        local center = start + Vector3.new(0, height / 2 - record.BottomOffset + 0.1, 0)
        return workspace:Blockcast(CFrame.new(center), Vector3.new(radius * 2, height, radius * 2), delta, params)
            == nil
    end
    local function travel(destination: CFrame, blocked: () -> boolean): boolean
        local current = model:GetPivot()
        local start = Placement.Face(current.Position, destination.Position, current)
        local goal = Placement.Face(destination.Position, destination.Position + start.LookVector, start)
        local duration = (start.Position - goal.Position).Magnitude / Movement.Speed
        local elapsed = 0
        while elapsed < duration do
            local dt = step()
            if not valid() or blocked() then
                return false
            end
            elapsed += dt
            pose(start:Lerp(goal, math.min(1, elapsed / duration)))
        end
        return valid() and not blocked()
    end
    if humanoid then
        humanoid.AutoRotate = true
    end
    record.Walk.SetMoving(true)
    task.spawn(function()
        if not valid() then
            return
        end
        local success = true
        for leg, destination in targets do
            local reached = false
            for _ = 1, Movement.MaxPathAttempts do
                if not valid() then
                    return
                end
                local path: any = nil
                local ok = pcall(function()
                    path = createPath()
                    path:ComputeAsync(
                        model:GetPivot().Position - Vector3.new(0, record.BottomOffset, 0),
                        destination.Position - Vector3.new(0, record.BottomOffset, 0)
                    )
                end)
                if not valid() then
                    if path then
                        path:Destroy()
                    end
                    return
                end
                if ok and path.Status == Enum.PathStatus.Success then
                    local blocked, index = false, 1
                    local connection = path.Blocked:Connect(function(at: number)
                        if at >= index then
                            blocked = true
                        end
                    end)
                    local function isBlocked(): boolean
                        return blocked
                    end
                    local points = path:GetWaypoints()
                    reached = #points > 0
                    for i, waypoint in points do
                        index = i
                        if waypoint.Action == Enum.PathWaypointAction.Jump then
                            reached = false
                            break
                        end
                        local at = waypoint.Position + Vector3.new(0, record.BottomOffset, 0)
                        -- Only shorten the final segment; never cut a corner just because
                        -- an earlier waypoint happens to be close to the marker.
                        if
                            i == #points
                            and (model:GetPivot().Position - destination.Position).Magnitude
                                <= Movement.FinalApproachDistance
                        then
                            break
                        end
                        if not travel(CFrame.new(at), isBlocked) then
                            reached = false
                            break
                        end
                    end
                    if reached then
                        -- Path endpoints can be projected far from an unreachable marker.
                        reached = (model:GetPivot().Position - destination.Position).Magnitude
                                <= Movement.FinalApproachDistance
                            and clearApproach(destination.Position)
                            and travel(destination, isBlocked)
                    end
                    connection:Disconnect()
                end
                if path then
                    path:Destroy()
                end
                if reached then
                    break
                end
            end
            if not reached then
                success = false
                break
            end
            if arrived and valid() then
                arrived(leg)
            end
        end
        if not valid() then
            return
        end
        record.Walk.SetMoving(false)
        if humanoid then
            humanoid.AutoRotate = false
        end
        if success then
            local start = model:GetPivot()
            local target = targets[#targets]
            local goal = Placement.Face(start.Position, start.Position + target.LookVector, target)
            local elapsed = 0
            while elapsed < Movement.TurnSeconds do
                elapsed += step()
                if not valid() then
                    return
                end
                pose(start:Lerp(goal, math.min(1, elapsed / Movement.TurnSeconds)))
            end
        end
        if valid() then
            finished(success)
        end
    end)
end

function CustomerWalk.Create(model: Model, templateName: string?)
    local track: AnimationTrack? = nil
    local animation: Animation? = nil
    local animator: Animator? = nil
    local moving, ready, destroyed = false, false, false
    local segment = 0
    local usableRig = false
    local controller = {}
    local warned = false
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rig = if humanoid then humanoid.RigType.Name else "<no Humanoid>"
    local id = DEFAULT_WALK[rig]
    local function diagnostic(message: string)
        if RunService:IsStudio() then
            print(
                string.format(
                    "[CustomerWalk] template=%s customer=%s rig=%s animation=%s %s",
                    templateName or "<generic>",
                    model.Name,
                    rig,
                    id or "<unsupported>",
                    message
                )
            )
        end
    end
    local function warnOnce(message: string)
        if RunService:IsStudio() and not warned then
            warned = true
            warn(string.format("[CustomerWalk] template=%s rig=%s %s", templateName or model.Name, rig, message))
        end
    end
    local function snapshot(phase: string)
        if not RunService:IsStudio() then
            return
        end
        local current = track
        if current then
            diagnostic(
                string.format(
                    "%s IsPlaying=%s Length=%.3f weight=%.3f targetWeight=%.3f speed=%.3f priority=%s",
                    phase,
                    tostring(current.IsPlaying),
                    current.Length,
                    current.WeightCurrent,
                    current.WeightTarget,
                    current.Speed,
                    current.Priority.Name
                )
            )
        end
        if animator then
            for _, other in animator:GetPlayingAnimationTracks() do
                if other ~= current then
                    diagnostic(
                        string.format(
                            "competing track=%s priority=%s weight=%.3f",
                            other.Animation.AnimationId,
                            other.Priority.Name,
                            other.WeightCurrent
                        )
                    )
                end
            end
        end
    end
    local function play()
        local current = track
        if not current or not ready or not moving or destroyed then
            return
        end
        local ok, reason = pcall(function()
            current:Play(FADE_TIME, WALK_WEIGHT, WALK_SPEED)
        end)
        if not ok then
            warnOnce("Play failed: " .. tostring(reason))
        end
        diagnostic("Play success=" .. tostring(ok))
        snapshot("after Play")
        if RunService:IsStudio() then
            local token = segment
            task.delay(FADE_TIME + 0.2, function()
                if not destroyed and moving and segment == token then
                    snapshot("after fade")
                end
            end)
        end
    end
    function controller.SetMoving(value: boolean)
        if destroyed or not usableRig or value == moving then
            return
        end
        moving = value
        segment += 1
        if value then
            diagnostic("route start ready=" .. tostring(ready))
            play()
        elseif track then
            track:Stop(FADE_TIME)
            diagnostic("route stop")
        end
    end
    function controller.Destroy()
        if destroyed then
            return
        end
        destroyed = true
        moving = false
        if track then
            track:Stop(0)
            track:Destroy()
            track = nil
        end
        if animation then
            animation:Destroy()
            animation = nil
        end
    end
    if not humanoid or not id then
        diagnostic("walk disabled: missing Humanoid or unsupported rig")
        return controller
    end
    local missing = missingParts(model, rig)
    if #missing > 0 then
        warnOnce("walk skipped; missing R15/R6 body parts: " .. table.concat(missing, ", "))
        return controller
    end
    animator = humanoid:FindFirstChildOfClass("Animator")
    local foundAnimator = animator ~= nil
    if not animator then
        local created = Instance.new("Animator")
        created.Parent = humanoid
        animator = created
    end
    diagnostic("Animator=" .. (if foundAnimator then "found" else "created") .. " health=" .. tostring(humanoid.Health))
    -- Use a rig-specific standard walk, not unverified assets copied from Animate.
    -- Keep the Animation alive with its track, including while the asset loads.
    local source = Instance.new("Animation")
    source.Name = "CustomerWalkAnimation"
    source.AnimationId = id
    source.Parent = animator
    animation = source
    local ok, loaded = pcall(function()
        return (animator :: Animator):LoadAnimation(source)
    end)
    if not ok or not loaded or not loaded:IsA("AnimationTrack") then
        warnOnce("Animator present=true LoadAnimation failed: " .. tostring(loaded))
        source:Destroy()
        animation = nil
        return controller
    end
    diagnostic("Animator present=true LoadAnimation success=true Length=" .. tostring(loaded.Length))
    usableRig = true
    track = loaded
    loaded.Looped = true
    loaded.Priority = Enum.AnimationPriority.Movement
    ready = loaded.Length > 0
    if not ready then
        -- A successful LoadAnimation can return before clip data is available.
        -- Never delay the route, and never start a late track after arrival/removal.
        task.spawn(function()
            local elapsed = 0
            while not destroyed and loaded.Length <= 0 and elapsed < LOAD_TIMEOUT do
                elapsed += task.wait(LOAD_POLL_INTERVAL)
            end
            if destroyed then
                return
            end
            ready = loaded.Length > 0
            if ready then
                diagnostic("clip ready Length=" .. tostring(loaded.Length))
                play()
            else
                warnOnce("clip unavailable after timeout; check asset permissions/Output errors")
                usableRig = false
                loaded:Destroy()
                track = nil
                source:Destroy()
                animation = nil
            end
        end)
    end
    return controller
end

return CustomerWalk
