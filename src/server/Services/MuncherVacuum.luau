--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local WorldInput = require(script.Parent.MuncherWorldInput)
local Physics = require(script.Parent.BlenderVacuumPhysics)
local Diagnostics = require(script.Parent.MuncherDiagnostics)
local Vacuum = {}

-- Bound to the existing per-plot component heartbeat. No global ingredient scan,
-- no persistent force/anchor, and no reservation until the commit boundary.
function Vacuum.Bind(services: any, input: BasePart, model: Instance): ((number) -> (), () -> ())
    local active: Instance? = nil
    local startedAt = 0
    local elapsed = Config.ScanInterval
    local wasAvailable = false
    local busySeen: { [Instance]: boolean } = {}
    local rejected = setmetatable({} :: { [Instance]: string }, { __mode = "k" })
    local retryAt = setmetatable({} :: { [Instance]: number }, { __mode = "k" })
    local warned = false
    local query = OverlapParams.new()
    query.FilterType = Enum.RaycastFilterType.Exclude
    query.FilterDescendantsInstances = { model }
    query.MaxParts = Config.Vacuum.MaxParts
    local function release()
        if active then
            Diagnostics.Log("Released", input, active)
        end
        active = nil
    end
    local function reject(object: Instance, reason: string)
        if rejected[object] ~= reason then
            rejected[object] = reason
            Diagnostics.Log("CandidateRejected", input, object, reason)
        end
    end
    local function visible(object: Instance, position: Vector3): boolean
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances = { object, input }
        ray.RespectCanCollide = true
        return workspace:Raycast(position, input.Position - position, ray) == nil
    end
    return function(dt: number)
        local owner = services.TycoonService.GetOwner(input)
        local available = model:IsDescendantOf(workspace)
            and input:IsDescendantOf(model)
            and owner ~= nil
            and services.MuncherService.CanVacuum(owner, input)
        if available ~= wasAvailable then
            Diagnostics.Log(if available then "VacuumActivated" else "VacuumDeactivated", input, nil)
            wasAvailable = available
        end
        if not available then
            release()
            -- Observe rejected items at the mouth without attracting or committing them.
            -- CanVacuum deliberately disables the ordinary intake scan while busy.
            elapsed += dt
            local snapshot = if owner then services.MuncherService.GetSnapshot(owner) else nil
            if
                owner
                and model:IsDescendantOf(workspace)
                and input:IsDescendantOf(model)
                and elapsed >= Config.ScanInterval
                and snapshot
                and (snapshot.Phase == "Processing" or snapshot.Phase == "Spitting")
            then
                elapsed = 0
                local observed: { [Instance]: boolean } = {}
                for _, part in workspace:GetPartBoundsInRadius(input.Position, Config.Vacuum.OverlapTolerance, query) do
                    local object = services.IngredientService.Resolve(part)
                    if object then
                        local actor, _, root = WorldInput.Eligible(services, input, object)
                        if
                            actor
                            and root
                            and (root.Position - input.Position).Magnitude <= Config.Vacuum.OverlapTolerance
                            and visible(object, root.Position)
                        then
                            observed[object] = true
                            if not busySeen[object] then
                                services.MuncherService.ReportBusy(actor, input, object)
                            end
                        end
                    end
                end
                busySeen = observed
            end
            return
        end
        table.clear(busySeen)
        local now = workspace:GetServerTimeNow()
        elapsed += dt
        if not active and elapsed >= Config.ScanInterval then
            elapsed = 0
            local nearest = Config.Vacuum.Radius
            local seen: { [Instance]: boolean } = {}
            for _, part in workspace:GetPartBoundsInRadius(input.Position, Config.Vacuum.Radius, query) do
                local object = services.IngredientService.Resolve(part)
                if not object or seen[object] or now < (retryAt[object] or 0) then
                    continue
                end
                seen[object] = true
                local actor, reason, root = WorldInput.Eligible(services, input, object)
                if not actor or not root then
                    reject(object, reason or "InvalidWorldItem")
                    continue
                end
                local distance = (root.Position - input.Position).Magnitude
                if distance <= nearest then
                    nearest, active = distance, object
                end
            end
            if active then
                startedAt = now
                Diagnostics.Log("PullStarted", input, active)
            end
        end
        local object = active
        if not object then
            return
        end
        local actor, reason, root = WorldInput.Eligible(services, input, object)
        if not actor or not root then
            reject(object, reason or "InvalidWorldItem")
            release()
            return
        end
        local distance = (root.Position - input.Position).Magnitude
        if distance > Config.Vacuum.Radius or now - startedAt > Config.Vacuum.MaxPullSeconds then
            retryAt[object] = now + Config.Vacuum.ReleaseSeconds
            Diagnostics.Log("PullTimedOut", input, object)
            release()
            return
        end
        if not visible(object, root.Position) then
            if not warned then
                warned = true
                warn(
                    "[Muncher] Intake path blocked at "
                        .. input:GetFullName()
                        .. "; place InputZone at the accessible mouth opening"
                )
            end
            retryAt[object] = now + Config.Vacuum.ReleaseSeconds
            release()
            return
        end
        -- Commit performs its own threshold, permission and lifecycle revalidation.
        if distance <= Config.Vacuum.OverlapTolerance then
            local accepted, failure =
                services.MuncherService.TryStartConversion(actor, input, object, "WorldVacuum", nil)
            if accepted then
                release()
                return
            elseif failure ~= "OutsideIntake" then
                reject(object, failure or "InvalidWorldItem")
                release()
                return
            end
        end
        root.AssemblyLinearVelocity = Physics.SteerToward(
            root.AssemblyLinearVelocity,
            root.Position,
            input.Position,
            Config.Vacuum.Radius,
            dt,
            Config.Vacuum
        )
    end,
        release
end
return Vacuum
