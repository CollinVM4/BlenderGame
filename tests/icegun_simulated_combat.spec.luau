config.StudioGamePassSimulation = true
studio = true
services.RunService.IsRunning = function()
    return true
end
loadModule("StudioServices").BeginBootstrap()
local realFighter = fighter
fighter = function(session)
    local player, humanoid = realFighter(session)
    player.UserId = -player.UserId
    return player, humanoid
end
services.MarketplaceService.UserOwnsGamePassAsync = function()
    error("simulated owner must use the entitlement provider")
end
local realFlush = flush
local bought = false
flush = function()
    realFlush()
    if not bought then
        bought = true
        local gun = loadModule("IceGunService")
        local player = roster[1]
        setup(gun.RequestPurchase(player), "pending simulated purchase")
        services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 123, true)
        setup(
            guns(player) == 1 and gun.IsEquipped(player),
            "simulation equips the normal weapon without a second pedestal interaction"
        )
    end
end
