config.StudioGamePassSimulation = false -- Exercise explicit opt-in independently of the developer setting.
deps.IceGunProjectileService = { ClearPlayer = function() end, RemovePlayer = function() end }
local gun = loadModule("IceGunService")
gun.Init(deps)
local owner, h = fighter("A")
local nonowner = fighter("A")
ready(owner)
ready(nonowner)
ownership[owner.UserId] = true
gun.AddPlayer(owner)
gun.AddPlayer(nonowner)
flush()
check(guns(owner) == 1 and guns(nonowner) == 0, "account entitlement never transfers to a teammate")
local foreign = instance("Tool")
foreign.Name, foreign.Parent = "IcicleGun", owner.Character
gun.GrantIfOwned(owner)
check(foreign.Destroyed and guns(owner) == 1, "foreign copies cannot coexist with the one authorized weapon")
local oldCalls = marketplaceCalls
for _ = 1, 10 do
    gun.RequestPurchase(owner)
    gun.GrantIfOwned(owner)
    advance(0.6)
end
check(guns(owner) == 1 and prompts == 0, "existing owner equips one copy without a second purchase")
check(marketplaceCalls == oldCalls, "confirmed ownership is cached")
local near = false
check(not gun.RequestPurchase(nonowner, function()
    return near
end) and prompts == 0, "world entry requires proximity")
near = true
check(gun.RequestPurchase(nonowner, function()
    return near
end) and prompts == 1, "public world point opens official pass prompt")
advance(1)
check(not gun.RequestPurchase(nonowner) and prompts == 1, "concurrent purchase prompts are rejected")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(nonowner, 123, false)
check(guns(nonowner) == 0, "cancel leaves entitlement and weapon unchanged")
check(gun.RequestPurchase(nonowner), "cancel allows retry")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(nonowner, 123, true)
flush()
check(guns(nonowner) == 0, "purchase-finished success is insufficient without verified ownership")
ownership[nonowner.UserId] = true
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(nonowner, 123, true)
flush()
check(guns(nonowner) == 1 and gun.IsEquipped(nonowner), "verified purchase grants and equips the weapon once")
check(gun.RequestEquip(nonowner) and gun.IsEquipped(nonowner), "future shop uses the same equip API")
local oldCharacter = owner.Character
h.Health = 0
h.Died:Fire()
gun.ApplyCharacter(owner, oldCharacter)
flush()
check(guns(owner) == 0, "dead owner cannot receive a gun")
local respawn, respawnHumanoid = fighter("B")
owner.Character = respawn.Character
respawn.Character = nil
h = respawnHumanoid
h.Health = 100
gun.ApplyCharacter(owner, owner.Character)
flush()
check(guns(owner) == 1, "owned access returns after respawn independent of plot")
gun.RemovePlayer(owner)
check(guns(owner) == 0, "departure cleans issued weapon")
gun.AddPlayer(owner)
flush()
check(guns(owner) == 1, "rejoining verifies and restores owned access")
local failed = fighter("C")
ready(failed)
marketplaceFailure = true
gun.AddPlayer(failed)
flush()
check(guns(failed) == 0 and failed:GetAttribute("IceGunOwnership") == "Unavailable", "marketplace errors fail closed")
local beforeRetry = marketplaceCalls
gun.PlayerOwns(failed)
gun.PlayerOwns(failed)
check(marketplaceCalls == beforeRetry, "errors are throttled")
marketplaceFailure = false
advance(config.OwnershipRetrySeconds)
marketplaceHook = function()
    near = false
end
check(not gun.RequestPurchase(failed, function()
    return near
end), "invalid proximity rejected before query")
near = true
check(not gun.RequestPurchase(failed, function()
    return near
end), "proximity rechecked after yielded ownership query")
marketplaceHook = nil
local leaving = fighter("D")
ready(leaving)
ownership[leaving.UserId] = true
marketplaceHook = function()
    gun.RemovePlayer(leaving)
    leaving.Parent = nil
end
check(gun.PlayerOwns(leaving) == nil and guns(leaving) == 0, "departed player cannot receive late entitlement results")
marketplaceHook = nil
local waiting = fighter("E")
ready(waiting)
local beforeConcurrent = marketplaceCalls
marketplaceHook = function()
    coroutine.yield()
end
local thread = coroutine.create(function()
    return gun.PlayerOwns(waiting)
end)
setup(coroutine.resume(thread), "start async ownership")
check(
    gun.PlayerOwns(waiting) == nil and not gun.RequestPurchase(waiting) and marketplaceCalls == beforeConcurrent + 1,
    "concurrent ownership queries and prompts coalesce"
)
marketplaceHook = nil
setup(coroutine.resume(thread), "complete async ownership")
check(
    waiting:GetAttribute("IceGunOwnership") == "Unowned" and guns(waiting) == 0,
    "unconfirmed async query cannot grant"
)
check(config.StudioGamePassSimulation == false, "simulation requires explicit opt-in")
local simulator = loadModule("StudioIceGunEntitlement")
local player1, h1 = fighter("S1")
local player2 = fighter("S2")
player1.UserId, player2.UserId = -1, -2
ready(player1)
ready(player2)
check(not simulator.Supports(player1, 123), "negative IDs cannot simulate without opt-in")
gun.AddPlayer(player1)
flush()
check(not gun.PlayerOwns(player1) and guns(player1) == 0, "disabled simulation uses real entitlement for synthetic IDs")
config.StudioGamePassSimulation = true
studio = false
check(not simulator.Supports(player1, 123), "published servers cannot simulate even with opt-in")
studio = true
check(not simulator.Supports(nonowner, 123), "real accounts cannot simulate")
local realNonowner = fighter("R")
ready(realNonowner)
gun.AddPlayer(realNonowner)
flush()
setup(gun.RequestPurchase(realNonowner), "real nonowner purchase request with development flag enabled")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(realNonowner, 123, true)
flush()
check(
    guns(realNonowner) == 0 and not gun.PlayerOwns(realNonowner),
    "positive IDs still require verified Roblox ownership with opt-in enabled"
)
check(not simulator.Supports(player1, 456), "simulation is scoped to Ice Gun pass")
services.RunService.IsServer = function()
    return false
end
check(not simulator.Supports(player1, 123), "simulation requires server authority")
services.RunService.IsServer = function()
    return true
end
gun.AddPlayer(player1)
gun.AddPlayer(player2)
flush()
check(gun.PlayerOwns(player1) == false and gun.PlayerOwns(player2) == false, "each synthetic player starts unowned")
local beforeSimulation = marketplaceCalls
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player1, 123, true)
check(guns(player1) == 0 and not gun.PlayerOwns(player1), "unsolicited completion cannot simulate ownership")
check(gun.RequestPurchase(player1), "synthetic player opens normal Roblox dialog")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player1, 456, true)
check(guns(player1) == 0, "mismatched pass event cannot grant")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player1, 123, false)
advance(1)
check(not gun.PlayerOwns(player1) and guns(player1) == 0, "canceled simulated purchase stays unowned")
check(gun.RequestPurchase(player1), "synthetic player can retry after cancel")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player1, 123, true)
check(
    gun.PlayerOwns(player1) and guns(player1) == 1 and gun.IsEquipped(player1),
    "successful simulated purchase immediately equips exactly one issued Tool"
)
local boughtTool = gun.GetEquipped(player1)
boughtTool.Parent = player1:FindFirstChildOfClass("Backpack")
boughtTool.AncestryChanged:Fire()
gun.GrantIfOwned(player1)
check(not gun.IsEquipped(player1) and guns(player1) == 1, "repeated grant does not forcibly re-equip")
h1:EquipTool(boughtTool)
check(gun.GetEquipped(player1) == boughtTool, "first hotbar selection authorizes the same issued instance")
check(not gun.PlayerOwns(player2) and guns(player2) == 0, "simulation never transfers between clients")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player1, 123, true)
check(guns(player1) == 1, "replayed completion cannot duplicate weapon")
check(
    gun.RequestEquip(player1) and gun.GetEquipped(player1) ~= nil,
    "simulated owner qualifies for normal firing authorization"
)
check(player1:GetAttribute("IceGunEquipped") == true, "equipped snapshot reflects issued tool")
gun.ApplyCharacter(player1, player1.Character)
flush()
h1.Health = 0
h1.Died:Fire()
check(guns(player1) == 0 and gun.PlayerOwns(player1), "death removes tool without clearing simulated ownership")
local respawn1 = fighter("S1")
player1.Character = respawn1.Character
respawn1.Character = nil
gun.ApplyCharacter(player1, player1.Character)
flush()
check(guns(player1) == 1 and gun.RequestEquip(player1), "respawn restores one usable gun")
advance(1)
check(
    gun.RequestPurchase(player1) and guns(player1) == 1,
    "repeated owned pedestal interaction reuses the issued weapon"
)
gun.ApplyCharacter(player2, player2.Character)
flush()
local missingBackpack = player2:FindFirstChildOfClass("Backpack")
missingBackpack.Parent = nil
check(gun.RequestPurchase(player2), "second synthetic player independently purchases")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player2, 123, true)
check(gun.PlayerOwns(player2) and not gun.IsEquipped(player2), "purchase entitlement survives unavailable Backpack")
missingBackpack.Parent = player2
player2.ChildAdded:Fire(missingBackpack)
check(
    guns(player1) == 1 and guns(player2) == 1 and gun.IsEquipped(player2),
    "deferred purchase grants/equips once when Backpack arrives"
)
check(marketplaceCalls == beforeSimulation, "mock ownership does not require real Marketplace ownership")
gun.RemovePlayer(player1)
gun.AddPlayer(player1)
flush()
check(not gun.PlayerOwns(player1) and guns(player1) == 0, "departing test player loses session entitlement")
cache.StudioIceGunEntitlement = nil
local freshSimulator = loadModule("StudioIceGunEntitlement")
check(not freshSimulator.PlayerOwns(player2, 123), "fresh server module starts with empty simulated state")
config.StudioGamePassSimulation = false
config.IceGunGamePassId = 0
cache.IceGunService = nil
local disabled = loadModule("IceGunService")
disabled.Init(deps)
check(
    disabled.PlayerOwns(nonowner) == nil
        and disabled.GrantIfOwned(nonowner) == nil
        and not disabled.RequestPurchase(nonowner),
    "unconfigured pass cannot grant or prompt"
)
print("PASS: Ice Gun entitlement contracts")
