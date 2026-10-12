--!strict
-- Sole owner of combat character Highlights. Stunned on Player is an aggregate
-- input lock, so outlines read character-specific server status attributes instead.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceShotgunPresentationConfig)
local Controller = {}
local NAME = "CharacterStatusOutline"
type Track = {
    Player: Player,
    Character: Model?,
    Dead: boolean,
    Highlight: Highlight?,
    CharacterConnections: { RBXScriptConnection },
    PlayerConnections: { RBXScriptConnection },
}
local tracks: { [Player]: Track } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function removeOutline(track: Track)
    if track.Highlight then
        track.Highlight:Destroy()
    end
    track.Highlight = nil
end

local function clearCharacter(track: Track)
    removeOutline(track)
    for _, connection in track.CharacterConnections do
        connection:Disconnect()
    end
    table.clear(track.CharacterConnections)
    track.Character = nil
end

local function immune(value: any, now: number): boolean
    return typeof(value) == "number" and value > now and value < math.huge
end

local function status(character: Model, now: number): (string?, Color3?, boolean)
    -- A freeze stays active until the server clears it, including a delayed thaw.
    local frozen = character:GetAttribute("FrozenUntil")
    if typeof(frozen) == "number" and frozen > 0 then
        return "Freeze", Config.Blue, false
    elseif character:GetAttribute("BatStunned") == true then
        return "BatStun", Config.White, false
    elseif immune(character:GetAttribute("FreezeImmuneUntil"), now) then
        return "FreezeImmunity", Config.Blue, true
    elseif immune(character:GetAttribute("BatImmuneUntil"), now) then
        return "BatImmunity", Config.White, true
    end
    return nil, nil, false
end

local function refresh()
    local camera = workspace.CurrentCamera
    local now = workspace:GetServerTimeNow()
    local candidates: { { Track: Track, Distance: number, Kind: string, Color: Color3, Flash: boolean } } = {}
    for _, track in tracks do
        local character = track.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local h = character and character:FindFirstChildOfClass("Humanoid")
        local kind, color, flash = nil, nil, false
        if character and not track.Dead and h and h.Health > 0 then
            kind, color, flash = status(character, now)
        end
        if kind and color and camera and root and root:IsA("BasePart") and root:IsDescendantOf(workspace) then
            local distance = (camera.CFrame.Position - root.Position).Magnitude
            if distance <= Config.OutlineDistance then
                table.insert(
                    candidates,
                    { Track = track, Distance = distance, Kind = kind, Color = color, Flash = flash }
                )
                continue
            end
        end
        removeOutline(track)
    end
    table.sort(candidates, function(a, b)
        local aLocal, bLocal = a.Track.Player == Players.LocalPlayer, b.Track.Player == Players.LocalPlayer
        if aLocal ~= bLocal then
            return aLocal
        end
        if a.Distance ~= b.Distance then
            return a.Distance < b.Distance
        end
        return a.Track.Player.UserId < b.Track.Player.UserId
    end)
    for index, candidate in candidates do
        local track = candidate.Track
        if index > Config.MaxOutlines then
            removeOutline(track)
            continue
        end
        local highlight = track.Highlight
        if not highlight or highlight.Parent ~= track.Character then
            removeOutline(track)
            local created = Instance.new("Highlight")
            created.Name = NAME
            created.Adornee = track.Character
            created.FillTransparency = 1
            created.DepthMode = Enum.HighlightDepthMode.Occluded
            created.Parent = track.Character
            track.Highlight, highlight = created, created
        end
        if not highlight then
            continue
        end
        highlight:SetAttribute("Status", candidate.Kind)
        highlight.OutlineColor = candidate.Color
        highlight.OutlineTransparency = if candidate.Flash
                and math.floor(now / Config.ImmunityFlashSeconds) % 2 == 1
            then 0.85
            else 0.05
    end
end

local function bindCharacter(track: Track, character: Model)
    clearCharacter(track)
    track.Character, track.Dead = character, false
    -- Reinitialization/hot reload may leave an owned outline; never touch other Highlights.
    for _, child in character:GetChildren() do
        if child:IsA("Highlight") and child.Name == NAME then
            child:Destroy()
        end
    end
    for _, attribute in { "FrozenUntil", "BatStunned", "FreezeImmuneUntil", "BatImmuneUntil" } do
        table.insert(track.CharacterConnections, character:GetAttributeChangedSignal(attribute):Connect(refresh))
    end
    local humanoid: Humanoid? = nil
    local function attachHumanoid()
        local h = character:FindFirstChildOfClass("Humanoid")
        if not h or h == humanoid then
            return
        end
        humanoid = h
        table.insert(
            track.CharacterConnections,
            h.Died:Connect(function()
                track.Dead = true
                removeOutline(track)
            end)
        )
        refresh()
    end
    table.insert(track.CharacterConnections, character.ChildAdded:Connect(attachHumanoid))
    attachHumanoid()
    refresh()
end

local function addPlayer(player: Player)
    if tracks[player] then
        return
    end
    local track: Track = {
        Player = player,
        Character = nil,
        Dead = false,
        Highlight = nil,
        CharacterConnections = {},
        PlayerConnections = {},
    }
    tracks[player] = track
    table.insert(
        track.PlayerConnections,
        player.CharacterAdded:Connect(function(character)
            bindCharacter(track, character)
        end)
    )
    table.insert(
        track.PlayerConnections,
        player.CharacterRemoving:Connect(function(character)
            if track.Character == character then
                clearCharacter(track)
            end
        end)
    )
    if player.Character then
        bindCharacter(track, player.Character)
    end
end

local function removePlayer(player: Player)
    local track = tracks[player]
    if not track then
        return
    end
    tracks[player] = nil
    clearCharacter(track)
    for _, connection in track.PlayerConnections do
        connection:Disconnect()
    end
end

function Controller.Init()
    if started then
        return
    end
    started = true
    table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
    table.insert(connections, Players.PlayerRemoving:Connect(removePlayer))
    for _, player in Players:GetPlayers() do
        addPlayer(player)
    end
    local elapsed = 0
    table.insert(
        connections,
        RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed >= Config.OutlineInterval then
                elapsed = 0
                refresh()
            end
        end)
    )
end

function Controller.Destroy()
    for player in tracks do
        removePlayer(player)
    end
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
    started = false
end

return Controller
