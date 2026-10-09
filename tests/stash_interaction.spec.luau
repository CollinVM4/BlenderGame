-- Real InventoryService transfers with fake character/world boundaries and clock.
do
    env.typeof = function(value)
        return if type(value) == "table" and value.ClassName then "Instance" else type(value)
    end
    env.Enum.ProximityPromptExclusivity = { OneGlobally = "OneGlobally" }
    env.Enum.KeyCode = { E = "E", ButtonX = "ButtonX" }
    local before = count
    cache.InventoryService = nil
    cache.StudioServices = {
        Wrap = function(_, service)
            return service
        end,
    }
    cache.IngredientCarryPresentation = {
        Attach = function()
            return frame(), function() end, 1
        end,
        RefreshValue = function() end,
    }
    local inventory = loadModule("InventoryService")
    local records = {}
    local fixtures = {}
    local sessions = {}
    local failVisual = false
    inventory.Init({
        PlayerDataService = {
            GetUpgrade = function(_, name)
                return 1
            end,
        },
        IngredientService = {
            GetDefinition = function(id)
                return loadModule("Ingredients")[id]
            end,
            GetRecord = function(object)
                return records[object]
            end,
            Consume = function(object)
                local record = records[object]
                records[object] = nil
                return record ~= nil
            end,
            CreateVisual = function()
                return if failVisual then nil else instance("Part")
            end,
            Spawn = function()
                return instance("Part")
            end,
        },
        TycoonService = {
            GetSessionId = function(p)
                return sessions[p]
            end,
            GetPlot = function(owner)
                return fixtures[owner]
            end,
            GetFixtures = function(plot)
                return { plot }
            end,
            GetOwner = function(fixture)
                while fixture and not fixture.Owner do
                    fixture = fixture.Parent
                end
                return fixture and fixture.Owner
            end,
            ValidateActor = function(p, context)
                return context.PlotSessionId == sessions[p] and context.MembershipRevision == 1
            end,
        },
    })
    local function player()
        local p = instance("Player")
        p.Near = true
        p.CharacterRemoving = signal()
        p.Character = instance("Model")
        local root = instance("Part")
        root.Name, root.Parent = "HumanoidRootPart", p.Character
        local humanoid = instance("Humanoid")
        humanoid.Parent, humanoid.Health, humanoid.Died = p.Character, 100, signal()
        function humanoid:EquipTool(tool)
            for _, current in p.Character:GetChildren() do
                if current:IsA("Tool") and current ~= tool then
                    current.Parent = p:FindFirstChildOfClass("Backpack")
                    current.Unequipped:Fire()
                end
            end
            tool.Parent = p.Character
            tool.Equipped:Fire()
        end
        local backpack = instance("Backpack")
        backpack.Parent = p
        local fixture = instance("Model")
        fixture.Owner = p
        fixtures[p] = fixture
        sessions[p] = tostring(#allInstances)
        for index = 1, 5 do
            local slot = instance("Part")
            slot.Parent = fixture
            slot:SetAttribute("SlotIndex", index)
        end
        inventory.AddPlayer(p)
        return p
    end
    local function carry(p, id, ripeValue)
        local object = instance("Part")
        local ingredientId = id or "Strawberry"
        local item = loadModule("IngredientItem").New(ingredientId, tostring(#allInstances))
        item.IsRipe = ripeValue ~= nil
        records[object] = { Id = ingredientId, Claimable = true, Item = item }
        setup(inventory.CarryWorldItem(p, object), "fixture pickup")
    end
    local function seed(p, index, amount, id)
        for _ = 1, amount do
            carry(p, id)
            setup(inventory.Deposit(p, id or "Strawberry", index), "fixture deposit")
        end
    end
    local function press(p, action, index, owner)
        now += 0.1
        return inventory.InteractStash(p, index or 3, owner or p, nil, action)
    end
    local function stored(p, index)
        return inventory.GetSnapshot(p).Stash[index or 3].Count
    end

    local definitions = loadModule("Ingredients")
    local valueOwner, valueThief = player(), player()
    seed(valueOwner, 3, 1, "Mango")
    carry(valueOwner, "Banana")
    setup(inventory.Deposit(valueOwner, "Banana", 3), "store Banana beside Mango")
    check(
        inventory.GetSnapshot(valueOwner).Stash[3].Value == definitions.Mango.Value + definitions.Banana.Value,
        "STORE rebuilds mixed ingredient total"
    )
    check(inventory.Withdraw(valueOwner, 3), "take one item from mixed slot")
    check(
        inventory.GetSnapshot(valueOwner).Stash[3].Value == definitions.Banana.Value,
        "TAKE rebuilds from remaining Banana"
    )
    inventory.ClearHeld(valueOwner)
    carry(valueOwner, "Mango")
    setup(inventory.Deposit(valueOwner, "Mango", 3), "restore mixed slot for theft")
    check(inventory.Steal(valueThief, valueOwner, 3), "steal from mixed slot")
    check(
        inventory.GetSnapshot(valueOwner).Stash[3].Value == definitions.Mango.Value,
        "steal rebuilds owner's remaining value"
    )
    local ripeOwner = player()
    carry(ripeOwner, "Strawberry", 3750)
    setup(inventory.Deposit(ripeOwner, "Strawberry", 3), "store ripe effective value")
    seed(ripeOwner, 3, 2, "Strawberry")
    check(
        inventory.GetSnapshot(ripeOwner).Stash[3].Value == definitions.Strawberry.Value * 3.25,
        "same-ID items retain separate effective values"
    )

    local protectedOwner = player()
    carry(protectedOwner, "Milk")
    check(press(protectedOwner, "STORE", 1), "protected slot accepts one ingredient")
    check(
        stored(protectedOwner, 1) == 1 and inventory.GetSnapshot(protectedOwner).Stash[1].Capacity == 1,
        "protected ingredient capacity is one"
    )
    carry(protectedOwner, "Banana")
    check(
        not press(protectedOwner, "STORE", 1) and inventory.GetCarryCount(protectedOwner) == 1,
        "second protected ingredient rejected without loss"
    )
    check(press(protectedOwner, "STORE", 3), "exposed slot retains capacity three")
    check(inventory.GetSnapshot(protectedOwner).Stash[3].Capacity == 3, "exposed capacity remains three")

    local p = player()
    for _ = 1, 3 do
        carry(p)
    end
    for n = 1, 3 do
        check(press(p, "STORE"), "repeated STORE succeeds")
        check(stored(p) == n and inventory.GetCarryCount(p) == 3 - n, "one unit per STORE")
        now += 0.9
    end
    check(not press(p, "STORE") and stored(p) == 3, "exhausted STORE never takes")
    for n = 1, 3 do
        check(press(p, "TAKE"), "repeated TAKE succeeds while carrying")
        check(stored(p) == 3 - n and inventory.GetCarryCount(p) == n, "one unit per TAKE")
        now += 0.9
    end
    check(not press(p, "TAKE") and stored(p) == 0, "exhausted TAKE never stores")
    check(press(p, "STORE") and press(p, "TAKE"), "switching actions works immediately")
    check(press(p, "STORE") and press(p, "STORE") and press(p, "STORE"), "rapid taps store exact units")
    check(
        not press(p, "STORE") and stored(p) == 3 and inventory.GetCarryCount(p) == 0,
        "rapid exhausted STORE preserves all units"
    )
    check(press(p, "TAKE") and press(p, "TAKE") and press(p, "TAKE"), "rapid taps take exact units")
    check(
        not press(p, "TAKE") and stored(p) == 0 and inventory.GetCarryCount(p) == 3,
        "rapid exhausted TAKE preserves all units"
    )

    p = player()
    seed(p, 3, 1, "Cabbage")
    seed(p, 4, 1, "Banana")
    seed(p, 5, 2, "Milk")
    check(press(p, "TAKE"), "take first slot")
    check(not press(p, "TAKE", 2) and stored(p, 2) == 0, "empty slot never stores carried item")
    check(press(p, "TAKE", 4) and inventory.GetHeldIngredientId(p) == "Banana", "next slot takes Banana")
    check(press(p, "TAKE", 5) and inventory.GetHeldIngredientId(p) == "Milk", "next slot takes Milk")
    check(not press(p, "TAKE", 5) and stored(p, 5) == 1, "full carry preserves stash")

    p = player()
    seed(p, 3, 2)
    carry(p)
    carry(p)
    check(press(p, "STORE") and stored(p) == 3, "store reaches exposed capacity")
    check(
        not press(p, "STORE") and stored(p) == 3 and inventory.GetCarryCount(p) == 1,
        "full slot rejects without reversing or losing carry"
    )
    p.Near = false
    check(not press(p, "TAKE") and stored(p) == 3, "distance validation retained")
    p.Near = true
    p.Character:FindFirstChildOfClass("Humanoid").Health = 0
    check(not press(p, "TAKE"), "dead character rejected")
    p.Character:FindFirstChildOfClass("Humanoid").Health = 100
    check(not press(p, "TAKE", 6), "invalid slot rejected")
    check(
        not press(p, "AUTO") and not inventory.InteractStash(p, 3, p, nil, nil),
        "invalid or missing action fails closed"
    )

    p = player()
    carry(p, "Banana")
    carry(p)
    carry(p)
    check(press(p, "STORE") and press(p, "STORE") and press(p, "STORE"), "STORE selects successive carried ingredients")
    local mixed = inventory.GetSnapshot(p).Stash[3]
    check(
        mixed.Ingredients[1].IngredientId == "Strawberry" and mixed.Ingredients[3].IngredientId == "Banana",
        "mixed ingredients retain individual records"
    )
    mixed.Ingredients[1].IngredientId = "Milk"
    now += 1.2
    check(
        press(p, "TAKE") and inventory.GetHeldIngredientId(p) == "Strawberry",
        "snapshot cannot mutate stored identity"
    )

    local guarded = player()
    seed(guarded, 3, 2)
    local reentrant = false
    local guardConnection = inventory.StashChanged:Connect(function(owner)
        if owner == guarded then
            reentrant = inventory.InteractStash(guarded, 3, guarded, nil, "TAKE")
        end
    end)
    check(
        press(guarded, "TAKE") and not reentrant and stored(guarded) == 1 and inventory.GetCarryCount(guarded) == 1,
        "reentrant transfer cannot duplicate processing"
    )
    guardConnection:Disconnect()

    local ripest = player()
    seed(ripest, 3, 1, "Banana")
    now += 30
    seed(ripest, 3, 1, "Milk")
    now += 20
    seed(ripest, 3, 1, "Strawberry")
    check(press(ripest, "TAKE") and inventory.GetHeldIngredientId(ripest) == "Banana", "TAKE withdraws ripest first")
    check(
        press(ripest, "TAKE") and inventory.GetHeldIngredientId(ripest) == "Milk",
        "remaining ripeness ordering preserved"
    )

    local owner, enemy, secondEnemy, teammate = player(), player(), player(), player()
    fixtures[teammate], sessions[teammate] = fixtures[owner], sessions[owner]
    carry(teammate, "Milk")
    check(press(teammate, "STORE", 1, owner), "teammate stores into owner's permanent slot")
    now += 1.2
    check(press(teammate, "TAKE", 1, owner), "teammate withdraws from owner's permanent slot")
    inventory.ClearHeld(teammate)
    seed(owner, 1, 1)
    seed(owner, 3, 2)
    seed(owner, 4, 1, "Banana")
    seed(owner, 4, 1, "Milk")
    seed(owner, 5, 1, "Milk")
    carry(enemy, "Milk")
    check(not press(enemy, "STORE", 3, owner) and stored(owner, 3) == 2, "enemy STORE rejects without taking")
    inventory.ClearHeld(enemy)
    enemy.Near = false
    check(not press(enemy, "TAKE", 3, owner), "enemy must be near actual slot")
    enemy.Near = true
    enemy.Character:FindFirstChildOfClass("Humanoid").Health = 0
    check(not press(enemy, "TAKE", 3, owner), "dead enemy cannot steal")
    enemy.Character:FindFirstChildOfClass("Humanoid").Health = 100
    loadModule("MovementService").SetStunned(enemy, true)
    check(not press(enemy, "TAKE", 3, owner), "stunned enemy cannot steal")
    loadModule("MovementService").SetStunned(enemy, false)
    check(
        not inventory.InteractStash(enemy, 3, owner, fixtures[enemy], "TAKE"),
        "wrong source fixture cannot redirect interaction"
    )
    local duplicate = instance("Part")
    duplicate:SetAttribute("SlotIndex", 3)
    duplicate.Parent = fixtures[owner]
    check(not press(enemy, "TAKE", 3, owner), "duplicate authored slot fails closed")
    duplicate:Destroy()
    failVisual = true
    check(not press(enemy, "TAKE", 3, owner) and stored(owner, 3) == 2, "failed visual creation preserves stash")
    check(inventory.GetStashRaidState(owner).State == "Normal", "failed theft does not start raid")
    failVisual = false
    local backpack = enemy:FindFirstChildOfClass("Backpack")
    backpack.Parent = nil
    check(not press(enemy, "TAKE", 4, owner) and stored(owner, 4) == 2, "failed equip restores exact slot")
    check(inventory.GetStashRaidState(owner).State == "Normal", "failed equip does not start raid")
    local restored = inventory.GetSnapshot(owner).Stash[4].Ingredients
    check(
        restored[1].IngredientId == "Banana" and restored[2].IngredientId == "Milk",
        "failed equip preserves mixed records and order in exact slot"
    )
    backpack.Parent = enemy
    check(press(enemy, "TAKE", 3, owner), "first successful theft starts raid")
    local deadline = inventory.GetStashRaidState(owner).RaidEndsAt
    check(
        press(enemy, "TAKE", 4, owner) and press(enemy, "TAKE", 5, owner),
        "enemy keeps TAKE across mixed slots while carrying stolen items"
    )
    check(not press(enemy, "TAKE", 4, owner), "enemy carry capacity enforced")
    check(press(secondEnemy, "TAKE", 4, owner), "other enemies share the raid window")
    check(inventory.GetStashRaidState(owner).RaidEndsAt == deadline, "later theft never extends deadline")
    check(not press(secondEnemy, "TAKE", 1, owner), "permanent protection also holds during raid")
    now = deadline
    check(not inventory.Withdraw(secondEnemy, 3, owner), "protection begins exactly at raid deadline")
    check(inventory.GetStashRaidState(owner).State == "Protected", "stash reports temporary protection")
    carry(teammate, "Milk")
    check(press(teammate, "STORE", 5, owner), "team can store during protection")
    now += 1.2
    check(press(teammate, "TAKE", 5, owner), "team can take during protection")
    fixtures[teammate], sessions[teammate] = nil, nil
    check(not inventory.Withdraw(teammate, 1, owner), "departed teammate has no friendly access")
    now = deadline + 30
    check(inventory.Withdraw(secondEnemy, 3, owner), "exposed slot reopens exactly at protection expiry")
    check(not inventory.Withdraw(secondEnemy, 1, owner), "permanent slots stay protected after expiry")
    local oldSession = sessions[owner]
    inventory.CleanupSession(oldSession)
    sessions[owner] = oldSession .. "-new"
    check(inventory.GetStashRaidState(owner).State == "Normal", "new plot session cannot inherit raid state")
    now += 100
    check(inventory.GetStashRaidState(owner).State == "Normal", "old deadlines cannot mutate new session")
    -- Exercise the network entry point with the actual authored focus prompt.
    p = player()
    seed(p, 3, 3)
    local fixture = fixtures[p]
    fixture.Parent = workspaceFake
    local slot = fixture:GetChildren()[3]
    local origin = instance("Attachment")
    origin.Name, origin.Parent = "StashPromptOrigin", slot
    local cleanup
    cache.WorldUtil.BindTag = function(tag, bind)
        check(tag == "PlayerStash", "component binds stash tag")
        cleanup = bind(fixture)
    end
    local component = assert(loadstring(sources.StashComponent))
    setfenv(
        component,
        setmetatable({
            script = {
                Parent = {
                    Parent = { Services = { WorldUtil = "WorldUtil", StashSlots = "StashSlots" } },
                    StashPresentation = "TestStashPresentation",
                },
            },
        }, { __index = env })
    )
    cache.TestStashPresentation = { Refresh = function() end, Clear = function() end }
    component().Init({
        InventoryService = inventory,
        TycoonService = {
            GetOwner = function()
                return p
            end,
        },
        IngredientService = {},
    })
    local prompt = slot:FindFirstChild("StashPrompt")
    check(
        prompt.Style == env.Enum.ProximityPromptStyle.Custom
            and prompt.KeyboardKeyCode == env.Enum.KeyCode.E
            and prompt.ActionText == "STASH"
            and slot:FindFirstChild("StashPromptOrigin") == origin,
        "stash prompt retains slot identity and stable focus label"
    )
    local context =
        { PlotSessionId = sessions[p], MembershipRevision = 1, TargetSessionId = sessions[p], RequestId = 1 }
    check(inventory.RequestStash(p, prompt, "TAKE", context), "network TAKE transfers one unit")
    check(
        not inventory.RequestStash(p, prompt, "TAKE", context) and stored(p) == 2,
        "replayed request cannot transfer twice"
    )
    context.RequestId = 2
    check(
        not inventory.RequestStash(p, prompt, "STORE", context) and stored(p) == 2,
        "same-frame request throttled without direction switching"
    )
    now += 0.1
    context.RequestId = 3
    check(inventory.RequestStash(p, prompt, "TAKE", context), "rapid next tap accepted")
    now += 0.1
    context.RequestId = 4
    check(inventory.RequestStash(p, prompt, "TAKE", context), "third tap still takes")
    check(inventory.GetCarryCount(p) == 3 and stored(p) == 0, "network taps conserve exact items")
    context.TargetSessionId = "stale"
    check(
        not inventory.RequestStash(p, prompt, "STORE", context) and stored(p) == 0,
        "recycled target context rejected"
    )
    context.TargetSessionId = sessions[p]
    context.MembershipRevision = 0
    check(not inventory.RequestStash(p, prompt, "STORE", context), "stale actor membership rejected")
    context.MembershipRevision = 1
    context.RequestId = 5
    check(not inventory.RequestStash(p, prompt, "AUTO", context), "invalid network action rejected")
    cleanup()
    check(slot:FindFirstChild("StashPromptOrigin") == origin, "component cleanup preserves authored origin")
    local promoted = false
    local promotionConnection = inventory.StashChanged:Connect(function(owner)
        if owner == ripeOwner then
            promoted = true
        end
    end)
    now += 120
    heartbeat:Fire(1)
    check(
        promoted and inventory.GetSnapshot(ripeOwner).Stash[3].Value == definitions.Strawberry.Value * 3.75,
        "ripeness promotion refreshes slot total"
    )
    promotionConnection:Disconnect()
    print("PASS stash interaction: " .. (count - before) .. " checks")
end
