--!strict
-- Live entitlement, airborne budget and registered accessory lifecycle.
local Players = game:GetService("Players")
local Marketplace = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Constants.WingsConfig)
local Ownership = require(script.Parent.BatKnockback)
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
    Release: (() -> ())?,
    Granted: boolean,
    Energy: number,
    PoweredTime: number,
    JumpHeld: boolean,
    GroundedTime: number,
    State: string,
    Overspeed: number,
    InvalidGlide: boolean,
    -- FallDamageService owns the episode and genuine landing boundary. This
    -- candidate is captured there before either service can publish Grounded.
    FallEpisode: boolean,
    LandingCandidate: boolean?,
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
    flight.State = value
    player:SetAttribute("WingState", value)
    if value ~= "Powered" and value ~= "Gliding" and flight.Release then
        flight.Release()
        flight.Release = nil
    end
end
local function clearCharacter(player: Player, state: State)
    local flight = state.Flight
    state.Flight = nil
    if not flight then
        return
    end
    if flight.Release then
        flight.Release()
    end
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
        then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
            item.Massless, item.Anchored = true, false
        end
    end
    local handle = clone:FindFirstChild("Handle")
    local attachment = handle and handle:FindFirstChild("BodyBackAttachment")
    if not handle or not handle:IsA("BasePart") or not attachment or not attachment:IsA("Attachment") then
        clone:Destroy()
        warnOnce("structure", "Expected supplied single Handle / BodyBackAttachment accessory.")
        return nil
    end
    local back = torso:FindFirstChild("BodyBackAttachment")
    local origin = if back and back:IsA("Attachment") then back.CFrame else CFrame.new(0, 0, torso.Size.Z * 0.5)
    local motor = Instance.new("Motor6D")
    motor.Name, motor.Part0, motor.Part1 = "WingMotor", torso, handle
    motor.C0, motor.C1 = origin, attachment.CFrame
    motor:SetAttribute("WingRestC0", origin)
    motor.Parent = handle
    handle.CFrame = torso.CFrame * motor.C0 * motor.C1:Inverse()
    flight.Clone, flight.Granted = clone, true
    clone.Parent = flight.Character
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
    flight.JumpHeld = held
    if not held then
        flight.LandingCandidate = false
        publish(player, flight, if flight.State == "Grounded" then "Grounded" else "Falling")
    end
end
function Service.IsGliding(player: Player): boolean
    local state = states[player]
    local flight = state and state.Flight
    return flight ~= nil
        and flight.State == "Gliding"
        and flight.JumpHeld
        and not flight.InvalidGlide
        and eligible(player, flight)
end
-- Explicit coordination with fall damage avoids timers and Heartbeat ordering.
-- Every fall start/reset invalidates evidence, even if wings have not recharged.
function Service.ResetFallEpisode(player: Player, character: Model, airborne: boolean?)
    local state = states[player]
    local flight = state and state.Flight
    if flight and flight.Character == character then
        flight.FallEpisode, flight.LandingCandidate = airborne == true, nil
    end
end
function Service.ObserveFallLanding(player: Player, character: Model, candidate: boolean)
    local state = states[player]
    local flight = state and state.Flight
    if not flight or flight.Character ~= character or not flight.FallEpisode then
        return
    end
    if not candidate then
        flight.LandingCandidate = nil
    elseif flight.LandingCandidate == nil then
        flight.LandingCandidate = Service.IsGliding(player)
    end
    if not flight.JumpHeld or not movementAllowed(player, flight) or flight.InvalidGlide then
        flight.LandingCandidate = false
    end
end
function Service.ConsumeGlideLandingProtection(player: Player, character: Model): boolean
    local state = states[player]
    local flight = state and state.Flight
    if not flight or flight.Character ~= character or player.Character ~= character then
        return false
    end
    local protect = flight.FallEpisode
        and flight.LandingCandidate == true
        and flight.JumpHeld
        and not flight.InvalidGlide
        and movementAllowed(player, flight)
    flight.FallEpisode, flight.LandingCandidate = false, nil
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
        Release = nil,
        Granted = false,
        Energy = Config.FlightDurationSeconds,
        PoweredTime = 0,
        JumpHeld = false,
        GroundedTime = 0,
        State = "Airborne",
        Overspeed = 0,
        InvalidGlide = false,
        FallEpisode = false,
        LandingCandidate = nil,
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
            flight.LandingCandidate = Service.IsGliding(player)
        end
        flight.GroundedTime += dt
        -- Do not apply airborne lift during the confirmation interval.
        if flight.Release then
            flight.Release()
            flight.Release = nil
        end
        if flight.GroundedTime >= Config.GroundedConfirmSeconds then
            flight.Energy, flight.PoweredTime, flight.Overspeed = Config.FlightDurationSeconds, 0, 0
            flight.InvalidGlide = false
            publish(player, flight, "Grounded")
            if state.Owned == false then
                removeWings(flight)
            end
        end
        return
    end
    flight.GroundedTime = 0
    if not flight.JumpHeld or flight.InvalidGlide then
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
    local velocity = flight.Root.AssemblyLinearVelocity
    if target == "Gliding" and velocity.Y < -(Config.GlideDescentVelocity + Config.GlideOverspeedTolerance) then
        flight.Overspeed += dt
        if flight.Overspeed > Config.GlideOverspeedSeconds then
            flight.InvalidGlide, flight.LandingCandidate = true, false
            publish(player, flight, "Falling")
            return
        end
    else
        flight.Overspeed = 0
    end
    -- Same channel as bat launch: borrow server simulation before writing Y,
    -- restore the previous network policy immediately on exit/cancel/cleanup.
    if not flight.Release then
        local ok, release = pcall(Ownership.TakeOwnership, flight.Root)
        if ok then
            flight.Release = release
        else
            warnOnce("ownership", "Could not borrow server simulation: " .. tostring(release))
        end
    end
    if not flight.Release then
        publish(player, flight, "Falling")
        return
    end
    local y = velocity.Y
    if target == "Powered" and y < Config.PoweredAscentVelocity then
        y = math.min(Config.PoweredAscentVelocity, y + Config.PoweredApproachAccel * poweredDt)
    elseif target == "Gliding" and y < -Config.GlideDescentVelocity then
        y = -Config.GlideDescentVelocity
    end
    flight.Root.AssemblyLinearVelocity = Vector3.new(velocity.X, y, velocity.Z)
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
