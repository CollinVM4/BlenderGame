local p, h, root = subject(false)
check(p:GetAttribute("WingsOwnership") == "Unowned", "join publishes verified unowned state")
check(wings.RequestPurchase(p) and prompts == 1, "unowned request opens server game-pass prompt")
check(not wings.RequestPurchase(p) and prompts == 1, "duplicate/pending purchase is rate limited")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p, 2021642550, false)
flush()
check(not p.Character:FindFirstChild("AngelWings"), "cancel grants nothing")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p, 2021642550, true)
flush()
check(not p.Character:FindFirstChild("AngelWings"), "finished event alone is never entitlement")
ownership[p.UserId] = true
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p, 2021642550, true)
flush()
check(
    p.Character:FindFirstChild("AngelWings") ~= nil and p:GetAttribute("WingsOwnership") == "Owned",
    "confirmed recheck grants without rejoin"
)
now += 1
check(wings.RequestPurchase(p) and prompts == 1, "owned Buy reconciles grant without prompting")
local calls = marketplaceCalls
local oldCharacter, oldWings = p.Character, p.Character:FindFirstChild("AngelWings")
p.CharacterRemoving:Fire(oldCharacter)
check(oldWings.Destroyed, "character removal destroys registered wings")
p.Character = oldCharacter -- Fresh application models respawn without querying Marketplace.
wings.ApplyCharacter(p, p.Character)
check(
    p.Character:FindFirstChild("AngelWings") ~= nil and marketplaceCalls == calls,
    "respawn grants from session cache without ownership query"
)
wings.SetJumpHeld(p, true)
fly(p, h, root, 1.7)
check(state(p) == "Powered", "new character starts with full powered budget")
ownership[p.UserId] = false
wings.PlayerOwns(p, true)
check(p.Character:FindFirstChild("AngelWings") ~= nil, "confirmed revocation preserves airborne wings")
for _ = 1, 9 do
    tick(p, h, root, 0.025, 0, true)
end
check(not p.Character:FindFirstChild("AngelWings"), "confirmed revocation removes on sustained landing")
marketplaceFailure = true
local u = subject(false)
check(u:GetAttribute("WingsOwnership") == "Unavailable", "failed lookup is unavailable rather than unowned")
check(not wings.RequestPurchase(u), "failed lookup cannot prompt or grant")
marketplaceFailure = false
now += 16
check(wings.PlayerOwns(u) == false, "unavailable ownership retries after configured delay")
local v = subject(false)
ownership[v.UserId] = true
marketplaceHook = function()
    wings.RemovePlayer(v)
end
check(wings.PlayerOwns(v, true) == nil, "removed session rejects late positive entitlement")
marketplaceHook = nil
check(not v.Character:FindFirstChild("AngelWings"), "removed state invalidates outstanding Marketplace results")
local d, dh = subject(true)
local clone = d.Character:FindFirstChild("AngelWings")
dh.Health = 0
dh.Died:Fire()
check(clone.Destroyed and not wings.IsGliding(d), "death clears wings and flight immediately")

local failurePlayer = subject(false)
marketplaceFailure = true
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(failurePlayer, 2021642550, true)
flush()
check(
    failurePlayer:GetAttribute("WingsOwnership") == "Unavailable"
        and not failurePlayer.Character:FindFirstChild("AngelWings"),
    "purchase-finished with failed recheck grants nothing"
)
marketplaceFailure = false
local promptPlayer = subject(false)
promptFailure = true
check(
    not wings.RequestPurchase(promptPlayer) and promptPlayer:GetAttribute("WingsOwnership") == "Unavailable",
    "failed purchase prompt fails closed"
)
promptFailure = false
