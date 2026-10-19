--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Path = require(ReplicatedStorage.Shared.FilmCamPath)
local Takes = {}

function Takes.Capture(time: number, cf: CFrame, fov: number): Path.Key
    local axis, angle = cf.Rotation:ToAxisAngle()
    local s = math.sin(angle / 2)
    return {
        Time = time,
        Position = { cf.X, cf.Y, cf.Z },
        Rotation = { axis.X * s, axis.Y * s, axis.Z * s, math.cos(angle / 2) },
        Fov = fov,
    }
end

function Takes.Encode(take: Path.Take): string
    local valid, message = Path.Validate(take)
    assert(valid, message)
    return HttpService:JSONEncode(take)
end

function Takes.Decode(json: string): (Path.Take?, string)
    local ok, value = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if not ok then
        return nil, "Invalid JSON"
    end
    local valid, message = Path.Validate(value)
    return if valid then value else nil, message
end

function Takes.Preset(kind: string, cf: CFrame, fov: number, target: Vector3?): Path.Take
    local duration = if kind == "Orbit" then 8 else 5
    local take: Path.Take = { Version = 1, Name = kind, Duration = duration, Keys = {} }
    local center = target or (cf.Position + cf.LookVector * 20)
    -- Avoid degenerate look-at frames when the center ray hits the camera itself.
    if (center - cf.Position).Magnitude < 0.1 then
        center = cf.Position + cf.LookVector * 20
    end
    local offset = cf.Position - center
    for i = 0, duration * 10 do
        local t = i / (duration * 10)
        local frame = cf + cf.LookVector * (10 * t * (if kind == "Pull-out" then -1 else 1))
        if kind == "Orbit" then
            local position = center + CFrame.Angles(0, t * math.pi * 2, 0):VectorToWorldSpace(offset)
            local up = if math.abs((center - position).Unit:Dot(Vector3.yAxis)) > 0.999
                then Vector3.zAxis
                else Vector3.yAxis
            frame = CFrame.lookAt(position, center, up)
        end
        table.insert(take.Keys, Takes.Capture(i / 10, frame, fov))
    end
    return take
end

return Takes
