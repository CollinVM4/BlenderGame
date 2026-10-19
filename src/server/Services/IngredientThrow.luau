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

-- No client position, cursor target, head height, or character-wide bounding box.
-- Carried visuals/Tools must not inflate the avatar's physical clearance.
function IngredientThrow.FindOrigin(root: BasePart, character: Model, object: Instance): (CFrame?, string)
    local direction = root.CFrame.LookVector
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
    local start = root.CFrame.Position + Vector3.new(0, math.max(2, itemRadius), 0)
    local boxSize = Vector3.new(2, 2, 2) * itemRadius
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
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = excluded
    ray.RespectCanCollide = true
    local vertical = workspace:Raycast(root.CFrame.Position, start - root.CFrame.Position, ray)
    if vertical then
        return nil, "launch height obstructed by " .. vertical.Instance:GetFullName()
    end
    -- Blockcast does not detect parts already overlapping its initial volume.
    local initial = workspace:GetPartBoundsInBox(CFrame.new(start), boxSize, overlap)
    if #initial > 0 then
        return nil, "launch volume obstructed by " .. initial[1]:GetFullName()
    end
    local reason = "no clear spawn"
    for _, distance in { math.max(5, minimum), minimum } do
        local position = start + direction * distance
        local hit = workspace:Blockcast(CFrame.new(start), boxSize, position - start, ray)
        local occupied = workspace:GetPartBoundsInBox(CFrame.new(position), boxSize, overlap)
        if not hit and #occupied == 0 then
            return CFrame.new(position) * root.CFrame.Rotation,
                string.format(
                    "clear origin=%s radius=%.3f avatarFront=%.3f distance=%.3f",
                    tostring(position),
                    itemRadius,
                    front,
                    distance
                )
        end
        local blocker = if hit then hit.Instance else occupied[1]
        reason = "spawn/path obstructed by " .. blocker:GetFullName()
    end
    return nil, reason
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
