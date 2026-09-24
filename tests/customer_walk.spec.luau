-- Body-only fixtures deliberately contain no Motor6Ds or AnimationConstraints.
-- The Roblox Animator boundary, not CustomerWalk, decides if an animation can load.
local function addLocomotionRig(model, rigType)
    model.Name = "ImportedAvatar"
    local names = if rigType == "R15"
        then {
            "HumanoidRootPart",
            "LowerTorso",
            "UpperTorso",
            "LeftUpperLeg",
            "RightUpperLeg",
            "LeftLowerLeg",
            "RightLowerLeg",
            "LeftFoot",
            "RightFoot",
        }
        else { "HumanoidRootPart", "Torso", "Left Leg", "Right Leg" }
    for _, name in names do
        local part = instance("Part")
        part.Name, part.Parent, part.Anchored = name, model, name == "HumanoidRootPart"
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

-- Missing body structure remains a safe, non-spawn-blocking rejection.
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
    for _, damage in { "static", "missing_part", "wrong_class", "roblox_rejected" } do
        local model = instance("Model")
        local humanoid = instance("Humanoid")
        humanoid.Parent, humanoid.RigType = model, { Name = "R15" }
        addLocomotionRig(model, "R15")
        if damage == "static" then
            for _, name in { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } do
                model:FindFirstChild(name):Destroy()
            end
        elseif damage ~= "roblox_rejected" then
            model:FindFirstChild("LeftFoot"):Destroy()
            if damage == "wrong_class" then
                local folder = instance("Folder")
                folder.Name, folder.Parent = "LeftFoot", model
            end
        end
        local animator = instance("Animator")
        animator.Parent = humanoid
        local attemptedLoad = false
        function animator:LoadAnimation()
            attemptedLoad = true
            error("Roblox rejected this animation/rig")
        end
        local before = #messages
        local controller = walk.Create(model, "ImportedAvatar")
        controller.SetMoving(true)
        controller.SetMoving(false)
        controller.SetMoving(true)
        check(attemptedLoad == (damage == "roblox_rejected"), "only basic body validation gates Roblox loading")
        check(
            #messages == before + 1 and string.find(messages[#messages], "ImportedAvatar", 1, true),
            "one warning identifies template"
        )
        check(
            string.find(
                messages[#messages],
                if damage == "roblox_rejected" then "LoadAnimation failed" else "LeftFoot",
                1,
                true
            ),
            "warning identifies missing body part or Roblox rejection"
        )
        check(not model.Destroyed, "animation rejection does not destroy customer")
        controller.Destroy()
    end
    services.RunService.IsStudio, env.warn = savedStudio, savedWarn
end

-- Standard R15 limbs must not remain anchored just because joint types have changed.
do
    local model = instance("Model")
    local humanoid = instance("Humanoid")
    humanoid.Parent, humanoid.RigType = model, { Name = "R15" }
    addLocomotionRig(model, "R15")
    for _, object in model:GetChildren() do
        if object:IsA("BasePart") then
            object.Anchored = true
        end
    end
    local decoration = instance("Part")
    decoration.Name, decoration.Parent, decoration.Anchored = "Decoration", model, true
    local root = model:FindFirstChild("HumanoidRootPart")
    loadModule("CustomerWalk").PrepareRig(model, root)
    check(
        not root.Anchored
            and not model:FindFirstChild("UpperTorso").Anchored
            and not model:FindFirstChild("LeftFoot").Anchored,
        "standard body is free to animate with an unanchored route root"
    )
    check(decoration.Anchored, "unrelated decoration retains anchoring")
end
