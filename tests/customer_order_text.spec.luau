-- Exercise real request selection, spawning, formatter and order-label writes.
-- Only Roblox instances/audio and scheduling are simulated; typing yields each frame.
local config = loadModule("CustomerRequests")
local ingredients = loadModule("Ingredients")
local recipes = {}
for _, request in config.Definitions do
    recipes[request.Id] = request
end
local jobs = {}
env.task.spawn = function(fn)
    local thread = coroutine.create(fn)
    table.insert(jobs, thread)
end
env.task.wait = function()
    coroutine.yield()
    return 0.04
end
local function step()
    local pending = jobs
    jobs = {}
    for _, thread in pending do
        local ok, err = coroutine.resume(thread)
        assert(ok, tostring(err))
        if coroutine.status(thread) ~= "dead" then
            table.insert(jobs, thread)
        end
    end
end
local function finish()
    for _ = 1, 500 do
        if #jobs == 0 then
            return
        end
        step()
    end
    error("customer presentation tasks did not finish")
end
-- Parented audio ensures the real typewriter's sound/pitch branch also executes.
cache.AudioService.CreateBlendGroup = function(root)
    local audio = {}
    for _, name in { "dialogueSound", "notReadySound", "customerServeSound" } do
        local sound = instance("Sound")
        sound.Parent = root
        sound.Stop = function() end
        sound.Play = function() end
        audio[name] = sound
    end
    return audio
end
env.UDim2.fromOffset = function(x, y)
    return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
local owner = instance("Player")
owner.Name, owner.UserId, owner.Parent = "OrderTextOwner", 52, services.Players
owner.Near = true
owner:SetAttribute("JumpLevel", 3)
local plot = instance("Model")
local markers = {}
for _, name in { "CustomerSpawn", "CustomerCounter", "CustomerWait1", "CustomerWait2", "CustomerExit" } do
    markers[name] = instance("Part")
end
services.Players.LocalPlayer = owner
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
workspaceFake.GetDescendants = function()
    return {}
end
loadModule("CustomerOrderController").Init()
local customer = loadModule("CustomerService")
local function visibleLabel(model)
    setup(customer.TakeOrder(owner, model), "take assigned order before typing")
    model.GetAttributeChangedSignal = function()
        return signal()
    end
    local bubble = model:FindFirstChild("OrderBubble", true)
    workspaceFake.DescendantAdded:Fire(bubble)
    check(bubble.Enabled, "owner controller enables the same order bubble")
    return bubble:FindFirstChildOfClass("TextLabel")
end
customer.Init({
    TycoonService = {
        GetPlot = function()
            return plot
        end,
        GetOwner = function()
            return owner
        end,
        GetReference = function(_, name)
            return markers[name]
        end,
    },
}, function() end, function()
    return true
end)
customer.ActivateForPlayer(owner)
local function colored(id, text)
    local c = ingredients[id].BlendColor
    return string.format(
        '<font color="rgb(%d,%d,%d)">%s</font>',
        math.round(c.R * 255),
        math.round(c.G * 255),
        math.round(c.B * 255),
        text
    )
end
local function tagColored(tag, text)
    local c = loadModule("CustomerPresentation").TagHighlights[string.lower(tag)].Color
    return string.format(
        '<font color="rgb(%d,%d,%d)">%s</font>',
        math.round(c.R * 255),
        math.round(c.G * 255),
        math.round(c.B * 255),
        text
    )
end
local cases = {
    {
        "AppleSour",
        "I need an " .. colored("Apple", "APPLE") .. " and something " .. tagColored("Sour", "SOUR") .. "!",
    },
    { "Yellow", "I'll have you know my favorite color is " .. tagColored("Yellow", "YELLOW") .. "!" },
    { "Red", "can you make a " .. tagColored("Red", "RED") .. " smoothie!" },
    { "Cold", "make it ice " .. tagColored("Cold", "COLD") .. "!" },
    {
        "SweetCold",
        "gimmie something " .. tagColored("Sweet", "SWEET") .. " and ICE " .. tagColored("Cold", "COLD") .. "!",
    },
    { "RedNoFruit", "something " .. tagColored("Red", "RED") .. "... but NO " .. tagColored("Fruit", "FRUIT") .. "!" },
    { "FruitNoMilk", "I want " .. tagColored("Fruit", "FRUIT") .. " but NO " .. tagColored("Milk", "MILK") .. "!" },
    {
        "SweetColdNoSpicy",
        tagColored("Sweet", "SWEET") .. " and " .. tagColored("Cold", "COLD") .. "... absolutely NO " .. tagColored(
            "Spicy",
            "SPICE"
        ) .. "!",
    },
    { "FastFood", "Im craving " .. tagColored("Fast Food", "FAST FOOD") .. "!" },

    {
        "AppleBananaIce",
        colored("Apple", "APPLE")
            .. ", "
            .. colored("Banana", "BANANA")
            .. ", and "
            .. colored("Ice", "ICE")
            .. "! Don't mess it up!",
    },
    {
        "SpicyPineapple",
        colored("Pineapple", "PINEAPPLE") .. ", " .. colored("Chili_Pepper", "CHILI PEPPER") .. ", " .. colored(
            "Ice",
            "ICE"
        ) .. "!",
    },
    {
        "DragonSpice",
        colored("Dragon_Fruit", "DRAGON FRUIT")
            .. " and "
            .. colored("Cinnamon", "CINNAMON")
            .. "! Pick the last ingredient.",
    },
    {
        "GoldenCloud",
        colored("Potato", "POTATO") .. ", " .. colored("GoldenTomato", "GOLDEN TOMATO") .. ", and " .. colored(
            "Tomato",
            "TOMATO"
        ) .. "! Golden everything!",
    },
}
local function selectRequest(request)
    table.clear(config.Definitions)
    table.insert(config.Definitions, request)
end
for _, case in cases do
    local request, expected = recipes[case[1]], case[2]
    selectRequest(request)
    check(customer.FormatRequestText(request) == expected, "real recipe formatter: " .. request.Id)
    local model = customer.SpawnForPlayer(owner)
    setup(model ~= nil, "spawn actual customer for " .. request.Id)
    check(model:GetAttribute("RequestId") == request.Id, "spawn selects current request")
    local label = visibleLabel(model)
    check(
        label.Font == "FredokaOne" and not label.TextScaled and label.TextWrapped,
        "regular request wraps in playful font"
    )
    check(
        label:FindFirstChildOfClass("UIStroke").Thickness >= 2
            and label:FindFirstChildOfClass("UIStroke").Transparency == 0,
        "regular dialogue has an opaque dark outline"
    )
    check(label.TextSize == 21, "regular text size stays fixed through reveal")
    check(model:FindFirstChild("CustomerName", true).Visible == false, "generic name does not clutter regular dialogue")
    check(model:FindFirstChild("TakeOrderPrompt", true).Style == "Custom", "take order uses custom prompt")
    check(label.Name ~= "CustomerName" and label.RichText == true, "actual dialogue label has RichText enabled")
    step()
    check(label.Text == expected and label.MaxVisibleGraphemes == 1, "first reveal frame retains full colored layout")
    local bubble = label.Parent
    local anchor = bubble.Adornee
    check(
        anchor:IsA("Attachment") and anchor.Parent == model.PrimaryPart and bubble.StudsOffset.Magnitude == 0,
        "dialogue follows stable root attachment without camera-relative stud offset"
    )
    local canvas = bubble.Size
    step()
    check(
        label.MaxVisibleGraphemes == 2 and label.Text == expected and bubble.Size == canvas and label.TextSize == 21,
        "revealing characters cannot resize or relayout text"
    )
    finish()
    check(label.MaxVisibleGraphemes == -1, "completed request stays fully visible")
    check(label.Text == expected, "actual NPC order label ends with colored markup: " .. request.Id)
    customer.RefreshQueue(owner)
    finish()
    check(label.Text == expected, "arrival and queue refresh preserve final markup")
    -- Change requests while old typing is still active; the old task must lose ownership.
    selectRequest(recipes.AppleBananaIce)
    customer:RefreshOrder(model)
    step()
    selectRequest(request)
    customer:RefreshOrder(model)
    finish()
    check(label.Text == expected, "latest request wins overlapping typewriters")
    model:Destroy()
    finish()
end
-- Alternatives whose display names differ from IDs, punctuation, and escaped source markup.
local alternate = table.clone(recipes.AppleBananaIce)
alternate.DisplayText = "<GREEN APPLE>, BANANA & ICE!"
selectRequest(alternate)
local model = customer.SpawnForPlayer(owner)
local label = visibleLabel(model)
step()
check(
    label.MaxVisibleGraphemes == 1 and label.Text:sub(1, 4) == "&lt;",
    "escaped full layout reveals one visible character"
)
finish()
check(
    label.Text
        == "&lt;"
            .. colored("Green_Apple", "GREEN APPLE")
            .. "&gt;, "
            .. colored("Banana", "BANANA")
            .. " &amp; "
            .. colored("Ice", "ICE")
            .. "!",
    "alternative display name and escaped text reach actual label"
)
model:Destroy()
finish()

-- Tag-only special orders intentionally have no ingredient-name markup.
local tagOnly = table.clone(recipes.Nathan)
tagOnly.NPCOnly = false -- Exercise its authored text through regular selection in this fixture.
selectRequest(tagOnly)
model = customer.SpawnForPlayer(owner)
label = visibleLabel(model)
finish()
check(label.Text == recipes.Nathan.DisplayText, "Nathan wildcard request intentionally remains plain")
model:Destroy()
finish()

-- Reset during a yielding reveal cancels text and audio work.
model = customer.SpawnForPlayer(owner)
label = visibleLabel(model)
step()
local partial = label.MaxVisibleGraphemes
local prompt = model:FindFirstChild("TakeOrderPrompt", true)
customer.DeactivateForPlayer(owner)
finish()
check(
    label.MaxVisibleGraphemes == partial and prompt.Destroyed,
    "reset destroys prompts and cancels in-flight dialogue"
)
check(not customer.TakeOrder(owner, model), "stale reveal rejected after reset")

-- Shared typography preserves the special dialogue/name regions and colored text.
local presentation = loadModule("CustomerPresentation")
local specialBubble = instance("BillboardGui")
specialBubble.Size = env.UDim2.fromOffset(270, 84)
specialBubble.SizeOffset = env.Vector2.new(0, 0.5)
local specialText = instance("TextLabel")
specialText.Size = env.UDim2.fromOffset(270, 56)
specialText.Text = customer.FormatRequestText(recipes.SweetCold)
specialText.RichText = true
specialText.MaxVisibleGraphemes = 3
specialText.Parent = specialBubble
local specialName = instance("TextLabel")
specialName.Name, specialName.Text = "CustomerName", "Special NPC"
specialName.Position = env.UDim2.fromOffset(0, 56)
specialName.Parent = specialBubble
local markup, canvas = specialText.Text, specialBubble.Size
presentation.StyleDialogue(specialBubble, specialText, true)
for _, label in { specialText, specialName } do
    check(
        label.Font == "FredokaOne" and not label.TextScaled and label:FindFirstChildOfClass("UIStroke").Thickness == 2.5,
        "special dialogue and name share rounded fixed lettering and charcoal outline"
    )
    check(
        label.TextColor3.R == 1 and label.TextColor3.G == 1 and label.TextColor3.B == 1,
        "special lettering has a white base"
    )
end
check(
    specialBubble.Size == canvas and specialName.Visible and specialName.Position.Y.Offset == 56,
    "special name remains in its reserved row"
)
check(
    specialText.Text == markup and specialText.RichText and specialText.MaxVisibleGraphemes == 3,
    "shared styling preserves keyword markup and reveal progress"
)
