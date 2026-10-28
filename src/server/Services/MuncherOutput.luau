--!strict
local WorldUtil = require(script.Parent.WorldUtil)
local Output = {}

function Output.Location(model: Instance, input: BasePart): CFrame
    local mouth = model:FindFirstChild("MouthOrigin", true)
    if mouth and mouth:IsA("Attachment") then
        return mouth.WorldCFrame
    elseif mouth and mouth:IsA("BasePart") then
        return mouth.CFrame
    end
    return input.CFrame
end

-- Test the arc in short segments, then choose a local, grounded fallback.
function Output.Placement(model: Instance, at: CFrame): (CFrame, Vector3)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { model }
    params.RespectCanCollide = true
    local direction = at.LookVector
    local velocity = direction * 10 + Vector3.new(0, 13, 0)
    local previous = at.Position
    local blocked = false
    for step = 1, 6 do
        local t = step * 0.08
        local point = at.Position + velocity * t - Vector3.new(0, workspace.Gravity * t * t / 2, 0)
        local hit = workspace:Spherecast(previous, 0.8, point - previous, params)
        if hit then
            -- A floor reached on descent is the intended landing, not an obstruction.
            if hit.Normal and hit.Normal.Y > 0.65 and velocity.Y - workspace.Gravity * t < 0 then
                return at, velocity
            end
            blocked = true
            break
        end
        previous = point
    end
    if not blocked and workspace:Raycast(previous + Vector3.new(0, 2, 0), Vector3.new(0, -24, 0), params) then
        return at, velocity
    end
    for _, offset in { Vector3.new(0, 0, 3), Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, -3) } do
        local candidate = at.Position + offset
        local floor = workspace:Raycast(candidate + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), params)
        if floor then
            local position = floor.Position + Vector3.new(0, 1.5, 0)
            local clearance = OverlapParams.new()
            clearance.RespectCanCollide = true
            if #workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(2, 2, 2), clearance) == 0 then
                return CFrame.new(position), Vector3.zero
            end
        end
    end
    error("No collectible Muncher landing position; retain reward for recovery")
end

function Output.Spawn(ingredients: any, transaction: any): boolean
    if transaction.Output then
        return true
    end
    local at, velocity = Output.Placement(transaction.Model, transaction.At)
    local candidate: Instance? = nil
    local ok, result = pcall(function()
        return ingredients.Spawn(transaction.Reward, at, nil, true, {
            Origin = "Muncher",
            MuncherImmune = true,
            BeforePublish = function(object: Instance)
                candidate = object
                object:SetAttribute("MuncherReward", true)
            end,
        })
    end)
    if not ok or not result then
        if candidate then
            candidate:Destroy()
        end
        return false
    end
    -- Commit before optional physics/presentation, so a failed impulse cannot duplicate output.
    transaction.Output = result
    pcall(function()
        local root = WorldUtil.Part(result)
        if root then
            root:ApplyImpulse(velocity * root.AssemblyMass)
        end
    end)
    return true
end
return Output
