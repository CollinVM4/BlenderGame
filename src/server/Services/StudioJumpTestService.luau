--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StudioJumpTestService = {}

local PAD_FOLDER_NAME = "StudioJumpPads"
local PAD_SIZE = Vector3.new(10, 1, 10)
local PAD_SPACING = 13
local PAD_HEIGHT_OFFSET = 0.5
local TOUCH_COOLDOWN_SEC = 0.05
local RESET_PAD_LABEL = "RESET JUMP"

local labelByTier: { [number]: string } = {
    [1] = "JUMP 1",
    [2] = "JUMP 2",
    [3] = "JUMP 3",
}

local colorByTier: { [number]: Color3 } = {
    [1] = Color3.fromRGB(120, 200, 120),
    [2] = Color3.fromRGB(110, 170, 245),
    [3] = Color3.fromRGB(255, 170, 90),
}

local movement: any
local lastTouchTimeByPlayer: { [Player]: number } = {}

local function applyTierToPlayer(player: Player, tier: number)
    movement.SetStudioJumpTier(player, tier)
end
local function resetJumpForPlayer(player: Player)
    movement.SetStudioJumpTier(player, nil)
end

local function getPadAnchorPosition(): Vector3
    local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    if spawn and spawn:IsA("BasePart") then
        return spawn.Position + Vector3.new(0, PAD_HEIGHT_OFFSET, -26)
    end
    return Vector3.new(0, 6, 0)
end

local function ensureLabel(part: BasePart, text: string)
    local existingSurface = part:FindFirstChild("Label")
    local surface: SurfaceGui
    if existingSurface and existingSurface:IsA("SurfaceGui") then
        surface = existingSurface
    else
        surface = Instance.new("SurfaceGui")
        surface.Name = "Label"
        surface.Face = Enum.NormalId.Top
        surface.AlwaysOnTop = true
        surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        surface.PixelsPerStud = 50
        surface.Parent = part
    end

    local existingText = surface:FindFirstChild("Text")
    local textLabel: TextLabel
    if existingText and existingText:IsA("TextLabel") then
        textLabel = existingText
    else
        textLabel = Instance.new("TextLabel")
        textLabel.Name = "Text"
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextScaled = true
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0.35
        textLabel.Parent = surface
    end

    textLabel.Text = text
end

local function ensurePad(folder: Folder, tier: number, position: Vector3): BasePart
    local partName = labelByTier[tier]
    local existing = folder:FindFirstChild(partName)
    local pad: BasePart

    if existing and existing:IsA("BasePart") then
        pad = existing
    else
        pad = Instance.new("Part")
        pad.Name = partName
        pad.Parent = folder
    end

    pad.Anchored = true
    pad.CanCollide = true
    pad.Material = Enum.Material.Neon
    pad.Color = colorByTier[tier]
    pad.Size = PAD_SIZE
    pad.Position = position
    pad.TopSurface = Enum.SurfaceType.Smooth
    pad.BottomSurface = Enum.SurfaceType.Smooth

    ensureLabel(pad, partName)

    pad.Touched:Connect(function(hit: BasePart)
        local character = hit.Parent
        if not character then
            return
        end

        local player = Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        local now = os.clock()
        local last = lastTouchTimeByPlayer[player]
        if last and (now - last) < TOUCH_COOLDOWN_SEC then
            return
        end
        lastTouchTimeByPlayer[player] = now

        applyTierToPlayer(player, tier)
    end)

    return pad
end

function StudioJumpTestService.Init(dependencies)
    if not (RunService:IsServer() and RunService:IsStudio()) then
        return
    end

    movement = dependencies.MovementService
    local folder = Workspace:FindFirstChild(PAD_FOLDER_NAME)
    if not folder or not folder:IsA("Folder") then
        folder = Instance.new("Folder")
        folder.Name = PAD_FOLDER_NAME
        folder.Parent = Workspace
    end

    local anchor = getPadAnchorPosition()
    for tier = 1, 3 do
        local position = anchor + Vector3.new((tier - 2) * PAD_SPACING, 0, 0)
        ensurePad(folder, tier, position)
    end
    local resetPosition = anchor + Vector3.new(2 * PAD_SPACING, 0, 0)
    local resetPad = folder:FindFirstChild(RESET_PAD_LABEL)
    if not resetPad or not resetPad:IsA("BasePart") then
        resetPad = Instance.new("Part")
        resetPad.Name = RESET_PAD_LABEL
        resetPad.Parent = folder
    end
    resetPad.Anchored = true
    resetPad.CanCollide = true
    resetPad.Material = Enum.Material.Neon
    resetPad.Color = Color3.fromRGB(235, 95, 95)
    resetPad.Size = PAD_SIZE
    resetPad.Position = resetPosition
    resetPad.TopSurface = Enum.SurfaceType.Smooth
    resetPad.BottomSurface = Enum.SurfaceType.Smooth
    ensureLabel(resetPad, RESET_PAD_LABEL)
    resetPad.Touched:Connect(function(hit: BasePart)
        local character = hit.Parent
        if not character then
            return
        end

        local player = Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        local now = os.clock()
        local last = lastTouchTimeByPlayer[player]
        if last and (now - last) < TOUCH_COOLDOWN_SEC then
            return
        end
        lastTouchTimeByPlayer[player] = now

        resetJumpForPlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        lastTouchTimeByPlayer[player] = nil
    end)
end

return StudioJumpTestService
