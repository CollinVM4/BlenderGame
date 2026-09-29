--!strict
-- CustomerService owns queue destinations; this module owns locomotion and animation.
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Movement = require(game:GetService("ReplicatedStorage").Shared.Constants.CustomerMovement)
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

local function removeLegacyHoldRig(model: Model, root: BasePart)
    local attachment = root:FindFirstChild("CustomerRouteAttachment")
    if not attachment or not attachment:IsA("Attachment") then
        return
    end
    for _, object in model:GetDescendants() do
        if
            (object:IsA("AlignPosition") or object:IsA("AlignOrientation"))
            and (object.Attachment0 == attachment or object.Attachment1 == attachment)
        then
            object:Destroy()
        end
    end
    attachment:Destroy()
end

-- Hand the spawned clone to native Humanoid locomotion and normal character physics.
function CustomerWalk.Prepare(model: Model, root: BasePart)
    removeLegacyHoldRig(model, root)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
        end
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.EvaluateStateMachine = true
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = Movement.Speed
    end
    if root:CanSetNetworkOwnership() then
        root:SetNetworkOwner(nil)
    end
end

function CustomerWalk.Cancel(record: any)
    record.MoveToken = (record.MoveToken or 0) + 1
    record.Walk.SetMoving(false)
    local humanoid = record.Model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = false
        -- Halt in-flight autonomous movement without going through MoveTo/MoveToFinished.
        humanoid:Move(Vector3.zero)
    end
end

-- Path factory is the only injectable engine boundary; Humanoid:MoveTo/MoveToFinished
-- drive the actual walk so slopes and minor terrain variation are handled natively.
-- A model without a Humanoid (e.g. the no-template placeholder) has no rig to drive
-- and glides directly between waypoints instead.
function CustomerWalk.Move(record: any, destination: CFrame, finished: (boolean) -> (), adapter: any?)
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
    local didLogFirstMoveTo = false
    local function valid(): boolean
        return model.Parent ~= nil and record.MoveToken == token
    end
    local function groundPosition(): Vector3
        return model:GetPivot().Position - Vector3.new(0, record.BottomOffset, 0)
    end
    local goalGround = destination.Position - Vector3.new(0, record.BottomOffset, 0)
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = Movement.Speed
    end
    record.Walk.SetMoving(true)

    local function settle(reached: boolean)
        if not valid() then
            return
        end
        record.Walk.SetMoving(false)
        if humanoid then
            humanoid.AutoRotate = false
        end
        if reached then
            model:PivotTo(destination)
        end
        finished(reached)
    end

    -- Drive one waypoint to completion; onDone reports whether it was actually reached.
    local function driveTo(at: Vector3, onDone: (boolean) -> ())
        if humanoid then
            local moveConnection: any
            moveConnection = humanoid.MoveToFinished:Connect(function(reached: boolean)
                moveConnection:Disconnect()
                onDone(reached)
            end)
            if not didLogFirstMoveTo and RunService:IsStudio() then
                didLogFirstMoveTo = true
                local root = model:FindFirstChild("HumanoidRootPart")
                local anchoredBodyParts = {}
                local bodyPartStates = {}
                local staleMovementObjects = {}
                for _, descendant in model:GetDescendants() do
                    if descendant:IsA("BasePart") then
                        if descendant.Anchored then
                            table.insert(anchoredBodyParts, descendant:GetFullName())
                        end
                        table.insert(
                            bodyPartStates,
                            descendant:GetFullName()
                                .. "(Anchored="
                                .. tostring(descendant.Anchored)
                                .. ",CanCollide="
                                .. tostring(descendant.CanCollide)
                                .. ")"
                        )
                    end
                    if
                        descendant:IsA("AlignPosition")
                        or descendant:IsA("AlignOrientation")
                        or descendant:IsA("BodyPosition")
                        or descendant:IsA("BodyVelocity")
                        or descendant:IsA("BodyGyro")
                        or descendant:IsA("LinearVelocity")
                        or descendant:IsA("VectorForce")
                    then
                        table.insert(staleMovementObjects, descendant.ClassName .. ":" .. descendant:GetFullName())
                    end
                end
                local rootAnchored = if root and root:IsA("BasePart") then tostring(root.Anchored) else "<missing>"
                local distance =
                    if root and root:IsA("BasePart") then (root.Position - destination.Position).Magnitude else 0
                print(
                    "[CustomerWalk] rootAnchored="
                        .. rootAnchored
                        .. " anchoredBodyParts="
                        .. table.concat(anchoredBodyParts, ",")
                        .. " evaluateStateMachine="
                        .. tostring(humanoid.EvaluateStateMachine)
                        .. " platformStand="
                        .. tostring(humanoid.PlatformStand)
                        .. " sit="
                        .. tostring(humanoid.Sit)
                        .. " walkSpeed="
                        .. tostring(humanoid.WalkSpeed)
                        .. " humanoidState="
                        .. tostring(humanoid:GetState())
                        .. " destination="
                        .. tostring(destination.Position)
                        .. " distance="
                        .. tostring(distance)
                        .. " moveToWaypoint="
                        .. tostring(at)
                        .. " bodyParts="
                        .. table.concat(bodyPartStates, ",")
                        .. " staleMovementObjects="
                        .. table.concat(staleMovementObjects, ",")
                )
            end
            humanoid:MoveTo(at)
            return
        end
        local start = model:GetPivot()
        local duration = (start.Position - at).Magnitude / Movement.Speed
        local elapsed = 0
        while elapsed < duration do
            if not valid() then
                return
            end
            elapsed += step()
            model:PivotTo(start:Lerp(CFrame.new(at), math.min(1, elapsed / math.max(duration, 0.0001))))
        end
        onDone(valid())
    end

    -- Walk one computed path to completion; reports success/failure of this attempt only.
    local function walkPath(onDone: (boolean) -> ())
        local path: any = nil
        local ok = pcall(function()
            path = createPath()
            path:ComputeAsync(groundPosition(), goalGround)
        end)
        if not valid() then
            if path then
                path:Destroy()
            end
            return
        end
        if not ok or path.Status ~= Enum.PathStatus.Success then
            if path then
                path:Destroy()
            end
            onDone(false)
            return
        end
        local points = path:GetWaypoints()
        if #points == 0 then
            path:Destroy()
            onDone(false)
            return
        end
        local blocked = false
        local connection = path.Blocked:Connect(function()
            blocked = true
        end)
        local function cleanup()
            connection:Disconnect()
            path:Destroy()
        end
        local index = 1
        local function advance()
            if not valid() then
                cleanup()
                return
            end
            if blocked then
                cleanup()
                onDone(false)
                return
            end
            local waypoint = points[index]
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                cleanup()
                onDone(false)
                return
            end
            local at = waypoint.Position + Vector3.new(0, record.BottomOffset, 0)
            driveTo(at, function(reached: boolean)
                if not valid() then
                    cleanup()
                    return
                end
                if blocked or not reached then
                    cleanup()
                    onDone(false)
                    return
                end
                index += 1
                if index > #points then
                    cleanup()
                    onDone(true)
                else
                    advance()
                end
            end)
        end
        advance()
    end

    local attempts = 0
    local function attempt()
        attempts += 1
        walkPath(function(reached)
            if not valid() then
                return
            end
            if reached then
                settle(true)
                return
            end
            if attempts < Movement.MaxPathAttempts then
                attempt()
                return
            end
            -- Bounded retries exhausted: only recover if we already ended up close
            -- to the marker; genuinely unreachable destinations still fail.
            settle((groundPosition() - goalGround).Magnitude <= Movement.FinalApproachDistance)
        end)
    end
    task.spawn(function()
        if valid() then
            attempt()
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
