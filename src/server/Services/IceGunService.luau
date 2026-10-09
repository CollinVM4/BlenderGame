--!strict
-- Account entitlement and issued Tool lifecycle. No cash ledger or plot-owned grants.
local Players = game:GetService("Players")
local Marketplace = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
local Simulator = require(script.Parent.StudioIceGunEntitlement)
local Service = {}
local lastDiagnostic: { [string]: number } = {}
local function trace(player: Player, stage: string, tool: Tool?)
    if not Config.DebugLogging or not RunService:IsStudio() then
        return
    end
    local key = tostring(player.UserId) .. ":" .. stage
    local now = os.clock()
    if now < (lastDiagnostic[key] or 0) then
        return
    end
    lastDiagnostic[key] = now + 1
    local detail = if tool
        then string.format(
            " issue=%s parent=%s weapon=%s Enabled=%s ManualActivationOnly=%s RequiresHandle=%s",
            tostring(tool:GetAttribute("IceGunIssueId")),
            tostring(tool.Parent),
            tostring(tool:GetAttribute("IceGunWeapon")),
            tostring(tool.Enabled),
            tostring(tool.ManualActivationOnly),
            tostring(tool.RequiresHandle)
        )
        else ""
    warn("[IceGun server] " .. tostring(player.UserId) .. " " .. stage .. detail)
end

local deps: any
local passId = Config.IceGunGamePassId
local configured = passId > 0 and passId == math.floor(passId) and passId < math.huge
type State = {
    Owned: boolean?,
    Checking: boolean,
    Recheck: boolean,
    NextCheck: number,
    Pending: boolean,
    RequestAt: number,
    AutoEquip: boolean?,
}
local states: { [Player]: State } = {}
local nextIssueId = 0
local issued: { [Player]: Tool? } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

local function stateFor(player: Player): State
    local state = states[player]
    if not state then
        state = { Owned = nil, Checking = false, Recheck = false, NextCheck = 0, Pending = false, RequestAt = 0 }
        states[player] = state
    end
    return state
end

function Service.PlayerOwns(player: Player, force: boolean?): boolean?
    if player.Parent ~= Players or not configured then
        player:SetAttribute("IceGunOwnership", "Unavailable")
        return nil
    end
    local state = stateFor(player)
    if Simulator.Supports(player, passId) then
        state.Owned = Simulator.PlayerOwns(player, passId)
        if state.Owned then
            trace(player, "Studio entitlement verified")
        end
        player:SetAttribute("IceGunOwnership", if state.Owned then "Owned" else "Unowned")
        return state.Owned
    end
    if state.Owned == true then
        return true
    end
    if state.Checking then
        state.Recheck = state.Recheck or force == true
        return nil
    end
    if not force and os.clock() < state.NextCheck then
        return state.Owned
    end
    state.Checking = true
    player:SetAttribute("IceGunOwnership", "Loading")
    local ok, owns = pcall(function()
        return Marketplace:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    if states[player] ~= state or player.Parent ~= Players then
        return nil
    end
    state.Checking = false
    state.NextCheck = os.clock() + Config.OwnershipRetrySeconds
    state.Owned = if ok and typeof(owns) == "boolean" then owns else nil
    player:SetAttribute(
        "IceGunOwnership",
        if state.Owned == true then "Owned" elseif state.Owned == false then "Unowned" else "Unavailable"
    )
    if state.Owned == true then
        trace(player, "entitlement verified")
    end
    if not ok then
        warn("[IceGun] Marketplace ownership check failed: " .. tostring(owns))
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

local function removeTool(player: Player)
    local tool = issued[player]
    issued[player] = nil
    player:SetAttribute("IceGunEquipped", false)
    if tool then
        tool:Destroy()
    end
    deps.IceGunProjectileService.ClearPlayer(player)
end

function Service.GrantIfOwned(player: Player): Tool?
    -- Grant is deliberately nonyielding; only a server-confirmed cached entitlement qualifies.
    local state = states[player]
    if not configured or player.Parent ~= Players or not state or state.Owned ~= true then
        return nil
    end
    local character = player.Character
    local h = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not character or not h or h.Health <= 0 or not backpack then
        return nil
    end
    local existing = issued[player]
    if existing and existing.Parent ~= character and existing.Parent ~= backpack then
        removeTool(player)
        existing = nil
    end
    -- Name/attributes never authorize a foreign/legacy copy, even beside an issued one.
    for _, container in { character :: Instance, backpack :: Instance } do
        for _, child in container:GetChildren() do
            if child:IsA("Tool") and child.Name == "IcicleGun" and child ~= existing then
                child:Destroy()
            end
        end
    end
    if existing then
        trace(player, "grant reused issued Tool", existing)
        state.AutoEquip = nil
        return existing
    end
    removeTool(player)
    local weapons = ServerStorage:FindFirstChild("Weapons")
    local template = weapons and weapons:FindFirstChild("IcicleGun")
    if not template or not template:IsA("Tool") then
        warn("[IceGun] Missing sanitized ServerStorage.Weapons.IcicleGun")
        return nil
    end
    local clone = template:Clone()
    clone.CanBeDropped = false
    for _, object in clone:GetDescendants() do
        if object:IsA("BaseScript") or object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
            object:Destroy()
        elseif object:IsA("BasePart") then
            deps.IceGunEffects.Inert(object, false)
        end
    end
    clone:SetAttribute("IceGunWeapon", true)
    nextIssueId += 1
    clone:SetAttribute("IceGunIssueId", nextIssueId) -- Diagnostic correlation only; never authorization.
    issued[player] = clone
    trace(player, "Tool issued and registered", clone)
    clone.AncestryChanged:Connect(function()
        if issued[player] == clone then
            player:SetAttribute("IceGunEquipped", clone.Parent == player.Character)
            if clone.Parent == player.Character then
                trace(player, "Tool equipped (ancestry)", clone)
            end
        end
        task.defer(function()
            if issued[player] == clone and clone.Parent ~= backpack and clone.Parent ~= character then
                trace(player, "issued Tool removed", clone)
                removeTool(player)
            end
        end)
    end)
    clone.Parent = backpack
    trace(player, "Tool granted to Backpack", clone)
    -- Consume the purchase preference once; later grants/refreshes never steal hotbar selection.
    if state.AutoEquip then
        state.AutoEquip = nil
        if deps.MovementService.CanPerformGameplayAction(player) and not h.PlatformStand then
            h:EquipTool(clone)
        end
    end
    return clone
end

function Service.IsEquipped(player: Player): boolean
    local state, tool = states[player], issued[player]
    return configured and state ~= nil and state.Owned == true and tool ~= nil and tool.Parent == player.Character
end

function Service.GetEquipped(player: Player): Tool?
    if Service.IsEquipped(player) then
        return issued[player]
    end
    local state, tool = states[player], issued[player]
    local reason = if not configured
        then "pass unavailable"
        elseif not state or state.Owned ~= true then "entitlement unverified"
        elseif not tool then "no registered Tool"
        else "registered Tool not in current Character"
    trace(player, "fire authorization rejected: " .. reason, tool)
    return nil
end

function Service.RequestEquip(player: Player): boolean
    if not deps.MovementService.CanPerformGameplayAction(player) then
        return false
    end
    local before = issued[player]
    trace(player, "pedestal equip before reconciliation", before)
    local tool = Service.GrantIfOwned(player)
    trace(player, if tool == before then "pedestal reused issued Tool" else "pedestal replaced issued Tool", tool)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not tool or not humanoid then
        return false
    end
    humanoid:EquipTool(tool)
    trace(
        player,
        if Service.IsEquipped(player)
            then "pedestal EquipTool: server equipped"
            else "pedestal EquipTool: server not equipped",
        tool
    )
    return true
end

-- Optional proximity validator belongs to the world entry point, checked again after async ownership.
function Service.RequestPurchase(player: Player, validate: (() -> boolean)?): boolean
    if player.Parent ~= Players or not configured or (validate and not validate()) then
        return false
    end
    local state = stateFor(player)
    if os.clock() < state.RequestAt or state.Pending or state.Checking then
        return false
    end
    state.RequestAt = os.clock() + Config.RequestInterval
    local owns = Service.PlayerOwns(player)
    if states[player] ~= state or player.Parent ~= Players or (validate and not validate()) then
        return false
    end
    if owns == true then
        return Service.RequestEquip(player)
    elseif owns == nil then
        return false
    end
    state.Pending = true
    local ok, problem = pcall(function()
        Marketplace:PromptGamePassPurchase(player, passId)
    end)
    if not ok and states[player] == state then
        state.Pending = false
        state.Owned = nil
        player:SetAttribute("IceGunOwnership", "Unavailable")
        warn("[IceGun] Purchase prompt failed: " .. tostring(problem))
    end
    return ok
end

function Service.AddPlayer(player: Player)
    player:SetAttribute("IceGunOwnership", if configured then "Loading" else "Unavailable")
    task.spawn(function()
        if Service.PlayerOwns(player) then
            Service.GrantIfOwned(player)
        end
    end)
end

function Service.ApplyCharacter(player: Player, character: Model)
    removeTool(player)
    deps.IceGunProjectileService.RemovePlayer(player)
    for _, c in (connections[player] or {}) :: { RBXScriptConnection } do
        c:Disconnect()
    end
    local list: { RBXScriptConnection } = {}
    connections[player] = list
    table.insert(
        list,
        player.CharacterRemoving:Connect(function(old)
            if old == character then
                removeTool(player)
            end
        end)
    )
    table.insert(
        list,
        player.ChildAdded:Connect(function(child)
            if child:IsA("Backpack") then
                Service.GrantIfOwned(player)
            end
        end)
    )
    task.spawn(function()
        local h = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if connections[player] ~= list or player.Character ~= character or not h or not h:IsA("Humanoid") then
            return
        end
        table.insert(
            list,
            h.Died:Connect(function()
                removeTool(player)
            end)
        )
        if Service.PlayerOwns(player) then
            Service.GrantIfOwned(player)
        end
    end)
end

function Service.RemovePlayer(player: Player)
    Simulator.RemovePlayer(player)
    states[player] = nil -- Invalidates outstanding Marketplace results before cleanup.
    removeTool(player)
    for _, c in (connections[player] or {}) :: { RBXScriptConnection } do
        c:Disconnect()
    end
    connections[player] = nil
end

function Service.Init(services)
    deps = services
    if Config.DebugLogging and RunService:IsStudio() then
        warn("[IceGun server] ownership initialized revision=icegun-circle-2026-10-09 module=" .. script:GetFullName())
    end
    if not configured then
        warn("[IceGun] IceGunGamePassId is unconfigured/invalid; purchases and grants disabled.")
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = "IceGunRequest"
    remote.Parent = ReplicatedStorage
    remote.OnServerEvent:Connect(function(player, action)
        if action == "Purchase" or action == "Equip" then
            Service.RequestPurchase(player)
        elseif action == "Refresh" then
            local state = stateFor(player)
            if os.clock() >= state.RequestAt then
                state.RequestAt = os.clock() + Config.RequestInterval
                if Service.PlayerOwns(player) then
                    Service.GrantIfOwned(player)
                end
            end
        end
    end)
    Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
        if id ~= passId or not states[player] or player.Parent ~= Players then
            return
        end
        local state = states[player]
        local pending = state.Pending
        state.Pending = false
        if purchased ~= true then
            return
        end
        if Simulator.Supports(player, id) then
            if pending and Simulator.Complete(player, id) then
                Service.PlayerOwns(player)
                state.AutoEquip = true
                Service.GrantIfOwned(player)
            end
            return
        end
        -- Production: server event is only a reason to recheck; never itself entitlement.
        task.spawn(function()
            for attempt = 1, 3 do
                if player.Parent ~= Players or not states[player] then
                    return
                end
                if Service.PlayerOwns(player, true) then
                    states[player].AutoEquip = true
                    Service.GrantIfOwned(player)
                    return
                end
                if attempt < 3 then
                    task.wait(attempt * 2)
                end
            end
        end)
    end)
end

return Service
