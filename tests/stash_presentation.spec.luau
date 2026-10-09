local display = loadModule("StashPresentation")
local realIngredients = loadModule("IngredientService")
env.CFrame.fromMatrix = function(position, right, up, back)
    local cf = frame(position.X, position.Y, position.Z)
    cf.RightVector, cf.UpVector, cf.LookVector = right, up, back * -1
    return cf
end
do
    local pad = instance("Part")
    pad:SetAttribute("SlotIndex", 3)
    pad.Position = vec(12, 7, -20)
    pad.Size = vec(0.4, 10, 10)
    pad.CFrame = frame(12, 7, -20)
    for _, sign in { 1, -1 } do
        pad.CFrame.RightVector = vec(0, sign, 0)
        pad.CFrame.UpVector = vec(-sign, 0, 0)
        for n = 1, 3 do
            local items = {}
            for i = 1, n do
                items[i] = { IngredientId = ({ "Strawberry", "Banana", "Milk" })[i] }
            end
            local rendered = {}
            local visuals = {
                CreateVisual = function(id)
                    table.insert(rendered, id)
                    return realIngredients.CreateVisual(id)
                end,
            }
            display.Refresh(
                pad,
                { IngredientId = "Strawberry", Ingredients = items, Count = n, Protected = false, Value = 0 },
                visuals
            )
            for i, item in items do
                check(rendered[i] == item.IngredientId, "each displayed proxy uses its own stored ingredient")
            end
            local total = vec(0, 0, 0)
            local copies = {}
            for _, child in pad:FindFirstChild("StashDisplay"):GetChildren() do
                if child:IsA("Model") then
                    table.insert(copies, child)
                end
            end
            check(#copies == n, "rotated pad count")
            for _, copy in copies do
                local part = copy:FindFirstChildWhichIsA("BasePart", true)
                check(
                    part.Size.X > pad.Size.X and part.Size.X < math.min(pad.Size.Y, pad.Size.Z) / 2,
                    "display uses the usable top face, not thin local X, and leaves spacing between items"
                )
                check(
                    copy.CFrame.UpVector:Dot(vec(0, 1, 0)) > 0.999,
                    "display normal points upward for either axis sign"
                )
                check(
                    copy.Position.Y - part.Size.Y / 2 >= 7.2 + 0.12 - 0.0001,
                    "proxy bottom clears actual top surface"
                )
                total += copy.Position - pad.Position
            end
            check(
                math.abs(total.X) < 0.0001 and math.abs(total.Z) < 0.0001,
                "all count layouts center over rotated pad"
            )
        end
    end
    pad:Destroy()
end

-- Monetary text follows slot snapshots, including duplicate smoothie ingredients.
do
    local pad = instance("Part")
    local visuals = {
        CreateVisual = function()
            return nil
        end,
    }
    local definitions = loadModule("Ingredients")
    local formatter = loadModule("MoneyFormat")
    local ripenessStyle = loadModule("RipenessPresentation")
    local values = loadModule("StashValue")
    local item = loadModule("IngredientItem")
    local function unit(id, ripe)
        local record = item.New(id, id .. "-test")
        record.IsRipe = ripe == true
        return record
    end
    local function textValue()
        return pad:FindFirstChild("StashDisplay"):FindFirstChild("SlotValue"):FindFirstChild("Value").Text
    end
    for _, count in { 1, 3, 2 } do
        local state = {
            ItemType = "Ingredient",
            IngredientId = "Apple",
            Count = count,
            Ingredients = table.create(count, unit("Apple")),
        }
        state.Value = values.Calculate(state)
        display.Refresh(pad, state, visuals)
        check(textValue() == formatter.Compact(definitions.Apple.Value * count), "slot value follows stack quantity")
        check(
            pad:FindFirstChild("StashDisplay"):FindFirstChild("SlotValue").MaxDistance == ripenessStyle.StashMaxDistance,
            "stash value uses nearby visibility range"
        )
    end
    local mixed = {
        ItemType = "Ingredient",
        IngredientId = "Banana",
        Count = 2,
        Ingredients = { unit("Mango"), unit("Banana") },
    }
    check(
        values.Calculate(mixed) == definitions.Mango.Value + definitions.Banana.Value,
        "mixed ingredients sum configured values"
    )
    mixed.Value = values.Calculate(mixed)
    display.Refresh(pad, mixed, visuals)
    check(textValue() == formatter.Compact(mixed.Value), "slot label uses complete mixed total")
    check(values.Calculate({
        ItemType = "Ingredient",
        Ingredients = {
            unit("Banana"),
            unit("Banana"),
            unit("Banana"),
        },
    }) == definitions.Banana.Value * 3, "three physical Bananas total $6K")
    check(
        values.Calculate({
            ItemType = "Ingredient",
            Ingredients = {
                unit("Starfruit"),
                unit("Tire"),
                unit("Banana"),
            },
        }) == definitions.Starfruit.Value + definitions.Tire.Value + definitions.Banana.Value,
        "mixed $10K, $8K and $2K items total $20K"
    )
    local ripe = {
        ItemType = "Ingredient",
        IngredientId = "Strawberry",
        Count = 3,
        Ingredients = {
            unit("Strawberry", true),
            unit("Strawberry"),
            unit("Strawberry"),
        },
    }
    check(
        values.Calculate(ripe) == definitions.Strawberry.Value * 3.25,
        "individual effective values sum before rounding"
    )
    ripe.Value = values.Calculate(ripe)
    display.Refresh(pad, ripe, visuals)
    check(textValue() == formatter.Compact(ripe.Value), "ripe and fresh values round once after summing")
    for _, sample in { { 9740, "$9.5K" }, { 9750, "$10K" }, { 10249, "$10K" }, { 10250, "$10.5K" } } do
        check(formatter.Compact(sample[1]) == sample[2], "nearest $500 boundary")
    end
    display.Refresh(pad, { Count = 0 }, visuals)
    check(not pad:FindFirstChild("StashDisplay"), "empty slot hides its value")
    local geometry = loadModule("SmoothieGeometry")
    local original = geometry.CreateVisual
    geometry.CreateVisual = function()
        return nil
    end
    local smoothie = {
        ItemType = "Smoothie",
        Count = 1,
        Smoothie = { BlendId = "value-test", Ingredients = { "Apple", "Apple", "Banana" } },
    }
    smoothie.Value = values.Calculate(smoothie)
    display.Refresh(pad, smoothie, visuals)
    check(
        textValue() == formatter.Compact(definitions.Apple.Value * 2 + definitions.Banana.Value),
        "smoothie value derives from composition and counts repeated ingredients"
    )
    geometry.CreateVisual = original
    display.Refresh(pad, nil, visuals)
    check(not pad:FindFirstChild("StashDisplay"), "removed smoothie hides its value")
    pad:Destroy()
end
