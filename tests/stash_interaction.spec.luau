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
    }
    local inventory = loadModule("InventoryService")
    local records = {}
    local fixtures = {}
    inventory.Init({
        PlayerDataService = {
            GetUpgrade = function(_, name)
                return if name == "CarryCapacity" then 3 else 1
            end,
        },
        IngredientService = {
            GetDefinition = function(id)
                return id == "Strawberry" or id == "Banana"
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
                return instance("Part")
            end,
            Spawn = function()
                return instance("Part")
            end,
        },
        TycoonService = {
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
        p.Character = instance("Model")
        local root = instance("Part")
        root.Name, root.Parent = "HumanoidRootPart", p.Character
        local humanoid = instance("Humanoid")
        humanoid.Parent, humanoid.Health, humanoid.Died = p.Character, 100, signal()
        function humanoid:EquipTool(tool)
            tool.Parent = p.Character
        end
        local backpack = instance("Backpack")
        backpack.Parent = p
        local fixture = instance("Model")
        fixture.Owner = p
        fixtures[p] = fixture
        for index = 1, 5 do
            local slot = instance("Part")
            slot.Parent = fixture
            slot:SetAttribute("SlotIndex", index)
        end
        inventory.AddPlayer(p)
        return p
    end
    local function carry(p, id)
        local object = instance("Part")
        records[object] = { Id = id or "Strawberry", Claimable = true }
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

    local p = player()
    for _ = 1, 3 do
        carry(p)
    end
    for n = 1, 3 do
        check(press(p), "A: rapid store succeeds")
        check(stored(p) == n and inventory.GetCarryCount(p) == 3 - n, "A: one unit stored each press")
    end
    check(not press(p) and stored(p) == 3 and inventory.GetCarryCount(p) == 0, "C: exhausted store never reverses")
    check(press(p) and stored(p) == 2, "C: later press can establish TAKE")
    for _ = 1, 2 do
        check(press(p), "take continuation")
    end
    check(not press(p) and stored(p) == 0 and inventory.GetCarryCount(p) == 3, "D: full take never reverses")

    p = player()
    seed(p, 3, 5)
    for n = 1, 3 do
        check(press(p), "B: rapid take succeeds")
        check(stored(p) == 5 - n and inventory.GetCarryCount(p) == n, "B: one unit taken each press")
    end
    check(not press(p) and stored(p) == 2 and inventory.GetCarryCount(p) == 3, "H: carry capacity remains three")

    p = player()
    seed(p, 3, 2)
    check(press(p), "E: establish TAKE")
    now += 0.91
    check(press(p) and stored(p) == 2 and inventory.GetCarryCount(p) == 0, "E: timeout reselects STORE")
    now += 0.91
    check(press(p) and stored(p) == 1, "E: timeout reselects TAKE")
    -- The idle window slides after each successful press, rather than starting once.
    now += 0.6
    check(press(p) and stored(p) == 0, "E: refreshed burst still takes after total duration exceeds timeout")

    p = player()
    seed(p, 3, 2)
    check(press(p), "F: establish TAKE on slot three")
    check(press(p, 4) and stored(p, 4) == 1, "F: switching slots establishes STORE")
    check(press(p, 3) and stored(p) == 0, "F: returning to old slot establishes fresh TAKE")

    local a, b = player(), player()
    for _ = 1, 3 do
        carry(a)
    end
    seed(b, 3, 5)
    for _ = 1, 3 do
        check(press(a), "G: player A keeps STORE")
        check(press(b), "G: player B keeps TAKE")
    end
    check(stored(a) == 3 and stored(b) == 2, "G: independent player results")
    check(not press(a, 3, b), "G: changing stash owner resets old direction and rejects theft")

    p = player()
    seed(p, 3, 4)
    carry(p)
    carry(p)
    check(press(p) and stored(p) == 5, "H: store reaches stash capacity")
    check(
        not press(p) and stored(p) == 5 and inventory.GetCarryCount(p) == 1,
        "H: full stash rejects without reversing"
    )
    inventory.ClearHeld(p)
    carry(p, "Banana")
    check(not press(p) and stored(p) == 5, "H: incompatible ingredient rejected")
    inventory.ClearHeld(p)
    p.Near = false
    check(not press(p) and stored(p) == 5, "H: distance validation retained")
    p.Near = true
    p.Character:FindFirstChildOfClass("Humanoid").Health = 0
    check(not press(p), "H: dead character rejected")
    p.Character:FindFirstChildOfClass("Humanoid").Health = 100
    local stranger = player()
    seed(p, 1, 1)
    check(not press(stranger, 1, p), "H: protected withdrawal rejected")
    check(not press(stranger, 3, p), "H: unprotected theft remains disabled")
    carry(stranger)
    check(not press(stranger, 4, p) and stored(p, 4) == 0, "H: foreign deposit rejected")
    check(not press(p, 6), "H: invalid slot rejected")

    p = player()
    carry(p, "Banana")
    carry(p)
    carry(p)
    check(press(p) and press(p), "selected ingredient stores repeatedly")
    check(
        not press(p) and inventory.GetHeldIngredientId(p) == "Banana" and stored(p) == 2,
        "ingredient change ends STORE without selecting another ingredient"
    )
    inventory.ClearHeld(p)
    now += 1
    check(press(p), "establish TAKE before replacing slot contents")
    inventory.ClearHeld(p)
    check(inventory.Withdraw(p, 3), "external withdrawal empties slot")
    inventory.ClearHeld(p)
    seed(p, 3, 1, "Banana")
    check(
        not press(p) and inventory.GetCarryCount(p) == 0 and stored(p) == 1,
        "TAKE does not switch ingredients when slot contents change"
    )
    -- Exercise the actual prompt callback, not just the service entry point.
    p = player()
    seed(p, 3, 5)
    local fixture = fixtures[p]
    fixture.Parent = workspaceFake
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
                    Parent = { Services = { WorldUtil = "WorldUtil" } },
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
    local prompt = fixture:GetChildren()[3]:FindFirstChild("StashPrompt")
    for _ = 1, 3 do
        now += 0.1
        prompt.Triggered:Fire(p)
    end
    check(inventory.GetCarryCount(p) == 3 and stored(p) == 2, "actual prompt preserves TAKE for three presses")
    cleanup()
    print("PASS stash interaction: " .. (count - before) .. " checks")
end
