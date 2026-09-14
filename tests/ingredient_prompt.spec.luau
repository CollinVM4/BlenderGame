env.Vector2 = {
    new = function(x, y)
        return { X = x, Y = y }
    end,
}
env.UDim2.new = function(xs, xo, ys, yo)
    return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
function vector:Abs()
    return vec(math.abs(self.X), math.abs(self.Y), math.abs(self.Z))
end
function vector:Min(other)
    return vec(math.min(self.X, other.X), math.min(self.Y, other.Y), math.min(self.Z, other.Z))
end
function vector:Max(other)
    return vec(math.max(self.X, other.X), math.max(self.Y, other.Y), math.max(self.Z, other.Z))
end
local modules = {}
local keys = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local chunk = assert(loadstring(sources[name], name))
    setfenv(
        chunk,
        setmetatable({
            script = { Parent = setmetatable({ Parent = { UI = keys } }, { __index = keys }) },
            require = function(key)
                return load(key)
            end,
        }, { __index = env })
    )
    modules[name] = chunk()
    return modules[name]
end
services.ReplicatedStorage.Shared.Constants.Ingredients = "Ingredients"
services.RunService.RenderStepped = signal()
prompts.Enabled = true
local definitions = load("Ingredients")
local style = load("IngredientPickupPromptStyle")
local view = load("IngredientPickupPromptPresentation")
local controller = load("IngredientPickupPromptController")
controller.Init()
controller.Init()
local item = uiInstance("Part", "NotTheIngredientId", workspaceFake)
item.Transparency = 0
item.Size = vec(2, 4, 2)
item:SetAttribute("IngredientId", "Strawberry")
services.CollectionService:AddTag(item, "IngredientWorldItem")
local attachment = uiInstance("Attachment", "PromptHost", item)
local prompt = uiInstance("ProximityPrompt", "CarryPrompt", attachment)
prompt.Style, prompt.Enabled = "Custom", true
prompt:SetAttribute("IngredientPickupPrompt", true)
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "F" }, { Name = "ButtonY" }
prompt.ActionText, prompt.ClickablePrompt, prompt.HoldDuration = "Pickup", true, 1
local begins, ends = 0, 0
function prompt:InputHoldBegin()
    begins += 1
end
function prompt:InputHoldEnd()
    ends += 1
end
local function show(kind)
    prompts.PromptShown:Fire(prompt, kind or "Keyboard")
end
local function gui()
    return playerGui:FindFirstChild("IngredientPickupPromptDisplay")
end
local function label(name)
    return gui():FindFirstChild(name)
end
show()
check(#playerGui:GetChildren() == 1, "idempotent startup gives one view")
check(
    label("Rarity").Text == "COMMON" and label("IngredientName").Text == "Strawberry",
    "registered Strawberry definition"
)
check(label("Action").Text == "[F]", "actual keyboard key, no pickup action or income text")
check(gui().Adornee == item and gui().StudsOffsetWorldSpace.Y == 2.35, "attachment prompt anchored above part bounds")
local old = gui()
show()
check(old.Destroyed and #playerGui:GetChildren() == 1, "repeated shown cleans previous view")
for id, rarity in { Crab = "Uncommon", Dragon_Fruit = "Rare", Mystery = "Mystery" } do
    item:SetAttribute("IngredientId", id)
    services.RunService.RenderStepped:Fire()
    check(label("Rarity").Text == string.upper(rarity), "rarity " .. rarity)
    check(label("Rarity").TextColor3 == style.RarityStyles[rarity].TextColor, "central palette " .. rarity)
end
item:SetAttribute("IngredientId", "Mystery")
show()
check(
    label("IngredientName").Text == "???" and item:GetAttribute("IngredientId") == "Mystery",
    "Mystery hides presentation only"
)
style.HideMysteryNames = false
show()
check(label("IngredientName").Text == "Mystery", "Mystery reveal toggle")
style.HideMysteryNames = true
definitions.Future = { Id = "Future", DisplayName = "Future Fruit" }
item:SetAttribute("IngredientId", "Future")
show()
check(
    label("Rarity").Text == "COMMON" and label("IngredientName").Text == "Future Fruit",
    "missing rarity and explicit display name"
)
local rarity, name = style.Resolve({ Id = "Fallback" })
check(rarity == "Common" and name == "Fallback", "missing display name uses Id")
show("Gamepad")
check(label("Action").Text == "[ButtonY]", "actual gamepad binding")
show("Touch")
check(label("Action").Text == "[TAP]", "mobile hint")
local finger = { UserInputType = "Touch" }
label("Action").InputBegan:Fire(finger)
prompt.PromptButtonHoldBegan:Fire()
check(begins == 1 and label("Action").Text == "HOLD [TAP]", "touch hold forwards to engine with feedback")
prompts.PromptHidden:Fire(prompt)
check(ends == 1 and gui() == nil, "hidden releases held touch and destroys UI")
show()
prompt.KeyboardKeyCode = { Name = "G" }
prompt:GetPropertyChangedSignal("KeyboardKeyCode"):Fire()
check(label("Action").Text == "[G]", "live key change")
prompt.Enabled = false
prompt.Changed:Fire("Enabled")
check(gui() == nil, "disabled cleanup")
prompt.Enabled = true
show()
prompt.Destroying:Fire()
check(gui() == nil, "pickup destruction cleans immediately")
show()
prompt.Parent = nil
prompt.AncestryChanged:Fire()
check(gui() == nil, "removed prompt cleans without hidden")
local model = uiInstance("Model", "Multipart", workspaceFake)
services.CollectionService:AddTag(model, "IngredientWorldItem")
model:SetAttribute("IngredientId", "Strawberry")
item.Parent = model
services.CollectionService:RemoveTag(item, "IngredientWorldItem")
prompt.Parent = attachment
show()
check(controller.Resolve(prompt) == model and gui().Adornee == item, "multipart registered ancestor through attachment")
local hidden = uiInstance("Part", "IngredientRoot", model)
hidden.Transparency, hidden.Size = 1, vec(100, 100, 100)
check(view.Top(model).Y == 2, "invisible pivot does not inflate visual bounds")
item.CFrame.UpVector, item.CFrame.RightVector = vec(1, 0, 0), vec(0, 1, 0)
check(view.Top(model).Y == 1, "rotated bounds use world axes")
model:SetAttribute("IngredientId", nil)
services.RunService.RenderStepped:Fire()
check(gui() == nil, "missing identity cannot use instance name")
model:SetAttribute("IngredientId", "Strawberry")
services.RunService.RenderStepped:Fire()
check(gui() ~= nil, "late replicated identity recovers shown prompt")
services.CollectionService:RemoveTag(model, "IngredientWorldItem")
services.RunService.RenderStepped:Fire()
check(gui() == nil, "removed registration cleans view")
services.CollectionService:AddTag(model, "IngredientWorldItem")
show()
check(#playerGui:GetChildren() == 1, "recreated registration shows once")
prompts.Enabled = false
services.RunService.RenderStepped:Fire()
check(gui() == nil, "service disable cleans view")
local attach, created, calls = nil, nil, 0
local record = { Id = "Strawberry", Claimable = true }
local actor = {}
local chunk = assert(loadstring(sources.IngredientPickup))
setfenv(
    chunk,
    setmetatable({
        script = { Parent = { Parent = { Services = { WorldUtil = "WorldUtil" } } } },
        require = function()
            return {
                BindTag = function(tag, callback)
                    check(tag == "IngredientWorldItem", "original registration tag")
                    attach = callback
                end,
                Part = function()
                    return item
                end,
                Prompt = function(part, name, action)
                    created = uiInstance("ProximityPrompt", name, part)
                    created.ActionText = action
                    created.MaxActivationDistance = 10
                    return created
                end,
            }
        end,
    }, { __index = env })
)
chunk().Init({
    IngredientService = {
        GetRecord = function()
            return record
        end,
    },
    InventoryService = {
        CarryWorldItem = function(player, object)
            check(player == actor and object == model, "original actor and registered root reach inventory")
            calls += 1
        end,
    },
})
local cleanup = attach(model)
check(created.Style == "Custom" and created:GetAttribute("IngredientPickupPrompt"), "server opts into custom view")
check(created.MaxActivationDistance == 10, "activation range preserved")
created.Triggered:Fire(actor)
check(calls == 1, "pickup still uses sole inventory entry point")
cleanup()
check(created.Destroyed, "server component owns prompt cleanup")
record.Claimable = false
check(attach(model) == nil, "market stock eligibility unchanged")
record = nil
check(attach(model) == nil, "unregistered item cannot get pickup prompt")
print(string.format("PASS: %d ingredient prompt assertions (mocked Roblox boundary).", count))
