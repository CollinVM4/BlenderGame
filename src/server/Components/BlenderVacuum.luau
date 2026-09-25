--!strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.BlenderVacuum)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Physics = require(script.Parent.Parent.Services.BlenderVacuumPhysics)
local BlenderVacuum = {}

local function log(message: string)
    if RunService:IsStudio() and ServerStorage:GetAttribute("DebugBlenderVacuum") == true then
        print("[BlenderVacuum] " .. message)
    end
end

local function targetPosition(zone: BasePart, input: BasePart): Vector3
    -- Attachments belong to BaseParts. Prefer a direct child of InputZone,
    -- then VacuumZone, so unrelated blender attachments cannot win by scan order.
    for _, parent in { input, zone } do
        local target = parent:FindFirstChild("VacuumTarget")
        if target and target:IsA("Attachment") then
            return target.WorldPosition
        end
    end
    return input.Position + input.CFrame.UpVector * (input.Size.Y * 0.5 + Config.TargetHeight)
end

local function looseRoot(item: Instance): BasePart?
    local ancestor: Instance? = item
    while ancestor and ancestor ~= workspace do
        if ancestor:IsA("Tool") or ancestor:IsA("Accessory") or ancestor:FindFirstChildOfClass("Humanoid") then
            return nil
        end
        ancestor = ancestor.Parent
    end
    local root = WorldUtil.Part(item)
    if not root or root.Anchored then
        return nil
    end
    -- Reject a registered object welded to a character/other external assembly.
    for _, part in root:GetConnectedParts(true) do
        if part.Anchored or (part ~= item and not part:IsDescendantOf(item)) then
            return nil
        end
    end
    return root
end

function BlenderVacuum.Init(services: any)
    local active: { [Instance]: BasePart } = {}
    -- One update for all authored zones; no workspace traversal or per-item connections.
    RunService.Heartbeat:Connect(function(dt: number)
        local candidates: { [Instance]: any } = {}
        for _, zone in CollectionService:GetTagged("BlenderVacuum") do
            if not zone:IsA("BasePart") or not zone:IsDescendantOf(workspace) then
                continue
            end
            local owner = services.TycoonService.GetOwner(zone)
            if not owner or services.TycoonService.GetReference(owner, "BlenderVacuum") ~= zone then
                continue
            end
            local input = services.TycoonService.GetReference(owner, "BlenderInput")
            if not input then
                continue
            end
            local target = targetPosition(zone, input)
            local insideInput: { [Instance]: boolean } = {}
            for _, part in workspace:GetPartsInPart(input) do
                local item = services.IngredientService.Resolve(part)
                if item then
                    insideInput[item] = true
                end
            end
            local seen: { [Instance]: boolean } = {}
            for _, part in workspace:GetPartsInPart(zone) do
                local item = services.IngredientService.Resolve(part)
                if not item or seen[item] or insideInput[item] then
                    continue
                end
                seen[item] = true
                local record = services.IngredientService.GetRecord(item)
                if
                    not record
                    or (record.Owner ~= nil and not services.TycoonService.IsMember(record.Owner, zone))
                    or (record.Owner == nil and not record.Claimable)
                then
                    continue
                end
                local root = looseRoot(item)
                if not root then
                    continue
                end
                -- Release at the opening; never hold ingredients below the target.
                if root.Position.Y < target.Y then
                    continue
                end
                local distance = (root.Position - target).Magnitude
                local previous = candidates[item]
                -- Public claimable items follow existing input ownership rules.
                -- Nearest valid opening wins, with UserId as a stable tie breaker.
                if
                    not previous
                    or distance < previous.Distance
                    or (distance == previous.Distance and owner.UserId < previous.Owner.UserId)
                then
                    candidates[item] = { Zone = zone, Root = root, Target = target, Owner = owner, Distance = distance }
                end
            end
        end
        local nextActive: { [Instance]: BasePart } = {}
        for item, candidate in candidates do
            local root = candidate.Root
            -- No yields between eligibility and velocity write/consumption boundary.
            if services.IngredientService.GetRecord(item) and root:IsDescendantOf(workspace) then
                if active[item] ~= candidate.Zone then
                    log("captured ingredient=" .. item.Name .. " owner=" .. candidate.Owner.Name)
                end
                nextActive[item] = candidate.Zone
                root.AssemblyLinearVelocity = Physics.Steer(
                    root.AssemblyLinearVelocity,
                    root.Position,
                    candidate.Target,
                    math.max(candidate.Zone.Size.X, candidate.Zone.Size.Z) * 0.5,
                    dt
                )
            end
        end
        for item, zone in active do
            if nextActive[item] ~= zone then
                log("released ingredient=" .. item.Name)
            end
        end
        active = nextActive
    end)
end

return BlenderVacuum
