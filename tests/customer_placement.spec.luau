-- Geometry is independent of rig proportions and authored template rotation.
do
    local placement = loadModule("CustomerPlacement")
    for _, height in { 5, 7.5 } do
        local model = instance("Model")
        model.CFrame = frame(10, 20, 30)
        function model:GetBoundingBox()
            return frame(10, 19, 30), vec(3, height, 2)
        end
        local offset = placement.BottomOffset(model)
        check(offset == 1 + height / 2, "bounding box offset includes pivot displacement for R6/R15 proportions")
        local marker = instance("Part")
        marker.CFrame, marker.Size = frame(4, 2, 8), vec(4, 2, 4)
        local at = placement.AtMarker(marker, offset)
        check(
            at.Position.X == 4 and at.Position.Z == 8 and at.Position.Y - offset == 3,
            "bounds bottom rests on marker top preserving XZ"
        )
        model:SetAttribute("CustomerVerticalOffset", 0.75)
        check(placement.BottomOffset(model) == offset + 0.75, "optional numeric vertical offset")
        model:SetAttribute("CustomerVerticalOffset", "bad")
        check(placement.BottomOffset(model) == offset, "invalid offset defaults to zero")
    end
    for _, target in { vec(10, 5, 0), vec(-10, 0, 0), vec(0, 2, 10), vec(0, 0, -10) } do
        local facing = placement.Face(vec(0, 0, 0), target, frame())
        local direction = vec(target.X, 0, target.Z).Unit
        check(facing.LookVector:Dot(direction) > 0.999, "standard rig -Z forward faces travel target")
        check(facing.UpVector.Y == 1, "avatar stays upright on sloped route")
    end
    check(
        placement.Face(vec(0, 0, 0), vec(0, 9, 0), frame()).LookVector.Z == -1,
        "zero horizontal movement has stable facing"
    )
end

-- Feedback selection and naming are presentation contracts, independent of grading.
do
    local presentation = loadModule("CustomerPresentation")
    local request = { GoodResponse = "good", BadResponse = "bad" }
    for _, grade in { "A", "B", "C", "D", "F" } do
        check(
            presentation.Response(request, grade) == (if grade == "A" or grade == "B" then "good" else "bad"),
            "grade selects configured response: " .. grade
        )
    end
    check(
        presentation.Response({ BadResponse = "bad" }, "A") == nil
            and presentation.Response({ GoodResponse = "good" }, "D") == nil,
        "missing response uses default behavior"
    )
    local model = instance("Model")
    model.Name = "AuthoredModel"
    local humanoid = instance("Humanoid")
    humanoid.DisplayName = "Authored Name"
    humanoid.Parent = model
    check(
        presentation.DisplayName(model, false, "Special", "id") == "CustomerNPC",
        "regular name ignores imported identity"
    )
    check(
        presentation.DisplayName(model, true, "Special", "id") == "Authored Name",
        "special prefers authored Humanoid name"
    )
    humanoid.DisplayName = "   "
    check(
        presentation.DisplayName(model, true, "Special", "id") == "Special",
        "blank authored name uses configured name"
    )
    check(presentation.DisplayName(model, true, nil, "id") == "id", "missing configured name uses identity")
    check(presentation.DisplayName(model, true, nil, nil) == "AuthoredModel", "last fallback is original model name")
end

-- Preparing an imported rig frees its connected body without detaching decorations.
do
    local model = instance("Model")
    local root, body, decoration = instance("Part"), instance("Part"), instance("Part")
    root.Name, body.Name, decoration.Name = "HumanoidRootPart", "Torso", "Decoration"
    for _, part in { root, body, decoration } do
        part.Parent, part.Anchored = model, true
    end
    local motor = instance("Motor6D")
    motor.Parent, motor.Part0, motor.Part1 = body, root, body
    function motor:IsA(class)
        return class == "Motor6D" or class == "JointInstance"
    end
    loadModule("CustomerWalk").PrepareRig(model, root)
    check(
        root.Anchored and not body.Anchored and decoration.Anchored,
        "root and disconnected decoration stay anchored while connected body can animate"
    )
    check(motor.Parent == body and motor.Part0 == root and motor.Part1 == body, "authored joint remains usable")
end

-- Disable only the engine-generated name/health UI.
do
    env.Enum.HumanoidDisplayDistanceType = { None = "None" }
    env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
    local humanoid = instance("Humanoid")
    humanoid.DisplayName = "Authored Name"
    loadModule("CustomerPresentation").HideDefaultDisplay(humanoid)
    check(
        humanoid.DisplayDistanceType == "None" and humanoid.HealthDisplayType == "AlwaysOff",
        "default name and health are hidden"
    )
    check(humanoid.DisplayName == "Authored Name", "hiding default display preserves authored name")
end
