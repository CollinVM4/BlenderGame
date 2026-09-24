-- Locomotion contracts: deterministic path service and heartbeat boundaries.
local walk = loadModule("CustomerWalk")
local config = loadModule("CustomerMovement")
local function rig()
    local model, humanoid = instance("Model"), instance("Humanoid")
    model.Parent, humanoid.Parent = workspaceFake, model
    local record = { Model = model, BottomOffset = 0, Moving = false, Frames = {} }
    record.Walk = {
        SetMoving = function(value)
            record.Moving = value
        end,
    }
    record.Pose = function(at)
        model:PivotTo(at)
        table.insert(record.Frames, at)
    end
    return record, humanoid
end
local function adapter(points, status)
    local state = { Attempts = 0 }
    state.Step = function()
        return 0.05
    end
    state.CreatePath = function()
        state.Attempts += 1
        local path = { Status = status or "Success", Blocked = signal() }
        state.Path = path
        function path:ComputeAsync(start, finish)
            state.LastStart = start
            self.Points = points or { { Position = start }, { Position = finish } }
        end
        function path:GetWaypoints()
            return self.Points
        end
        function path:Destroy() end
        return path
    end
    return state
end
local destination = env.CFrame.lookAt(vec(12, 0, 0), vec(13, 0, 0))
do
    local record, humanoid = rig()
    local engine = adapter({ { Position = vec(0, 0, 5) }, { Position = vec(12, 0, 5) }, { Position = vec(12, 0, 0) } })
    local arrived, wasWalking, turnedSmoothly = false, false, false
    engine.Step = function()
        wasWalking = wasWalking or (record.Moving and humanoid.AutoRotate)
        if not record.Moving then
            turnedSmoothly = true
            check(not humanoid.AutoRotate, "automatic turning disabled during final settle")
            check(record.Model:GetPivot().Position.Y == 0, "final turn preserves grounded height")
        end
        return 0.05
    end
    walk.Move(record, { destination }, function(ok)
        arrived = ok
    end, engine)
    flush()
    local detoured = false
    for _, at in record.Frames do
        detoured = detoured or at.Position.Z >= 5
    end
    check(arrived and detoured, "traverse the obstacle detour before arriving")
    check(
        record.Model:GetPivot().Position.X == 12 and record.Model:GetPivot().Position.Z == 0,
        "final approach reaches exact marker XZ"
    )
    check(record.Model:GetPivot().LookVector.X > 0.999, "settles to marker horizontal facing")
    check(
        wasWalking and turnedSmoothly and not record.Moving and not humanoid.AutoRotate,
        "walking transitions to stable idle"
    )
    local resumed = false
    engine.Step = function()
        resumed = resumed or humanoid.AutoRotate
        return 0.05
    end
    walk.Move(record, { frame(20, 0, 0) }, function() end, engine)
    flush()
    check(resumed and not humanoid.AutoRotate, "walking resumes AutoRotate then disables it at next stop")
end
for _, failure in { "NoPath", "error", "blocked", "jump", "projected" } do
    local record = rig()
    local engine = adapter(nil, if failure == "NoPath" then "NoPath" else "Success")
    local create = engine.CreatePath
    engine.CreatePath = function()
        local path = create()
        if failure == "error" then
            function path:ComputeAsync()
                error("engine failure")
            end
        elseif failure == "jump" then
            function path:GetWaypoints()
                return { { Position = vec(1, 0, 0), Action = "Jump" } }
            end
        elseif failure == "projected" then
            function path:GetWaypoints()
                return { { Position = vec(1, 0, 0) } }
            end
        end
        return path
    end
    if failure == "blocked" then
        engine.Step = function()
            engine.Path.Blocked:Fire(2)
            return 0.05
        end
    end
    local result = nil
    walk.Move(record, { destination }, function(ok)
        result = ok
    end, engine)
    flush()
    check(
        result == false and engine.Attempts == config.MaxPathAttempts,
        failure .. " retries are bounded and report failure"
    )
    check(not record.Moving and record.Model:GetPivot().Position.X < 12, "failed route never teleports to destination")
end
-- A single forward obstruction recomputes from the customer's actual position.
do
    local record = rig()
    local engine = adapter()
    local ticks = 0
    engine.Step = function()
        ticks += 1
        if ticks == 4 then
            engine.Path.Blocked:Fire(2)
        end
        return 0.05
    end
    local arrived = false
    walk.Move(record, { destination }, function(ok)
        arrived = ok
    end, engine)
    flush()
    check(arrived and engine.Attempts == 2 and engine.LastStart.X > 0, "blocked route recomputes from current position")
end
for _, phase in { "compute", "travel", "turn", "despawn" } do
    local record = rig()
    local engine = adapter()
    local called, cancelledAt = false, nil
    local function cancel()
        if phase == "despawn" then
            record.Model:Destroy()
        else
            walk.Cancel(record)
        end
        cancelledAt = #record.Frames
    end
    if phase == "compute" then
        local create = engine.CreatePath
        engine.CreatePath = function()
            local path = create()
            local compute = path.ComputeAsync
            function path:ComputeAsync(a, b)
                compute(self, a, b)
                cancel()
            end
            return path
        end
    else
        engine.Step = function()
            if not cancelledAt and (phase ~= "turn" or not record.Moving) then
                cancel()
            end
            return 0.05
        end
    end
    walk.Move(record, { destination }, function()
        called = true
    end, engine)
    flush()
    check(
        cancelledAt ~= nil and not called and #record.Frames == cancelledAt,
        phase .. " cancellation prevents stale poses and arrival"
    )
end
-- Arrival from a projected path endpoint still makes a short precision approach.
do
    local record = rig()
    local engine = adapter({ { Position = vec(10, 0, 0) } })
    local result = false
    walk.Move(record, { destination }, function(ok)
        result = ok
    end, engine)
    flush()
    check(result and record.Model:GetPivot().Position.X == 12, "short final direct approach corrects path endpoint")
end

-- Precision approach cannot cut through an obstacle to reach an off-mesh marker.
do
    local record = rig()
    local engine = adapter({ { Position = vec(10, 0, 0) } })
    local savedCast = workspaceFake.Blockcast
    workspaceFake.Blockcast = function()
        return {}
    end
    local result = nil
    walk.Move(record, { destination }, function(ok)
        result = ok
    end, engine)
    flush()
    check(
        result == false and engine.Attempts == config.MaxPathAttempts,
        "obstructed final approach fails safely within retry budget"
    )
    workspaceFake.Blockcast = savedCast
end
