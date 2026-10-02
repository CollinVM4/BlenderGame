-- Real InventoryService transfers with fake character/world boundaries and clock.
do
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
                return fixture.Owner
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
    local function press(p, index, owner)
        now += 0.1
        return inventory.InteractStash(p, index or 3, owner or p)
    end
    local function stored(p, index)
        return inventory.GetSnapshot(p).Stash[index or 3].Count
    end

    local valueOwner, valueThief = player(), player()
    seed(valueOwner, 3, 1, "Mango")
    carry(valueOwner, "Banana")
    setup(inventory.Deposit(valueOwner, "Banana", 3), "store Banana beside Mango")
    check(inventory.GetSnapshot(valueOwner).Stash[3].Value == 22000, "STORE rebuilds $20K plus $2K")
    check(inventory.Withdraw(valueOwner, 3), "take one item from mixed slot")
    check(inventory.GetSnapshot(valueOwner).Stash[3].Value == 2000, "TAKE rebuilds from remaining Banana")
    inventory.ClearHeld(valueOwner)
    carry(valueOwner, "Mango")
    setup(inventory.Deposit(valueOwner, "Mango", 3), "restore mixed slot for theft")
    check(inventory.Steal(valueThief, valueOwner, 3), "steal from mixed slot")
    check(inventory.GetSnapshot(valueOwner).Stash[3].Value == 20000, "steal rebuilds owner's remaining value")
    local ripeOwner = player()
    carry(ripeOwner, "Strawberry", 3750)
    setup(inventory.Deposit(ripeOwner, "Strawberry", 3), "store ripe effective value")
    seed(ripeOwner, 3, 2, "Strawberry")
    check(inventory.GetSnapshot(ripeOwner).Stash[3].Value == 9750, "same-ID items retain separate effective values")

    local protectedOwner = player()
    carry(protectedOwner, "Milk")
    check(inventory.Deposit(protectedOwner, "Milk", 1), "empty protected slot accepts one ingredient")
    check(
        stored(protectedOwner, 1) == 1 and inventory.GetSnapshot(protectedOwner).Stash[1].Capacity == 1,
        "protected ingredient capacity is one"
    )
    carry(protectedOwner, "Banana")
    check(not inventory.Deposit(protectedOwner, "Banana", 1), "occupied protected slot rejects another ingredient")
    check(
        stored(protectedOwner, 1) == 1 and inventory.GetCarryCount(protectedOwner) == 1,
        "rejected deposit retains carried ingredient"
    )
    check(inventory.Deposit(protectedOwner, "Banana", 3), "unprotected slot accepts ingredient")
    check(inventory.GetSnapshot(protectedOwner).Stash[3].Capacity == 3, "unprotected stack capacity remains three")

    local p = player()
    for _ = 1, 3 do
        carry(p)
    end
    for n = 1, 3 do
        check(press(p), "A: rapid store succeeds")
        check(stored(p) == n and inventory.GetCarryCount(p) == 3 - n, "A: one unit stored each press")
    end
    check(not press(p) and stored(p) == 3 and inventory.GetCarryCount(p) == 0, "C: exhausted store never reverses")
    check(not press(p) and stored(p) == 3, "C: repeated failed STORE preserves direction")
    now += 1.11
    check(press(p) and stored(p) == 2, "C: later press can establish TAKE")
    for _ = 1, 2 do
        check(press(p), "take continuation")
    end
    check(not press(p) and stored(p) == 0 and inventory.GetCarryCount(p) == 3, "D: full take never reverses")

    p = player()
    seed(p, 3, 3)
    for n = 1, 3 do
        check(press(p), "B: rapid take succeeds")
        check(stored(p) == 3 - n and inventory.GetCarryCount(p) == n, "B: one unit taken each press")
    end
    check(not press(p) and stored(p) == 0 and inventory.GetCarryCount(p) == 3, "H: carry capacity remains three")

    p = player()
    seed(p, 3, 2)
    check(press(p), "E: establish TAKE")
    now += 1.11
    check(press(p) and stored(p) == 2 and inventory.GetCarryCount(p) == 0, "E: timeout reselects STORE")
    now += 1.11
    check(press(p) and stored(p) == 1, "E: timeout reselects TAKE")
    -- The idle window slides after each successful press, rather than starting once.
    now += 0.4
    check(press(p) and stored(p) == 0, "E: refreshed burst still takes after total duration exceeds timeout")

    p = player()
    seed(p, 3, 1, "Cabbage")
    seed(p, 4, 1, "Banana")
    seed(p, 5, 2, "Milk")
    check(press(p), "F: establish TAKE on slot three")
    check(not press(p, 2) and not press(p, 2) and stored(p, 2) == 0, "F: empty slot never reverses TAKE")
    check(press(p, 4) and inventory.GetHeldIngredientId(p) == "Banana", "F: next slot takes Banana immediately")
    check(press(p, 5) and inventory.GetHeldIngredientId(p) == "Milk", "F: next slot takes Milk immediately")
    check(stored(p, 3) == 0 and stored(p, 4) == 0 and stored(p, 5) == 1, "F: TAKE uses each slot's item")
    check(not press(p, 5) and not press(p, 5) and stored(p, 5) == 1, "F: full inventory never reverses TAKE")

    local a, b = player(), player()
    for index = 3, 5 do
        seed(a, index, 1)
        seed(b, index, 2)
    end
    for _ = 1, 3 do
        carry(a)
    end
    for index = 3, 5 do
        check(press(a, index) and stored(a, index) == 2, "G: player A keeps STORE across occupied slots")
        check(press(b, index) and stored(b, index) == 1, "G: player B keeps TAKE across slots")
    end
    check(inventory.GetCarryCount(a) == 0 and inventory.GetCarryCount(b) == 3, "G: independent player directions")
    check(not press(a, 1, b), "G: foreign protected stash rejects theft")
    check(not press(a, 4) and not press(a, 5), "G: exhausted STORE survives foreign and own slot switches")

    p = player()
    seed(p, 3, 2)
    carry(p)
    carry(p)
    check(press(p) and stored(p) == 3, "H: store reaches stash capacity")
    check(
        not press(p) and stored(p) == 3 and inventory.GetCarryCount(p) == 1,
        "H: full stash rejects without reversing"
    )
    inventory.ClearHeld(p)
    carry(p, "Banana")
    check(not press(p) and stored(p) == 3, "H: full mixed ingredient slot rejected")
    inventory.ClearHeld(p)
    p.Near = false
    check(not press(p) and stored(p) == 3, "H: distance validation retained")
    p.Near = true
    p.Character:FindFirstChildOfClass("Humanoid").Health = 0
    check(not press(p), "H: dead character rejected")
    p.Character:FindFirstChildOfClass("Humanoid").Health = 100
    local stranger = player()
    seed(p, 1, 1)
    check(not press(stranger, 1, p), "H: protected withdrawal rejected")
    check(press(stranger, 3, p), "H: unprotected theft succeeds")
    carry(stranger)
    check(not press(stranger, 4, p) and stored(p, 4) == 0, "H: foreign deposit rejected")
    check(not press(p, 6), "H: invalid slot rejected")

    p = player()
    carry(p, "Banana")
    carry(p)
    carry(p)
    check(press(p) and press(p), "selected ingredient stores repeatedly")
    check(press(p) and stored(p) == 3, "STORE accepts a different ingredient into the same slot")
    local mixed = inventory.GetSnapshot(p).Stash[3]
    check(
        mixed.Ingredients[1].IngredientId == "Strawberry" and mixed.Ingredients[3].IngredientId == "Banana",
        "mixed ingredients retain individual records"
    )
    mixed.Ingredients[1].IngredientId = "Milk"
    now += 1.2
    check(press(p) and inventory.GetHeldIngredientId(p) == "Strawberry", "snapshot mutation cannot alter stored record")

    local owner, enemy, secondEnemy, teammate = player(), player(), player(), player()
    fixtures[teammate], sessions[teammate] = fixtures[owner], sessions[owner]
    carry(teammate, "Milk")
    check(press(teammate, 1, owner), "teammate stores into owner's permanent slot")
    now += 1.2
    check(press(teammate, 1, owner), "teammate withdraws from owner's permanent slot")
    inventory.ClearHeld(teammate)
    seed(owner, 1, 1)
    seed(owner, 3, 2)
    seed(owner, 4, 1, "Banana")
    seed(owner, 4, 1, "Milk")
    seed(owner, 5, 1, "Milk")
    enemy.Near = false
    check(not press(enemy, 3, owner), "enemy must be near actual slot")
    enemy.Near = true
    enemy.Character:FindFirstChildOfClass("Humanoid").Health = 0
    check(not press(enemy, 3, owner), "dead enemy cannot steal")
    enemy.Character:FindFirstChildOfClass("Humanoid").Health = 100
    loadModule("MovementService").SetStunned(enemy, true)
    check(not press(enemy, 3, owner), "stunned enemy cannot steal")
    loadModule("MovementService").SetStunned(enemy, false)
    check(
        not inventory.InteractStash(enemy, 3, owner, fixtures[enemy]),
        "wrong source fixture cannot redirect interaction"
    )
    local duplicate = instance("Part")
    duplicate:SetAttribute("SlotIndex", 3)
    duplicate.Parent = fixtures[owner]
    check(not press(enemy, 3, owner), "duplicate authored slot fails closed")
    duplicate:Destroy()
    failVisual = true
    check(not press(enemy, 3, owner) and stored(owner, 3) == 2, "failed visual creation preserves stash")
    check(inventory.GetStashRaidState(owner).State == "Normal", "failed theft does not start raid")
    failVisual = false
    local backpack = enemy:FindFirstChildOfClass("Backpack")
    backpack.Parent = nil
    check(not press(enemy, 4, owner) and stored(owner, 4) == 2, "failed equip restores exact slot")
    check(inventory.GetStashRaidState(owner).State == "Normal", "failed equip does not start raid")
    local restored = inventory.GetSnapshot(owner).Stash[4].Ingredients
    check(
        restored[1].IngredientId == "Banana" and restored[2].IngredientId == "Milk",
        "failed equip preserves mixed records and order in exact slot"
    )
    backpack.Parent = enemy
    check(press(enemy, 3, owner), "first successful theft starts raid")
    local deadline = inventory.GetStashRaidState(owner).RaidEndsAt
    check(
        press(enemy, 4, owner) and press(enemy, 5, owner),
        "enemy keeps TAKE across mixed slots while carrying stolen items"
    )
    check(not press(enemy, 4, owner), "enemy carry capacity enforced")
    check(press(secondEnemy, 4, owner), "other enemies share the raid window")
    check(inventory.GetStashRaidState(owner).RaidEndsAt == deadline, "later theft never extends deadline")
    check(not press(secondEnemy, 1, owner), "permanent protection also holds during raid")
    now = deadline
    check(not inventory.Withdraw(secondEnemy, 3, owner), "protection begins exactly at raid deadline")
    check(inventory.GetStashRaidState(owner).State == "Protected", "stash reports temporary protection")
    carry(teammate, "Milk")
    check(press(teammate, 5, owner), "team can store during protection")
    now += 1.2
    check(press(teammate, 5, owner), "team can take during protection")
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
    -- Exercise the actual prompt callback, not just the service entry point.
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
            and prompt:GetAttribute("InteractionOrigin") == "StashPromptOrigin"
            and slot:FindFirstChild("StashPromptOrigin") == origin,
        "stash prompt uses authored origin for shared custom presentation"
    )
    for _ = 1, 3 do
        now += 0.1
        prompt.Triggered:Fire(p)
    end
    check(inventory.GetCarryCount(p) == 3 and stored(p) == 0, "actual prompt preserves TAKE for three presses")
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
        promoted and inventory.GetSnapshot(ripeOwner).Stash[3].Value == 11250,
        "ripeness promotion refreshes slot total"
    )
    promotionConnection:Disconnect()
    print("PASS stash interaction: " .. (count - before) .. " checks")
end
