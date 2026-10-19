--!strict
-- Numeric, JSON-safe tracks. No services or engine instances; reusable by CLI tests.
local Path = {}
export type Key = { Time: number, Position: { number }, Rotation: { number }, Fov: number }
export type Take = { Version: number, Name: string, Duration: number, Keys: { Key } }
type Segment = { Start: number, Length: number, Coefficients: { { number } }, A: Key, B: Key, Dot: number }
export type Track = { Duration: number, Segments: { Segment } }

function Path.Allowed(studio: boolean, userId: number, ids: { number }): boolean
    return studio or table.find(ids, userId) ~= nil
end

function Path.ShouldSample(previous: Key, nextKey: Key, positionThreshold: number, rotationThreshold: number): boolean
    local distance, dot = 0, 0
    for i = 1, 3 do
        distance += (previous.Position[i] - nextKey.Position[i]) ^ 2
    end
    for i = 1, 4 do
        dot += previous.Rotation[i] * nextKey.Rotation[i]
    end
    return distance > positionThreshold ^ 2
        or 2 * math.acos(math.clamp(math.abs(dot), 0, 1)) > rotationThreshold
        or math.abs(previous.Fov - nextKey.Fov) > 0.01
end

local function finite(value: any): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Path.Validate(value: any): (boolean, string)
    if type(value) ~= "table" or value.Version ~= 1 or type(value.Name) ~= "string" or #value.Name > 100 then
        return false, "Invalid take header"
    end
    if not finite(value.Duration) or value.Duration <= 0 or value.Duration > 300 then
        return false, "Duration must be within 5 minutes"
    end
    if type(value.Keys) ~= "table" or #value.Keys < 2 or #value.Keys > 3002 then
        return false, "Take needs 2..3002 keys"
    end
    local last = -1
    for _, key in value.Keys do
        if type(key) ~= "table" or not finite(key.Time) or key.Time <= last or key.Time > value.Duration then
            return false, "Key times must increase"
        end
        if not finite(key.Fov) or key.Fov < 1 or key.Fov > 120 then
            return false, "Invalid FOV"
        end
        for _, field in { "Position", "Rotation" } do
            local array = key[field]
            local size = if field == "Position" then 3 else 4
            if type(array) ~= "table" or #array ~= size then
                return false, "Invalid transform"
            end
            for _, number in array do
                if not finite(number) then
                    return false, "Non-finite transform"
                end
            end
        end
        local q = key.Rotation
        if math.abs(q[1] ^ 2 + q[2] ^ 2 + q[3] ^ 2 + q[4] ^ 2 - 1) > 0.001 then
            return false, "Quaternion must be normalized"
        end
        last = key.Time
    end
    if value.Keys[1].Time ~= 0 or last ~= value.Duration then
        return false, "Track must include both endpoints"
    end
    return true, ""
end

local function samePosition(a: Key, b: Key): boolean
    return a.Position[1] == b.Position[1] and a.Position[2] == b.Position[2] and a.Position[3] == b.Position[3]
end

function Path.Compile(take: Take): Track
    local valid, message = Path.Validate(take)
    assert(valid, message)
    local segments: { Segment } = {}
    for i = 1, #take.Keys - 1 do
        local a, b = take.Keys[i], take.Keys[i + 1]
        local previous = take.Keys[math.max(1, i - 1)]
        local following = take.Keys[math.min(#take.Keys, i + 2)]
        local p0, p3 = previous.Position, following.Position
        local coefficients = {}
        for axis = 1, 3 do
            local x0, x1, x2, x3 = p0[axis], a.Position[axis], b.Position[axis], p3[axis]
            -- Timestamp-aware Catmull-Rom tangents keep velocity continuous
            -- when delta filtering leaves unequally spaced key times.
            local length = b.Time - a.Time
            local m1 = if i == 1 then (x2 - x1) / 2 else (x2 - x0) * length / (b.Time - previous.Time)
            local m2 = if i == #take.Keys - 1 then (x2 - x1) / 2 else (x3 - x1) * length / (following.Time - a.Time)
            -- Explicit hold anchors must remain still, without spline overshoot.
            if samePosition(a, b) then
                m1, m2 = 0, 0
            end
            if i > 1 and samePosition(previous, a) then
                m1 = 0
            end
            if i < #take.Keys - 1 and samePosition(b, following) then
                m2 = 0
            end
            coefficients[axis] = { x1, m1, 3 * (x2 - x1) - 2 * m1 - m2, 2 * (x1 - x2) + m1 + m2 }
        end
        local dot = 0
        for axis = 1, 4 do
            dot += a.Rotation[axis] * b.Rotation[axis]
        end
        table.insert(segments, {
            Start = a.Time,
            Length = b.Time - a.Time,
            Coefficients = coefficients,
            A = a,
            B = b,
            Dot = math.clamp(dot, -1, 1),
        })
    end
    return { Duration = take.Duration, Segments = segments }
end

local function polynomial(c: { number }, t: number): number
    return ((c[4] * t + c[3]) * t + c[2]) * t + c[1]
end

-- Scalar returns keep the render loop free of Lua table allocations (including seek).
function Path.Evaluate(track: Track, time: number): (number, number, number, number, number, number, number, number)
    local segments = track.Segments
    local low, high = 1, #segments
    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        if segments[mid].Start <= time then
            low = mid
        else
            high = mid - 1
        end
    end
    local segment = segments[low]
    local t = math.clamp((time - segment.Start) / segment.Length, 0, 1)
    local dot = math.abs(segment.Dot)
    local sign = if segment.Dot < 0 then -1 else 1
    local a, b = 1 - t, t
    if dot < 0.9995 then
        local angle = math.acos(dot)
        local denominator = math.sin(angle)
        a, b = math.sin((1 - t) * angle) / denominator, math.sin(t * angle) / denominator
    end
    b *= sign
    local q0, q1 = segment.A.Rotation, segment.B.Rotation
    local x, y, z, w = a * q0[1] + b * q1[1], a * q0[2] + b * q1[2], a * q0[3] + b * q1[3], a * q0[4] + b * q1[4]
    local norm = math.sqrt(x * x + y * y + z * z + w * w)
    return polynomial(segment.Coefficients[1], t),
        polynomial(segment.Coefficients[2], t),
        polynomial(segment.Coefficients[3], t),
        x / norm,
        y / norm,
        z / norm,
        w / norm,
        segment.A.Fov + (segment.B.Fov - segment.A.Fov) * t
end

local function startIntegral(v: number, edge: number): number
    local u = v / edge
    return edge * (u ^ 3 - u ^ 4 / 2)
end

-- Integrates a smooth speed ramp at either end, preserving exact endpoints/duration.
function Path.EasedTime(time: number, duration: number, enabled: boolean): number
    local t = math.clamp(time, 0, duration)
    if not enabled then
        return t
    end
    local edge = math.min(0.5, duration / 2)
    local area = duration - edge
    if t < edge then
        return startIntegral(t, edge) * duration / area
    end
    if t > duration - edge then
        return duration - startIntegral(duration - t, edge) * duration / area
    end
    return (t - edge / 2) * duration / area
end

return Path
