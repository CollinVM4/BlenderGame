--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.BatConfig)
local BatKnockback = {}

-- Player launches borrow server simulation only around the initial impulse.
-- The returned release is also called by combat death/reset/recovery cleanup.
function BatKnockback.TakeOwnership(root: BasePart): (() -> ())?
    if root.Anchored or not root:CanSetNetworkOwnership() then
        return nil
    end
    local automatic, owner = root:GetNetworkOwnershipAuto(), root:GetNetworkOwner()
    root:SetNetworkOwner(nil)
    local released = false
    return function()
        if released then
            return
        end
        released = true
        local ok, problem = pcall(function(): string?
            if not root:IsDescendantOf(workspace) or not root:CanSetNetworkOwnership() then
                return nil
            end
            -- Do not overwrite a later explicit handoff by another system.
            if root:GetNetworkOwnershipAuto() or root:GetNetworkOwner() ~= nil then
                return nil
            end
            if automatic or (owner and owner.Parent ~= game:GetService("Players")) then
                root:SetNetworkOwnershipAuto()
            else
                root:SetNetworkOwner(owner)
            end
            return nil
        end)
        if not ok then
            warn("[Bat] Ownership restoration failed: " .. tostring(problem))
        end
    end
end

function BatKnockback.Direction(attackerRoot: BasePart, root: BasePart): Vector3
    local delta = root.Position - attackerRoot.Position
    local away = Vector3.new(delta.X, 0, delta.Z)
    if away.Magnitude < 0.001 then
        local forward = attackerRoot.CFrame.LookVector
        away = Vector3.new(forward.X, 0, forward.Z)
    end
    return if away.Magnitude > 0.001 then away.Unit else Vector3.new(0, 0, -1)
end

function BatKnockback.Apply(
    root: BasePart,
    away: Vector3,
    tuning: { HorizontalKnockback: number, VerticalKnockback: number }?,
    scale: number?
)
    local mass = root.AssemblyMass
    if not root.Anchored and mass > 0 and mass < math.huge then
        local horizontal = if tuning then tuning.HorizontalKnockback else Config.Knockback.HorizontalSpeed
        local vertical = if tuning then tuning.VerticalKnockback else Config.Knockback.UpwardSpeed
        horizontal *= scale or 1
        vertical *= scale or 1
        -- Direction is already a horizontal unit vector; do not normalize the combined launch.
        local velocity = away * horizontal + Vector3.new(0, vertical, 0)
        if tuning then
            local current = root.AssemblyLinearVelocity
            local planar = Vector3.new(current.X, 0, current.Z)
            local launched = planar + away * horizontal
            if launched.Magnitude > (Config.Knockback.MaxHorizontalSpeed * (scale or 1)) then
                launched = launched.Unit * (Config.Knockback.MaxHorizontalSpeed * (scale or 1))
            end
            -- Bound only upward accumulation. Real falling speed still reaches FallDamageService.
            local upward = math.min(current.Y + vertical, (Config.Knockback.MaxUpwardSpeed * (scale or 1)))
            velocity = launched - planar + Vector3.new(0, upward - current.Y, 0)
        end
        root:ApplyImpulse(velocity * mass)
    end
end

return BatKnockback
