-- Exercise production bootstrap wiring; engine and unrelated services are doubles.
local noop = function() end
local unrelated = {
    "AdminService",
    "AnnouncementService",
    "DiscoveryService",
    "RagdollService",
    "FallDamageService",
    "HealthRegenService",
    "CharacterPhysicsService",
    "SprintService",
    "PlayerHeadDropService",
    "MarketService",
    "DevContentService",
    "GameplayService",
    "FreezeStatusService",
    "IceGunProjectileService",
    "IceGunService",
    "IceGunEffects",
    "FilmingUtil",
    "GameplaySfxService",
    "PlayerOnlyCollisionService",
    "StashExpansionService",
    "JackedNoobService",
    "StandIdentityService",
    "PlotClaimZones",
}
for _, name in unrelated do
    cache[name] = setmetatable({}, {
        __index = function()
            return noop
        end,
    })
end
local added, removed = {}, {}
services.CollectionService.GetInstanceAddedSignal = function(_, tag)
    added[tag] = added[tag] or signal()
    return added[tag]
end
services.CollectionService.GetInstanceRemovedSignal = function(_, tag)
    removed[tag] = removed[tag] or signal()
    return removed[tag]
end
local addTag = services.CollectionService.AddTag
services.CollectionService.AddTag = function(self, object, tag)
    local exists = self:HasTag(object, tag)
    addTag(self, object, tag)
    if not exists and added[tag] then
        added[tag]:Fire(object)
    end
end
workspaceFake.GetDescendants = function()
    local result = {}
    for _, object in allInstances do
        if object:IsDescendantOf(workspaceFake) then
            table.insert(result, object)
        end
    end
    return result
end
workspaceFake.DescendantAdded = signal()
cache.WorldUtil.BindTag = function(tag, bind)
    for _, object in services.CollectionService:GetTagged(tag) do
        bind(object)
    end
    services.CollectionService:GetInstanceAddedSignal(tag):Connect(bind)
end
-- Stash rendering has a separate presentation suite. Keep its replicated state
-- and prompt binding real here, with cosmetic geometry isolated at the boundary.
cache.StashPresentation = {
    Refresh = function(base, state)
        base:SetAttribute("StashCount", if state then state.Count else 0)
        base:SetAttribute("StashValue", if state then state.Value else 0)
    end,
    Clear = noop,
}
local pad = part("EquipmentSpawner", workspaceFake)
services.CollectionService:AddTag(pad, "IceGunPurchaseDisplay")
setup(storage:FindFirstChild("Weapons") == nil, "reproduce missing Weapons import")
env.Enum.KeyCode = { E = "E", ButtonX = "ButtonX" }
env.Enum.ProximityPromptExclusivity = { OneGlobally = "OneGlobally" }
cache.StudioServices.BeginBootstrap = noop
local runtime
cache.StudioServices.Publish = function(value)
    runtime = value
end
local originalInstance = instance
instance = function(class)
    local object = originalInstance(class)
    local signals = {}
    object.GetAttributeChangedSignal = function(_, key)
        signals[key] = signals[key] or signal()
        return signals[key]
    end
    local setAttribute = object.SetAttribute
    object.SetAttribute = function(self, key, value)
        local previous = self:GetAttribute(key)
        setAttribute(self, key, value)
        if previous ~= value and signals[key] then
            signals[key]:Fire()
        end
    end
    return object
end
env.Instance.new = instance
local listed = {}
services.Players.GetPlayers = function()
    return listed
end
services.Players.PlayerAdded, services.Players.PlayerRemoving = signal(), signal()
shared.TutorialTargets = "TutorialTargets"
env.Enum.HumanoidStateType = { Climbing = "Climbing" }
env.Random = {
    new = function()
        return {
            NextInteger = function(_, low)
                return low
            end,
        }
    end,
}
workspaceFake.Gravity = 196.2
local p = player()
local authoredPlot = dependency.TycoonService.GetPlot(p)
dependency.TycoonService.RemovePlayer(p)
local bootstrap = assert(loadstring(sources.ServerBootstrap, "ServerBootstrap"))
local bootstrapEnv = setmetatable({
    script = {
        Services = parent,
        Admin = parent,
        Components = setmetatable({}, {
            __index = function(_, name)
                if name == "IceGunDisplay" then
                    return "IceGunDisplayComponent"
                end
                if name == "Stash" then
                    return "StashComponent"
                end
                local key = "BootstrapComponent" .. name
                cache[key] = { Init = noop }
                return key
            end,
        }),
    },
}, { __index = env })
setfenv(bootstrap, bootstrapEnv)
bootstrap()
setup(runtime, "bootstrap published services")
setup(
    runtime.TycoonService.ClaimPlot(p, authoredPlot, { ClaimRevision = authoredPlot:GetAttribute("PlotClaimRevision") }),
    "claim after bootstrap"
)
check(slot(p, 3).Count == 3, "production claim seeds starter inventory")
check(
    fixtures[p]:FindFirstChild("Slot3"):FindFirstChild("StashPrompt") ~= nil,
    "missing display assets cannot abort stash prompt binding"
)
check(fixtures[p]:FindFirstChild("Slot3"):GetAttribute("StashCount") == 3, "starter stash replicated after claim")

local tycoon = runtime.TycoonService
local plot = tycoon.GetPlot(p)
tycoon.RemovePlayer(p)
inventory.RemovePlayer(p)
setup(
    tycoon.ClaimPlot(p, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") }),
    "claim before player stash setup"
)
check(slot(p, 3).Count == 3, "claim prepares stash before player setup")
inventory.AddPlayer(p)
check(slot(p, 3).Count == 3, "late player setup preserves committed starters")

local orders = loadModule("TutorialOrders")
local function verifyStarters(actor)
    local snapshot = inventory.GetSnapshot(actor)
    check(snapshot.Layout.Slots == 5, "five starting slots")
    check(snapshot.Stash[1].Count == 0 and snapshot.Stash[2].Count == 0, "protected slots empty")
    check(snapshot.Stash[1].Capacity == 1 and snapshot.Stash[2].Capacity == 1, "protected capacity stays one")
    local total = 0
    for _, order in orders do
        local state = snapshot.Stash[order.Slot]
        total += state.Count
        check(state.Count == 3, "three records per starter group")
        local expectedValue = 0
        for index, id in order.Ingredients do
            local unit = state.Ingredients[index]
            expectedValue += ingredients.GetDefinition(id).Value
            check(unit.IngredientId == id and unit.ItemId ~= nil and not unit.IsRipe, "exact fresh normal unit")
        end
        check(state.Value == expectedValue, "normal stash value")
    end
    check(total == 9 and inventory.GetCarryCount(actor) == 0, "nine stored ingredients, no carried grants")
end
verifyStarters(p)
check(next(dataService.GetDiscoveryState(p).Ingredients) == nil, "seeding does not discover ingredients")
local itemId = slot(p, 3).Ingredients[1].ItemId
inventory.InitializeTutorialStash(p)
check(slot(p, 3).Ingredients[1].ItemId == itemId, "duplicate callback preserves item identity")
check(not tycoon.ClaimPlot(p, plot, { ClaimRevision = 0 }), "duplicate claim rejected")
setup(inventory.InteractStash(p, 3, p, nil, "TAKE"), "normal stash TAKE")
check(inventory.GetCarryCount(p) == 1 and slot(p, 3).Count == 2, "TAKE uses authoritative ledger")
itemId = slot(p, 3).Ingredients[1].ItemId
inventory.InitializeTutorialStash(p)
check(slot(p, 3).Count == 2, "withdrawal is never replenished")
p.Parent = services.Players
p.Character.Parent = workspaceFake
p.Character.WaitForChild = p.Character.FindFirstChild
p.CharacterAdded = signal()
p.ChildAdded = signal()
services.Players.PlayerAdded:Fire(p)
p.CharacterAdded:Fire(p.Character)
flush()
check(slot(p, 3).Count == 2 and slot(p, 3).Ingredients[1].ItemId == itemId, "respawn preserves remaining stash")
local peer = player()
tycoon.RemovePlayer(peer)
setup(tycoon.JoinSession(peer, p, tycoon.GetRequestContext(p)), "teammate joins existing tutorial")
inventory.InitializeTutorialStash(peer)
check(slot(p, 3).Count == 2, "join cannot seed another set")
local session = tycoon.GetSessionId(p)
tycoon.RemovePlayer(p, function()
    inventory.RemovePlayer(p)
end)
check(tycoon.GetSessionId(peer) == session and slot(peer, 3).Count == 2, "owner departure preserves session stash")
check(slot(peer, 3).Ingredients[1].ItemId == itemId, "promotion retains exact inventory records")
local beforeCleanup = slot(peer, 4).Ingredients[1].ItemId
ingredients.ClearLooseIngredients()
check(slot(peer, 4).Ingredients[1].ItemId == beforeCleanup, "loose cleanup cannot remove stash records")
tycoon.RemovePlayer(peer)
check(slot(peer, 3).Count == 0 and slot(peer, 4).Count == 0, "release clears session inventory")
setup(
    tycoon.ClaimPlot(peer, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") }),
    "fresh claim after release"
)
verifyStarters(peer)
check(slot(peer, 3).Ingredients[1].ItemId ~= itemId, "fresh session has fresh units")
tycoon.RemovePlayer(peer)
local generate = services.HttpService.GenerateGUID
local attempts = 0
services.HttpService.GenerateGUID = function(...)
    attempts += 1
    if attempts == 5 then
        error("temporary item preparation failure")
    end
    return generate(...)
end
check(
    not tycoon.ClaimPlot(peer, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") }),
    "failed seed rejects claim"
)
check(tycoon.GetSessionId(peer) == nil and tycoon.IsPlotAvailable(plot), "failed initialization releases session lock")
check(
    slot(peer, 3).Count == 0 and slot(peer, 4).Count == 0 and slot(peer, 5).Count == 0,
    "preparation failure commits no partial rewards"
)
services.HttpService.GenerateGUID = generate
setup(
    tycoon.ClaimPlot(peer, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") }),
    "retry after preparation recovery"
)
verifyStarters(peer)
-- Departure requested by an immediate inventory signal is serialized after claim.
tycoon.RemovePlayer(peer)
local departure = inventory.StashChanged:Connect(function(actor)
    if actor == peer and tycoon.GetSessionId(peer) then
        tycoon.RemovePlayer(peer)
    end
end)
check(
    not tycoon.ClaimPlot(peer, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") }),
    "departure during initialization does not report a live claim"
)
departure:Disconnect()
check(tycoon.GetSessionId(peer) == nil and slot(peer, 3).Count == 0, "departure clears session-specific starter state")
