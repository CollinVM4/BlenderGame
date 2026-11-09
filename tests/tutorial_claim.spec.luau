-- Exercise production bootstrap wiring; engine and unrelated services are doubles.
local noop = function() end
local unrelated = {
    "AdminService",
    "FarmService",
    "LockBaseService",
    "UnstuckService",
    "CashBoostService",
    "WingsService",
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
    "ScrapbookPreviewAssets",
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

local itemId = slot(p, 1).Ingredients[1].ItemId
inventory.InitializeTutorialStash(p)
check(slot(p, 1).Ingredients[1].ItemId == itemId, "bootstrap retry preserves loaded inventory")
