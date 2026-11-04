--!strict
-- Live entitlement, airborne budget and registered accessory lifecycle.
local Players = game:GetService("Players")
local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Constants.WingsConfig)
local Service = {}
local deps: any
local passId = Config.WingsGamePassId
local configured = passId == 2021642550 and passId == math.floor(passId) and passId < math.huge

type Flight = {
    Character: Model,
    Humanoid: Humanoid,
    Root: BasePart,
    Clone: Instance?,
    Connections: { RBXScriptConnection },
    Granted: boolean,
    Energy: number,
    PoweredTime: number,
    JumpHeld: boolean,
    GroundedTime: number,
    State: string,
    -- FallDamageService owns the episode and genuine landing boundary. This
    -- candidate is captured there before either service can publish Grounded.
    FallEpisode: boolean,
    LandingCandidate: boolean?,
    GraceUntil: number,
}
type State = {
    Owned: boolean?,
    Checking: boolean,
    Recheck: boolean,
    NextCheck: number,
    Pending: boolean,
    RequestAt: number,
    Flight: Flight?,
}
local states: { [Player]: State } = {}
local warned: { [string]: boolean } = {}
local grounded = {
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.Landed] = true,
    [Enum.HumanoidStateType.RunningNoPhysics] = true,
    [Enum.HumanoidStateType.GettingUp] = true,
}
local excluded = {
    [Enum.HumanoidStateType.Swimming] = true,
    [Enum.HumanoidStateType.Climbing] = true,
    [Enum.HumanoidStateType.Seated] = true,
    [Enum.HumanoidStateType.Physics] = true,
}
local function warnOnce(key: string, message: string)
    if not warned[key] then
        warned[key] = true
        warn("[Wings] " .. message)
    end
end
local function publish(player: Player, flight: Flight, value: string)
    if flight.State ~= value then
        flight.State = value
        player:SetAttribute("WingState", value)
    end
end
local function clearCharacter(player: Player, state: State)
    local flight = state.Flight
    state.Flight = nil
    if not flight then
        return
    end
    flight.GraceUntil = 0
    for _, connection in flight.Connections do
        connection:Disconnect()
    end
    if flight.Clone then
        flight.Clone:Destroy()
    end
    player:SetAttribute("WingState", "Grounded")
end
local function removeWings(flight: Flight)
    flight.Granted = false
    if flight.Clone then
        flight.Clone:Destroy()
        flight.Clone = nil
    end
end
local function movementAllowed(player: Player, flight: Flight): boolean
    return player.Character == flight.Character
        and flight.Humanoid.Health > 0
        and not flight.Root.Anchored
        and not flight.Humanoid.PlatformStand
        and not excluded[flight.Humanoid:GetState()]
        and not deps.MovementService.IsMovementLocked(player)
end
local function eligible(player: Player, flight: Flight): boolean
    return flight.Granted and movementAllowed(player, flight)
end
local function groundEvidence(flight: Flight): boolean
    -- Deliberately stricter than fall damage's torso/foot probes: recharge
    -- requires 0.2s of state AND floor evidence; a raycast graze cannot refill.
    return grounded[flight.Humanoid:GetState()] == true and flight.Humanoid.FloorMaterial ~= Enum.Material.Air
end
function Service.GrantIfOwned(player: Player): Instance?
    local state = states[player]
    local flight = state and state.Flight
    if
        not configured
        or not state
        or state.Owned ~= true
        or not flight
        or player.Character ~= flight.Character
        or flight.Humanoid.Health <= 0
    then
        return nil
    end
    if flight.Clone and flight.Clone.Parent == flight.Character then
        return flight.Clone
    end
    if flight.Clone then
        flight.Clone:Destroy()
        flight.Clone = nil
    end
    local template = ServerStorage:FindFirstChild("AngelWingsTemplate")
    local torso = flight.Character:FindFirstChild("UpperTorso") or flight.Character:FindFirstChild("Torso")
    if not template or not torso or not torso:IsA("BasePart") then
        warnOnce("asset", "Missing AngelWingsTemplate or character torso; grant deferred.")
        return nil
    end
    local clone = template:Clone()
    clone.Name = "AngelWings"
    clone:SetAttribute("WingsAccessory", true)
    for _, item in clone:GetDescendants() do
        if
            item:IsA("BaseScript")
            or item:IsA("RemoteEvent")
            or item:IsA("RemoteFunction")
            or item:IsA("JointInstance")
            or item:IsA("Constraint")
        then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
            item.Massless, item.Anchored = true, false
        end
    end
    local handle = clone:FindFirstChild("Handle")
    local attachment = handle and handle:FindFirstChild("BodyBackAttachment")
    if
        not clone:IsA("Accessory")
        or not handle
        or not handle:IsA("BasePart")
        or not attachment
        or not attachment:IsA("Attachment")
    then
        clone:Destroy()
        warnOnce("structure", "Expected supplied single Handle / BodyBackAttachment accessory.")
        return nil
    end
    -- Let Humanoid attach AND scale the supplied accessory. Upgraded avatars
    -- use AccessoryRigidConstraint; a pre-parented custom Motor6D is not a
    -- durable accessory joint across native rig/appearance rebuilds.
    local back = torso:FindFirstChild("BodyBackAttachment")
    if not back then
        -- R6/custom torso fallback: keep the same back origin as before.
        local fallback = Instance.new("Attachment")
        fallback.Name = "BodyBackAttachment"
        fallback.CFrame = CFrame.new(0, 0, torso.Size.Z * 0.5)
        fallback.Parent = torso
    elseif not back:IsA("Attachment") then
        clone:Destroy()
        warnOnce("attachment", "Expected torso BodyBackAttachment to be an Attachment.")
        return nil
    end
    local ok, problem = pcall(function()
        flight.Humanoid:AddAccessory(clone)
    end)
    if not ok then
        clone:Destroy()
        warnOnce("attach", "Could not attach wings: " .. tostring(problem))
        return nil
    end
    flight.Clone, flight.Granted = clone, true
    return clone
end
function Service.PlayerOwns(player: Player, force: boolean?): boolean?
    local state = states[player]
    if not configured or player.Parent ~= Players or not state then
        player:SetAttribute("WingsOwnership", "Unavailable")
        return nil
    end
    if state.Checking then
        state.Recheck = state.Recheck or force == true
        return nil
    end
    if not force and (state.Owned == true or os.clock() < state.NextCheck) then
        return state.Owned
    end
    state.Checking = true
    player:SetAttribute("WingsOwnership", "Loading")
    local ok, owns = pcall(function()
        return Marketplace:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    if states[player] ~= state or player.Parent ~= Players then
        return nil
    end
    state.Checking, state.NextCheck = false, os.clock() + Config.OwnershipRetrySeconds
    state.Owned = if ok and typeof(owns) == "boolean" then owns else nil
    player:SetAttribute(
        "WingsOwnership",
        if state.Owned == true then "Owned" elseif state.Owned == false then "Unowned" else "Unavailable"
    )
    -- Confirmed revocation waits for a sustained landing or respawn. A failed
    -- lookup never yanks an already granted character out of flight.
    if state.Owned == false and state.Flight and state.Flight.State == "Grounded" and groundEvidence(state.Flight) then
        removeWings(state.Flight)
    end
    if not ok then
        warnOnce("marketplace", "Marketplace ownership check failed: " .. tostring(owns))
    end
    if state.Recheck then
        state.Recheck = false
        task.defer(function()
            if states[player] == state and Service.PlayerOwns(player, true) then
                Service.GrantIfOwned(player)
            end
        end)
    end
    return state.Owned
end
function Service.RequestPurchase(player: Player): boolean
    local state = states[player]
    if
        not configured
        or player.Parent ~= Players
        or not state
        or state.Pending
        or state.Checking
        or os.clock() < state.RequestAt
    then
        return false
    end
    state.RequestAt = os.clock() + Config.RequestInterval
    local owns = Service.PlayerOwns(player)
    if states[player] ~= state or player.Parent ~= Players then
        return false
    end
    if owns == true then
        return Service.GrantIfOwned(player) ~= nil
    end
    if owns ~= false then
        return false
    end
    state.Pending = true
    local ok, problem = pcall(function()
        Marketplace:PromptGamePassPurchase(player, passId)
    end)
    if not ok and states[player] == state then
        state.Pending, state.Owned = false, nil
        player:SetAttribute("WingsOwnership", "Unavailable")
        warnOnce("prompt", "Purchase prompt failed: " .. tostring(problem))
    end
    return ok
end
function Service.SetJumpHeld(player: Player, held: any)
    local state = states[player]
    local flight = state and state.Flight
    if typeof(held) ~= "boolean" or not flight or not eligible(player, flight) or held == flight.JumpHeld then
        return
    end
    local wasWingControlled = Service.IsWingControlled(player)
    local wasFallEpisode = flight.FallEpisode
    flight.JumpHeld = held
    if not held then
        if wasWingControlled and wasFallEpisode then
            flight.GraceUntil = os.clock() + Config.GraceSeconds
        else
            flight.GraceUntil = 0
            flight.LandingCandidate = false
        end
        publish(player, flight, if flight.State == "Grounded" then "Grounded" else "Falling")
    else
        flight.GraceUntil = 0
    end
end
function Service.IsWingControlled(player: Player): boolean
    local state = states[player]
    local flight = state and state.Flight
    return flight ~= nil
        and (flight.State == "Powered" or flight.State == "Gliding")
        and flight.JumpHeld
        and eligible(player, flight)
end
function Service.IsGraceActive(player: Player): boolean
    local state = states[player]
    local flight = state and state.Flight
    return flight ~= nil
        and player.Character == flight.Character
        and flight.FallEpisode
        and os.clock() <= flight.GraceUntil
end
-- Explicit coordination with fall damage avoids timers and Heartbeat ordering.
-- Every fall start/reset invalidates evidence, even if wings have not recharged.
function Service.ResetFallEpisode(player: Player, character: Model, airborne: boolean?)
    local state = states[player]
    local flight = state and state.Flight
    if flight and flight.Character == character then
        flight.FallEpisode, flight.LandingCandidate = airborne == true, nil
        flight.GraceUntil = 0
    end
end
function Service.ObserveFallLanding(player: Player, character: Model, candidate: boolean)
    local state = states[player]
    local flight = state and state.Flight
    if not flight or flight.Character ~= character or not flight.FallEpisode then
        return
    end
    local graceActive = Service.IsGraceActive(player)
    if not candidate then
        flight.LandingCandidate = nil
    elseif flight.LandingCandidate == nil then
        flight.LandingCandidate = Service.IsWingControlled(player) or graceActive
    end
    if (not flight.JumpHeld and not graceActive) or not movementAllowed(player, flight) then
        flight.LandingCandidate = false
    end
end
function Service.ConsumeGlideLandingProtection(player: Player, character: Model): boolean
    local state = states[player]
    local flight = state and state.Flight
    if not flight or flight.Character ~= character or player.Character ~= character then
        return false
    end
    local graceActive = Service.IsGraceActive(player)
    local protect = flight.FallEpisode
        and flight.LandingCandidate == true
        and (flight.JumpHeld or graceActive)
        and movementAllowed(player, flight)
    flight.FallEpisode, flight.LandingCandidate = false, nil
    flight.GraceUntil = 0
    return protect
end
function Service.AddPlayer(player: Player)
    if states[player] then
        return
    end
    local state: State =
        { Owned = nil, Checking = false, Recheck = false, NextCheck = 0, Pending = false, RequestAt = 0 }
    states[player] = state
    player:SetAttribute("WingsOwnership", if configured then "Loading" else "Unavailable")
    task.spawn(function()
        if states[player] == state and Service.PlayerOwns(player) then
            Service.GrantIfOwned(player)
        end
    end)
end
function Service.ApplyCharacter(player: Player, character: Model)
    local state = states[player]
    if not state then
        return
    end
    clearCharacter(player, state)
    for _, item in character:GetChildren() do
        if item.Name == "AngelWings" or item.Name == "Angel wings" or item:GetAttribute("WingsAccessory") == true then
            item:Destroy()
        end
    end
    local h = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not h or not root or not root:IsA("BasePart") or player.Character ~= character then
        return
    end
    local flight: Flight = {
        Character = character,
        Humanoid = h,
        Root = root,
        Clone = nil,
        Connections = {},
        Granted = false,
        Energy = Config.FlightDurationSeconds,
        PoweredTime = 0,
        JumpHeld = false,
        GroundedTime = 0,
        State = "", -- First publish must initialize the replicated state.
        FallEpisode = false,
        LandingCandidate = nil,
        GraceUntil = 0,
    }
    state.Flight = flight
    publish(player, flight, if groundEvidence(flight) then "Grounded" else "Airborne")
    table.insert(
        flight.Connections,
        player.CharacterRemoving:Connect(function(old)
            if old == character and state.Flight == flight then
                clearCharacter(player, state)
            end
        end)
    )
    table.insert(
        flight.Connections,
        h.Died:Connect(function()
            if state.Flight == flight then
                clearCharacter(player, state)
            end
        end)
    )
    Service.GrantIfOwned(player) -- Cached session entitlement; never query on respawn.
end
function Service.RemovePlayer(player: Player)
    local state = states[player]
    states[player] = nil -- Invalidate async results before any cleanup.
    if state then
        clearCharacter(player, state)
    end
end
local function step(player: Player, state: State, flight: Flight, dt: number)
    if
        player.Character ~= flight.Character
        or not flight.Root:IsDescendantOf(workspace)
        or flight.Humanoid.Health <= 0
    then
        clearCharacter(player, state)
        return
    end
    if not flight.Granted then
        return
    end
    if not eligible(player, flight) then
        flight.GroundedTime, flight.LandingCandidate = 0, false
        publish(player, flight, "Falling")
        return
    end
    if groundEvidence(flight) then
        -- Provisional pre-touchdown evidence, consumed only if fall damage later
        -- confirms a genuine landing. Its graze/reset callback clears this.
        if flight.FallEpisode and flight.LandingCandidate == nil then
            flight.LandingCandidate = Service.IsWingControlled(player)
        end
        flight.GroundedTime += dt
        -- Stop client lift immediately; recharge still requires sustained support.
        if flight.GroundedTime >= Config.GroundedConfirmSeconds then
            flight.Energy, flight.PoweredTime = Config.FlightDurationSeconds, 0
            publish(player, flight, "Grounded")
            if state.Owned == false then
                removeWings(flight)
            end
        else
            publish(player, flight, "Airborne")
        end
        return
    end
    flight.GroundedTime = 0
    if not flight.JumpHeld then
        publish(
            player,
            flight,
            if flight.State == "Grounded" or flight.State == "Airborne" then "Airborne" else "Falling"
        )
        return
    end
    local target: string
    local poweredDt = 0
    if flight.Energy > 0 and flight.PoweredTime < Config.FlightDurationSeconds + Config.PoweredTimeToleranceSeconds then
        target = "Powered"
        poweredDt = math.min(dt, flight.Energy)
        flight.Energy = math.max(0, flight.Energy - poweredDt)
        if flight.Energy < dt * 1e-6 then
            flight.Energy = 0
        end
        flight.PoweredTime += poweredDt
    else
        target = "Gliding"
    end
    publish(player, flight, if flight.Energy <= 0 then "Gliding" else target)
end
function Service.Init(services)
    deps = services
    if not configured then
        warnOnce("config", "WingsGamePassId invalid; grants and purchases disabled.")
    end
    local request = Instance.new("RemoteEvent")
    request.Name, request.Parent = "WingsRequest", ReplicatedStorage
    request.OnServerEvent:Connect(function(player, action)
        if action == "Purchase" then
            Service.RequestPurchase(player)
        elseif action == "Refresh" then
            local state = states[player]
            if state and player.Parent == Players and os.clock() >= state.RequestAt then
                state.RequestAt = os.clock() + Config.RequestInterval
                if Service.PlayerOwns(player, true) then
                    Service.GrantIfOwned(player)
                end
            end
        end
    end)
    local held = Instance.new("RemoteEvent")
    held.Name, held.Parent = "WingsJumpHeld", ReplicatedStorage
    held.OnServerEvent:Connect(Service.SetJumpHeld)
    Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
        local state = states[player]
        if id ~= passId or not state or player.Parent ~= Players then
            return
        end
        state.Pending = false
        if purchased ~= true then
            return
        end
        task.spawn(function()
            for attempt = 1, 3 do
                if states[player] ~= state or player.Parent ~= Players then
                    return
                end
                if Service.PlayerOwns(player, true) then
                    Service.GrantIfOwned(player)
                    return
                end
                if attempt < 3 then
                    task.wait(attempt * 2)
                end
            end
        end)
    end)
    RunService.Heartbeat:Connect(function(dt)
        for player, state in states do
            if state.Flight then
                step(player, state, state.Flight, dt)
            end
        end
    end)
end
return Service
