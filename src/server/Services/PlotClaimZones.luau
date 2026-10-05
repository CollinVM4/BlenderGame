--!strict
-- Server samples live character roots in authored oriented boxes. No client entry
-- report or Touched callback can authorize a claim. Session creation never yields.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.StandIdentity)
local Sign = require(script.Parent.StandSignPresentation)
local MovementService = require(script.Parent.MovementService)
local Zones = {}
local authority: any
local claimed: RemoteEvent
local visuals: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local styled: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local entered: { [BasePart]: { [Player]: Model } } = {}
local pendingEntry: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function Zones.Inside(zone: BasePart, position: Vector3): boolean
    local point = zone.CFrame:PointToObjectSpace(position)
    local half = zone.Size * 0.5
    return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Zones.Enter(player: Player, plot: Instance, zone: BasePart): boolean
    local identity = plot:FindFirstChild("PlotIdentity")
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    if
        not MovementService.CanPerformGameplayAction(player)
        or not player:IsDescendantOf(Players)
        or not character
        or not character:IsDescendantOf(workspace)
        or not humanoid
        or humanoid.Health <= 0
        or not root
        or not root:IsA("BasePart")
        or not CollectionService:HasTag(plot, "PlayerPlot")
        or not plot:IsDescendantOf(workspace)
        or not identity
        or zone.Parent ~= identity
        or not Zones.Inside(zone, root.Position)
    then
        return false
    end
    if identity:FindFirstChild("ClaimZone") == zone then
        local success =
            authority.ClaimPlot(player, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") or 0 })
        if success and authority.GetOwner(plot) == player then
            local context = authority.GetRequestContext(player)
            claimed:FireClient(player, plot, context.PlotSessionId, context.MembershipRevision)
        end
        return success
    elseif identity:FindFirstChild("TeammateZone") == zone then
        local owner = authority.GetOwner(plot)
        return owner ~= nil
            and owner ~= player
            and authority.RequestJoin(player, plot, authority.GetRequestContext(owner))
    end
    return false
end

local function showVisual(object: Instance?, active: boolean)
    if not object then
        return
    end
    local parts = object:GetDescendants()
    table.insert(parts, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            if visuals[part] == nil then
                -- Hidden authored pads still need a visible active appearance.
                -- ActiveTransparency also lets nested invisible helpers stay invisible.
                local authored = part:GetAttribute("ActiveTransparency")
                visuals[part] = if type(authored) == "number"
                        and authored >= 0
                        and authored <= 1
                    then authored
                    elseif part.Transparency < 1 then part.Transparency
                    else 0
            end
            part.Transparency = if active then visuals[part] else 1
        end
    end
end

function Zones.Refresh(plot: Instance)
    local occupancy = plot:GetAttribute("PlotOccupancy") or 0
    local identity = plot:FindFirstChild("PlotIdentity")
    if identity then
        for _, role in { "Claim", "Teammate" } do
            local active = if role == "Claim" then occupancy == 0 else occupancy == 1
            local zone = identity:FindFirstChild(role .. "Zone")
            if zone and zone:IsA("BasePart") then
                zone.Transparency, zone.CanCollide, zone.CanTouch, zone.CanQuery = 1, false, false, false
                zone:SetAttribute("PlotZoneActive", active)
            end
            showVisual(identity:FindFirstChild(role .. "Visual"), active)
        end
    end
    local area = plot:FindFirstChild("Customer Area")
    local sign = if area then area:FindFirstChild("Dynamic Sign Text") else nil
    if sign then
        local gui = sign:FindFirstChild("SurfaceGui")
        if gui and not styled[gui] then
            Sign.Style(sign)
            styled[gui] = true
        end
        Sign.SetStandName(sign, tostring(plot:GetAttribute("StandName") or ""))
    end
end

function Zones.Step()
    local live: { [BasePart]: boolean } = {}
    for _, plot in CollectionService:GetTagged("PlayerPlot") do
        if not plot:IsDescendantOf(workspace) then
            continue
        end
        Zones.Refresh(plot)
        local identity = plot:FindFirstChild("PlotIdentity")
        if not identity then
            continue
        end
        for _, name in { "ClaimZone", "TeammateZone" } do
            local zone = identity:FindFirstChild(name)
            if not zone or not zone:IsA("BasePart") then
                continue
            end
            live[zone] = true
            local previous = entered[zone] or {}
            local current: { [Player]: Model } = {}
            local arrivals: { Player } = {}
            for _, player in Players:GetPlayers() do
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and root:IsA("BasePart") and Zones.Inside(zone, root.Position) then
                    current[player] = player.Character :: Model
                    if previous[player] ~= player.Character and zone:GetAttribute("PlotZoneActive") then
                        table.insert(arrivals, player)
                    end
                end
            end
            entered[zone] = current
            -- Record entry before dispatch. Friendship policies can yield; the
            -- heartbeat must keep sampling without launching duplicate joins.
            for _, player in arrivals do
                if not pendingEntry[player] then
                    pendingEntry[player] = true
                    task.spawn(function()
                        local ok, message = pcall(Zones.Enter, player, plot, zone)
                        pendingEntry[player] = nil
                        if not ok then
                            warn("[PlotClaimZones] " .. tostring(message))
                        end
                        if plot:IsDescendantOf(workspace) then
                            Zones.Refresh(plot)
                        end
                    end)
                end
            end
        end
    end
    for zone in entered do
        if not live[zone] then
            entered[zone] = nil
        end
    end
end

function Zones.Init(services: any)
    authority = services.TycoonService
    claimed = Instance.new("RemoteEvent")
    claimed.Name = "PlotClaimed"
    claimed.Parent = ReplicatedStorage.Shared.Events
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= Config.ZoneInterval then
            elapsed = 0
            Zones.Step()
        end
    end)
end

return Zones
