-- Locomotion contracts: deterministic path service and native Humanoid MoveTo boundary.
local walk = loadModule("CustomerWalk")
local config = loadModule("CustomerMovement")
local function rig()
    local model, humanoid = instance("Model"), instance("Humanoid")
    model.Parent, humanoid.Parent = workspaceFake, model
    local record = { Model = model, BottomOffset = 0, Moving = false }
    record.Walk = {
        SetMoving = function(value)
            record.Moving = value
        end,
    }
    return record, humanoid
end
local function adapter(points, status)
    local state = { Attempts = 0 }
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

-- A successful path walks every waypoint via MoveTo/MoveToFinished, then settles once.
do
    local record, humanoid = rig()
    local engine = adapter({ { Position = vec(6, 0, 0) }, { Position = vec(12, 0, 0) } })
    local sawAutoRotate, arrived = false, nil
    humanoid.MoveTo = function(self, position)
        sawAutoRotate = sawAutoRotate or self.AutoRotate
        self.MoveToFinished:Fire(true)
    end
    walk.Move(record, destination, function(ok)
        arrived = ok
    end, engine)
    flush()
    check(arrived == true and sawAutoRotate, "successful route walks and arrives")
    check(
        record.Model:GetPivot().Position.X == 12 and record.Model:GetPivot().Position.Z == 0,
        "final approach reaches exact marker XZ"
    )
    check(record.Model:GetPivot().LookVector.X > 0.999, "settles to marker horizontal facing")
    check(not record.Moving and not humanoid.AutoRotate, "walking transitions to stable idle")
end

-- Bounded, distinct failure modes never teleport toward the destination.
for _, failure in { "NoPath", "computeError", "jump", "stuck" } do
    local record, humanoid = rig()
    local engine = adapter(nil, if failure == "NoPath" then "NoPath" else "Success")
    local create = engine.CreatePath
    engine.CreatePath = function()
        local path = create()
        if failure == "computeError" then
            function path:ComputeAsync()
                error("engine failure")
            end
        elseif failure == "jump" then
            function path:GetWaypoints()
                return { { Position = vec(1, 0, 0), Action = "Jump" } }
            end
        end
        return path
    end
    if failure == "stuck" then
        humanoid.MoveTo = function(self)
            self.MoveToFinished:Fire(false)
        end
    end
    local result = nil
    walk.Move(record, destination, function(ok)
        result = ok
    end, engine)
    flush()
    check(
        result == false and engine.Attempts == config.MaxPathAttempts,
        failure .. " retries are bounded and report failure"
    )
    check(not record.Moving and record.Model:GetPivot().Position.X < 12, "failed route never teleports to destination")
end

-- Bounded retries exhausted but the customer already ended up close settles instead of failing.
do
    local record = rig()
    record.Model:PivotTo(env.CFrame.new(vec(11, 0, 0)))
    local engine = adapter(nil, "NoPath")
    local result = nil
    walk.Move(record, destination, function(ok)
        result = ok
    end, engine)
    flush()
    check(result == true and engine.Attempts == config.MaxPathAttempts, "close arrival recovers after bounded failures")
    check(record.Model:GetPivot().Position.X == 12, "recovered arrival still settles at the exact marker")
end

-- A path obstruction recomputes from the customer's actual current position.
do
    local record, humanoid = rig()
    local engine = adapter({ { Position = vec(6, 0, 0) }, { Position = vec(12, 0, 0) } })
    local calls, arrived = 0, nil
    humanoid.MoveTo = function(self, position)
        calls += 1
        record.Model:PivotTo(env.CFrame.new(position))
        if calls == 1 then
            engine.Path.Blocked:Fire(2)
        end
        self.MoveToFinished:Fire(true)
    end
    walk.Move(record, destination, function(ok)
        arrived = ok
    end, engine)
    flush()
    check(arrived == true, "blocked leg recomputes and still arrives")
    check(engine.Attempts == 2, "blocked route recomputes exactly once from current position")
    check(engine.LastStart.X == 6, "recompute path starts from the customer's actual current position")
end

-- Cancellation during compute, in-flight travel, or despawn prevents stale arrival.
for _, phase in { "compute", "travel", "despawn" } do
    local record, humanoid = rig()
    local engine = adapter()
    local called = false
    local function cancel()
        if phase == "despawn" then
            record.Model:Destroy()
        else
            walk.Cancel(record)
        end
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
        humanoid.MoveTo = function(self, position)
            cancel()
            self.MoveToFinished:Fire(true)
        end
    end
    walk.Move(record, destination, function()
        called = true
    end, engine)
    flush()
    check(not called, phase .. " cancellation prevents stale arrival")
end
