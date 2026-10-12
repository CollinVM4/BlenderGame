-- Local engine boundary extensions. Physical contact/replication remain Studio checks.
local function lockObject(class, name, parentObject)
    local object = instance(class)
    object.Name, object.Parent = name or class, parentObject
    object.CFrame = env.CFrame.new()
    object.DescendantAdded, object.DescendantRemoving, object.Changed = signal(), signal(), signal()
    object.Touched, object.TouchEnded = signal(), signal()
    return object
end
env.Instance.new = function(class)
    return lockObject(class)
end
env.typeof = function(value)
    if type(value) == "table" then
        if value.ClassName then
            return "Instance"
        end
        if value.Position and value.LookVector then
            return "CFrame"
        end
    end
    return type(value)
end
-- Include world-space translation in the fake CFrame implementation.
local originalFrame = env.CFrame.new
env.CFrame.new = function(...)
    local result = originalFrame(...)
    getmetatable(result).__add = function(cf, offset)
        local moved = originalFrame(cf.Position + offset)
        moved.RightVector, moved.UpVector, moved.LookVector = cf.RightVector, cf.UpVector, cf.LookVector
        getmetatable(moved).__add = getmetatable(cf).__add
        return moved
    end
    return result
end
local tagAdded, tagRemoved = {}, {}
services.CollectionService.GetInstanceAddedSignal = function(_, tag)
    tagAdded[tag] = tagAdded[tag] or signal()
    return tagAdded[tag]
end
services.CollectionService.GetInstanceRemovedSignal = function(_, tag)
    tagRemoved[tag] = tagRemoved[tag] or signal()
    return tagRemoved[tag]
end
local registered, matrix = { Default = true, Players = true, Ingredients = true, WorldItems = true }, {}
local function pair(a, b)
    return if a < b then a .. ":" .. b else b .. ":" .. a
end
services.PhysicsService = {
    IsCollisionGroupRegistered = function(_, name)
        return registered[name] == true
    end,
    RegisterCollisionGroup = function(_, name)
        registered[name] = true
    end,
    GetRegisteredCollisionGroups = function()
        local result = {}
        for name in registered do
            table.insert(result, { name = name })
        end
        return result
    end,
    CollisionGroupSetCollidable = function(_, a, b, value)
        matrix[pair(a, b)] = value
    end,
}
local function physicalCollision(wall, body)
    if not wall.CanCollide or matrix[pair(wall.CollisionGroup, body.CollisionGroup)] == false then
        return false
    end
    for _, constraint in allInstances do
        if
            constraint.ClassName == "NoCollisionConstraint"
            and constraint.Parent
            and not constraint.Destroyed
            and (
                (constraint.Part0 == wall and constraint.Part1 == body)
                or (constraint.Part1 == wall and constraint.Part0 == body)
            )
        then
            return false
        end
    end
    return true
end
local standingOn = {}
local buttonRayHits = {}
env.Enum.RaycastFilterType.Include = "Include"
workspaceFake.Raycast = function(_, position, _direction, params)
    local hit = if params.FilterType == "Include" then buttonRayHits[position] else standingOn[position]
    return if hit and hit.CanCollide ~= false then { Instance = hit } else nil
end
local function prepareCharacter(p)
    p.Character.DescendantAdded, p.Character.DescendantRemoving = signal(), signal()
    for _, body in p.Character:GetDescendants() do
        if body:IsA("BasePart") then
            body.CollisionGroup = "Players"
            body.AssemblyLinearVelocity = vec(0, 0, 0)
        end
    end
    p.Character:FindFirstChildOfClass("Humanoid").HipHeight = 2
end
local function securityAssets(plot, assemblyClass)
    plot.DescendantAdded, plot.DescendantRemoving = signal(), signal()
    local lock = lockObject("Model", "LockBase", plot)
    -- Direct LockAttachment needs a BasePart host, not the old invalid Model fixture.
    local assembly = lockObject(assemblyClass or "Part", "LockButton", lock)
    local blackBase = lockObject("Part", "BlackBase", assembly)
    blackBase.CanCollide = true
    local button = lockObject("Part", "Button", assembly)
    button.CanCollide = true
    local attachment = lockObject("Attachment", "LockAttachment", assembly)
    local visual = lockObject("Model", "Visual", assembly)
    visual.CFrame = env.CFrame.new(10, 20, 30)
    local laser = lockObject("Part", "Laser", visual)
    laser.Transparency, laser.Size = 0.2, vec(1, 8, 1)
    local base = lockObject("Part", "LaserBase", visual)
    base.Transparency = 0.1
    -- Authored walls deliberately live outside LockBase.
    local container = lockObject("Folder", "Walls", plot)
    local wall = lockObject("Part", "SecurityBarrier", container)
    services.CollectionService:AddTag(wall, "PlayerOnlyCollision")
    return button, wall, visual, attachment, laser, base
end
env.Enum.EasingStyle, env.Enum.EasingDirection = { Quart = "Quart", Quad = "Quad" }, { Out = "Out" }
env.TweenInfo = {
    new = function(duration, style, direction)
        return { Duration = duration, Style = style, Direction = direction }
    end,
}
local tweens = {}
services.TweenService = {
    Create = function(_, target, info, properties)
        local completion = signal()
        function completion:Wait()
            local thread = coroutine.running()
            local connection
            connection = self:Connect(function()
                connection:Disconnect()
                local ok, message = coroutine.resume(thread)
                assert(ok, message)
            end)
            coroutine.yield()
        end
        local tween = { Target = target, Info = info, Properties = properties, Completed = completion }
        function tween:Play()
            self.Played = true
        end
        function tween:Cancel()
            self.Canceled = true
            self.Completed:Fire()
        end
        function tween:Finish()
            if self.Canceled then
                return
            end
            for key, value in self.Properties do
                self.Target[key] = value
            end
            if self.Target.Changed then
                self.Target.Changed:Fire()
            end
            self.Completed:Fire()
        end
        table.insert(tweens, tween)
        return tween
    end,
}
-- Complete waits like Roblox task.spawn rather than blocking the CLI process.
env.task.spawn = function(fn)
    local thread = coroutine.create(fn)
    local ok, message = coroutine.resume(thread)
    assert(ok, message)
end
