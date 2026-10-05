--!strict
-- CustomerService owns claims/queue/economy. This helper only runs cancellable routes/physics.
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.BadCustomers)
local Walk = require(script.Parent.CustomerWalk)
local Placement = require(script.Parent.CustomerPlacement)
local Knockback = require(script.Parent.BatKnockback)
local RunService = game:GetService("RunService")
local Behavior = {}

local function route(record: any, context: any, name: string, finished: () -> ())
    if not context.Valid() then
        return
    end
    local marker = context.Marker(name)
    if not marker then
        finished()
        return
    end
    Walk.Move(record, Placement.AtMarker(marker, record.BottomOffset), function(reached)
        if not context.Valid() then
            return
        end
        if reached then
            finished()
        else
            context.Destroy()
        end
    end)
end

function Behavior.Thief(record: any, context: any)
    task.delay(Config.BehaviorTimeout, function()
        if context.Valid() then
            context.Destroy()
        end
    end)
    local function escape()
        if not context.Valid() then
            return
        end
        record.State = "Escaping"
        route(record, context, "CustomerWait2", context.Exit)
    end
    if record.State == "Escaping" then
        escape()
        return
    end
    if not context.Marker("CustomerThiefPoint") then
        if RunService:IsStudio() then
            warn("[Customer] Missing CustomerThiefPoint; skipping theft")
        end
        escape()
        return
    end
    route(record, context, "CustomerThiefPoint", function()
        task.delay(Config.TheftWindup, function()
            if context.Valid() and record.State == "Stealing" then
                context.Theft()
                escape()
            end
        end)
    end)
end

function Behavior.Reject(record: any, context: any, ragdoll: any)
    local model, root = record.Model, record.Root
    local tuning = Config.Reject
    local ok, enabled = pcall(function()
        return ragdoll.SetRagdolled(model, true)
    end)
    if not ok or enabled ~= true then
        context.Destroy()
        return
    end
    local started = os.clock()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { model }
    params.RespectCanCollide = true
    local function poll()
        if not context.Valid() then
            return
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if
            not root.Parent
            or not humanoid
            or humanoid.Health <= 0
            or root.Position.Y <= workspace.FallenPartsDestroyHeight + 10
            or os.clock() - started >= tuning.LandingTimeout
        then
            context.Destroy()
            return
        end
        local floor = workspace:Raycast(
            root.Position,
            Vector3.new(0, -(record.BottomOffset + tuning.LandingClearance), 0),
            params
        )
        if os.clock() - started >= tuning.MinimumFlight and root.AssemblyLinearVelocity.Y <= 3 and floor then
            task.delay(tuning.RecoveryDelay, function()
                if not context.Valid() then
                    return
                end
                local restored, result = pcall(function()
                    return ragdoll.SetRagdolled(model, false)
                end)
                if not restored or result ~= true then
                    context.Destroy()
                    return
                end
                RunService.Heartbeat:Once(function()
                    if context.Valid() then
                        record.Recovering = false
                        context.Exit()
                    end
                end)
            end)
        else
            task.delay(tuning.LandingPoll, poll)
        end
    end
    RunService.Heartbeat:Once(function()
        if not context.Valid() then
            return
        end
        local launched = pcall(function()
            root:SetNetworkOwner(nil)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.new(tuning.TumbleSpeed, 0, tuning.TumbleSpeed / 2)
            local look = root.CFrame.LookVector
            local away = Vector3.new(look.X, 0, look.Z)
            Knockback.Apply(root, if away.Magnitude > 0.001 then away.Unit else Vector3.new(0, 0, -1), {
                HorizontalKnockback = tuning.LaunchHorizontal,
                VerticalKnockback = tuning.LaunchVertical,
            })
        end)
        if not launched then
            context.Destroy()
            return
        end
        poll()
    end)
    task.delay(tuning.LandingTimeout, function()
        if context.Valid() and record.Recovering then
            context.Destroy()
        end
    end)
end

return Behavior
