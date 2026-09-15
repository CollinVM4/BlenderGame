-- Minimal standard locomotion chains at the Roblox boundary.
local function addLocomotionRig(model, rigType)
    local chains = if rigType == "R15"
        then {
            { "Root", "HumanoidRootPart", "LowerTorso" },
            { "Waist", "LowerTorso", "UpperTorso" },
            { "LeftHip", "LowerTorso", "LeftUpperLeg" },
            { "RightHip", "LowerTorso", "RightUpperLeg" },
            { "LeftKnee", "LeftUpperLeg", "LeftLowerLeg" },
            { "RightKnee", "RightUpperLeg", "RightLowerLeg" },
        }
        else {
            { "RootJoint", "HumanoidRootPart", "Torso" },
            { "Left Hip", "Torso", "Left Leg" },
            { "Right Hip", "Torso", "Right Leg" },
        }
    for _, chain in chains do
        for index = 2, 3 do
            if not model:FindFirstChild(chain[index]) then
                local part = instance("Part")
                part.Name, part.Parent = chain[index], model
                part.Anchored = chain[index] == "HumanoidRootPart"
            end
        end
        local motor = instance("Motor6D")
        motor.Name, motor.Parent, motor.Enabled = chain[1], model, true
        motor.Part0, motor.Part1 = model:FindFirstChild(chain[2]), model:FindFirstChild(chain[3])
    end
end

-- Walk presentation uses the Animator boundary; movement owns only start/stop commands.
do
    local walk = loadModule("CustomerWalk")
    env.Enum.AnimationPriority = { Movement = "Movement" }
    for _, rigType in { "R6", "R15" } do
        local model = instance("Model")
        local humanoid = instance("Humanoid")
        humanoid.RigType = { Name = rigType }
        humanoid.Parent = model
        addLocomotionRig(model, rigType)
        local animator = instance("Animator")
        animator.Parent = humanoid
        local track = { IsPlaying = false, Destroyed = false, Length = 1 }
        function track:IsA(class)
            return class == "AnimationTrack"
        end
        function track:Play()
            self.IsPlaying = true
        end
        function track:Stop()
            self.IsPlaying = false
        end
        function track:Destroy()
            self.Destroyed = true
        end
        function animator:LoadAnimation(animation)
            setup(animation.AnimationId ~= "", "compatible default has an asset")
            return track
        end
        local presentation = walk.Create(model)
        check(not track.IsPlaying, rigType .. " starts idle")
        presentation.SetMoving(true)
        check(track.IsPlaying, rigType .. " movement plays walk")
        presentation.SetMoving(false)
        check(not track.IsPlaying, rigType .. " stop ends walk")
        presentation.SetMoving(true)
        check(track.IsPlaying, rigType .. " departure resumes walk")
        presentation.Destroy()
        presentation.SetMoving(true)
        presentation.Destroy()
        check(track.Destroyed and not track.IsPlaying, rigType .. " cleanup prevents stale playback")
        function animator:LoadAnimation()
            error("asset unavailable")
        end
        -- A pending clip must honor route state when loading finishes.
        function animator:LoadAnimation()
            return track
        end
        track.Destroyed, track.Length = false, 0
        local pending = walk.Create(model)
        pending.SetMoving(true)
        check(not track.IsPlaying, "pending clip does not pretend playback is ready")
        track.Length = 1
        flush()
        check(track.IsPlaying, "loaded clip starts while route is still moving")
        pending.Destroy()
        track.Destroyed, track.Length = false, 0
        local stopped = walk.Create(model)
        stopped.SetMoving(true)
        stopped.SetMoving(false)
        track.Length = 1
        flush()
        check(not track.IsPlaying, "late load does not restart walking at counter")
        stopped.Destroy()
        track.Destroyed, track.Length = false, 0
        local removed = walk.Create(model)
        removed.SetMoving(true)
        removed.Destroy()
        flush()
        check(track.Destroyed and not track.IsPlaying, "removal cancels pending clip playback")
        function animator:LoadAnimation()
            error("asset unavailable")
        end
        local unavailable = walk.Create(model)
        unavailable.SetMoving(true)
        unavailable.SetMoving(false)
        unavailable.Destroy()
        check(not track.IsPlaying, "unavailable animation is safe")
    end
end

-- Malformed imports still support route commands, without loading an animation.
do
    local walk = loadModule("CustomerWalk")
    local savedStudio, savedWarn = services.RunService.IsStudio, env.warn
    services.RunService.IsStudio = function()
        return true
    end
    local messages = {}
    env.warn = function(message)
        table.insert(messages, message)
    end
    for _, damage in { "root_only", "missing", "disconnected", "anchored", "disabled" } do
        local model = instance("Model")
        local humanoid = instance("Humanoid")
        humanoid.Parent, humanoid.RigType = model, { Name = "R15" }
        addLocomotionRig(model, "R15")
        local knee = model:FindFirstChild("LeftKnee")
        if damage == "root_only" then
            for _, object in model:GetDescendants() do
                if object:IsA("Motor6D") and object.Name ~= "Root" then
                    object:Destroy()
                end
            end
            model:FindFirstChild("UpperTorso").Anchored = true
        elseif damage == "missing" then
            knee:Destroy()
        elseif damage == "disconnected" then
            knee.Part1 = model:FindFirstChild("UpperTorso")
        elseif damage == "anchored" then
            knee.Part1.Anchored = true
        else
            knee.Enabled = false
        end
        local animator = instance("Animator")
        animator.Parent = humanoid
        function animator:LoadAnimation()
            error("malformed rig must not load a track")
        end
        local before = #messages
        local controller = walk.Create(model, "BrokenAvatar")
        controller.SetMoving(true)
        controller.SetMoving(false)
        controller.SetMoving(true)
        check(
            #messages == before + 1
                and string.find(messages[#messages], "BrokenAvatar", 1, true)
                and string.find(messages[#messages], "LeftKnee", 1, true),
            "one warning identifies template and unusable joint: " .. damage
        )
        check(not model.Destroyed, "malformed animation does not destroy customer")
        if damage == "anchored" then
            check(knee.Part1.Anchored, "validation does not unanchor malformed body")
        end
        controller.Destroy()
    end
    services.RunService.IsStudio, env.warn = savedStudio, savedWarn
end
