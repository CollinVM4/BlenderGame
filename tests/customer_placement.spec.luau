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
