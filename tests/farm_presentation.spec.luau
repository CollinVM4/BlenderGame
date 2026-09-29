env.UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}
env.UDim2.new = function(xs, xo, ys, yo)
    return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
services.RunService.RenderStepped = signal()
services.TweenService = {}
local harvestAdded = signal()
services.CollectionService.GetInstanceAddedSignal = function()
    return harvestAdded
end
prompts.Enabled = true
local heldId = "Banana"
services.Players.LocalPlayer.GetAttribute = function(_, key)
    return if key == "HeldIngredientId" then heldId else nil
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
            require = load,
        }, { __index = env })
    )
    modules[name] = chunk()
    return modules[name]
end
local row = uiInstance("Model", "Row1", workspaceFake)
local markers = uiInstance("Part", "FarmMarkers", row)
local origin = uiInstance("Attachment", "PlantPoint", markers)
local pad = uiInstance("Part", "PurchasePoint1", row)
pad.CanTouch, pad.Transparency = true, 0
local prompt = uiInstance("ProximityPrompt", "FarmPlantPrompt", origin)
prompt.Style, prompt.Enabled = "Custom", true
prompt.ActionText = "Plant ingredient"
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
local begins, ends = 0, 0
function prompt:InputHoldBegin()
    begins += 1
end
function prompt:InputHoldEnd()
    ends += 1
end
row:SetAttribute("FarmState", "LOCKED")
local controller = load("FarmPresentationController")
controller.Init()
controller.Init()
local function tick()
    services.RunService.RenderStepped:Fire(0.1)
end
local function display(adornee)
    for _, gui in playerGui:GetChildren() do
        if gui.Adornee == adornee and gui.Name == "FarmDisplay" then
            return gui
        end
    end
end
tick()
check(not display(origin).Enabled, "locked row hides state")
check(
    display(pad).Enabled and display(pad):FindFirstChild("Detail").Text == "$1,000",
    "configured comma-separated pad price"
)
row:SetAttribute("FarmState", "EMPTY")
pad.CanTouch = false
prompts.PromptShown:Fire(prompt, "Keyboard")
local planting = playerGui:FindFirstChild("FarmPlantDisplay")
check(
    planting:FindFirstChild("Title").Text == "PLANT" and planting:FindFirstChild("Detail").Text == "Banana",
    "selected carry target and display name"
)
check(planting:FindFirstChild("Action").Text == "[E]", "native keyboard hint")
heldId = nil
tick()
check(
    planting:FindFirstChild("Title").Text == "HOLD AN INGREDIENT" and planting:FindFirstChild("Detail").Text == "",
    "missing carry clears old name"
)
heldId = "Banana"
load("Ingredients").Banana.Farmable = false
tick()
check(planting:FindFirstChild("Detail").Text == "", "nonfarmable selection has no planting name")
load("Ingredients").Banana.Farmable = nil
prompts.PromptShown:Fire(prompt, "Touch")
planting = playerGui:FindFirstChild("FarmPlantDisplay")
check(planting:FindFirstChild("Action").Text == "[TAP]", "native mobile hint")
local finger = { UserInputType = "Touch" }
planting:FindFirstChild("Action").InputBegan:Fire(finger)
prompts.PromptHidden:Fire(prompt)
check(begins == 1 and ends == 1 and planting.Destroyed, "mobile uses prompt API and hidden releases hold")
prompts.PromptShown:Fire(prompt, "Gamepad")
check(
    playerGui:FindFirstChild("FarmPlantDisplay"):FindFirstChild("Action").Text == "[ButtonX]",
    "native controller key"
)
row:SetAttribute("FarmState", "GROWING")
row:SetAttribute("FarmGrowEnd", now + 28)
tick()
check(
    not playerGui:FindFirstChild("FarmPlantDisplay") and display(origin):FindFirstChild("Detail").Text == "0:28",
    "growth replaces planting with countdown"
)
local title = display(origin):FindFirstChild("Title").Text
now += 0.4
tick()
check(display(origin):FindFirstChild("Title").Text ~= title, "ellipsis animates locally")
now += 40
tick()
check(display(origin):FindFirstChild("Detail").Text == "0:00", "countdown clamps without predicting ready")
row:SetAttribute("FarmState", "READY")
tick()
check(
    display(origin):FindFirstChild("Title").Text == "READY!" and display(origin):FindFirstChild("Detail").Text == "",
    "ready replaces countdown"
)
row:SetAttribute("FarmState", "LOCKED")
pad.CanTouch = true
tick()
check(not display(origin).Enabled and display(pad).Enabled, "session reset restores pad and hides row")
row.Parent = nil
tick()
check(#playerGui:GetChildren() == 0, "streaming out cleans all farm views")
env.Enum.EasingStyle, env.Enum.EasingDirection = { Back = "Back" }, { Out = "Out" }
services.TweenService.GetValue = function(_, alpha)
    return alpha
end
local crop = uiInstance("Model", "Crop", workspaceFake)
crop:SetAttribute("SpawnSource", "Farm")
crop:SetAttribute("FarmSpawnTime", now)
crop:SetAttribute("FrozenUntilPickup", true)
local target = frame(2, 4, 6)
getmetatable(target).__add = function(cf, offset)
    return frame(cf.Position + offset)
end
function crop:GetPivot()
    return target
end
harvestAdded:Fire(crop)
tick()
check(crop.CFrame.Position.Y < 4, "multipart harvest starts below authored pivot")
now += load("FarmConfig").HarvestPopSeconds + 0.01
tick()
check(crop.CFrame == target, "pop finishes at exact target pivot")
local ordinary = uiInstance("Part", "Ordinary", workspaceFake)
local original = ordinary.CFrame
harvestAdded:Fire(ordinary)
tick()
check(ordinary.CFrame == original, "normal world ingredient does not animate")
print(string.format("PASS: %d farm presentation assertions", count))
