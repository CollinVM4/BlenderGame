--!strict
local CollectionService = game:GetService("CollectionService")
local WorldUtil = require(script.Parent.WorldUtil)
local TycoonService = {}
local HttpService = game:GetService("HttpService")
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Constants.Upgrades)
local FarmConfig = require(game:GetService("ReplicatedStorage").Shared.Constants.FarmConfig)
local StandIdentity = require(game:GetService("ReplicatedStorage").Shared.Constants.StandIdentity)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type Session =
    Types.PlotSessionState
    & { Plot: Instance, Owner: Player, Teammate: Player?, Busy: boolean, Pending: { () -> () } }
local sessions: { [Instance]: Session } = {}
local byId: { [string]: Session } = {}
local plots: { [Player]: Instance } = {}
local hooks: any = {}
local shared: { [string]: boolean } = {
    FarmRows = true,
    SecondStorage = true,
    Bat = true,
    Jump = true,
    Payout = true,
    MovementSpeed = true,
    SprintStamina = true,
    Hand = true,
    BlendSpeed = true,
}

function TycoonService.Init(callbacks: any)
    hooks = callbacks or {}
end
local function sessionFor(player: Player): Session?
    local plot = plots[player]
    local session = if plot then sessions[plot] else nil
    return if session and session.Status == "Active" and session.Plot:IsDescendantOf(workspace) then session else nil
end
function TycoonService.GetPlot(player: Player): Instance?
    local session = sessionFor(player)
    return if session then session.Plot else nil
end
function TycoonService.GetSessionId(player: Player): string?
    local session = sessionFor(player)
    return if session then session.PlotSessionId else nil
end
function TycoonService.GetSessionOwner(id: string): Player?
    local session = byId[id]
    return if session
            and session.Status == "Active"
            and session.Plot:IsDescendantOf(workspace)
        then session.Owner
        else nil
end
function TycoonService.GetOwner(object: Instance): Player?
    for plot, session in sessions do
        if
            session.Status == "Active"
            and plot:IsDescendantOf(workspace)
            and (object == plot or object:IsDescendantOf(plot))
        then
            return session.Owner
        end
    end
    return nil
end
function TycoonService.IsMember(player: Player, object: Instance): boolean
    local plot = TycoonService.GetPlot(player)
    return plot ~= nil and (object == plot or object:IsDescendantOf(plot))
end
function TycoonService.GetMembers(id: string): { Player }
    local session = byId[id]
    if not session or session.Status ~= "Active" then
        return {}
    end
    return if session.Teammate then { session.Owner, session.Teammate } else { session.Owner }
end
function TycoonService.GetSession(player: Player): Types.PlotSessionState?
    local session = sessionFor(player)
    if not session then
        return nil
    end
    return {
        PlotId = session.PlotId,
        PlotSessionId = session.PlotSessionId,
        OwnerUserId = session.OwnerUserId,
        TeammateUserId = session.TeammateUserId,
        JoinMode = session.JoinMode,
        StandName = session.StandName,
        StandNameRevision = session.StandNameRevision,
        SharedCash = session.SharedCash,
        SharedUpgrades = table.clone(session.SharedUpgrades),
        Status = session.Status,
        MembershipRevision = session.MembershipRevision,
    }
end
function TycoonService.GetRequestContext(player: Player): Types.PlotRequestContext?
    local session = sessionFor(player)
    return if session
        then { PlotSessionId = session.PlotSessionId, MembershipRevision = session.MembershipRevision }
        else nil
end
function TycoonService.ValidateActor(player: Player, context: any): boolean
    local session = sessionFor(player)
    return session ~= nil
        and type(context) == "table"
        and context.PlotSessionId == session.PlotSessionId
        and context.MembershipRevision == session.MembershipRevision
end
-- A synchronous transaction linearizes against reentrant membership changes.
-- Lifecycle requests made by Immediate signals run after the committed transaction.
function TycoonService.BeginTransaction(player: Player, context: any): string?
    local session = sessionFor(player)
    if not session or session.Busy or not TycoonService.ValidateActor(player, context) then
        return nil
    end
    session.Busy = true
    return session.PlotSessionId
end
function TycoonService.EndTransaction(id: string)
    local session = byId[id]
    if not session then
        return
    end
    session.Busy = false
    local pending = session.Pending
    session.Pending = {}
    for _, operation in pending do
        operation()
    end
end
local function publishIdentity(plot: Instance, session: Session?)
    plot:SetAttribute("StandName", if session then session.StandName else nil)
    plot:SetAttribute("StandNameRevision", if session then session.StandNameRevision else nil)
    plot:SetAttribute("PlotOwnerName", if session then session.Owner.Name else nil)
    plot:SetAttribute("PlotTeammateName", if session and session.Teammate then session.Teammate.Name else nil)
    plot:SetAttribute("TeammateUserId", if session then session.TeammateUserId else nil)
    plot:SetAttribute("JoinMode", if session then session.JoinMode else nil)
    plot:SetAttribute("PlotMembershipRevision", if session then session.MembershipRevision else nil)
    plot:SetAttribute("PlotOccupancy", if session then (if session.Teammate then 2 else 1) else 0)
    plot:SetAttribute("PlotCapacity", 2)
end
-- Publish the authoritative tier projection even before a player claims a plot.
-- UI readiness must not depend on membership or optional Tool assets.
function TycoonService.RefreshUpgradeAttributes(player: Player)
    for id in shared do
        local tier = TycoonService.GetUpgrade(player, id)
        player:SetAttribute(id .. "PurchasedLevel", tier - 1)
        player:SetAttribute(id .. "Level", tier - 1)
    end
end
local function publish(session: Session)
    session.Plot:SetAttribute("OwnerUserId", session.OwnerUserId)
    session.Plot:SetAttribute("PlotSessionId", session.PlotSessionId)
    session.Plot:SetAttribute("SecondStoragePurchased", session.SharedUpgrades.SecondStorage == 2)
    publishIdentity(session.Plot, session)
    for _, player in TycoonService.GetMembers(session.PlotSessionId) do
        player:SetAttribute("PlotSessionId", session.PlotSessionId)
        player:SetAttribute("PlotMembershipRevision", session.MembershipRevision)
        player:SetAttribute("playerCash", session.SharedCash)
        TycoonService.RefreshUpgradeAttributes(player)
        if hooks.MemberChanged then
            hooks.MemberChanged(player)
        end
    end
end
function TycoonService.IsSharedUpgrade(id: string): boolean
    return (shared :: any)[id] == true
end
function TycoonService.GetUpgrade(player: Player, id: string): number
    local session = sessionFor(player)
    return if session then session.SharedUpgrades[id] or 1 else 1
end
function TycoonService.GetJumpTier(player: Player): number
    return TycoonService.GetUpgrade(player, "Jump") - 1
end
function TycoonService.GetCash(player: Player): number
    local session = sessionFor(player)
    return if session then session.SharedCash else 0
end
local function validAmount(amount: number): boolean
    return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end
-- Server-only cash operations; network actions must supply a captured context.
function TycoonService.SetCash(player: Player, amount: number): number
    assert(validAmount(amount), "Invalid cash")
    local context = TycoonService.GetRequestContext(player)
    local id = TycoonService.BeginTransaction(player, context)
    if not id then
        return TycoonService.GetCash(player)
    end
    local session = byId[id]
    session.SharedCash = math.floor(amount)
    publish(session)
    TycoonService.EndTransaction(id)
    return session.SharedCash
end
function TycoonService.AddCash(player: Player, amount: number): number
    assert(validAmount(amount), "Invalid award")
    local total = TycoonService.GetCash(player) + amount
    assert(validAmount(total), "Invalid cash")
    return TycoonService.SetCash(player, total)
end
-- Only a service holding the transaction may credit it; never expose to a remote.
function TycoonService.CreditTransaction(id: string, amount: number)
    local session = byId[id]
    assert(session and session.Busy and session.Status == "Active", "No transaction")
    assert(validAmount(amount) and validAmount(session.SharedCash + amount), "Invalid award")
    session.SharedCash = math.floor(session.SharedCash + amount)
    publish(session)
end
-- Server-only loss under the same nonnegative cash policy as SetCash/purchases.
function TycoonService.DebitTransaction(id: string, amount: number)
    local session = byId[id]
    assert(session and session.Busy and session.Status == "Active", "No transaction")
    assert(validAmount(amount), "Invalid debit")
    session.SharedCash = math.max(0, session.SharedCash - math.floor(amount))
    publish(session)
end
function TycoonService.PurchaseUpgrade(
    player: Player,
    id: string,
    expectedTier: number,
    context: any
): (boolean, string?)
    if not TycoonService.IsSharedUpgrade(id) or id == "FarmRows" or id == "SecondStorage" then
        return false, "InvalidUpgrade"
    end
    local token = TycoonService.BeginTransaction(player, context)
    if not token then
        return false, "StaleSession"
    end
    local session = byId[token]
    local nextTier = session.SharedUpgrades[id] + 1
    local definition = (Upgrades :: any)[id][nextTier]
    local reason = if expectedTier ~= nextTier
        then "InvalidLevel"
        elseif not definition then "MaxLevel"
        elseif session.SharedCash < definition.Cost then "InsufficientCash"
        else nil
    if reason then
        TycoonService.EndTransaction(token)
        return false, reason
    end
    session.SharedCash -= definition.Cost
    session.SharedUpgrades[id] = nextTier
    publish(session)
    TycoonService.EndTransaction(token)
    return true
end
-- Farm progression uses the same session cash/upgrade ledger, but only physical
-- farm interactions may commit it. The callback must be synchronous.
function TycoonService.PurchaseFarmRow(player: Player, row: number, context: any, commit: () -> ()): boolean
    local cost = FarmConfig.RowPrices[row]
    if not cost then
        return false
    end
    local token = TycoonService.BeginTransaction(player, context)
    if not token then
        return false
    end
    local session = byId[token]
    if session.SharedUpgrades.FarmRows ~= row or session.SharedCash < cost then
        TycoonService.EndTransaction(token)
        return false
    end
    session.SharedCash -= cost
    session.SharedUpgrades.FarmRows = row + 1
    commit()
    publish(session)
    TycoonService.EndTransaction(token)
    return true
end

-- Server-only physical stash pad transaction; membership is checked against the target plot.
function TycoonService.PurchaseSecondStorage(player: Player, plot: Instance, context: any): boolean
    if not TycoonService.IsMember(player, plot) then
        return false
    end
    local token = TycoonService.BeginTransaction(player, context)
    if not token then
        return false
    end
    local session = byId[token]
    local cost = Upgrades.SecondStorage[2].Cost
    if session.SharedUpgrades.SecondStorage ~= 1 or session.SharedCash < cost then
        TycoonService.EndTransaction(token)
        return false
    end
    session.SharedCash -= cost
    session.SharedUpgrades.SecondStorage = 2
    publish(session)
    TycoonService.EndTransaction(token)
    return true
end

-- Isolated adapter for the still-personal CarryCapacity/StackSize policy.
function TycoonService.PurchasePersonalUpgrade(
    player: Player,
    context: any,
    cost: number,
    commit: () -> ()
): (boolean, string?)
    if not validAmount(cost) then
        return false, "InvalidCost"
    end
    local token = TycoonService.BeginTransaction(player, context)
    if not token then
        return false, "StaleSession"
    end
    local session = byId[token]
    if session.SharedCash < cost then
        TycoonService.EndTransaction(token)
        return false, "InsufficientCash"
    end
    session.SharedCash -= cost
    commit()
    publish(session)
    TycoonService.EndTransaction(token)
    return true
end
-- Trusted server-only membership primitive; public joins must pass RequestJoin policy.
function TycoonService.JoinSession(player: Player, owner: Player, context: any): boolean
    local session = sessionFor(owner)
    if
        not session
        or session.Busy
        or session.Owner ~= owner
        or session.Teammate
        or plots[player]
        or not TycoonService.ValidateActor(owner, context)
    then
        return false
    end
    session.Busy = true
    session.Teammate, session.TeammateUserId = player, player.UserId
    plots[player] = session.Plot
    session.MembershipRevision += 1
    publish(session)
    TycoonService.EndTransaction(session.PlotSessionId)
    return true
end
function TycoonService.RemovePlayer(player: Player, afterTransition: (() -> ())?)
    local plot = plots[player]
    local session = if plot then sessions[plot] else nil
    if not session then
        if afterTransition then
            afterTransition()
        end
        return
    end
    if session.Busy then
        table.insert(session.Pending, function()
            TycoonService.RemovePlayer(player, afterTransition)
        end)
        return
    end
    session.Busy = true
    plots[player] = nil -- revoke authority before any cleanup or projection signals
    session.MembershipRevision += 1
    local remaining = if session.Owner == player then session.Teammate else session.Owner
    if remaining then
        session.Owner, session.OwnerUserId = remaining, remaining.UserId
        session.Teammate, session.TeammateUserId = nil, nil
    else
        session.Status = "Closing" -- invalidate first, clean once, release last
    end
    player:SetAttribute("PlotSessionId", nil)
    player:SetAttribute("PlotMembershipRevision", nil)
    player:SetAttribute("playerCash", 0)
    for upgrade in shared do
        player:SetAttribute(upgrade .. "PurchasedLevel", 0)
        player:SetAttribute(upgrade .. "Level", 0)
    end
    if hooks.MemberRemoved then
        hooks.MemberRemoved(player)
    end
    if remaining then
        publish(session)
        TycoonService.EndTransaction(session.PlotSessionId)
    else
        if hooks.SessionEnded then
            hooks.SessionEnded(session.PlotSessionId)
        end
        session.Status = "Closed"
        sessions[session.Plot], byId[session.PlotSessionId] = nil, nil
        session.Plot:SetAttribute("SecondStoragePurchased", false)
        session.Plot:SetAttribute("OwnerUserId", nil)
        session.Plot:SetAttribute("PlotSessionId", nil)
        publishIdentity(session.Plot, nil)
        session.Plot:SetAttribute(
            "PlotClaimRevision",
            ((session.Plot:GetAttribute("PlotClaimRevision") or 0) :: number) + 1
        )
    end
    if afterTransition then
        afterTransition()
    end
end
function TycoonService.Kick(owner: Player, teammate: Player, context: any): boolean
    local session = sessionFor(owner)
    if
        not session
        or session.Owner ~= owner
        or session.Teammate ~= teammate
        or not TycoonService.ValidateActor(owner, context)
    then
        return false
    end
    if session.Busy then
        table.insert(session.Pending, function()
            TycoonService.Kick(owner, teammate, context)
        end)
    else
        TycoonService.RemovePlayer(teammate)
    end
    return true
end
function TycoonService.GetFixtures(plot: Instance, role: string): { Instance }
    local fixtures = {}
    for _, object in CollectionService:GetTagged(role) do
        if object:IsDescendantOf(plot) then
            table.insert(fixtures, object)
        end
    end
    return fixtures
end

-- Compatibility runs before binding. An explicitly tagged role always wins over old names.
function TycoonService.AutoTagLegacyPlot(plot: Instance)
    CollectionService:AddTag(plot, "PlayerPlot")
    if plot:GetAttribute("PlotClaimRevision") == nil then
        plot:SetAttribute("PlotClaimRevision", 0)
    end
    if plot:GetAttribute("PlotId") == nil then
        plot:SetAttribute("PlotId", HttpService:GenerateGUID(false))
    end
    if not sessions[plot] then
        plot:SetAttribute("SecondStoragePurchased", false)
        plot:SetAttribute("OwnerUserId", nil)
        plot:SetAttribute("PlotSessionId", nil)
        publishIdentity(plot, nil)
    end
    for _, role in
        {
            "BlenderInput",
            "BlenderVacuum",
            "IngredientSpawn",
            "DispenseButton",
            "CustomerSpawn",
            "CustomerCounter",
            "CustomerWait1",
            "CustomerWait2",
            "CustomerExit",
            "CustomerThiefPoint",
            "StartDayButton",
            "PlayerStash",
            "TurbineWheel",
        }
    do
        if #TycoonService.GetFixtures(plot, role) == 0 then
            local object = plot:FindFirstChild(role, true)
            if not object and role == "PlayerStash" then
                object = plot:FindFirstChild("Stash")
            end
            if not object and role == "TurbineWheel" then
                local turbine = plot:FindFirstChild("Turbine", true)
                object = turbine
                    and (
                        turbine:FindFirstChild("blade", true)
                        or turbine:FindFirstChild("stem", true)
                        or WorldUtil.Part(turbine)
                    )
            end
            if object then
                CollectionService:AddTag(object, role)
            end
        end
    end
end

local customerRoles = {
    CustomerSpawn = true,
    CustomerCounter = true,
    CustomerWait1 = true,
    CustomerWait2 = true,
    CustomerExit = true,
    CustomerThiefPoint = true,
}

-- Customer destinations must be explicit markers, never an arbitrary part of a tagged area.
-- Prefer tagged parts over legacy tagged containers so tagging the actual marker repairs
-- an old area-level tag without making the reference ambiguous.
local function customerReference(fixtures: { Instance }, name: string): (BasePart?, string?)
    local markers: { BasePart } = {}
    for _, fixture in fixtures do
        if fixture:IsA("BasePart") then
            table.insert(markers, fixture)
        end
    end
    if #markers == 0 then
        for _, fixture in fixtures do
            local parts: { BasePart } = {}
            local named: { BasePart } = {}
            for _, child in fixture:GetDescendants() do
                if child:IsA("BasePart") then
                    table.insert(parts, child)
                    if child.Name == name then
                        table.insert(named, child)
                    end
                end
            end
            local marker = if #named == 1 then named[1] elseif #parts == 1 then parts[1] else nil
            if not marker then
                return nil,
                    "Tag the " .. name .. " marker BasePart itself; ambiguous/empty container " .. fixture:GetFullName()
            end
            if not table.find(markers, marker) then
                table.insert(markers, marker)
            end
        end
    end
    if #markers ~= 1 then
        local paths = {}
        for _, fixture in fixtures do
            table.insert(paths, fixture:GetFullName())
        end
        return nil,
            string.format(
                "%s: expected one marker, found %d; tagged objects=[%s]",
                name,
                #markers,
                table.concat(paths, ", ")
            )
    end
    local marker = markers[1]
    if
        CollectionService:HasTag(marker, "StartDayButton")
        or marker.Name == "StartDayButton"
        or marker:FindFirstChild("StartDayPrompt")
    then
        return nil,
            name .. " resolves to Start Day button " .. marker:GetFullName() .. "; tag a separate customer marker"
    end
    return marker
end

function TycoonService.GetReference(player: Player, name: string): (BasePart?, string?)
    local plot = TycoonService.GetPlot(player)
    if not plot then
        return nil, "No assigned plot"
    end
    local fixtures = TycoonService.GetFixtures(plot, name)
    if (customerRoles :: any)[name] then
        return customerReference(fixtures, name)
    end
    if #fixtures ~= 1 then
        return nil
    end
    local fixture = fixtures[1]
    if (name == "BlenderInput" or name == "BlenderVacuum") and not fixture:IsA("BasePart") then
        return nil
    end
    local part = WorldUtil.Part(fixture)
    if part and (part == fixture or part:IsDescendantOf(fixture)) then
        return part
    end
    return nil
end
-- Shared stable order for arrival routing and trusted automatic assignment.
function TycoonService.GetOrderedPlots(): { Instance }
    local candidates = CollectionService:GetTagged("PlayerPlot")
    local folder = workspace:FindFirstChild("Plots")
    if folder then
        for _, plot in folder:GetChildren() do
            if not table.find(candidates, plot) then
                table.insert(candidates, plot)
            end
        end
    end
    table.sort(candidates, function(a, b)
        local ao, bo = a:GetAttribute("SpawnOrder"), b:GetAttribute("SpawnOrder")
        if type(ao) == "number" and type(bo) == "number" and ao ~= bo then
            return ao < bo
        elseif type(ao) == "number" and type(bo) ~= "number" then
            return true
        elseif type(bo) == "number" and type(ao) ~= "number" then
            return false
        end
        return a:GetFullName() < b:GetFullName()
    end)
    return candidates
end
function TycoonService.IsPlotAvailable(plot: Instance): boolean
    return plot:IsDescendantOf(workspace) and sessions[plot] == nil
end
-- Trusted compatibility API. Runtime arrivals never call this; claims select an exact plot.
function TycoonService.AssignPlot(player: Player, requestedPlot: Instance?): Instance?
    if TycoonService.GetPlot(player) then
        return plots[player]
    end
    if plots[player] then
        TycoonService.RemovePlayer(player)
        if plots[player] then
            return nil
        end
    end
    local candidates = TycoonService.GetOrderedPlots()
    for _, plot in candidates do
        if not CollectionService:HasTag(plot, "PlayerPlot") then
            TycoonService.AutoTagLegacyPlot(plot)
        end
    end
    for _, plot in candidates do
        if plot:IsDescendantOf(workspace) and not sessions[plot] and (not requestedPlot or plot == requestedPlot) then
            plots[player] = plot
            local id = HttpService:GenerateGUID(false)
            local authoredId = plot:GetAttribute("PlotId")
            local plotId = if type(authoredId) == "string" then authoredId else HttpService:GenerateGUID(false)
            plot:SetAttribute("PlotId", plotId)
            local upgrades: { [string]: number } = {}
            for upgrade in shared do
                upgrades[upgrade] = 1
            end
            local session: Session = {
                Plot = plot,
                PlotId = plotId,
                PlotSessionId = id,
                Owner = player,
                OwnerUserId = player.UserId,
                Teammate = nil,
                TeammateUserId = nil,
                JoinMode = "Open",
                -- DisplayName is platform moderated; custom submissions use StandIdentityService.
                StandName = StandIdentity.DefaultName(player.DisplayName or player.Name),
                StandNameRevision = 1,
                SharedCash = 0,
                SharedUpgrades = upgrades,
                Status = "Active",
                MembershipRevision = 1,
                Busy = true,
                Pending = {},
            }
            sessions[plot], byId[id] = session, session
            publish(session)
            local ok, started = true, nil
            if hooks.SessionStarted then
                ok, started = pcall(hooks.SessionStarted, player)
            end
            TycoonService.EndTransaction(id)
            if not ok or started == false then
                warn("[TycoonService] Session initialization failed session=" .. id .. " reason=" .. tostring(started))
                if TycoonService.GetSessionId(player) == id then
                    TycoonService.RemovePlayer(player)
                end
                return nil
            end
            return if TycoonService.GetSessionId(player) == id then plot else nil
        end
    end
    warn("[TycoonService] No free PlayerPlot / workspace.Plots child for " .. player.Name)
    return nil
end
-- Requests retain the submitted context across any yielding friendship lookup.
function TycoonService.ClaimPlot(player: Player, plot: Instance, context: any): boolean
    if
        plots[player]
        or not CollectionService:HasTag(plot, "PlayerPlot")
        or not plot:IsDescendantOf(workspace)
        or sessions[plot]
        or type(context) ~= "table"
        or context.PlotSessionId ~= nil
        or context.ClaimRevision ~= (plot:GetAttribute("PlotClaimRevision") or 0)
    then
        return false
    end
    return TycoonService.AssignPlot(player, plot) == plot
end
function TycoonService.RequestJoin(player: Player, plot: Instance, context: any): boolean
    local session = sessions[plot]
    if
        not session
        or session.Status ~= "Active"
        or session.Busy
        or plots[player]
        or session.Teammate
        or not TycoonService.ValidateActor(session.Owner, context)
    then
        return false
    end
    local owner = session.Owner
    if session.JoinMode == "Closed" then
        return false
    elseif session.JoinMode == "FriendsOnly" then
        local ok, friend = pcall(function()
            return player:IsFriendsWithAsync(owner.UserId)
        end)
        if not ok or not friend then
            return false
        end
    end
    -- Joining can yield above: never substitute a newer session, owner, or revision.
    if sessions[plot] ~= session or session.Owner ~= owner or player.Parent == nil then
        return false
    end
    return TycoonService.JoinSession(player, owner, context)
end
function TycoonService.SetJoinMode(player: Player, mode: any, context: any): boolean
    local session = sessionFor(player)
    if
        not session
        or session.Owner ~= player
        or session.Busy
        or not TycoonService.ValidateActor(player, context)
        or (mode ~= "Open" and mode ~= "FriendsOnly" and mode ~= "Closed")
    then
        return false
    end
    session.Busy = true
    session.JoinMode = mode
    session.MembershipRevision += 1
    publish(session)
    TycoonService.EndTransaction(session.PlotSessionId)
    return true
end
-- TODO(Settings): Expose teammate access in Settings > Stand.
-- Planned policies: Anyone / FriendsOnly. Access checks stay server-authoritative
-- in RequestJoin; this adapter retains the existing Open wire value.
function TycoonService.SetTeammateAccess(player: Player, mode: string, context: any): boolean
    return TycoonService.SetJoinMode(player, if mode == "Anyone" then "Open" else mode, context)
end

-- Trusted server-only commit. Never expose this method directly to a remote.
function TycoonService.CommitFilteredStandName(player: Player, plot: Instance, text: string, context: any): boolean
    local session = sessionFor(player)
    if
        not session
        or session.Owner ~= player
        or session.Plot ~= plot
        or type(context) ~= "table"
        or context.StandNameRevision ~= session.StandNameRevision
    then
        return false
    end
    local id = TycoonService.BeginTransaction(player, context)
    if not id then
        return false
    end
    session.StandName = text
    session.StandNameRevision += 1
    publishIdentity(plot, session)
    TycoonService.EndTransaction(id)
    return true
end
function TycoonService.LeaveTeam(player: Player, context: any): boolean
    local session = sessionFor(player)
    if
        not session
        or session.Teammate ~= player
        or session.Busy
        or not TycoonService.ValidateActor(player, context)
    then
        return false
    end
    TycoonService.RemovePlayer(player)
    return true
end
return require(script.Parent.StudioServices).Wrap("TycoonService", TycoonService)
