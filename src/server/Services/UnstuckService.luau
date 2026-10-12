--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.UnstuckConfig)
local Policy = require(script.Parent.UnstuckPolicy)
local Placement = require(script.Parent.UnstuckPlacement)
local getEvent = require(Shared.Events.UnstuckEvents)
local Service = {}
local deps: any
local started = false
type Watch = {
    Character: Model,
    RecentUntil: number,
    RecoveryAt: number,
    Anchor: Vector3?,
    StillAt: number,
    IntentUntil: number,
    LastRequest: number,
    Eligible: boolean,
    PlotContext: any,
}
local watches: { [Player]: Watch } = {}
local cooldowns: { [Player]: number } = {}
local function publish(player: Player, watch: Watch, eligible: boolean)
    watch.Eligible = eligible
    player:SetAttribute("UnstuckEligible", eligible)
end
local function currentMembership(player: Player, watch: Watch): boolean
    if watch.PlotContext then
        return deps.TycoonService.ValidateActor(player, watch.PlotContext)
    end
    return deps.TycoonService.GetRequestContext(player) == nil
end
local function inspect(player: Player, watch: Watch, now: number): (boolean, Humanoid?, BasePart?)
    local character = watch.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local part = character:FindFirstChild("HumanoidRootPart")
    local root = if part and part:IsA("BasePart") then part else nil
    if
        not currentMembership(player, watch)
        or player.Character ~= character
        or not character:IsDescendantOf(workspace)
        or not humanoid
        or not root
        or humanoid.Health <= 0
        or root.Anchored
        or humanoid.Sit
    then
        return false, humanoid, root
    end
    local speed = root.AssemblyLinearVelocity.Magnitude
    if
        not watch.Anchor
        or (root.Position - watch.Anchor).Magnitude > Config.MaxDisplacement
        or speed > Config.MaxSpeed
    then
        watch.Anchor = root.Position
        watch.StillAt = now
    end
    local locked = deps.MovementService.IsMovementLocked(player)
    local mode = humanoid:GetState()
    local obstructed = false
    if not locked and now - watch.StillAt >= Config.ObserveSeconds then
        local overlap = OverlapParams.new()
        overlap.FilterDescendantsInstances = { character }
        overlap.RespectCanCollide = true
        overlap.CollisionGroup = root.CollisionGroup
        -- Exact geometry overlap, paired with movement intent or abnormal state.
        for _, body in character:GetChildren() do
            if
                body:IsA("BasePart")
                and (body.CanCollide or body == root)
                and #workspace:GetPartsInPart(body, overlap) > 0
            then
                obstructed = true
                break
            end
        end
    end
    local abnormal = humanoid.PlatformStand
        or deps.RagdollService.IsRagdolled(character)
        or (obstructed and (mode == Enum.HumanoidStateType.Physics or mode == Enum.HumanoidStateType.GettingUp))
    return Policy.Eligible({
        Recent = now <= watch.RecentUntil,
        Alive = humanoid.Health > 0,
        Locked = locked,
        Cooldown = now < (cooldowns[player] or 0),
        StationarySeconds = now - watch.StillAt,
        RecoverySeconds = now - watch.RecoveryAt,
        Intent = now < watch.IntentUntil,
        Obstructed = obstructed,
        Abnormal = abnormal,
    }),
        humanoid,
        root
end
function Service.RemovePlayer(player: Player)
    watches[player] = nil
    cooldowns[player] = nil
    player:SetAttribute("UnstuckWatching", false)
    player:SetAttribute("UnstuckEligible", false)
end
function Service.Request(player: Player): boolean
    local watch = watches[player]
    local now = os.clock()
    if not watch or now - watch.LastRequest < Config.RequestIntervalSeconds then
        return false
    end
    watch.LastRequest = now
    local eligible, humanoid, root = inspect(player, watch, now)
    if not eligible or not humanoid or not root then
        publish(player, watch, false)
        return false
    end
    -- Find and validate before mutating anything. No client destination is accepted.
    local destination = Placement.Find(watch.Character, humanoid, root)
    local feedback = "Unstuck!"
    if not destination then
        local spawnPivot, plot = deps.InitialSpawnService.GetAssignedSpawn(player)
        if spawnPivot and plot == deps.TycoonService.GetPlot(player) then
            local spawnRoot = spawnPivot * watch.Character:GetPivot():ToObjectSpace(root.CFrame)
            if Placement.IsUsable(watch.Character, root, spawnRoot) then
                destination = spawnRoot
                feedback = "Returned to your plot!"
            end
        end
    end
    if not destination then
        getEvent():FireClient(player, "Unable to find a safe recovery position.")
        return false
    end
    -- Placement and spawn resolution are nonyielding; recheck session/character
    -- before changing physics in case an authority callback invalidated the request.
    if
        player.Character ~= watch.Character
        or not currentMembership(player, watch)
        or humanoid.Health <= 0
        or deps.MovementService.IsMovementLocked(player)
    then
        publish(player, watch, false)
        return false
    end
    if not root:CanSetNetworkOwnership() then
        return false
    end
    local automatic = root:GetNetworkOwnershipAuto()
    local owner = root:GetNetworkOwner()
    root:SetNetworkOwner(nil)
    local function restoreOwnership()
        if player.Character == watch.Character and root:IsDescendantOf(workspace) and not root.Anchored then
            if automatic then
                root:SetNetworkOwnershipAuto()
            else
                root:SetNetworkOwner(owner)
            end
        end
    end
    if not deps.RagdollService.RecoverCharacter(watch.Character) then
        restoreOwnership()
        return false
    end
    if
        player.Character ~= watch.Character
        or not currentMembership(player, watch)
        or humanoid.Health <= 0
        or deps.MovementService.IsMovementLocked(player)
    then
        restoreOwnership()
        publish(player, watch, false)
        return false
    end
    task.delay(0.2, restoreOwnership)
    -- All operations below are nonyielding. Move the complete model, including carried items.
    watch.Character:PivotTo(destination * root.CFrame:Inverse() * watch.Character:GetPivot())
    for _, part in watch.Character:GetDescendants() do
        if part:IsA("BasePart") then
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    deps.FallDamageService.NotifyRecoveryTeleport(player, watch.Character)
    humanoid.PlatformStand = false
    humanoid.AutoRotate = true
    deps.MovementService.RefreshPlayer(player)
    deps.SprintService.ApplySpeed(player)
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    cooldowns[player] = now + Config.CooldownSeconds
    watch.Anchor = root.Position
    watch.StillAt = now
    publish(player, watch, false)
    getEvent():FireClient(player, feedback, watch.Character)
    return true
end
function Service.Init(dependencies)
    if started then
        return
    end
    started = true
    deps = dependencies
    deps.RagdollService.Changed:Connect(function(character: Model, active: boolean)
        local player = Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end
        local now = os.clock()
        if active then
            watches[player] = {
                Character = character,
                RecentUntil = now + Config.RecentSeconds,
                RecoveryAt = now,
                Anchor = nil,
                StillAt = now,
                IntentUntil = 0,
                LastRequest = -math.huge,
                Eligible = false,
                PlotContext = deps.TycoonService.GetRequestContext(player),
            }
            player:SetAttribute("UnstuckEligible", false)
            player:SetAttribute("UnstuckWatching", true)
        else
            local watch = watches[player]
            if watch and watch.Character == character then
                watch.RecoveryAt = now
                watch.StillAt = now
                watch.Anchor = nil
            end
        end
    end)
    getEvent().OnServerEvent:Connect(function(player: Player, action: any)
        local watch = watches[player]
        if type(action) == "boolean" then
            if watch then
                watch.IntentUntil = if action then os.clock() + Config.IntentExpirySeconds else 0
            end
        elseif action == "Recover" then
            Service.Request(player)
        end
    end)
    Players.PlayerRemoving:Connect(Service.RemovePlayer)
    task.spawn(function()
        while true do
            task.wait(Config.SampleSeconds)
            local now = os.clock()
            -- Only recently ragdolled characters are watched; never scan every player each frame.
            for player, watch in watches do
                if player.Character ~= watch.Character or now > watch.RecentUntil or player.Parent ~= Players then
                    watches[player] = nil
                    player:SetAttribute("UnstuckWatching", false)
                    player:SetAttribute("UnstuckEligible", false)
                else
                    local eligible = inspect(player, watch, now)
                    publish(player, watch, eligible)
                end
            end
        end
    end)
end
return Service
