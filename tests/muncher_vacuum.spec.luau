-- Real inventory, registry, plot authority and conversion; only engine geometry/motion is doubled.
local rolls = 0
env.Random = {
    new = function()
        return {
            NextNumber = function()
                rolls += 1
                return 0
            end,
        }
    end,
}
workspaceFake.Gravity = 196.2
local config = loadModule("Muncher")
local muncher = loadModule("MuncherService")
local eligibility = loadModule("MuncherWorldInput")
local vacuum = loadModule("MuncherVacuum")
local physics = loadModule("BlenderVacuumPhysics")
local output = loadModule("MuncherOutput")
dependency.MuncherService = muncher
muncher.Init(dependency)
output.Placement = function()
    return frame(0, 3, 0), vec(0, 0, 0)
end
local owner = player(3)
local authority = dependency.TycoonService
local plot = authority.GetPlot(owner)
local model = instance("Model")
model.Name, model.Parent = "Muncher", plot
local input, pad = part("InputZone", model), part("PurchasePoint1", model)
input.Position, input.CFrame = vec(0, 4, 0), frame(0, 4, 0)
local candidates = {}
local queries = 0
workspaceFake.GetPartBoundsInRadius = function(_, position, radius, params)
    check(
        (radius == config.Vacuum.Radius or radius == config.Vacuum.OverlapTolerance)
            and params.MaxParts == config.Vacuum.MaxParts,
        "bounded local query"
    )
    queries += 1
    return candidates
end
local update, stop = vacuum.Bind(dependency, input, model)
local function physical(object, at)
    local root = cache.WorldUtil.Part(object)
    root.Position, root.CFrame = at or vec(4, 4, 0), frame(at or vec(4, 4, 0))
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    root.GetConnectedParts = function()
        return {}
    end
    return object, root
end
local function loose(actor, at, options)
    options = options or {}
    if actor then
        options.FeedingActor = actor
        options.FeedingSessionId = authority.GetSessionId(actor)
    end
    return physical(ingredients.Spawn("Apple", frame(), nil, true, options), at)
end
local function finish()
    now += config.ChewSeconds
    muncher.Step()
    now += config.SpitSeconds
end
local outputs = {}
local realSpawn = ingredients.Spawn
ingredients.Spawn = function(id, at, who, claimable, options)
    local object = realSpawn(id, at, who, claimable, options)
    if options and options.MuncherImmune then
        table.insert(outputs, object)
    end
    return object
end
muncher.Reset(owner)
local apple, root = loose(owner)
candidates = { apple }
update(0.1)
check(root.AssemblyLinearVelocity.Magnitude == 0 and queries == 0, "locked machine cannot attract")
authority.SetCash(owner, config.PurchaseCost)
setup(muncher.TryPurchase(owner, pad, nil), "buy Muncher")
update(0.1)
check(root.AssemblyLinearVelocity.Magnitude == 0 and not muncher.CanVacuum(owner, input), "reveal cannot attract")
now += config.RevealSeconds
setup(muncher.CompleteReveal(owner, model), "complete reveal")
update(1 / 60)
check(
    root.AssemblyLinearVelocity.X < 0 and ingredients.GetRecord(apple) ~= nil and rolls == 0,
    "authorized loose ingredient visibly steers without premature consumption or reveal"
)
check(root.Position.X == 4, "vacuum changes velocity rather than teleporting")
local extra = loose(owner, vec(3, 4, 0))
root.Position = vec(0.5, 4, 0)
owner.Near = false
update(1 / 60)
check(
    ingredients.GetRecord(apple) == nil and rolls == 1 and muncher.GetSnapshot(owner).Phase == "Processing",
    "mouth threshold commits once without needing E or actor proximity"
)
owner.Near = true
candidates = { extra }
local extraRoot = cache.WorldUtil.Part(extra)
local before = extraRoot.AssemblyLinearVelocity
extraRoot.Position = vec(0.5, 4, 0)
update(0.1)
check(
    ingredients.GetRecord(extra) ~= nil and extraRoot.AssemblyLinearVelocity == before and rolls == 1,
    "busy machine leaves extras intact and unqueued"
)
check(model:GetAttribute("BusyUntil") == now + config.BusySeconds, "busy physical arrival projects feedback")
local busyUntil = model:GetAttribute("BusyUntil")
now += 0.1
update(0.1)
check(model:GetAttribute("BusyUntil") == busyUntil, "stationary rejected item does not repeatedly flash")
finish()
local reward = outputs[1]
physical(reward, vec(1, 4, 0))
local actor, reason = eligibility.Eligible(dependency, input, reward)
check(actor == nil and reason == "OutputImmune", "fresh output has authoritative spawn immunity")
candidates = { reward }
update(0.1)
check(
    ingredients.GetRecord(reward) ~= nil and cache.WorldUtil.Part(reward).AssemblyLinearVelocity.Magnitude == 0,
    "untouched output is neither attracted nor automatically consumed"
)
now += 100
update(0.1)
check(ingredients.GetRecord(reward).MuncherImmune, "immunity does not expire with time")
setup(inventory.CarryWorldItem(owner, reward), "pick up reward")
check(ingredients.GetRecord(reward) == nil, "successful pickup retires immune spawn")
local rethrown = inventory.ThrowHeld(owner)
physical(rethrown, vec(0.5, 4, 0))
check(
    not ingredients.GetRecord(rethrown).MuncherImmune and eligibility.Eligible(dependency, input, rethrown) == owner,
    "pickup and real throw create normal eligible attributed world item"
)
candidates = { rethrown }
update(0.1)
check(ingredients.GetRecord(rethrown) == nil and rolls == 2, "deliberate re-gamble succeeds once")
finish()

-- Authoritative eligibility: crops remain excluded even after anchoring/visual flags change.
for _, state in { "Growing", "Ready" } do
    local crop, cropRoot = loose(owner, nil, { FarmManaged = true, FreezeUntilPickup = state == "Ready" })
    cropRoot.Anchored = false
    crop:SetAttribute("FrozenUntilPickup", nil)
    crop:SetAttribute("FarmState", state)
    local valid, why = eligibility.Eligible(dependency, input, crop)
    check(valid == nil and why == "FarmCrop", state .. " unanchored farm lifecycle remains protected")
    candidates = { crop }
    update(0.1)
    check(
        ingredients.GetRecord(crop) ~= nil and cropRoot.AssemblyLinearVelocity.Magnitude == 0,
        state .. " crop cannot be pulled or consumed"
    )
end
local anonymous = loose(nil)
local visitor = player(3)
local foreign = loose(visitor)
for _, case in { { anonymous, "MissingAttribution" }, { foreign, "UnauthorizedOwner" } } do
    local valid, why = eligibility.Eligible(dependency, input, case[1])
    check(valid == nil and why == case[2], "missing and foreign attribution reject")
end
anonymous:SetAttribute("OwnerUserId", owner.UserId)
check(eligibility.Eligible(dependency, input, anonymous) == nil, "forged metadata grants no feeding rights")
local carried, carriedRoot = loose(owner)
carried.Parent = owner.Character
check(
    select(2, eligibility.Eligible(dependency, input, carried)) == "CarriedIngredient",
    "registered overhead item excluded"
)
local heldTool = instance("Tool")
heldTool.Parent = owner.Character
carried.Parent = heldTool
check(
    select(2, eligibility.Eligible(dependency, input, carried)) == "CarriedIngredient",
    "equipped tool contents excluded"
)
carried.Parent = workspaceFake
carriedRoot.GetConnectedParts = function()
    return { owner.Character:FindFirstChild("HumanoidRootPart") }
end
check(
    select(2, eligibility.Eligible(dependency, input, carried)) == "CarriedIngredient",
    "external character weld excluded"
)
heldTool:Destroy()
local stored = loose(owner)
stored.Parent = fixtures[owner]
check(
    select(2, eligibility.Eligible(dependency, input, stored)) == "StashedIngredient",
    "stored/protected slot geometry excluded"
)
for _, class in { "Part", "Tool", "Model" } do
    local fake = instance(class)
    fake.Parent = workspaceFake
    check(eligibility.Eligible(dependency, input, fake) == nil, "unregistered prop/tool/smoothie model rejected")
end
local reserved = loose(owner, vec(0.5, 4, 0))
local reservation = ingredients.Reserve(reserved)
setup(reservation ~= nil, "reserve for competing consumer")
check(select(2, eligibility.Eligible(dependency, input, reserved)) == "AlreadyReserved", "reserved ingredient excluded")
check(
    not inventory.CarryWorldItem(owner, reserved) and ingredients.GetRecord(reserved) ~= nil,
    "pickup cannot steal an active claim"
)
check(
    ingredients.Consume(reserved) == nil and ingredients.Reserve(reserved) == nil,
    "other machine cannot consume or reserve same identity"
)
ingredients.ReleaseReservation(reserved, reservation)
setup(inventory.CarryWorldItem(owner, reserved), "pickup wins before vacuum")
check(not muncher.TryStartConversion(owner, input, reserved, "WorldVacuum", nil), "pickup-first cannot also gamble")
inventory.ClearHeld(owner)

-- Owner and teammate real throws retain attribution; visitors and stale sessions cannot bypass permissions.
local teammate = player(3)
authority.RemovePlayer(teammate)
setup(authority.JoinSession(teammate, owner, authority.GetRequestContext(owner)), "join teammate")
carry(teammate, "Apple")
local teamThrow = inventory.ThrowHeld(teammate)
physical(teamThrow, vec(0.5, 4, 0))
check(ingredients.GetRecord(teamThrow).FeedingActor == teammate, "real throw records authoritative actor")
candidates = { teamThrow }
update(0.1)
check(
    ingredients.GetRecord(teamThrow) == nil and muncher.GetSnapshot(owner).Phase == "Processing",
    "teammate throw feeds owner's machine"
)
finish()
local stale = loose(teammate, vec(0.5, 4, 0))
setup(authority.Kick(owner, teammate, authority.GetRequestContext(owner)), "remove member")
check(
    eligibility.Eligible(dependency, input, stale) == nil
        and not muncher.TryStartConversion(teammate, input, stale, "WorldVacuum", nil),
    "membership changes invalidate pending physical permissions"
)
carry(visitor, "Apple")
local visitorThrow = inventory.ThrowHeld(visitor)
physical(visitorThrow, vec(0.5, 4, 0))
check(
    eligibility.Eligible(dependency, input, visitorThrow) == nil and ingredients.GetRecord(visitorThrow) ~= nil,
    "visitor throw cannot feed another plot"
)
-- An attributed dynamic head uses the same world path and reward commit.
local head = physical(ingredients.Spawn("PlayerHead", frame(), owner, true), vec(0.5, 4, 0))
check(
    muncher.TryStartConversion(owner, input, head, "WorldVacuum", nil),
    "world PlayerHead accepted with ordinary ownership"
)
finish()
-- Conversion preparation failure releases the world claim and preserves the item.
local retryItem = loose(owner, vec(0.5, 4, 0))
local originalId = config.RewardPools[1][1].Id
config.RewardPools[1][1].Id = "PlayerHead"
check(
    not muncher.TryStartConversion(owner, input, retryItem, "WorldVacuum", nil)
        and ingredients.GetRecord(retryItem) ~= nil
        and not ingredients.GetRecord(retryItem).Reserved,
    "failed preparation preserves loose input and releases claim"
)
config.RewardPools[1][1].Id = originalId
local r = ingredients.Reserve(retryItem)
local blenderInput = references[owner].BlenderInput
blenderInput.Overlaps = { retryItem }
check(
    not blend.TryInput(owner, retryItem, blenderInput, nil) and ingredients.GetRecord(retryItem) ~= nil,
    "blender cannot consume a registry claim owned by another transaction"
)
ingredients.ReleaseReservation(retryItem, r)
check(blend.TryInput(owner, retryItem, blenderInput, nil), "released claim remains usable by normal blender")
local staleSession = physical(
    ingredients.Spawn("Apple", frame(), nil, true, {
        FeedingActor = owner,
        FeedingSessionId = "retired-session",
    }),
    vec(0.5, 4, 0)
)
check(
    select(2, eligibility.Eligible(dependency, input, staleSession)) == "UnauthorizedOwner",
    "old plot attribution cannot follow an actor to a replacement session"
)
-- Nearby independent plot cannot attract or consume the owner's item.
local otherPlot = authority.GetPlot(visitor)
local otherModel = instance("Model")
otherModel.Name, otherModel.Parent = "Muncher", otherPlot
local otherInput, otherPad = part("InputZone", otherModel), part("PurchasePoint1", otherModel)
otherInput.Position = input.Position
muncher.Reset(visitor)
authority.SetCash(visitor, config.PurchaseCost)
setup(muncher.TryPurchase(visitor, otherPad, nil), "buy independent Muncher")
now += config.RevealSeconds
setup(muncher.CompleteReveal(visitor, otherModel), "reveal independent Muncher")
local foreignUpdate, foreignStop = vacuum.Bind(dependency, otherInput, otherModel)
local single, singleRoot = loose(owner, vec(0.5, 4, 0))
candidates = { single }
foreignUpdate(0.1)
check(
    ingredients.GetRecord(single) ~= nil and singleRoot.AssemblyLinearVelocity.Magnitude == 0,
    "overlapping foreign vacuum cannot steal attributed item"
)
local rollBefore = rolls
update(0.1)
foreignUpdate(0.1)
check(
    ingredients.GetRecord(single) == nil and rolls == rollBefore + 1,
    "overlapping machines settle one identity only once"
)
finish()
foreignStop()
-- Failed output settlement for a physical feed retains the same committed reward.
local recoverable = loose(owner, vec(0.5, 4, 0))
setup(muncher.TryStartConversion(owner, input, recoverable, "WorldVacuum", nil), "feed recoverable world item")
local rollAtCommit = rolls
local spawnOutput = output.Spawn
output.Spawn = function()
    return false
end
now += config.ChewSeconds
muncher.Step()
check(
    muncher.GetSnapshot(owner).Phase == "Spitting" and rolls == rollAtCommit,
    "world feed retry preserves predetermined debt without reroll"
)
output.Spawn = spawnOutput
now += config.RetrySeconds
muncher.Step()
check(
    muncher.GetSnapshot(owner).Phase == "Idle" and rolls == rollAtCommit,
    "physical conversion recovers the original reward"
)
now += config.SpitSeconds
-- Multipart assemblies follow their authoritative root and retain all parts until commitment.
local multipart = loose(owner, vec(4, 4, 0))
local leaf = part("Leaf", multipart)
local multiRoot = cache.WorldUtil.Part(multipart)
multiRoot.GetConnectedParts = function()
    return { multiRoot, leaf }
end
candidates = { leaf, multipart }
update(0.1)
check(
    multiRoot.AssemblyLinearVelocity.X < 0 and leaf.Parent == multipart,
    "multipart candidates resolve once and steer intact"
)
local beforeObstruction = multiRoot.AssemblyLinearVelocity
workspaceFake.Raycast = function()
    return { Instance = input }
end
update(0.1)
check(
    multiRoot.AssemblyLinearVelocity == beforeObstruction and ingredients.GetRecord(multipart) ~= nil,
    "solid mouth obstruction releases safely instead of consuming through artwork"
)
workspaceFake.Raycast = function()
    return nil
end
now += config.Vacuum.ReleaseSeconds
update(0.1)
local beforeTimeout = multiRoot.AssemblyLinearVelocity
now += config.Vacuum.MaxPullSeconds + 0.01
update(0.1)
check(
    multiRoot.AssemblyLinearVelocity == beforeTimeout and ingredients.GetRecord(multipart) ~= nil,
    "stuck capture has a bounded release timeout"
)
now += config.Vacuum.ReleaseSeconds
update(0.1)
local velocity = multiRoot.AssemblyLinearVelocity
muncher.Reset(owner)
update(0.1)
check(
    ingredients.GetRecord(multipart) ~= nil and multiRoot.AssemblyLinearVelocity == velocity,
    "reset immediately stops attraction without anchoring or consuming"
)
stop()
-- Steering is bounded through a hitch and can pull up toward a side-facing opening.
local steered = physics.SteerToward(vec(0, 0, 0), vec(3, 2, 0), vec(0, 4, 0), 6, 10, config.Vacuum)
check(
    steered.X < 0
        and steered.Y > 0
        and steered.Magnitude <= config.Vacuum.MaxAcceleration * config.Vacuum.MaxStep + 0.001,
    "full 3D steering compensates gravity with bounded acceleration and hitch step"
)

-- Ordinary destruction retires both the per-spawn immunity and any claim.
local immune = ingredients.Spawn("Apple", frame(), nil, true, { MuncherImmune = true })
local immuneClaim = ingredients.Reserve(immune)
immune:Destroy()
check(
    ingredients.GetRecord(immune) == nil and ingredients.Reserve(immune) == nil,
    "destroyed immune output cannot retain a usable registry identity"
)
ingredients.ReleaseReservation(immune, immuneClaim)

-- Harvest pickup/throw retires the farm lifecycle; only that new loose spawn is eligible.
local harvest, harvestRoot = loose(owner, vec(2, 4, 0), { FarmManaged = true, FreezeUntilPickup = true })
setup(inventory.CarryWorldItem(owner, harvest), "normal harvest pickup")
local harvestedThrow = inventory.ThrowHeld(owner)
physical(harvestedThrow, vec(2, 4, 0))
check(
    not ingredients.GetRecord(harvestedThrow).FarmManaged
        and eligibility.Eligible(dependency, input, harvestedThrow) == owner,
    "normal harvesting then throwing produces eligible loose item without changing farm growth"
)
local deniedOutput = physical(ingredients.Spawn("Apple", frame(), nil, true, { MuncherImmune = true }), vec(2, 4, 0))
local deny = ingredients.Reserve(deniedOutput)
check(
    not inventory.CarryWorldItem(owner, deniedOutput) and ingredients.GetRecord(deniedOutput).MuncherImmune,
    "failed pickup never clears output immunity"
)
ingredients.ReleaseReservation(deniedOutput, deny)
