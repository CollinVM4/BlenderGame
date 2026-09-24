--!strict
-- Markers describe ground surfaces, not avatar pivot heights.
local CustomerPlacement = {}

function CustomerPlacement.BottomOffset(model: Model): number
    local bounds, size = model:GetBoundingBox()
    local halfHeight = (
        math.abs(bounds.RightVector.Y) * size.X
        + math.abs(bounds.UpVector.Y) * size.Y
        + math.abs(bounds.LookVector.Y) * size.Z
    ) / 2
    local offset = model:GetAttribute("CustomerVerticalOffset")
    local extra = if type(offset) == "number" and offset == offset and math.abs(offset) < math.huge then offset else 0
    return model:GetPivot().Position.Y - (bounds.Position.Y - halfHeight) + extra
end

function CustomerPlacement.AtMarker(marker: BasePart, bottomOffset: number): CFrame
    -- Top surface at the marker's center X/Z. Author upright, horizontal route markers.
    local position = marker.CFrame.Position
    local grounded = Vector3.new(position.X, position.Y + marker.Size.Y / 2 + bottomOffset, position.Z)
    return CustomerPlacement.Face(grounded, grounded + marker.CFrame.LookVector, marker.CFrame)
end

function CustomerPlacement.Face(position: Vector3, target: Vector3, fallback: CFrame): CFrame
    local direction = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
    if direction.Magnitude < 0.0001 then
        direction = Vector3.new(fallback.LookVector.X, 0, fallback.LookVector.Z)
        if direction.Magnitude < 0.0001 then
            direction = Vector3.new(0, 0, -1)
        end
    end
    return CFrame.lookAt(position, position + direction)
end

return CustomerPlacement
