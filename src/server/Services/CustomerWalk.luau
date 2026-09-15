--!strict
-- Presentation only: CustomerService owns the route and arrival timing.
local RunService = game:GetService("RunService")
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

-- Standard locomotion chains: names alone are insufficient if endpoints are broken.
local REQUIRED_JOINTS = {
    R15 = {
        { "Root", "HumanoidRootPart", "LowerTorso" },
        { "Waist", "LowerTorso", "UpperTorso" },
        { "LeftHip", "LowerTorso", "LeftUpperLeg" },
        { "RightHip", "LowerTorso", "RightUpperLeg" },
        { "LeftKnee", "LeftUpperLeg", "LeftLowerLeg" },
        { "RightKnee", "RightUpperLeg", "RightLowerLeg" },
    },
    R6 = {
        { "RootJoint", "HumanoidRootPart", "Torso" },
        { "Left Hip", "Torso", "Left Leg" },
        { "Right Hip", "Torso", "Right Leg" },
    },
}

local function missingJoints(model: Model, rig: string): { string }
    local missing = {}
    local motors: { [string]: { Motor6D } } = {}
    for _, object in model:GetDescendants() do
        if object:IsA("Motor6D") then
            motors[object.Name] = motors[object.Name] or {}
            table.insert(motors[object.Name], object)
        end
    end
    for _, expected in REQUIRED_JOINTS[rig] do
        local a, b = model:FindFirstChild(expected[2]), model:FindFirstChild(expected[3])
        local usable = false
        if a and a:IsA("BasePart") and b and b:IsA("BasePart") and not b.Anchored then
            local candidates: { Motor6D } = motors[expected[1]] or {}
            for _, motor in candidates do
                if motor.Enabled and motor.Part0 == a and motor.Part1 == b then
                    usable = true
                    break
                end
            end
        end
        if not usable then
            table.insert(missing, expected[1])
        end
    end
    return missing
end

function CustomerWalk.PrepareRig(model: Model, root: BasePart)
    -- PivotTo controls the anchored root. Free connected limbs for Motor6D posing.
    -- Disconnected decorative parts retain the old anchored behavior.
    local connected: { [BasePart]: boolean } = { [root] = true }
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
        part.Anchored = part == root
    end
end

function CustomerWalk.Create(model: Model, templateName: string?)
    local track: AnimationTrack? = nil
    local animation: Animation? = nil
    local animator: Animator? = nil
    local moving, ready, destroyed = false, false, false
    local segment = 0
    local usableRig = false
    local controller = {}
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
        diagnostic("Play success=" .. tostring(ok) .. (if ok then "" else " error=" .. tostring(reason)))
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
    local missing = missingJoints(model, rig)
    if #missing > 0 then
        if RunService:IsStudio() then
            warn(
                string.format(
                    "[CustomerWalk] template=%s rig=%s walk skipped; missing/unusable joints: %s",
                    templateName or model.Name,
                    rig,
                    table.concat(missing, ", ")
                )
            )
        end
        return controller
    end
    usableRig = true
    animator = humanoid:FindFirstChildOfClass("Animator")
    local foundAnimator = animator ~= nil
    if not animator then
        local created = Instance.new("Animator")
        created.Parent = humanoid
        animator = created
    end
    diagnostic("Animator=" .. (if foundAnimator then "found" else "created") .. " health=" .. tostring(humanoid.Health))
    if RunService:IsStudio() then
        local motors = 0
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        diagnostic(
            "root="
                .. (if root then root.Name else "<missing>")
                .. " anchored="
                .. tostring(if root and root:IsA("BasePart") then root.Anchored else nil)
        )
        for _, object in model:GetDescendants() do
            if object:IsA("Motor6D") then
                motors += 1
                local a, b = object.Part0, object.Part1
                diagnostic(
                    string.format(
                        "motor=%s enabled=%s Part0=%s anchored=%s Part1=%s anchored=%s",
                        object.Name,
                        tostring(object.Enabled),
                        if a then a.Name else "<missing>",
                        tostring(if a then a.Anchored else nil),
                        if b then b.Name else "<missing>",
                        tostring(if b then b.Anchored else nil)
                    )
                )
            end
        end
        diagnostic("Motor6Ds=" .. tostring(motors))
    end
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
        diagnostic("LoadAnimation failed: " .. tostring(loaded))
        source:Destroy()
        animation = nil
        return controller
    end
    diagnostic("LoadAnimation success=true Length=" .. tostring(loaded.Length))
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
                diagnostic("clip unavailable after timeout; check asset permissions/Output errors")
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
