-- Real CustomerService with the shared fake Roblox boundary.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
env.math = table.clone(math)
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
env.UDim2.fromOffset = function(x, y)
    return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
local function player(name)
    local owner = instance("Player")
    owner.Name = name
    owner.UserId = #allInstances
    owner.Parent = services.Players
    owner.Near = true
    return owner
end
local data = loadModule("PlayerDataService")
local requestConfig = loadModule("CustomerRequests")
local requests = requestConfig.Definitions
local customer = loadModule("CustomerService")
local refs = {}
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].CFrame = frame()
end
local plots = {}
local function getPlot(owner)
    if not plots[owner] then
        plots[owner] = instance("Model")
        plots[owner].Owner = owner
    end
    return plots[owner]
end
local function getOwner(plot)
    return plot.Owner
end
local function spawnFor(owner)
    local random = env.math.random
    env.math.random = math.random
    customer.ActivateForPlayer(owner)
    env.math.random = random
    return customer.SpawnForPlayer(owner)
end
customer.Init({
    PlayerDataService = data,
    TycoonService = {
        GetPlot = getPlot,
        GetOwner = getOwner,
        GetReference = function(_, name)
            return refs[name]
        end,
    },
}, function() end, function()
    return true
end)
local ids = {}
for _, request in requests do
    check(not ids[request.Id], "request IDs are unique")
    ids[request.Id] = true
    check(
        type(request.MinJumpTier) == "number"
            and request.MinJumpTier >= 0
            and request.MinJumpTier <= 3
            and request.MinJumpTier == math.floor(request.MinJumpTier),
        "every request has a valid minimum jump tier"
    )
end
-- Exercise actual arrival/refresh selection with every random index, not statistical sampling.
for id, mapping in requestConfig.NPCs do
    check(ids[mapping.RequestId], "authored NPC RequestId resolves: " .. id)
end
do
    local owner = player("RequestTiers")
    data.AddPlayer(owner)
    data.SetCash(owner, 10000)
    local savedRequests = table.clone(requests)
    local savedWindow = requestConfig.RegularRequestRecencyWindow
    requestConfig.RegularRequestRecencyWindow = 0 -- Exhaust eligibility independently of recency below.
    local savedRandom, savedWarn = env.math.random, env.warn
    local warnings = 0
    env.warn = function(message)
        check(string.find(message, "No eligible requests", 1, true) ~= nil, "empty pool warning explains failure")
        warnings += 1
    end
    table.clear(requests)
    for tier = 0, 3 do
        table.insert(requests, {
            Id = "Tier" .. tier,
            DisplayText = "Tier " .. tier,
            RequiredTags = { "Red" },
            BasePayout = 25,
            MinJumpTier = tier,
        })
    end
    for tier = 0, 3 do
        if tier > 0 then
            check(data.PurchaseUpgrade(owner, "Jump"), "purchase authoritative jump upgrade")
        end
        check(owner:GetAttribute("JumpLevel") == tier, "existing progression publishes zero-based tier")
        for roll = 1, tier + 1 do
            env.math.random = function(low, high)
                check(low == 1 and high == tier + 1, "random bounds contain exactly eligible requests")
                return roll
            end
            local model = spawnFor(owner)
            check(model ~= nil, "eligible player can spawn")
            flush()
            flush()
            check(customer.GetSnapshot(owner).RequestId == "Tier" .. (roll - 1), "arrival selects eligible request")
            customer:RefreshOrder(model)
            flush()
            check(customer.GetSnapshot(owner).RequestId == "Tier" .. (roll - 1), "refresh selects eligible request")
            customer.RemovePlayer(owner)
        end
    end
    env.math.random = function()
        error("empty pool must not call random")
    end
    table.clear(requests)
    check(spawnFor(owner) == nil and customer.GetSnapshot(owner) == nil, "empty pool creates no customer")
    -- Only locked requests is also an empty eligible pool.
    owner:SetAttribute("JumpLevel", 0)
    requests[1] = savedRequests[1]
    local savedTier = requests[1].MinJumpTier
    requests[1].MinJumpTier = 1
    check(spawnFor(owner) == nil, "all locked requests fail safely")
    requests[1].MinJumpTier = savedTier
    -- Configuration/progression can change during arrival or before a refresh.
    env.math.random = savedRandom
    local arriving = spawnFor(owner)
    table.clear(requests)
    flush()
    check(
        not arriving.Destroyed and customer.GetSnapshot(owner).RequestId ~= nil,
        "queued request survives catalog changes during arrival"
    )
    arriving:Destroy()
    requests[1] = savedRequests[1]
    env.math.random = savedRandom
    local ready = spawnFor(owner)
    flush()
    flush()
    table.clear(requests)
    env.math.random = function()
        error("empty refresh must not call random")
    end
    customer:RefreshOrder(ready)
    check(ready.Destroyed and customer.GetSnapshot(owner) == nil, "empty refresh removes stale order")
    check(not customer.Serve(owner), "empty pool cannot be served or paid")
    check(warnings == 3, "all empty pool paths warn")
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random, env.warn = savedRandom, savedWarn
    requestConfig.RegularRequestRecencyWindow = savedWindow
    data.RemovePlayer(owner)
end
-- Exhaust the authored pool at each tier, including all advanced definitions.
do
    local owner = player("AuthoredRequestTiers")
    data.AddPlayer(owner)
    local savedRandom = env.math.random
    for tier = 0, 3 do
        owner:SetAttribute("JumpLevel", tier)
        local eligible = {}
        for _, request in requests do
            if not request.NPCOnly and request.MinJumpTier <= tier then
                table.insert(eligible, request)
            end
        end
        for roll, expected in eligible do
            env.math.random = function(low, high)
                check(low == 1 and high == #eligible, "authored pool includes exactly unlocked normal requests")
                return roll
            end
            local model = spawnFor(owner)
            flush()
            flush()
            check(
                customer.GetSnapshot(owner).RequestId == expected.Id,
                "authored request remains selectable: " .. expected.Id
            )
            customer.RemovePlayer(owner)
        end
    end
    env.math.random = savedRandom
    data.RemovePlayer(owner)
end

-- The real serve path uses forbidden metadata, authored feedback, and one payment.
do
    local owner = player("AdvancedServing")
    data.AddPlayer(owner)
    owner:SetAttribute("JumpLevel", 3)
    local selected, selectedIndex
    local index = 0
    for _, request in requests do
        if not request.NPCOnly then
            index += 1
            if request.Id == "SweetColdNoSpicy" then
                selected, selectedIndex = request, index
            end
        end
    end
    local savedRandom = env.math.random
    env.math.random = function()
        return selectedIndex
    end
    local cup
    customer.Init({
        PlayerDataService = data,
        TycoonService = {
            GetPlot = getPlot,
            GetOwner = getOwner,
            GetReference = function(_, name)
                return refs[name]
            end,
        },
        BlendService = {
            ConsumeCup = function()
                local result = cup
                cup = nil
                return result
            end,
        },
    }, function() end, function()
        return true
    end)
    for _, example in
        {
            { { "Strawberry", "Ice", "Banana" }, true },
            { { "Strawberry", "Ice", "Chili_Pepper" }, false },
            { { "Strawberry", "Banana", "Banana" }, false },
        }
    do
        local model = spawnFor(owner)
        flush()
        flush()
        cup = { Ingredients = example[1], Tags = { "Sweet", "Cold" }, BlendId = "advanced" }
        local cash = data.GetCash(owner)
        check(customer.Serve(owner), "advanced serving completes")
        flush()
        check(
            data.GetCash(owner) == cash + (if example[2] then selected.BasePayout else 0),
            "advanced validation controls payment"
        )
        check(
            model:FindFirstChild("OrderBubble", true):FindFirstChildOfClass("TextLabel").Text
                == (if example[2] then selected.GoodResponse else selected.BadResponse),
            "advanced result uses authored response"
        )
        check(cup == nil and not customer.Serve(owner), "advanced cup consumed once and cannot be served twice")
        customer.RemovePlayer(owner)
    end
    env.math.random = savedRandom
    data.RemovePlayer(owner)
end

-- Recency contracts through real spawn/arrival/refresh, with deterministic first-candidate rolls.
do
    local savedRequests = table.clone(requests)
    local savedRandom, savedChance = env.math.random, requestConfig.SpecialCustomerChance
    local savedMapping = requestConfig.NPCs.steak.RequestId
    table.clear(requests)
    for index = 1, 6 do
        table.insert(requests, {
            Id = "Recent" .. index,
            DisplayText = "Same text",
            RequiredTags = { "Red" },
            BasePayout = 25,
            MinJumpTier = if index == 5 then 3 else 0,
            NPCOnly = index == 6,
        })
    end
    env.math.random = function(low)
        return low or 0
    end
    requestConfig.SpecialCustomerChance = 0
    local function child(class, name, parent)
        local item = instance(class)
        item.Name, item.Parent = name, parent
        if class == "Humanoid" then
            item.RigType = { Name = "R15" }
        end
        return item
    end
    local folder = child("Folder", "CustomerNPCs", storage)
    local regular = child("Folder", "Regular", folder)
    local special = child("Folder", "Special", folder)
    local templates = {}
    for index = 1, 5 do
        local model = child("Model", "Template" .. index, if index == 5 then special else regular)
        child("Humanoid", "Humanoid", model)
        child("Part", "HumanoidRootPart", model)
        model:SetAttribute("SourceProbe", index)
        if index == 5 then
            model:SetAttribute("CustomerId", "steak")
        end
        templates[index] = model
    end
    local a, b = player("RecencyA"), player("RecencyB")
    local function spawn(owner)
        local model = spawnFor(owner)
        setup(model ~= nil, "recency customer spawns")
        flush()
        flush()
        return model, customer.GetSnapshot(owner).RequestId
    end
    local function depart(model)
        model:Destroy() -- Preserve player history between selections.
        flush()
    end
    for turn = 1, 9 do
        customer.BeginDay(a) -- Day boundaries do not erase regular history.
        local model, id = spawn(a)
        local expected = (turn - 1) % 4 + 1
        check(model:GetAttribute("SourceProbe") == expected, "template waits for three intervening regular selections")
        check(
            id == "Recent" .. expected,
            "stable request IDs remain independent despite shared tags/text; locked/NPCOnly excluded"
        )
        depart(model)
    end
    local modelB, idB = spawn(b)
    check(
        modelB:GetAttribute("SourceProbe") == 1 and idB == "Recent1",
        "another player starts with independent histories"
    )
    depart(modelB)
    local modelA, idA = spawn(a)
    check(modelA:GetAttribute("SourceProbe") == 2 and idA == "Recent2", "other player cannot advance either history")
    customer:RefreshOrder(modelA)
    check(customer.GetSnapshot(a).RequestId == "Recent3", "refresh advances only request history")
    depart(modelA)
    modelA, idA = spawn(a)
    check(
        modelA:GetAttribute("SourceProbe") == 3 and idA == "Recent4",
        "template and request histories advance independently"
    )
    depart(modelA)
    requestConfig.SpecialCustomerChance = 1
    for _, forcedId in { "Recent4", "Recent6" } do
        requestConfig.NPCs.steak.RequestId = forcedId
        now += 300 -- Continuous cooldown, independent of BeginDay.
        customer.BeginDay(a)
        modelA, idA = spawn(a)
        check(
            modelA:GetAttribute("SourceProbe") == 5 and idA == forcedId,
            "special bypasses recent request and NPCOnly exclusion"
        )
        customer:RefreshOrder(modelA)
        check(customer.GetSnapshot(a).RequestId == forcedId, "special refresh preserves forced request")
        depart(modelA)
        -- Existing special immediate-repeat rule needs a regular between specials.
        requestConfig.SpecialCustomerChance = 0
        modelA, idA = spawn(a)
        check(
            modelA:GetAttribute("SourceProbe") == (if forcedId == "Recent4" then 4 else 1),
            "special does not advance template history"
        )
        check(
            idA == (if forcedId == "Recent4" then "Recent1" else "Recent2"),
            "special does not advance request history"
        )
        depart(modelA)
        requestConfig.SpecialCustomerChance = 1
    end
    requestConfig.SpecialCustomerChance = 0
    customer.RemovePlayer(a)
    modelA, idA = spawn(a)
    check(modelA:GetAttribute("SourceProbe") == 1 and idA == "Recent1", "player removal clears both histories")
    depart(modelA)
    for index = 2, 4 do
        templates[index]:Destroy()
    end
    table.clear(requests)
    table.insert(
        requests,
        { Id = "Recent1", DisplayText = "Only", RequiredTags = { "Red" }, BasePayout = 25, MinJumpTier = 0 }
    )
    for _ = 1, 5 do
        modelA, idA = spawn(a)
        check(modelA:GetAttribute("SourceProbe") == 1 and idA == "Recent1", "all-recent pools fall back safely")
        depart(modelA)
    end
    customer.RemovePlayer(a)
    customer.RemovePlayer(b)
    folder:Destroy()
    table.clear(requests)
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random, requestConfig.SpecialCustomerChance = savedRandom, savedChance
    requestConfig.NPCs.steak.RequestId = savedMapping
end

-- Custom templates use the same request and serving transaction.
do
    local owner = player("ImportedAvatars")
    data.AddPlayer(owner)
    owner:SetAttribute("JumpLevel", 3)
    local savedChance = requestConfig.SpecialCustomerChance
    local savedRandom = env.math.random
    requestConfig.SpecialCustomerChance = 1
    env.math.random = function(low)
        return low or 0
    end
    local folder = instance("Folder")
    folder.Name, folder.Parent = "CustomerNPCs", storage
    local function child(class, name, parent)
        local item = instance(class)
        if class == "Humanoid" then
            item.RigType = { Name = "R15" }
        end
        item.Name, item.Parent = name, parent
        return item
    end
    local regularFolder = child("Folder", "Regular", folder)
    local specialFolder = child("Folder", "Special", folder)
    local function rig(name, id)
        local model = child(
            "Model",
            name,
            if requestConfig.NPCs[requestConfig.NormalizeCustomerId(id)] then specialFolder else regularFolder
        )
        model:SetAttribute("CustomerId", id)
        child("Humanoid", "Humanoid", model)
        child("Part", "Head", model)
        child("Part", "HumanoidRootPart", model)
        return model
    end
    refs.CustomerSpawn.CFrame = frame(0, 0, 0)
    refs.CustomerCounter.CFrame = frame(10, 0, 0)
    refs.CustomerExit.CFrame = frame(20, 0, 0)
    local steak = rig("UsernameCanChange", "  steak  ")
    local importedScript = child("Script", "ImportedCode", steak)
    child("LocalScript", "Animate", steak)
    child("ModuleScript", "Module", steak)
    child("Tool", "ImportedTool", steak)
    child("ProximityPrompt", "OtherPrompt", steak)
    local accessory = child("Accessory", "Hat", steak)
    child("Part", "Handle", accessory)
    child("Attachment", "HatAttachment", accessory)
    child("Motor6D", "Neck", steak)
    child("Shirt", "Shirt", steak)
    child("Decal", "face", steak)
    -- Observe presentation commands independently of the mock engine's missing Animator.
    local walkModule = loadModule("CustomerWalk")
    local savedCreate = walkModule.Create
    local presentations = {}
    walkModule.Create = function()
        local state = { Moving = false, Started = false, Destroyed = false }
        table.insert(presentations, state)
        return {
            SetMoving = function(value)
                if not state.Destroyed then
                    state.Moving = value
                    state.Started = state.Started or value
                end
            end,
            Destroy = function()
                state.Moving, state.Destroyed = false, true
            end,
        }
    end
    local function spawn()
        local model = spawnFor(owner)
        setup(model ~= nil, "customer spawns")
        check(presentations[#presentations].Moving, "route start plays walk before the first movement step")
        flush()
        flush()
        return model, customer.GetSnapshot(owner)
    end
    -- Each mapped avatar must bypass the random order pool at arrival and refresh.
    for _, id in { "steak", "caseoh", "pirate", "walter", "prankster" } do
        local config = requestConfig.NPCs[id]
        local fixed = requestConfig.GetForNPC(id)
        steak:SetAttribute("CustomerId", id)
        owner:SetAttribute("JumpLevel", fixed.MinJumpTier - 1)
        local locked, lockedSnapshot = spawn()
        check(lockedSnapshot.CustomerId == nil, "mapped special is excluded below its own tier: " .. id)
        check(locked:FindFirstChild("CustomerName", true).Text == "CustomerNPC", "generic fallback shows regular name")
        customer.RemovePlayer(owner)
        owner:SetAttribute("JumpLevel", fixed.MinJumpTier)
        env.math.random = function(low, high)
            check(low ~= 1, "fixed special must never draw from random request pool")
            return low or 0
        end
        local selected, selectedSnapshot = spawn()
        check(selectedSnapshot.RequestId == config.RequestId, "arrival uses configured fixed request: " .. id)
        local bubble = selected:FindFirstChild("OrderBubble", true)
        local nameText = bubble:FindFirstChild("CustomerName")
        check(nameText.Text == config.DisplayName, "name comes from config: " .. id)
        -- All IDs exercise mapping; shared nameplate styling needs one representative.
        if id == "steak" then
            check(bubble.MaxDistance == 30 and bubble.Enabled == false, "approaching owner order defaults private")
            check(bubble.StudsOffset.X == 0 and bubble.StudsOffset.Z == 0, "billboard preserves original X/Z")
            check(bubble.AlwaysOnTop and nameText.BackgroundTransparency == 1, "name keeps transparent topmost style")
            check(nameText.TextStrokeTransparency <= 0.2 and nameText.TextSize < 24, "name is secondary and outlined")
            local dialogue = bubble:FindFirstChildOfClass("TextLabel")
            check(nameText.Position.Y.Offset >= dialogue.Size.Y.Offset, "name sits below a separate dialogue row")
            local serve = selected:FindFirstChild("ServePrompt", true)
            check(
                serve.Style == "Custom" and serve:GetAttribute("InteractionActionText") == "SERVE",
                "serve uses custom action"
            )
            check(
                selected:FindFirstChild(serve:GetAttribute("InteractionOrigin"), true) ~= nil,
                "serve has generated origin"
            )
            check(
                selected:FindFirstChildOfClass("Humanoid").DisplayDistanceType == "None",
                "custom row replaces clone nameplate"
            )
            check(
                steak:FindFirstChildOfClass("Humanoid").DisplayDistanceType ~= "None",
                "template nameplate remains untouched"
            )
        end
        selected:SetAttribute("CustomerId", "untrusted")
        customer:RefreshOrder(selected)
        flush()
        check(customer.GetSnapshot(owner).RequestId == config.RequestId, "refresh preserves private fixed request")
        check(nameText.Text == config.DisplayName, "typewriter refresh leaves name intact")
        customer.RemovePlayer(owner)
        local savedName = config.DisplayName
        config.DisplayName = nil
        selected = spawn()
        check(selected:FindFirstChild("CustomerName", true).Text == id, "absent display name falls back to ID")
        customer.RemovePlayer(owner)
        config.DisplayName = savedName
        env.math.random = function(low)
            return low or 0
        end
    end
    local authoredHumanoid = steak:FindFirstChildOfClass("Humanoid")
    authoredHumanoid.DisplayName = "Authored Customer"
    local authoredModel = spawn()
    check(
        authoredModel.Name == "CustomerNPC"
            and authoredModel:FindFirstChild("CustomerName", true).Text == "Authored Customer",
        "authored name survives runtime model rename"
    )
    check(authoredHumanoid.DisplayName == "Authored Customer", "authored template name is unchanged")
    customer.RemovePlayer(owner)
    authoredHumanoid.DisplayName = nil
    steak:SetAttribute("CustomerId", "  steak  ")
    owner:SetAttribute("JumpLevel", 0)
    local model, snapshot = spawn()
    check(
        snapshot.CustomerId == nil and snapshot.RequestId ~= "Steak",
        "locked special excluded; no-special chance falls back to regular"
    )
    customer.RemovePlayer(owner)
    owner:SetAttribute("JumpLevel", 1)
    model, snapshot = spawn()
    check(
        snapshot.CustomerId == "steak" and snapshot.RequestId == "Steak",
        "special becomes eligible at fixed request tier"
    )
    check(model ~= steak and steak.Parent == specialFolder and not steak.Destroyed, "template is cloned and retained")
    check(
        steak:GetAttribute("CustomerId") == "  steak  " and importedScript.Parent == steak,
        "template attributes and scripts untouched"
    )
    check(snapshot.CustomerId == "steak" and snapshot.RequestId == "Steak", "trimmed stable ID forces Steak")
    check(model.PrimaryPart.Name == "HumanoidRootPart", "HRP takes priority over first body part")
    check(model:GetPivot().LookVector.X > 0.999, "spawned avatar actually faces counter travel direction")
    check(model:GetPivot().Position.X == 10, "movement reaches counter XZ")
    check(model:GetPivot().Position.Y == 1.2, "spawned avatar uses marker top plus measured bottom offset")
    for _, name in { "ImportedCode", "Animate", "Module", "ImportedTool", "OtherPrompt" } do
        check(model:FindFirstChild(name, true) == nil, "clone removes " .. name)
    end
    for _, name in { "Hat", "Handle", "HatAttachment", "Neck", "Shirt", "face" } do
        check(model:FindFirstChild(name, true) ~= nil, "clone preserves " .. name)
    end
    check(
        model.PrimaryPart.Anchored and not model.PrimaryPart.CanCollide,
        "route root stays anchored without changing collision policy"
    )
    model:SetAttribute("CustomerId", "unknown")
    customer:RefreshOrder(model)
    check(customer.GetSnapshot(owner).RequestId == "Steak", "replicated ID cannot change private assignment")
    customer.RemovePlayer(owner)
    requestConfig.SpecialCustomerChance = 0
    model, snapshot = spawn()
    check(snapshot.CustomerId == nil, "zero chance uses regular fallback even with eligible special")
    customer.RemovePlayer(owner)
    requestConfig.SpecialCustomerChance = 1
    steak.Name = "RenamedNPC"
    model, snapshot = spawn()
    check(snapshot.RequestId == "Steak", "model rename does not change request")
    customer.RemovePlayer(owner)
    for _, id in { "random_avatar", "", "   ", "STEAK", 42 } do
        steak:SetAttribute("CustomerId", id)
        model, snapshot = spawn()
        check(snapshot.RequestId ~= "Steak", "unmapped/empty/invalid IDs use normal requests")
        check(not requestConfig.GetForNPC(snapshot.CustomerId), "no override for fallback customer")
        check(model:FindFirstChild("CustomerName", true).Text == "CustomerNPC", "regular customer shows CustomerNPC")
        customer.RemovePlayer(owner)
    end
    steak:SetAttribute("CustomerId", nil)
    model, snapshot = spawn()
    check(snapshot.CustomerId == nil and snapshot.RequestId ~= "Steak", "missing ID works without name fallback")
    customer.RemovePlayer(owner)
    steak:SetAttribute("CustomerId", "steak")
    requestConfig.NPCs.steak.RequestId = "NotARequest"
    check(select(2, requestConfig.GetForNPC("steak")) ~= nil, "invalid mapping returns diagnostic")
    model, snapshot = spawn()
    check(snapshot.RequestId ~= "Steak", "invalid mapping safely falls back")
    customer.RemovePlayer(owner)
    requestConfig.NPCs.steak.RequestId = "Steak"

    -- A mapped avatar in Regular cannot impersonate a missing Special avatar.
    steak.Parent = regularFolder
    local ordinary = rig("Ordinary", nil)
    ordinary:SetAttribute("SourceProbe", "Regular")
    local misplaced = rig("UnmappedSpecial", nil)
    misplaced.Parent = specialFolder
    local flat = rig("OldFlatAvatar", nil)
    flat.Parent = folder
    model, snapshot = spawn()
    check(
        snapshot.CustomerId == nil and snapshot.RequestId ~= "Steak",
        "missing special falls back without special identity"
    )
    check(model:GetAttribute("SourceProbe") == "Regular", "regular avatar is selected exclusively from Regular")
    check(model:FindFirstChild("CustomerName", true).Text == "CustomerNPC", "fallback has regular name")
    check(
        presentations[#presentations].Started and not presentations[#presentations].Moving,
        "travel starts walk and counter arrival stops it"
    )
    customer.RemovePlayer(owner)
    check(presentations[#presentations].Destroyed, "removal cleans walking presentation")
    ordinary:Destroy()
    model, snapshot = spawn()
    check(
        model:FindFirstChild("Torso") ~= nil and snapshot.CustomerId == nil,
        "regular excludes Special and old flat folder models"
    )
    customer.RemovePlayer(owner)
    model = spawnFor(owner)
    model:Destroy()
    flush()
    check(
        presentations[#presentations].Destroyed and customer.GetSnapshot(owner) == nil,
        "external destruction cleans pending travel"
    )
    misplaced:Destroy()
    flat:Destroy()
    steak.Parent = specialFolder

    local second = rig("Second", "random_avatar")
    local third = rig("Third", "another_regular")
    requestConfig.NPCs.steak.RequestId = "Sweet"
    local days = loadModule("GameService")
    local cup = nil
    local dependency = {
        PlayerDataService = data,
        CustomerService = customer,
        TycoonService = {
            GetPlot = getPlot,
            GetOwner = getOwner,
            AssignPlot = function() end,
            GetReference = function(_, name)
                return refs[name]
            end,
        },
        BlendService = {
            ConsumeCup = function()
                local result = cup
                cup = nil
                return result
            end,
        },
    }
    days.Init(dependency)
    days.AddPlayer(owner)
    customer.Init(dependency, days.CustomerServed, days.IsServing)
    local transactionRequests = table.clone(requests)
    local sweet
    for _, request in requests do
        if request.Id == "Sweet" then
            sweet = request
        end
    end
    table.clear(requests)
    table.insert(requests, sweet)
    check(days.StartDay(owner), "custom customer starts day")
    local previous = nil
    local specials = 0
    for turn = 1, 3 do
        setup(spawnFor(owner) ~= nil, "timed arrival boundary spawns next customer")
        flush()
        flush()
        snapshot = customer.GetSnapshot(owner)
        check(previous == nil or snapshot.CustomerId ~= previous, "multiple templates do not immediately repeat")
        previous = snapshot.CustomerId
        if snapshot.CustomerId == "steak" then
            specials += 1
        end
        local cash = data.GetCash(owner)
        cup = {
            Ingredients = if turn == 2 then { "Tire", "Tire", "Tire" } else { "Banana", "Strawberry", "Banana" },
            Tags = { "Sweet" },
            BlendId = "npc-" .. turn,
        }
        local assigned
        for _, request in requests do
            if request.Id == snapshot.RequestId then
                assigned = request
            end
        end
        local savedGood = assigned.GoodResponse
        if turn == 1 then
            check(customer.SetForcedReaction(owner, "Disgust"), "force independent reaction")
        elseif turn == 3 then
            assigned.GoodResponse = nil
        end
        check(customer.Serve(owner), "existing serving transaction consumes custom order")
        assigned.GoodResponse = savedGood
        flush()
        local feedback = snapshot.Model:FindFirstChild("OrderBubble", true)
        if turn == 3 then
            check(feedback == nil, "missing response retains no-dialogue fallback")
        else
            check(
                feedback:FindFirstChildOfClass("TextLabel").Text
                    == (if turn == 1 then assigned.GoodResponse else assigned.BadResponse),
                "serve dialogue comes from assigned request and authoritative grade"
            )
        end
        if turn == 1 then
            check(
                snapshot.Model:GetAttribute("Reaction") == "Disgust",
                "good dialogue does not change independent reaction"
            )
        end
        check(
            data.GetCash(owner) == cash + (if turn == 2 then 0 else 25),
            "success pays and failure rejects forged tags"
        )
        check(not customer.Serve(owner), "completed order cannot pay twice")
        check(days.GetSnapshot(owner).Served == turn, "completion records each serve once")
    end
    check(days.GetSnapshot(owner).State == "SERVING", "third customer does not end flow")
    check(specials == 1, "at most one special even with 100 percent chance")
    check(days.StartDay(owner), "legacy start is idempotent")
    setup(spawnFor(owner) ~= nil, "flow continues after third serve")
    flush()
    check(customer.GetSnapshot(owner).CustomerId ~= "steak", "legacy start cannot reset special cooldown")
    customer.RemovePlayer(owner)
    local allCleaned = true
    for _, presentation in presentations do
        allCleaned = allCleaned and presentation.Destroyed and not presentation.Moving
    end
    check(allCleaned, "reset removes active and departing presentation")
    table.clear(requests)
    for _, request in transactionRequests do
        table.insert(requests, request)
    end
    requestConfig.NPCs.steak.RequestId = "Steak"
    requestConfig.NPCs.random_avatar = nil
    second:Destroy()
    third:Destroy()
    steak:Destroy()
    local r6 = rig("R6PrimaryFallback", "steak")
    r6:FindFirstChild("HumanoidRootPart"):Destroy()
    r6.PrimaryPart = child("Part", "Torso", r6)
    model, snapshot = spawn()
    check(model.PrimaryPart.Name == "Torso" and snapshot.RequestId == "Steak", "R6 PrimaryPart fallback works")
    customer.RemovePlayer(owner)
    r6.PrimaryPart = nil
    model = spawn()
    check(model.PrimaryPart ~= nil, "legacy BasePart root resolution works without PrimaryPart")
    customer.RemovePlayer(owner)
    r6:Destroy()
    -- Malformed/non-archivable templates cannot break the generic fallback.
    child("Part", "NotAModel", folder)
    child("Model", "NoHumanoid", folder)
    local broken = rig("NotArchivable", "steak")
    broken.Archivable = false
    local toolRig = child("Model", "OnlyToolRoot", folder)
    child("Humanoid", "Humanoid", toolRig)
    child("Part", "Handle", child("Tool", "Tool", toolRig))
    local noRoot = child("Model", "NoRoot", folder)
    child("Humanoid", "Humanoid", noRoot)
    local noClonedRoot = rig("NonArchivableParts", "steak")
    noClonedRoot:FindFirstChild("Head").Archivable = false
    noClonedRoot:FindFirstChild("HumanoidRootPart").Archivable = false
    model, snapshot = spawn()
    check(snapshot.CustomerId == nil and model:FindFirstChild("Torso"), "all malformed templates fall back")
    customer.RemovePlayer(owner)
    for _, item in folder:GetChildren() do
        item:Destroy()
    end
    model, snapshot = spawn()
    check(model:FindFirstChild("Torso") and snapshot.RequestId ~= "Steak", "empty folder keeps generic customer")
    customer.RemovePlayer(owner)
    local legacy = child("Model", "Customer", storage)
    child("Part", "Torso", legacy)
    model = spawn()
    check(model ~= legacy and legacy.Parent == storage, "empty custom folder retains legacy template cloning")
    customer.RemovePlayer(owner)
    legacy:Destroy()
    folder:Destroy()
    walkModule.Create = savedCreate
    data.RemovePlayer(owner)
    requestConfig.SpecialCustomerChance = savedChance
    env.math.random = savedRandom
end
print(string.format("PASS: %d customer request assertions (mocked Roblox boundary).", count))
