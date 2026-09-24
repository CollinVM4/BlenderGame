-- Real client visibility controller; waiting/approaching orders share the same owner contract.
local descendants, changed, bubbles = {}, {}, {}
services.Players.LocalPlayer = { UserId = 51 }
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
workspaceFake.GetDescendants = function()
    return descendants
end
for index = 1, 3 do
    local model = instance("Model")
    model:SetAttribute("OwnerUserId", 51)
    model:SetAttribute("QueuePosition", index)
    changed[index] = signal()
    model.GetAttributeChangedSignal = function()
        return changed[index]
    end
    local root = instance("Part")
    root.Parent = model
    local bubble = instance("BillboardGui")
    bubble.Name, bubble.Parent, bubble.Enabled = "OrderBubble", root, false
    table.insert(descendants, bubble)
    bubbles[index] = bubble
end
loadModule("CustomerOrderController").Init()
for index, bubble in bubbles do
    check(not bubble.Enabled, "unrevealed orders are hidden even from owner")
    bubble.Parent.Parent:SetAttribute("OrderRevealed", true)
    changed[index]:Fire()
    check(bubble.Enabled, "taken orders are visible in all queue slots")
    local model = bubble.Parent.Parent
    model:SetAttribute("QueuePosition", index - 1)
    changed[index]:Fire()
    check(bubble.Enabled, "queue advancement keeps order visible")
    model:SetAttribute("OwnerUserId", 99)
    changed[index]:Fire()
    check(not bubble.Enabled, "other owners cannot see this order")
end

-- Ingredient highlighting is presentation-only and reads the live catalog colors.
local customer = loadModule("CustomerService")
local ingredients = loadModule("Ingredients")
local function colored(id, text)
    local color = ingredients[id].BlendColor
    return string.format(
        '<font color="rgb(%d,%d,%d)">%s</font>',
        math.round(color.R * 255),
        math.round(color.G * 255),
        math.round(color.B * 255),
        text
    )
end
local function format(message, required)
    return customer.FormatRequestText({ DisplayText = message, RequiredIngredients = required })
end
check(
    format("APPLE, Banana and ICE!", { { "Apple", "Green_Apple" }, "Banana", "Ice" })
        == colored("Apple", "APPLE")
            .. ", "
            .. colored("Banana", "Banana")
            .. " and "
            .. colored("Ice", "ICE")
            .. "!",
    "required names use catalog colors and authored case"
)
check(
    format("GREEN APPLE or Apple", { { "Apple", "Green_Apple" } })
        == colored("Green_Apple", "GREEN APPLE") .. " or " .. colored("Apple", "Apple"),
    "alternative names prefer longest full match"
)
check(
    format("pineapple APPLE apples SWEET", { "Apple" }) == "pineapple " .. colored("Apple", "APPLE") .. " apples SWEET",
    "whole names only; tag words remain plain"
)
check(
    format([[RED <SWEET> & "FRUIT"]], nil) == [[RED &lt;SWEET&gt; &amp; "FRUIT"]],
    "plain messages escape markup without coloring tags"
)
local oldName = ingredients.Apple.DisplayName
ingredients.Apple.DisplayName = nil
check(format("Apple", { "Apple" }) == colored("Apple", "Apple"), "missing display name falls back to ID")
ingredients.Apple.DisplayName = oldName

local presentation = loadModule("CustomerPresentation")
local function tagColored(tag, text)
    local c = presentation.TagHighlights[string.lower(tag)].Color
    return string.format(
        '<font color="rgb(%d,%d,%d)">%s</font>',
        math.round(c.R * 255),
        math.round(c.G * 255),
        math.round(c.B * 255),
        text
    )
end
check(
    customer.FormatRequestText({
        DisplayText = "MILK!",
        RequiredIngredients = { "Milk" },
        RequiredTags = { "milk" },
        ForbiddenTags = { "Milk" },
    }) == colored("Milk", "MILK") .. "!",
    "ingredient catalog color takes precedence over required and forbidden tag colors"
)
check(
    customer.FormatRequestText({
        DisplayText = "<sWeEt> & FAST FOOD, SWEETER RED!",
        RequiredTags = { "SWEET", "fast food" },
    })
        == "&lt;"
            .. tagColored("Sweet", "sWeEt")
            .. "&gt; &amp; "
            .. tagColored("Fast Food", "FAST FOOD")
            .. ", SWEETER RED!",
    "tag matching preserves case, escapes source, and ignores unrelated words"
)
for _, tag in
    {
        "Red",
        "Yellow",
        "Green",
        "Purple",
        "Blue",
        "Cold",
        "Sweet",
        "Spicy",
        "Protein",
        "Fruit",
        "Seafood",
        "Fast Food",
        "Milk",
        "Weird",
    }
do
    check(
        customer.FormatRequestText({ DisplayText = string.upper(tag) .. "!", RequiredTags = { string.lower(tag) } })
            == tagColored(tag, string.upper(tag)) .. "!",
        "required tag has a centralized presentation color: " .. tag
    )
end
