-- Real CustomerService with the shared fake Roblox boundary.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
env.math = table.clone(math)
env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
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
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerExit" } do
    refs[name] = instance("Part")
    refs[name].CFrame = frame()
end
customer.Init({
    PlayerDataService = data,
    TycoonService = {
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
do
    local owner = player("RequestTiers")
    data.AddPlayer(owner)
    data.SetCash(owner, 10000)
    local savedRequests = table.clone(requests)
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
            local model = customer.SpawnForPlayer(owner)
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
    check(
        customer.SpawnForPlayer(owner) == nil and customer.GetSnapshot(owner) == nil,
        "empty pool creates no customer"
    )
    -- Only locked requests is also an empty eligible pool.
    owner:SetAttribute("JumpLevel", 0)
    requests[1] = savedRequests[1]
    local savedTier = requests[1].MinJumpTier
    requests[1].MinJumpTier = 1
    check(customer.SpawnForPlayer(owner) == nil, "all locked requests fail safely")
    requests[1].MinJumpTier = savedTier
    -- Configuration/progression can change during arrival or before a refresh.
    local arriving = customer.SpawnForPlayer(owner)
    table.clear(requests)
    flush()
    check(arriving.Destroyed and customer.GetSnapshot(owner) == nil, "empty arrival cleans up without an order")
    requests[1] = savedRequests[1]
    env.math.random = savedRandom
    local ready = customer.SpawnForPlayer(owner)
    flush()
    flush()
    table.clear(requests)
    env.math.random = function()
        error("empty refresh must not call random")
    end
    customer:RefreshOrder(ready)
    check(ready.Destroyed and customer.GetSnapshot(owner) == nil, "empty refresh removes stale order")
    check(not customer.Serve(owner), "empty pool cannot be served or paid")
    check(warnings == 4, "all empty pool paths warn")
    for _, request in savedRequests do
        table.insert(requests, request)
    end
    env.math.random, env.warn = savedRandom, savedWarn
    data.RemovePlayer(owner)
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
        local model = customer.SpawnForPlayer(owner)
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
            check(bubble.StudsOffset.Y == 2.5 + 2, "billboard rises exactly two studs")
            check(bubble.StudsOffset.X == 0 and bubble.StudsOffset.Z == 0, "billboard preserves original X/Z")
            check(bubble.AlwaysOnTop and nameText.BackgroundTransparency == 1, "name keeps transparent topmost style")
            check(nameText.TextStrokeTransparency == 0.25, "name keeps outlined text")
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
    model = customer.SpawnForPlayer(owner)
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
    check(days.StartDay(owner), "custom customer starts day")
    local previous = nil
    local specials = 0
    for turn = 1, 3 do
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
        check(#days.GetSnapshot(owner).Grades == turn, "completion advances day once")
    end
    check(days.GetSnapshot(owner).State == "FINISHED", "custom day ends after exactly three customers")
    check(specials == 1, "at most one special even with 100 percent chance")
    check(days.StartDay(owner), "next day starts")
    flush()
    check(customer.GetSnapshot(owner).CustomerId == "steak", "new day resets special budget")
    customer.RemovePlayer(owner)
    local allCleaned = true
    for _, presentation in presentations do
        allCleaned = allCleaned and presentation.Destroyed and not presentation.Moving
    end
    check(allCleaned, "reset removes active and departing presentation")
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
