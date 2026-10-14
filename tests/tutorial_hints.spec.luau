-- Presentation contracts use the real banner, wording and tutorial controller.
env.Enum.PreferredInput = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Gamepad" }
env.Enum.KeyCode = { ButtonR2 = { EnumType = "KeyCode", Name = "ButtonR2" } }
env.Enum.KeyCode.ButtonR2.EnumType = env.Enum.KeyCode
env.NumberSequenceKeypoint = {
    new = function(time, value)
        return { Time = time, Value = value }
    end,
}
env.NumberSequence = {
    new = function(value)
        if type(value) == "table" then
            assert(#value >= 2 and #value <= 20, "Roblox NumberSequence requires 2-20 keypoints")
            assert(value[1].Time == 0 and value[#value].Time == 1, "sequence spans both beam endpoints")
        end
        return if type(value) == "table" then { Keypoints = value } else value
    end,
}
env.Enum.HighlightDepthMode = { AlwaysOnTop = "AlwaysOnTop" }
env.Enum.ScreenInsets = { CoreUISafeInsets = "Safe" }
env.Enum.EasingStyle = { Back = "Back", Quad = "Quad", Sine = "Sine" }
env.Enum.EasingDirection = { Out = "Out", In = "In", InOut = "InOut" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
local udim = {
    __sub = function(a)
        return a
    end,
}
env.UDim2.fromScale = function()
    return setmetatable({}, udim)
end
env.UDim2.new = function()
    return setmetatable({}, udim)
end
services.TweenService = {
    Create = function(_, target, _, goal)
        return {
            Play = function()
                for key, value in goal do
                    target[key] = value
                end
            end,
            Cancel = function() end,
        }
    end,
}
local p = instance("Player")
p.Parent, p.Character = workspaceFake, instance("Model")
p.Character.Parent = workspaceFake
p.CharacterAdded = signal()
p.ChildAdded, p.ChildRemoved = signal(), signal()
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", p.Character
local humanoid = instance("Humanoid")
humanoid.Health, humanoid.Parent = 100, p.Character
local gui = instance("PlayerGui")
gui.Name, gui.Parent = "PlayerGui", p
services.Players.LocalPlayer = p
local preferredChanged = signal()
services.UserInputService = {
    PreferredInput = "Mouse",
    GetPropertyChangedSignal = function()
        return preferredChanged
    end,
    GetStringForKeyCode = function()
        return "R2"
    end,
}
services.ContextActionService = {
    GetBoundActionInfo = function()
        return { inputTypes = { env.Enum.KeyCode.ButtonR2 } }
    end,
}
local changes = {}
p.GetAttributeChangedSignal = function(_, key)
    changes[key] = changes[key] or signal()
    return changes[key]
end
local setter = p.SetAttribute
p.SetAttribute = function(self, key, value)
    setter(self, key, value)
    if changes[key] then
        changes[key]:Fire()
    end
end
cache.MobileControlLayout = {}
local function controllerModule(name)
    local object = instance("ModuleScript")
    object.Parent = parent
    local chunk = assert(loadstring(sources[name], name))
    setfenv(chunk, setmetatable({ script = object }, { __index = env }))
    return chunk(), object
end
shared.TutorialTargets = "TutorialTargets"
local presentation = loadModule("TutorialPresentationState")
presentation.Read(p) -- Replication may not have delivered tutorial attributes at startup.
local banner = loadModule("AnnouncementBanner")
local controller = controllerModule("TutorialHintController")
local function advance(seconds)
    now += seconds or 0.2
    heartbeat:Fire(0.1)
end
local function label()
    local root = gui:FindFirstChild("TutorialHint")
    return if root then root:FindFirstChild("Announcement") else nil
end
local function hintContains(text)
    local current = label()
    return current and current.Visible and string.find(current.Text, text, 1, true) ~= nil
end
shared.TutorialTargets = "TutorialTargets"
local plot = instance("Model")
plot.Name, plot.Parent = "TutorialPlot", workspaceFake
plot:SetAttribute("PlotSessionId", "tutorial")
services.CollectionService:AddTag(plot, "PlayerPlot")
local stash = instance("Model")
stash.Name, stash.Parent = "Stash", plot
services.CollectionService:AddTag(stash, "PlayerStash")
local slot = instance("Part")
slot.Name, slot.Parent = "Slot3", stash
slot:SetAttribute("SlotIndex", 3)
local slotBase = instance("Part")
slotBase.Name, slotBase.Parent = "base", slot
local counter = plot
for _, name in { "Customer Area", "Counter", "Base Structure", "Base" } do
    local child = instance(if name == "Base" then "Part" else "Model")
    child.Name, child.Parent = name, counter
    counter = child
end
counter.Position = vec(60, 0, 0)
local dispenser = instance("Model")
dispenser.Name, dispenser.Parent = "Dispenser", plot
local customer = instance("Model")
customer.Parent = workspaceFake
customer:SetAttribute("PlotSessionId", "tutorial")
local customerRoot = instance("Part")
customerRoot.Name, customerRoot.Parent, customerRoot.Position = "HumanoidRootPart", customer, counter.Position
local customerTarget = instance("ObjectValue")
customerTarget.Name, customerTarget.Parent, customerTarget.Value = "TutorialCustomerTarget", p, customer
local gleam, gleamScript = controllerModule("TutorialGleamController")
local function beams(name)
    local result = {}
    for _, object in allInstances do
        if object:IsA("Beam") and object.Name == (name or "TutorialStashBeam") and not object.Destroyed then
            table.insert(result, object)
        end
    end
    return result
end
local function highlights()
    local result = {}
    for _, object in allInstances do
        if object:IsA("Highlight") and not object.Destroyed then
            table.insert(result, object)
        end
    end
    return result
end
local function noHint()
    return label() == nil or not label().Visible
end
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("TutorialActive", true)
p:SetAttribute("TutorialHintReady", false)
p:SetAttribute("TutorialStage", "ClaimPlot")
controller.Init()
gleam.Init()
check(
    hintContains("Claim your smoothie stand!"),
    "stand claiming is the first immediate instruction, before world hint readiness"
)
p:SetAttribute("PlotSessionId", "tutorial")
p:SetAttribute("TutorialHintReady", true)
p:SetAttribute("TutorialStage", "Counter")
check(noHint(), "claim clears immediately while initial counter navigation waits")
advance(2.9)
check(noHint(), "counter navigation waits three seconds after claiming")
advance(0.1)
check(
    hintContains("Head to your customer counter!") and highlights()[1].Adornee == counter,
    "initial counter instruction appears three seconds after claiming"
)
p:SetAttribute("TutorialStage", "Order")
advance()
check(hintContains("Take the customer's order!"), "first customer receives immediate order instruction")
check(
    label().Font == "FredokaOne" and label().BackgroundTransparency == 1,
    "hints reuse outlined announcement typography without a panel"
)
p:SetAttribute("TutorialStashSlot", 3)
p:SetAttribute("TutorialStage", "Stash")
check(
    noHint() and #beams() == 0 and #highlights() == 0,
    "first accepted order immediately clears old guidance while dialogue plays"
)
advance(2.4)
check(noHint() and #beams() == 0 and #highlights() == 0, "stash text, beam and gleam share the 2.5-second delay")
advance(0.1)
check(
    hintContains("Grab ingredients") and #beams() == 1 and #highlights() == 2,
    "stash instruction and world guidance appear together after 2.5 seconds"
)
local beam = beams()[1]
check(beam.Attachment0.Parent == root and beam.Attachment0.Position.Z > 0, "beam starts behind the moving avatar")
check(beam.Attachment1.Parent == slot, "beam ends on the exact active stash slot")
check(
    beam.Width0 == 0.26 and beam.Width1 == 0.195 and beam.Transparency == 0.6 and beam.Segments == 20,
    "outer beam is 62.5 percent thicker while remaining translucent"
)
local flow = beams("TutorialStashFlow")[1]
check(
    flow and flow.Attachment0 == beam.Attachment0 and flow.Attachment1 == beam.Attachment1,
    "brighter inner flow travels along the same player-to-stash curve"
)
local function peak(sequence)
    local lowest = sequence.Keypoints[1]
    for _, point in sequence.Keypoints do
        if point.Value < lowest.Value then
            lowest = point
        end
    end
    return lowest.Time
end
advance(0.6)
local firstPeak = peak(flow.Transparency)
advance(0.6)
local secondPeak = peak(flow.Transparency)
advance(0.6)
local thirdPeak = peak(flow.Transparency)
check(
    firstPeak < secondPeak and secondPeak < thirdPeak,
    "bright segment moves forward from player Attachment0 to stash Attachment1"
)
advance(0.6)
advance(0.6)
check(peak(flow.Transparency) < thirdPeak, "forward flow repeats from the player without reversing")
root.Position = vec(2, 0, 0)
advance()
check(
    beams()[1] == beam and beams("TutorialStashFlow")[1] == flow,
    "moving avatar keeps the same smoothly attached beams"
)
root.Position = vec(0, 0, 0)
local start, finish = beam.Attachment0, beam.Attachment1
p:SetAttribute("TutorialStage", "Blender")
check(
    #beams() == 0 and #beams("TutorialStashFlow") == 0 and start.Destroyed and finish.Destroyed,
    "completing pickup destroys beam and both local attachments"
)
advance()
check(hintContains("Click to throw into the blender!"), "mouse wording")
services.UserInputService.PreferredInput = "Touch"
preferredChanged:Fire()
advance()
check(hintContains("Tap Throw to toss it in!"), "preferred touch switches the displayed hint")
services.UserInputService.PreferredInput = "Gamepad"
preferredChanged:Fire()
advance()
check(hintContains("Press R2 to throw into the blender!"), "controller wording reads the live carry binding")
services.UserInputService.GetStringForKeyCode = function()
    return "RT"
end
advance()
advance()
check(hintContains("Press RT"), "platform binding label can change while the objective persists")
p:SetAttribute("TutorialStage", "Stash")
advance()
check(
    hintContains("Grab ingredients") and #beams() == 1,
    "repeated one-item stash objective resumes text and beam without another dialogue delay"
)
p:SetAttribute("TutorialStage", "Blender")
advance()
check(#beams() == 0, "returning to throwing clears the repeated pickup beam")
banner.SetGlobalActive(true)
check(not label().Visible, "announcement priority hides tutorial synchronously")
p:SetAttribute("TutorialStage", "Turbine")
advance(20)
check(not label().Visible, "progress continues without visual overlap during announcements")
banner.SetGlobalActive(false)
check(hintContains("Spin to blend smoothie!"), "priority release resumes the current objective")
-- Exercise the actual announcement producer, including entrance/exit and queue drain.
shared.AnnouncementFormat = "AnnouncementFormat"
services.ReplicatedStorage.WaitForChild = function(_, name)
    return services.ReplicatedStorage[name]
end
shared.WaitForChild = function(_, name)
    return shared[name]
end
shared.Events.WaitForChild = shared.Events.FindFirstChild
p.WaitForChild = p.FindFirstChild
local remote = instance("RemoteEvent")
remote.Name, remote.Parent, remote.OnClientEvent = "RareIngredientSpawned", shared.Events, signal()
services.SoundService = instance("Folder")
local rare = controllerModule("RareIngredientPresentationController")
rare.Init()
flush()
local overlaps = 0
local observedGlobal = false
env.task.wait = function(seconds)
    now += seconds or 0.1
    heartbeat:Fire(0.1)
    local globalGui = gui:FindFirstChild("RareIngredientAnnouncement")
    local globalLabel = globalGui:FindFirstChild("Announcement")
    if globalLabel.Visible then
        observedGlobal = true
        if label() and label().Visible then
            overlaps += 1
        end
    end
end
remote.OnClientEvent:Fire({ Type = "MysteryAcquired", DisplayName = "Learner" })
flush()
check(observedGlobal and overlaps == 0, "real global announcement never overlaps a tutorial hint, including exit")
check(hintContains("Spin to blend smoothie!"), "real announcement drain restores the ongoing tutorial")
local previous = label()
p.CharacterRemoving:Fire(p.Character)
check(label() == nil, "respawn clears visible UI")
p.CharacterAdded:Fire(p.Character)
check(hintContains("Spin to blend smoothie!"), "respawn resumes current stage rather than restarting")
label().Parent:Destroy()
advance()
check(hintContains("Spin to blend smoothie!") and label() ~= previous, "GUI destruction is recovered")
p:SetAttribute("TutorialStage", "Dispenser")
check(
    hintContains("Dispense your smoothie!") and highlights()[1].Adornee == dispenser,
    "ready smoothie shows the original dispensing instruction with dispenser highlight"
)
p:SetAttribute("TutorialStage", "Turbine")
p:SetAttribute("TutorialStage", "Dispenser")
check(
    hintContains("Dispense your smoothie!") and label().TextTransparency == 0,
    "dispensing readiness cancels an outgoing animation immediately"
)
p:SetAttribute("TutorialStage", "Serve")
advance()
check(
    hintContains("Serve customer and get PAYED!") and highlights()[1].Adornee == customer,
    "smoothie collection proceeds directly to serving, without relocating counter navigation"
)
advance(5)
check(
    hintContains("Serve customer and get PAYED!"),
    "failed serve without authoritative progression retains Serve guidance"
)
root.Position = vec(0, 0, 0)
for _, index in { 2, 3 } do
    p:SetAttribute("TutorialOrderIndex", index)
    for _, stage in { "Order", "Stash", "Blender", "Turbine", "Dispenser", "Serve" } do
        p:SetAttribute("TutorialStage", stage)
        advance(20)
        check(noHint() and #beams() == 0, "later tutorial customers never show text or stash beams, even on hesitation")
        if stage == "Stash" then
            check(#highlights() == 2, "later customers retain existing yellow stash highlights")
        end
    end
end
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("TutorialStage", "Stash")
advance(20)
check(noHint() and #beams() == 0, "first-serve text suppression is latched for the entire session")
observedGlobal = false
remote.OnClientEvent:Fire({ Type = "MysteryAcquired", DisplayName = "Learner" })
flush()
check(observedGlobal and noHint(), "normal global broadcasts still work after tutorial text is disabled")
p:SetAttribute("TutorialStage", "Complete")
p:SetAttribute("TutorialActive", false)
check(label() == nil, "completion removes tutorial GUI")
p:SetAttribute("TutorialStage", "Order")
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("PlotSessionId", "fresh-session")
p:SetAttribute("TutorialActive", true)
advance()
check(hintContains("Take the customer's order!"), "a fresh plot session can restart guidance after completion")
-- A fresh session gets its own cancellable first-order dialogue delay.
plot:SetAttribute("PlotSessionId", "fresh-session")
p:SetAttribute("TutorialStage", "Stash")
advance(1)
p.CharacterRemoving:Fire(p.Character)
advance(5)
check(noHint() and #beams() == 0, "reset cancels the pending hint and beam")
p.CharacterAdded:Fire(p.Character)
advance(2.4)
check(noHint() and #beams() == 0, "respawn cannot revive the removed avatar's old deadline")
advance(0.1)
check(
    hintContains("Grab ingredients") and #beams() == 1,
    "respawn can resume the still-valid pickup objective with a fresh delay"
)
p:SetAttribute("TutorialStage", "Blender")
advance()
check(#beams() == 0, "respawn beam clears on real objective change")
p:SetAttribute("TutorialStage", "Order")
p:SetAttribute("PlotSessionId", "rapid-session")
plot:SetAttribute("PlotSessionId", "rapid-session")
p:SetAttribute("TutorialStage", "Stash")
advance(1)
p:SetAttribute("TutorialStage", "Blender")
advance(5)
check(hintContains("Press RT") and #beams() == 0, "rapid gameplay cannot revive an obsolete delayed stash objective")
-- Initial counter deadlines cancel on respawn and faster order acceptance.
p:SetAttribute("TutorialStage", "ClaimPlot")
p:SetAttribute("PlotSessionId", "counter-session")
plot:SetAttribute("PlotSessionId", "counter-session")
p:SetAttribute("TutorialStage", "Counter")
advance(1)
p.CharacterRemoving:Fire(p.Character)
advance(5)
check(noHint() and #highlights() == 0, "reset cancels pending initial counter navigation")
p.CharacterAdded:Fire(p.Character)
advance(2.9)
check(noHint(), "respawn cannot reuse the removed avatar's counter deadline")
advance(0.1)
check(hintContains("Head to your customer counter!"), "valid initial counter objective resumes after a fresh delay")
p:SetAttribute("TutorialStage", "ClaimPlot")
p:SetAttribute("PlotSessionId", "early-order-session")
plot:SetAttribute("PlotSessionId", "early-order-session")
p:SetAttribute("TutorialStage", "Counter")
advance(1)
p:SetAttribute("TutorialStage", "Order")
advance(5)
check(hintContains("Take the customer's order!"), "early counter arrival cancels obsolete delayed navigation")
p:SetAttribute("TutorialStage", "Stash")
advance(2.5)
check(hintContains("Grab ingredients from the stash!"), "early order acceptance keeps the correct stash objective")
root.Position = vec(0, 0, 0)
p:SetAttribute("TutorialStage", "Order")
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("TutorialStage", "Order")
p:SetAttribute("PlotSessionId", "cancel-session")
p:SetAttribute("TutorialStage", "Stash")
p:SetAttribute("TutorialActive", false)
advance(5)
check(
    noHint() and #beams() == 0 and #highlights() == 0,
    "tutorial cancellation clears pending and active world/UI work"
)
controller.Destroy()
gleamScript.Destroying:Fire()
preferredChanged:Fire()
advance(20)
check(
    label() == nil and #beams() == 0 and #beams("TutorialStashFlow") == 0,
    "shutdown cannot resurrect tutorial UI or beam"
)
