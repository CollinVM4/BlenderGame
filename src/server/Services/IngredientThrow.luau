--!strict
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local IngredientThrow = {}
local GRACE_SECONDS = 0.2
local CLEARANCE = 0.25
local MAX_DISTANCE = 32

local diagnostics =
    setmetatable({} :: { [Player]: { Attempt: string, Window: number, Count: number } }, { __mode = "k" })

-- Correlation metadata never participates in gameplay validation.
function IngredientThrow.BeginRequest(player: Player, attempt: any)
    if player:GetAttribute("ThrowDebug") ~= true then
        diagnostics[player] = nil
        return
    end
    local state: { Attempt: string, Window: number, Count: number } = diagnostics[player]
        or { Attempt = "none", Window = os.clock(), Count = 0 }
    state.Attempt = if type(attempt) == "number"
            and attempt == attempt
            and attempt >= 0
            and attempt <= 2147483647
            and attempt == math.floor(attempt)
        then tostring(attempt)
        else "none"
    diagnostics[player] = state
end

function IngredientThrow.Trace(player: Player, message: string)
    if player:GetAttribute("ThrowDebug") ~= true then
        return
    end
    local state = diagnostics[player]
    if not state then
        IngredientThrow.BeginRequest(player, nil)
        state = diagnostics[player]
    end
    if not state then
        return
    end
    local now = os.clock()
    if now - state.Window >= 5 then
        state.Window, state.Count = now, 0
    end
    if state.Count >= 40 then
        return
    end
    state.Count += 1
    print("[ThrowServer] player=" .. player.Name .. " attempt=" .. state.Attempt .. " " .. message)
end

-- Retain the nominal facing frame for callers; placement is validated after preparation.
function IngredientThrow.Origin(root: BasePart): CFrame
    return root.CFrame * CFrame.new(0, 2, -5)
end

local function extent(part: BasePart, direction: Vector3): number
    local frame, half = part.CFrame, part.Size * 0.5
    return math.abs(frame.RightVector:Dot(direction)) * half.X
        + math.abs(frame.UpVector:Dot(direction)) * half.Y
        + math.abs(frame.LookVector:Dot(direction)) * half.Z
end

-- A pivot-centered radius also covers multipart templates with off-center pivots.
local function radius(object: Instance): number
    local pivot = (object :: any):GetPivot().Position
    local result = 0
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            result = math.max(result, (part.CFrame.Position - pivot).Magnitude + part.Size.Magnitude * 0.5)
        end
    end
    return result + CLEARANCE
end

-- Bounds in the object's pivot frame become oriented bounds under the spawn rotation.
-- Preserve the center offset so asymmetric multipart templates are queried correctly.
local function bounds(object: Instance): (Vector3, Vector3)
    local pivot = (object :: any):GetPivot()
    local low = Vector3.new(math.huge, math.huge, math.huge)
    local high = Vector3.new(-math.huge, -math.huge, -math.huge)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            local relative = pivot:ToObjectSpace(part.CFrame).Position
            local half = Vector3.new(
                extent(part, pivot.RightVector),
                extent(part, pivot.UpVector),
                extent(part, pivot.LookVector * -1)
            )
            local lower, upper = relative - half, relative + half
            low = Vector3.new(math.min(low.X, lower.X), math.min(low.Y, lower.Y), math.min(low.Z, lower.Z))
            high = Vector3.new(math.max(high.X, upper.X), math.max(high.Y, upper.Y), math.max(high.Z, upper.Z))
        end
    end
    return (low + high) * 0.5, high - low + Vector3.new(2, 2, 2) * CLEARANCE
end

-- No client position, cursor target, head height, or character-wide bounding box.
-- Carried visuals/Tools must not inflate the avatar's physical clearance.
function IngredientThrow.FindOrigin(root: BasePart, character: Model, object: Instance): (CFrame?, string)
    local facing = root.CFrame.LookVector
    local direction = Vector3.new(facing.X, 0, facing.Z).Unit
    local itemRadius = radius(object)
    local front = 0
    for _, part in character:GetDescendants() do
        if
            part:IsA("BasePart")
            and not part:FindFirstAncestorWhichIsA("Tool")
            and not part:FindFirstAncestor("IngredientCarryVisuals")
        then
            front =
                math.max(front, (part.CFrame.Position - root.CFrame.Position):Dot(direction) + extent(part, direction))
        end
    end
    local minimum = front + itemRadius + CLEARANCE
    if minimum > MAX_DISTANCE then
        return nil, "avatar/item clearance exceeds safe distance"
    end
    local boxCenter, boxSize = bounds(object)
    local excluded: { Instance } = { character }
    -- Running receptors resolve arrivals through their vacuum, including busy shake-off.
    for _, plot in CollectionService:GetTagged("PlayerPlot") do
        local muncher = plot:FindFirstChild("Muncher")
        if muncher and muncher:GetAttribute("Purchased") == true and muncher:GetAttribute("Active") == true then
            table.insert(excluded, muncher)
        end
    end
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = excluded
    overlap.RespectCanCollide = true
    local start = root.CFrame.Position + Vector3.new(0, math.max(2, itemRadius), 0)
    local distances = {}
    local distance = math.max(5, minimum)
    while distance > minimum do
        table.insert(distances, distance)
        distance -= 1
    end
    table.insert(distances, minimum)
    for _, angle in { 0, 20, -20, 40, -40 } do
        local radians = math.rad(angle)
        local candidateDirection = Vector3.new(
            direction.X * math.cos(radians) + direction.Z * math.sin(radians),
            0,
            -direction.X * math.sin(radians) + direction.Z * math.cos(radians)
        )
        for _, candidateDistance in distances do
            local position = start + candidateDirection * candidateDistance
            local origin = CFrame.new(position) * root.CFrame.Rotation
            local occupied = workspace:GetPartBoundsInBox(origin * CFrame.new(boxCenter), boxSize, overlap)
            if #occupied == 0 then
                return origin, string.format("clear distance=%.3f angle=%d", candidateDistance, angle)
            end
        end
    end
    return CFrame.new(start + direction * minimum) * root.CFrame.Rotation,
        string.format("placement forced distance=%.3f", minimum)
end

-- Pairwise exclusions preserve collisions with the world, blender and other players.
-- Install before publishing the object to Workspace; no global collision groups change.
function IngredientThrow.IgnoreCharacter(object: Instance, character: Model)
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            for _, body in character:GetDescendants() do
                if body:IsA("BasePart") then
                    local exclusion = Instance.new("NoCollisionConstraint")
                    exclusion.Part0 = part
                    exclusion.Part1 = body
                    exclusion.Parent = part
                    Debris:AddItem(exclusion, GRACE_SECONDS)
                end
            end
        end
    end
end

return IngredientThrow
