--!strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.LockBaseConfig)
local FloorButton = require(script.Parent.RejectFloorButton)
local Collision = require(script.Parent.LockBaseCollision)
local Presentation = require(script.Parent.LockBasePresentation)
local Service = {}
local authority: any
local states: { [Instance]: any } = {}
local initialized = false

local function diagnostic(state: any, event: string, player: Player?, accepted: boolean?, reason: string?)
    if workspace:GetAttribute("LockBaseDiagnostics") ~= true then
        return
    end
    print(
        string.format(
            "[LockBase] event=%s plot=%s player=%s member=%s locked=%s remaining=%d accepted=%s reason=%s",
            event,
            state.Plot:GetFullName(),
            if player then player.Name else "-",
            tostring(player ~= nil and authority.IsMember(player, state.Plot)),
            tostring(state.Deadline > workspace:GetServerTimeNow()),
            math.max(0, math.ceil(state.Deadline - workspace:GetServerTimeNow())),
            tostring(accepted),
            reason or "-"
        )
    )
end

-- Keep the lookup shared with the inspector; LockButton may itself be a Part.
function Service.ResolveAssets(plot: Instance): any
    local lock = if plot.Name == "LockBase" then plot else plot:FindFirstChild("LockBase", true)
    local assembly = lock and lock:FindFirstChild("LockButton")
    local button = assembly and assembly:FindFirstChild("Button")
    local attachment = assembly and assembly:FindFirstChild("LockAttachment", true)
    local visual = assembly and assembly:FindFirstChild("Visual")
    return {
        Lock = lock,
        Assembly = assembly,
        Button = if button and button:IsA("BasePart") then button else nil,
        Attachment = if attachment and attachment:IsA("Attachment") then attachment else nil,
        Visual = if visual and visual:IsA("Model") then visual else nil,
    }
end

-- Use Reject's unchanged exact support rule first. Only a sibling support plate
-- gets a fallback, and that still requires a downward hit on Button itself.
function Service.CheckStanding(player: Player, plot: Instance): (boolean, string)
    local assets = if states[plot] and states[plot].Assets then states[plot].Assets else Service.ResolveAssets(plot)
    local button: BasePart? = assets.Button
    if not button or not button:IsDescendantOf(plot) or not button:IsDescendantOf(workspace) then
        return false, "MissingButton"
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
        return false, "NoLiveCharacter"
    end
    if root.AssemblyLinearVelocity.Y > 2 then
        return false, "Ascending"
    end
    if FloorButton.IsStanding(player, button) then
        return true, "ButtonSupport"
    end
    local leg = character:FindFirstChild("Left Leg")
    local legHeight = if leg and leg:IsA("BasePart") then leg.Size.Y else 0
    local direction = Vector3.new(0, -(root.Size.Y / 2 + humanoid.HipHeight + legHeight + 0.5), 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.RespectCanCollide = true
    local hit = workspace:Raycast(root.Position, direction, params)
    if not hit then
        return false, "NoSupport"
    end
    local blackBase = assets.Assembly and assets.Assembly:FindFirstChild("BlackBase")
    local decorative = hit.Instance == assets.Assembly
        or hit.Instance == blackBase
        or (blackBase ~= nil and hit.Instance:IsDescendantOf(blackBase))
    if not decorative then
        return false, "Support=" .. hit.Instance:GetFullName()
    end
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { button }
    local plate = workspace:Raycast(root.Position, direction, params)
    return plate ~= nil and plate.Instance == button,
        if plate and plate.Instance == button then "ButtonOverSupport" else "OutsideButton"
end

-- Tagged walls can be below LockBase or elsewhere in this plot's Walls hierarchy.
-- An explicit association handles unnamed sibling walls without taking over helpers.
function Service.DiscoverWalls(plot: Instance, lock: Instance?): { BasePart }
    local walls = {}
    local assembly = lock and lock:FindFirstChild("LockButton")
    local visual = assembly and assembly:FindFirstChild("Visual")
    local button = assembly and assembly:FindFirstChild("Button")
    local base = assembly and assembly:FindFirstChild("BlackBase")
    for _, part in CollectionService:GetTagged("PlayerOnlyCollision") do
        if
            not part:IsA("BasePart")
            or not part:IsDescendantOf(plot)
            or part == button
            or part == base
            or part == assembly
            or (base and part:IsDescendantOf(base))
            or (visual and part:IsDescendantOf(visual))
        then
            continue
        end
        local associated = (lock ~= nil and part:IsDescendantOf(lock)) or part:GetAttribute("LockBaseWall") == true
        local ancestor: Instance? = part
        while ancestor and ancestor ~= plot do
            if ancestor.Name == "Walls" or ancestor.Name == "Wall" then
                associated = true
            end
            ancestor = ancestor.Parent
        end
        if associated then
            table.insert(walls, part)
        end
    end
    return walls
end

local function members(state: any): { Player }
    return if state.SessionId then authority.GetMembers(state.SessionId) else {}
end
local function publish(state: any)
    state.Plot:SetAttribute("LockBaseSessionId", state.SessionId)
    state.Plot:SetAttribute("LockBaseLockedUntil", state.Deadline)
    state.Plot:SetAttribute("LockBaseLocked", state.Deadline > workspace:GetServerTimeNow())
end
local function unlock(state: any, immediate: boolean?)
    local wasLocked = state.Deadline > 0
    state.Deadline = 0
    state.NextLockAt = workspace:GetServerTimeNow() + Config.RelockCooldown
    if state.Collision then
        state.Collision.SetLocked(false, {})
    end
    if state.Presentation then
        state.Presentation.SetLocked(false, immediate)
    end
    publish(state)
    if wasLocked then
        diagnostic(state, "unlock", nil, true, if immediate then "LifecycleReset" else "Expired")
    end
end
local function refreshState(state: any)
    local owner = authority.GetOwner(state.Plot)
    local id = if owner then authority.GetSessionId(owner) else nil
    if owner ~= state.Owner or id ~= state.SessionId then
        unlock(state, true)
        state.Owner, state.SessionId = owner, id
        state.Latched = {}
        -- Claim/handoff placement is not a fresh button entry. Every member must
        -- first be observed off the plate before standing can activate security.
        for _, member in members(state) do
            state.Latched[member] = true
        end
        state.NextLockAt = 0
        publish(state)
    end
    if state.Collision then
        state.Collision.Refresh(members(state))
    end
    if state.Presentation then
        state.Presentation.Update(owner ~= nil, state.Deadline, workspace:GetServerTimeNow())
    end
end
local function lockFor(state: any, duration: number): boolean
    refreshState(state)
    local now = workspace:GetServerTimeNow()
    if not state.Owner or state.Deadline > now or now < state.NextLockAt then
        return false
    end
    state.Deadline = now + duration
    if state.Collision then
        state.Collision.SetLocked(true, members(state))
    end
    if state.Presentation then
        state.Presentation.SetLocked(true)
        state.Presentation.Update(true, state.Deadline, now)
    end
    publish(state)
    diagnostic(state, "lock", nil, true, "Manual")
    return true
end

local function bindAssets(state: any)
    local previousVisual = state.Assets and state.Assets.Visual
    if state.TouchConnection then
        state.TouchConnection:Disconnect()
        state.TouchConnection = nil
    end
    if state.TouchEndConnection then
        state.TouchEndConnection:Disconnect()
        state.TouchEndConnection = nil
    end
    state.Contacts = {}
    if state.Collision then
        state.Collision.Destroy()
    end
    if state.Presentation then
        state.Presentation.Destroy()
    end
    local plot = state.Plot
    local assets = Service.ResolveAssets(plot)
    state.Assets = assets
    local lock = assets.Lock
    state.Button = assets.Button
    local origin, model = assets.Attachment, assets.Visual
    local walls = Service.DiscoverWalls(plot, lock)
    local missing = {}
    if not lock then
        table.insert(missing, "LockBase")
    end
    if not state.Button then
        table.insert(missing, "LockButton.Button BasePart")
    end
    if not origin then
        table.insert(missing, "LockAttachment Attachment")
    end
    if not model then
        table.insert(missing, "LockButton.Visual Model")
    end
    if #walls == 0 then
        table.insert(missing, "associated PlayerOnlyCollision walls (under LockBase/Walls, or LockBaseWall=true)")
    end
    if model then
        for _, name in { "Laser", "LaserBase" } do
            local found = model:FindFirstChild(name, true)
            if not found or not found:IsA("BasePart") then
                table.insert(missing, "Visual." .. name .. " BaseParts")
            end
        end
    end
    local missingSummary = table.concat(missing, ", ")
    if missingSummary ~= "" and missingSummary ~= state.Diagnostic then
        warn("[LockBase] " .. plot:GetFullName() .. " missing: " .. missingSummary)
    end
    state.Diagnostic = missingSummary
    -- Hide the authored active geometry before setting up any physical helpers.
    state.Presentation = Presentation.Bind(state.Button, origin, model)
    state.Collision = Collision.Bind(plot, walls)
    state.Collision.SetLocked(state.Deadline > workspace:GetServerTimeNow(), members(state))
    local active = state.Deadline > workspace:GetServerTimeNow()
    state.Presentation.SetLocked(active, not active or previousVisual == model)
    state.Presentation.Update(state.Owner ~= nil, state.Deadline, workspace:GetServerTimeNow())
    state.Dirty = false
    plot:SetAttribute(
        "LockBaseAssetsReady",
        state.Button ~= nil
            and model ~= nil
            and origin ~= nil
            and origin.Parent ~= nil
            and origin.Parent:IsA("BasePart")
            and #walls > 0
    )
    if state.Button then
        local function actor(part: BasePart): Player?
            local ancestor: Instance? = part.Parent
            while ancestor and ancestor ~= workspace do
                if ancestor:IsA("Model") then
                    local player = Players:GetPlayerFromCharacter(ancestor)
                    if player then
                        return player
                    end
                end
                ancestor = ancestor.Parent
            end
            return nil
        end
        state.TouchConnection = state.Button.Touched:Connect(function(part)
            if workspace:GetAttribute("LockBaseDiagnostics") ~= true then
                return
            end
            local player = actor(part)
            if not player then
                return
            end
            local contacts = state.Contacts[player]
            if not contacts then
                contacts = {}
                state.Contacts[player] = contacts
                -- Touch never activates gameplay; standing is checked separately.
                local reason = if not authority.GetOwner(plot)
                    then "Unclaimed"
                    elseif not authority.IsMember(player, plot) then "NotMember"
                    elseif state.Deadline > workspace:GetServerTimeNow() then "AlreadyLocked"
                    else "AwaitStandingCheck"
                diagnostic(state, "contact", player, false, reason)
            end
            contacts[part] = true
        end)
        state.TouchEndConnection = state.Button.TouchEnded:Connect(function(part)
            local player = actor(part)
            local contacts = player and state.Contacts[player]
            if contacts then
                contacts[part] = nil
                if next(contacts) == nil then
                    state.Contacts[player] = nil
                end
            end
        end)
    end
    if workspace:GetAttribute("LockBaseDiagnostics") == true then
        print(
            "[LockBase] event=bind plot=" .. plot:GetFullName() .. " walls=" .. #walls .. " missing=" .. missingSummary
        )
    end
end
local function bindPlot(plot: Instance)
    if states[plot] or not plot:IsDescendantOf(workspace) then
        return
    end
    local state: any = { Plot = plot, Deadline = 0, NextLockAt = 0, Latched = {}, Connections = {} }
    states[plot] = state
    refreshState(state)
    bindAssets(state)
    local function changed(instance: Instance)
        if
            instance.Name == "LockBase"
            or instance.Name == "LockButton"
            or instance.Name == "Button"
            or instance.Name == "LockAttachment"
            or instance.Name == "Visual"
            or instance.Name == "Laser"
            or instance.Name == "LaserBase"
            or CollectionService:HasTag(instance, "PlayerOnlyCollision")
        then
            state.Dirty = true
        end
    end
    table.insert(state.Connections, plot.DescendantAdded:Connect(changed))
    table.insert(state.Connections, plot.DescendantRemoving:Connect(changed))
end

function Service.RefreshMembership()
    if not authority then
        return
    end
    for _, state in states do
        refreshState(state)
    end
end
function Service.ApplyCharacter(player: Player, _character: Model)
    Service.RefreshMembership()
    local plot = authority.GetPlot(player)
    if plot and states[plot] then
        states[plot].Latched[player] = true
    end
end
function Service.RemoveCharacter(player: Player)
    for _, state in states do
        if state.Collision then
            local remaining = members(state)
            local index = table.find(remaining, player)
            if index then
                table.remove(remaining, index)
            end
            state.Collision.Refresh(remaining)
        end
        state.Latched[player] = nil
        if state.Contacts then
            state.Contacts[player] = nil
        end
        if state.Support then
            state.Support[player] = nil
        end
    end
end
function Service.StartSession(player: Player)
    local plot = authority.GetPlot(player)
    if not plot then
        return
    end
    bindPlot(plot)
    -- Keep the lifecycle API, but a claim only binds the unlocked presentation.
    refreshState(states[plot])
    for _, member in members(states[plot]) do
        states[plot].Latched[member] = true
    end
end
function Service.CleanupSession(id: string)
    for _, state in states do
        if state.SessionId == id then
            unlock(state, true)
            state.Owner, state.SessionId = nil, nil
            state.Latched = {}
            publish(state)
            state.Presentation.Update(false, 0, workspace:GetServerTimeNow())
        end
    end
end
function Service.IsLocked(object: Instance): boolean
    local owner = authority and authority.GetOwner(object)
    local plot = if owner then authority.GetPlot(owner) else nil
    local state = if plot then states[plot] else nil
    return state ~= nil
        and state.Owner == owner
        and state.SessionId == authority.GetSessionId(owner)
        and state.Deadline > workspace:GetServerTimeNow()
end
-- Server-only physical interaction: no client timer, target, or activation remote.
function Service.Activate(player: Player, plot: Instance): boolean
    local state = states[plot]
    if not state then
        return false
    end
    local reason: string? = nil
    if not plot:IsDescendantOf(workspace) then
        reason = "PlotRemoved"
    elseif not authority.GetOwner(plot) then
        reason = "Unclaimed"
    elseif not authority.IsMember(player, plot) then
        reason = "NotMember"
    else
        local standing, support = Service.CheckStanding(player, plot)
        if not standing then
            reason = support
        end
    end
    if reason then
        diagnostic(state, "activate", player, false, reason)
        return false
    end
    if lockFor(state, Config.ManualLockDuration) then
        state.Presentation.Press()
        diagnostic(state, "activate", player, true, "Manual")
        return true
    end
    diagnostic(
        state,
        "activate",
        player,
        false,
        if state.Deadline > workspace:GetServerTimeNow() then "AlreadyLocked" else "Cooldown"
    )
    return false
end
function Service.Init(services: any)
    if initialized then
        return
    end
    initialized = true
    authority = services.TycoonService
    for _, plot in authority.GetOrderedPlots() do
        bindPlot(plot)
    end
    workspace:SetAttribute("LockBaseInitialized", true)
    CollectionService:GetInstanceAddedSignal("PlayerPlot"):Connect(bindPlot)
    for _, tag in { "PlayerOnlyCollision" } do
        local function dirty(instance: Instance)
            for plot, state in states do
                if instance:IsDescendantOf(plot) then
                    state.Dirty = true
                end
            end
        end
        CollectionService:GetInstanceAddedSignal(tag):Connect(dirty)
        CollectionService:GetInstanceRemovedSignal(tag):Connect(dirty)
    end
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.05 then
            return
        end
        elapsed = 0
        local now = workspace:GetServerTimeNow()
        for plot, state in states do
            if not plot:IsDescendantOf(workspace) or not CollectionService:HasTag(plot, "PlayerPlot") then
                unlock(state, true)
                state.Collision.Destroy()
                state.Presentation.Destroy()
                if state.TouchConnection then
                    state.TouchConnection:Disconnect()
                end
                if state.TouchEndConnection then
                    state.TouchEndConnection:Disconnect()
                end
                for _, connection in state.Connections do
                    connection:Disconnect()
                end
                states[plot] = nil
                continue
            end
            if state.Dirty then
                bindAssets(state)
            end
            if state.Deadline > 0 and state.Deadline <= now then
                unlock(state)
            end
            state.Presentation.Update(state.Owner ~= nil, state.Deadline, now)
            if state.Button then
                local current = members(state)
                for player in state.Latched do
                    if not table.find(current, player) then
                        state.Latched[player] = nil
                    end
                end
                for _, player in current do
                    local standing, support = Service.CheckStanding(player, plot)
                    if workspace:GetAttribute("LockBaseDiagnostics") == true then
                        state.Support = state.Support or {}
                        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if
                            root
                            and root:IsA("BasePart")
                            and (root.Position - state.Button.Position).Magnitude <= 12
                            and state.Support[player] ~= support
                        then
                            state.Support[player] = support
                            diagnostic(state, "support", player, standing, support)
                        end
                    end
                    if not standing then
                        state.Latched[player] = nil
                    elseif not state.Latched[player] then
                        -- Contacts during an active lock also require stepping off.
                        state.Latched[player] = true
                        Service.Activate(player, plot)
                    end
                end
            end
        end
    end)
end

return Service
