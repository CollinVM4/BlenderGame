local function uiInstance(class, name, parentObject)
    local object = instance(class)
    object.Name, object.Parent = name, parentObject
    object.Changed, object.AttributeChanged, object.InputBegan = signal(), signal(), signal()
    object.PromptButtonHoldBegan, object.PromptButtonHoldEnded = signal(), signal()
    local properties = {}
    function object:GetPropertyChangedSignal(property)
        properties[property] = properties[property] or signal()
        return properties[property]
    end
    function object:GetAttributeChangedSignal(attribute)
        return self:GetPropertyChangedSignal(attribute)
    end
    function object:SetAttribute(attribute, value)
        self.Attributes[attribute] = value
        self.AttributeChanged:Fire(attribute)
        self:GetAttributeChangedSignal(attribute):Fire()
    end
    return object
end
env.Instance.new = uiInstance
env.UDim2.fromOffset = function(x, y)
    return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
env.Enum.ProximityPromptStyle = { Custom = "Custom", Default = "Default" }
env.Enum.ProximityPromptInputType = { Keyboard = "Keyboard", Gamepad = "Gamepad", Touch = "Touch" }
env.Enum.UserInputType = { Touch = "Touch", MouseButton1 = "MouseButton1" }
env.Enum.TextXAlignment = { Center = "Center" }
env.Enum.TextYAlignment = { Center = "Center" }
local input = { InputEnded = signal(), WindowFocusReleased = signal() }
function input:GetStringForKeyCode(key)
    return key.Name
end
services.UserInputService = input
local prompts = { PromptShown = signal(), PromptHidden = signal() }
services.ProximityPromptService = prompts
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
local workspaceMethods = instance("Folder")
workspaceFake.GetChildren = workspaceMethods.GetChildren
workspaceFake.GetDescendants = workspaceMethods.GetDescendants
local playerGui = uiInstance("PlayerGui")
local studio = true
services.RunService.IsStudio = function()
    return studio
end
local logs = {}
env.print = function(message)
    table.insert(logs, message)
end
services.Players.LocalPlayer = {
    GetAttributeChangedSignal = function()
        return signal()
    end,
    WaitForChild = function()
        return playerGui
    end,
}
local function module(name, requires)
    local chunk = assert(loadstring(sources[name], name))
    setfenv(
        chunk,
        setmetatable({
            script = {
                Parent = {
                    WorldBillboardStyle = "WorldBillboardStyle",
                    Parent = { UI = { InteractionPromptPresentation = "Presentation" }, Services = parent },
                },
            },
            require = function(key)
                return requires[key]
            end,
        }, { __index = env })
    )
    return chunk()
end
local style = module("WorldBillboardStyle", {})
local view =
    module("Presentation", { WorldBillboardStyle = style, DialogueTextStyle = loadModule("DialogueTextStyle") })
local controller = module("Controller", { Presentation = view })
controller.Init()
controller.Init()
local object = uiInstance("Model", "Dispenser", workspaceFake)
local button = uiInstance("Part", "DispenseButton", object)
local origin = uiInstance("Attachment", "DispenserTextOrigin", object)
local prompt = uiInstance("ProximityPrompt", "DispensePrompt", button)
prompt.Style, prompt.Enabled = "Custom", true
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
prompt.ActionText, prompt.ClickablePrompt = "Dispense smoothie", true
prompt:SetAttribute("InteractionOrigin", "DispenserTextOrigin")
prompt:SetAttribute("InteractionActionText", "DISPENSE")
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
    return playerGui:FindFirstChild("InteractionPromptDisplay")
end
local function label()
    return gui():FindFirstChild("Action")
end
show()
check(#playerGui:GetChildren() == 1, "one view after idempotent controller startup")
check(gui().Adornee == origin, "sibling attachment is exact adornee")
check(label().Font == "FredokaOne" and not label().TextWrapped, "dispenser uses fixed dialogue lettering")
check(label():FindFirstChild("DialogueOutline").Thickness == 2.5, "dispenser has heavy NPC text outline")
local originPart = uiInstance("Part", "MarkerPart", object)
origin.Parent = originPart
show()
check(gui().Adornee == origin, "nested attachment beneath containing model resolves")
origin.Parent = object
check(label().Text == "[E] DISPENSE", "configured action and actual key")
check(gui().AlwaysOnTop and label().BackgroundTransparency == 1, "transparent outlined world UI")
check(label().TextScaled == false and label().TextSize == 24, "fixed font size")
check(gui().Size.X.Scale == 0 and gui().Size.Y.Scale == 0, "pixel-only canvas")
local old = gui()
show()
check(old.Destroyed and #playerGui:GetChildren() == 1, "repeated shown replaces view without duplicates")
prompt.KeyboardKeyCode = { Name = "F" }
prompt:GetPropertyChangedSignal("KeyboardKeyCode"):Fire()
check(label().Text == "[F] DISPENSE", "key changes refresh visible text")
prompt.PromptButtonHoldBegan:Fire()
check(label().Text == "[F] HOLD DISPENSE", "hold lifecycle feedback")
prompt.PromptButtonHoldEnded:Fire()
check(label().Text == "[F] DISPENSE", "hold end restores text")
show("Gamepad")
check(label().Text == "[ButtonX] DISPENSE", "gamepad key comes from prompt")
show("Touch")
check(label().Text == "[TAP] DISPENSE", "touch hint")
local finger = { UserInputType = "Touch" }
label().InputBegan:Fire(finger)
input.InputEnded:Fire(finger)
check(begins == 1 and ends == 1, "touch forwards begin/end through prompt")
label().InputBegan:Fire(finger)
prompts.PromptHidden:Fire(prompt)
check(ends == 2 and #playerGui:GetChildren() == 0, "hide releases input and destroys view")
prompt.PromptButtonHoldBegan:Fire()
check(#playerGui:GetChildren() == 0, "hidden listeners cannot recreate view")
origin.Parent = nil
show()
check(gui() == nil, "missing origin never draws at button")
origin.Parent = object
workspaceFake.DescendantAdded:Fire(origin)
check(gui().Adornee == origin, "late marker binds already-visible prompt")
workspaceFake.DescendantRemoving:Fire(origin)
origin.Parent = nil
check(gui() == nil, "streamed-out origin cleans view")
origin.Parent = object
workspaceFake.DescendantAdded:Fire(origin)
check(#playerGui:GetChildren() == 1, "streamed-in origin recreates exactly once")
prompt.Enabled = false
prompt.Changed:Fire("Enabled")
check(gui() == nil, "disabled prompt cleans view")
prompt.Enabled = true
show()
prompt.Parent = nil
prompt.AncestryChanged:Fire()
check(gui() == nil, "prompt removal cleans view without hidden event")
prompt.Parent = button
prompt.Style = "Default"
show()
check(gui() == nil, "default prompts not migrated implicitly")
prompt.Style = "Custom"
prompt.Changed:Fire("Style")
check(gui() ~= nil, "late custom style is supported")
prompt:SetAttribute("InteractionActionText", "START DAY")
check(label().Text == "[F] START DAY", "generic configuration updates in place")
prompt:SetAttribute("InteractionKeyText", "USE")
check(label().Text == "[USE] START DAY", "optional key override")
prompt:SetAttribute("InteractionOrigin", nil)
check(gui() == nil, "removing opt-in clears presentation")
local attach, serverPrompt
local owner = {}
local dispenseCalls = 0
local server = module("DispenseButton", {
    WorldUtil = {
        BindTag = function(tag, callback)
            check(tag == "DispenseButton", "existing button tag retained")
            attach = callback
        end,
        Part = function(part)
            return part
        end,
        Prompt = function(part, name, action)
            serverPrompt = uiInstance("ProximityPrompt", name, part)
            serverPrompt.ActionText = action
            return serverPrompt
        end,
    },
    AudioService = {
        CreateBlendGroup = function()
            return { pourSound = { Play = function() end, Destroy = function() end } }
        end,
    },
})
server.Init({
    TycoonService = {
        GetOwner = function()
            return owner
        end,
    },
    BlendService = {
        Dispense = function(actor, part)
            check(actor == owner and part == button, "original server dispense arguments preserved")
            dispenseCalls += 1
            return true
        end,
    },
})
local detach = attach(button)
check(serverPrompt.Style == "Custom", "actual dispense prompt hides default presentation")
check(serverPrompt:GetAttribute("InteractionOrigin") == origin.Name, "actual button config resolves authored marker")
check(serverPrompt:GetAttribute("InteractionActionText") == "DISPENSE", "actual button config supplies action")
serverPrompt.Triggered:Fire({})
check(dispenseCalls == 0, "foreign player still rejected by original owner check")
serverPrompt.Triggered:Fire(owner)
check(dispenseCalls == 1, "owner still reaches authoritative dispense")
detach()
check(serverPrompt.Destroyed, "original component cleanup retained")
-- Start Day uses the same controller/view with its authored sibling prompt.
local dayRoot = uiInstance("Model", "Start Day", workspaceFake)
local dayOrigin = uiInstance("Attachment", "StartDayTextOrigin", dayRoot)
local dayPart = uiInstance("Part", "StartButton", dayRoot)
local dayPrompt = uiInstance("ProximityPrompt", "ProximityPrompt", dayRoot)
dayPrompt.Style, dayPrompt.Enabled = "Default", true
dayPrompt.KeyboardKeyCode, dayPrompt.GamepadKeyCode = { Name = "F" }, { Name = "ButtonY" }
dayPrompt.MaxActivationDistance, dayPrompt.HoldDuration = 13, 1.5
dayPrompt.RequiresLineOfSight, dayPrompt.ClickablePrompt = true, false
dayPrompt.ActionText = "Old Start Day"
dayPrompt:SetAttribute("InteractionKeyText", "E")
local dayOwner = uiInstance("Player")
local dayAttach, fallbackPrompt
local createdPrompts, dayCalls = 0, 0
local success = false
local dayServer = module("DayButton", {
    WorldUtil = {
        BindTag = function(tag, callback)
            check(tag == "StartDayButton", "Start Day tag unchanged")
            dayAttach = callback
        end,
        Part = function()
            return dayPart
        end,
        Prompt = function(part, name, action)
            createdPrompts += 1
            fallbackPrompt = uiInstance("ProximityPrompt", name, part)
            fallbackPrompt.ActionText = action
            fallbackPrompt.MaxActivationDistance = 10
            fallbackPrompt.RequiresLineOfSight = false
            return fallbackPrompt
        end,
    },
})
dayServer.Init({
    TycoonService = {
        GetOwner = function(part)
            check(part == dayPart, "server ownership still uses original physical part")
            return dayOwner
        end,
    },
    GameService = {
        StartDay = function(actor)
            check(actor == dayOwner, "original StartDay actor retained")
            dayCalls += 1
            return success, "Day already active"
        end,
    },
})
local dayCleanup = dayAttach(dayPart)
check(
    createdPrompts == 0 and dayPrompt.Parent == dayRoot,
    "authored sibling prompt reused without moving or duplicate creation"
)
check(dayPrompt.Style == "Custom", "default Start Day UI hidden")
check(dayPrompt:GetAttribute("InteractionOrigin") == "StartDayTextOrigin", "Start Day origin metadata")
check(dayPrompt:GetAttribute("InteractionActionText") == "START DAY", "Start Day action metadata")
check(
    dayPrompt.KeyboardKeyCode.Name == "F" and dayPrompt.MaxActivationDistance == 13 and dayPrompt.HoldDuration == 1.5,
    "authored key/range/hold preserved"
)
check(
    dayPrompt.RequiresLineOfSight and not dayPrompt.ClickablePrompt and dayPrompt.Enabled,
    "authored input visibility settings retained"
)
local originFrame = dayOrigin.CFrame
playerGui:SetAttribute("DebugFilmLoop", true)
local function logged(text)
    for _, message in logs do
        if string.find(message, text, 1, true) then
            return true
        end
    end
    return false
end
check(logged("Model.PrimaryPart is nil"), "snapshot diagnoses invalid model placement before engine event")
check(logged("PromptShownCount=0"), "snapshot includes prompts that never emitted shown")
check(logged("InteractionActionText=START DAY"), "snapshot reads actual action metadata")
check(logged("MaxActivationDistance=13"), "snapshot includes authored range")
check(logged("RequiresLineOfSight=true"), "snapshot includes authored line of sight")
check(logged("HoldDuration=1.5"), "snapshot includes authored hold duration")
prompts.PromptShown:Fire(dayPrompt, "Keyboard")
check(logged("PromptShown received by controller"), "engine callback logs received prompt")
check(logged("BillboardGui created="), "presentation creation logged after return")
check(gui().Adornee == dayOrigin and dayOrigin.CFrame == originFrame, "Start Day exact origin retained without moving")
check(label().Text == "[F] START DAY", "Start Day key label comes from prompt, clears hardcoded override")
check(
    gui().Size.X.Offset == 300 and gui().Size.Y.Offset == 56 and not label().TextScaled,
    "Start Day uses shared fixed pixel view"
)
for _ = 1, 3 do
    prompts.PromptHidden:Fire(dayPrompt)
    check(#playerGui:GetChildren() == 0, "Start Day exit destroys view")
    prompts.PromptShown:Fire(dayPrompt, "Keyboard")
    prompts.PromptShown:Fire(dayPrompt, "Keyboard")
    check(#playerGui:GetChildren() == 1, "Start Day reentry and repeated shown remain single view")
end
dayPrompt.Triggered:Fire({})
check(dayCalls == 0, "Start Day foreign owner rejected")
dayPrompt.Triggered:Fire(dayOwner)
check(
    dayCalls == 1 and dayOwner:GetAttribute("LastActionError") == "Day already active",
    "Start Day failure still reports server reason"
)
success = true
dayPrompt.Triggered:Fire(dayOwner)
check(dayCalls == 2 and dayOwner:GetAttribute("LastActionError") == "", "Start Day success still clears prior error")
prompts.PromptHidden:Fire(dayPrompt)
dayOrigin.Parent = nil
prompts.PromptShown:Fire(dayPrompt, "Keyboard")
check(logged("Rejected: Attachment StartDayTextOrigin not found"), "exact missing origin rejection logged")
local otherModel = uiInstance("Model", "OtherInteractable", workspaceFake)
local otherOrigin = uiInstance("Attachment", "StartDayTextOrigin", otherModel)
workspaceFake.DescendantAdded:Fire(otherOrigin)
check(gui() == nil, "resolver never borrows origin from another interactable")
local markerPart = uiInstance("Part", "Marker", dayRoot)
dayOrigin.Parent = markerPart
local duplicatePart = uiInstance("Part", "DuplicateMarker", dayRoot)
local duplicate = uiInstance("Attachment", "StartDayTextOrigin", duplicatePart)
workspaceFake.DescendantAdded:Fire(duplicate)
check(gui() == nil and logged("Rejected: Ambiguous InteractionOrigin"), "ambiguous nested markers rejected explicitly")
duplicate.Parent = nil
workspaceFake.DescendantAdded:Fire(dayOrigin)
check(gui().Adornee == dayOrigin, "nested origin resolves after ambiguity removed")
dayOrigin.Parent = dayRoot
local logCount = #logs
studio = false
prompts.PromptShown:Fire(dayPrompt, "Keyboard")
check(#logs == logCount, "debug flag cannot enable production logging")
studio = true
playerGui:SetAttribute("DebugFilmLoop", false)
prompts.PromptShown:Fire(dayPrompt, "Keyboard")
check(#logs == logCount, "debug flag disables all prompt logging")
prompts.PromptHidden:Fire(dayPrompt)
dayCleanup()
check(
    not dayPrompt.Destroyed and dayPrompt.Style == "Default" and dayPrompt:GetAttribute("InteractionKeyText") == "E",
    "detach restores authored presentation without destroying prompt"
)
dayPrompt.Triggered:Fire(dayOwner)
check(dayCalls == 2, "detach disconnects gameplay listener")
dayPrompt.Parent = nil
local fallbackCleanup = dayAttach(dayPart)
check(
    createdPrompts == 1 and fallbackPrompt.Name == "StartDayPrompt",
    "unconfigured fixtures keep existing prompt creation"
)
check(
    fallbackPrompt.MaxActivationDistance == 10 and not fallbackPrompt.RequiresLineOfSight,
    "fallback keeps original range and line-of-sight settings"
)
check(
    fallbackPrompt.Style == "Custom" and fallbackPrompt:GetAttribute("InteractionOrigin") == "StartDayTextOrigin",
    "fallback also opts into shared presentation"
)
fallbackCleanup()
check(fallbackPrompt.Destroyed, "generated prompt remains component-owned")
print(string.format("PASS: %d interaction presentation assertions (mocked Roblox boundary).", count))
