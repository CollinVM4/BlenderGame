local display = loadModule("StashPresentation")
env.CFrame.fromMatrix = function(position, right, up, back)
    local cf = frame(position.X, position.Y, position.Z)
    cf.RightVector, cf.UpVector, cf.LookVector = right, up, back * -1
    return cf
end

-- Authored capacity readouts follow snapshots and only change part colors.
do
    local visuals = {
        CreateVisual = function()
            return nil
        end,
    }
    local function expectColors(indicators, filled)
        for index, part in indicators do
            local expected = if index <= filled then env.Color3.fromRGB(0, 255, 0) else env.Color3.fromRGB(117, 0, 0)
            check(
                part.Color.R == expected.R and part.Color.G == expected.G and part.Color.B == expected.B,
                "indicator color follows authoritative occupancy in local left-to-right order"
            )
        end
    end
    local function snapshot(count, capacity)
        return {
            ItemType = "Ingredient",
            IngredientId = "Apple",
            Count = count,
            Capacity = capacity,
            Value = 0,
            Ingredients = table.create(count, { IngredientId = "Apple" }),
        }
    end
    for _, slotIndex in { 1, 2, 3, 4, 5, 6 } do
        local model = instance("Model")
        model.Name = if slotIndex <= 2 then "LockedSlot" .. slotIndex else "Slot" .. slotIndex
        local pad = instance("Part")
        pad.Parent = model
        pad:SetAttribute("StashLogicalSlotIndex", slotIndex)
        pad.CFrame = frame(10, 4, 20)
        pad.Position = pad.CFrame.Position
        pad.CFrame.RightVector = vec(0, 0, -1)
        pad.CFrame.LookVector = vec(-1, 0, 0)
        local capacity = if slotIndex <= 2 then 1 else 3
        local indicators, authored = {}, {}
        -- Reverse creation order and rotate the base to exercise visual sorting.
        for index = capacity + 1, 1, -1 do
            local part = instance("Part")
            part.Name = "SlotIndicator"
            part.Parent = model
            part.Position = pad.Position + pad.CFrame.RightVector * index
            part.CFrame = frame(part.Position)
            part.Material = "AuthoredMaterial"
            indicators[index] = part
            authored[index] = { part.Position, part.CFrame, part.Size, part.Material }
        end
        local decoy = instance("Folder")
        decoy.Name, decoy.Parent = "SlotIndicator", model
        display.Refresh(pad, nil, visuals)
        expectColors(indicators, 0)
        for _, count in { 1, capacity, math.max(0, capacity - 1), 0 } do
            local state = snapshot(count, capacity)
            display.Refresh(pad, state, visuals)
            expectColors(indicators, count)
            check(state.Capacity == capacity and state.Count == count, "indicator count cannot change stash rules")
        end
        for index, part in indicators do
            local original = authored[index]
            check(
                part.Position == original[1]
                    and part.CFrame == original[2]
                    and part.Size == original[3]
                    and part.Material == original[4],
                "indicator refresh preserves authored geometry and material"
            )
        end
        -- Fewer indicators than stored items safely fills just the remaining parts.
        for index = 2, #indicators do
            indicators[index]:Destroy()
        end
        display.Refresh(pad, snapshot(capacity, capacity), visuals)
        expectColors({ indicators[1] }, 1)
        for _, malformed in
            {
                false,
                { Count = "invalid" },
                { Count = 1, IngredientId = "Apple" },
                { Count = 1, IngredientId = "Apple", Ingredients = { false } },
            }
        do
            display.Refresh(pad, malformed, visuals)
            expectColors({ indicators[1] }, 0)
        end
        display.Refresh(pad, nil, visuals)
        expectColors({ indicators[1] }, 0)
        model:Destroy()
    end
    local standalone = instance("Part")
    local sharedContainer = instance("Model")
    sharedContainer.Name = "PlayerStash"
    standalone.Parent = sharedContainer
    local otherSlot = instance("Part")
    otherSlot.Parent = sharedContainer
    local otherIndicator = instance("Part")
    otherIndicator.Name, otherIndicator.Parent = "SlotIndicator", otherSlot
    local authoredColor = env.Color3.fromRGB(10, 20, 30)
    otherIndicator.Color = authoredColor
    local nested = instance("Folder")
    nested.Parent = standalone
    local indicator = instance("Part")
    indicator.Name, indicator.Parent = "SlotIndicator", nested
    display.Refresh(standalone, snapshot(1, 3), visuals)
    expectColors({ indicator }, 1)
    check(otherIndicator.Color == authoredColor, "refresh only paints indicators belonging to this slot")
    indicator:Destroy()
    display.Refresh(standalone, snapshot(2, 3), visuals)
    display.Refresh(nil, nil, visuals)
    sharedContainer:Destroy()
end
