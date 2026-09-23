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
local function visibleLabel(model)
    model.GetAttributeChangedSignal = function()
        return signal()
    end
    local bubble = model:FindFirstChild("OrderBubble", true)
    workspaceFake.DescendantAdded:Fire(bubble)
    check(bubble.Enabled, "owner controller enables the same order bubble")
    return bubble:FindFirstChildOfClass("TextLabel")
end
local customer = loadModule("CustomerService")
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
    check(label.Name ~= "CustomerName" and label.RichText == true, "actual dialogue label has RichText enabled")
    step()
    check(label.Text == request.DisplayText:sub(1, 1), "first typewriter frame is plain text")
    finish()
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
check(label.Text == "&lt;", "typing escapes source markup without adding font tags")
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
