-- Workspace lookup boundary supports authored global scenery in this suite.
workspaceFake.FindFirstChild = function(_, name)
    for _, object in allInstances do
        if object.Parent == workspaceFake and object.Name == name then
            return object
        end
    end
    return nil
end
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
-- Attachments follow their parent in the engine; supply positions at this test boundary.
local originalInstance = env.Instance.new
env.Instance.new = function(class)
    local object = originalInstance(class)
    if class == "Attachment" then
        object.WorldPosition = vec(0, 0, 0)
    end
    return object
end
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
local function part(name, owner)
    local result = instance("Part")
    result.Name, result.Parent = name, owner
    return result
end
local identity = instance("Folder")
identity.Name, identity.Parent = "PlotIdentity", plot
local claimPad = part("ClaimVisual", identity)
local arrival = instance("ObjectValue")
arrival.Name, arrival.Parent, arrival.Value = "TutorialSpawnTarget", p, plot
arrival.GetPropertyChangedSignal = function()
    return signal()
end
local blender = instance("Model")
blender.Name, blender.Parent = "Blender", plot
part("Glass", blender)
local input = part("InputZone", blender)
services.CollectionService:AddTag(input, "BlenderInput")
local inputMarker = instance("Attachment")
inputMarker.Name, inputMarker.Parent = "VacuumTarget", input
local wheel = instance("Model")
wheel.Name, wheel.Parent = "Turbine Wheel", plot
local turbine = instance("Model")
turbine.Name, turbine.Parent = "turbine", wheel
part("anchor", turbine)
part("blade", turbine)
local stem = part("stem", turbine)
stem.Anchored, stem.Size = true, vec(2, 12, 2)
local turbineOrigin = instance("Attachment")
turbineOrigin.WorldPosition = vec(0, 0, 0)
turbineOrigin.Name, turbineOrigin.Parent = "TurbineBeamTarget", stem
local dispenserPart = part("Output", dispenser)
dispenserPart.Anchored = true
local dispenserMarker = instance("Attachment")
dispenserMarker.Parent = dispenserPart
dispenserMarker.WorldPosition = vec(0, 0, 0)
local dispensePrompt = instance("ProximityPrompt")
dispensePrompt.Parent = dispenserMarker
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
plot:SetAttribute("PlotSessionId", nil)
controller.Init()
gleam.Init()
check(
    hintContains("Claim your smoothie stand!"),
    "stand claiming is the first immediate instruction, before world hint readiness"
)
check(
    #beams() == 1 and beams()[1].Attachment1.Parent == claimPad,
    "claim beam and highlight activate with the immediate claim instruction"
)
plot:SetAttribute("PlotSessionId", "tutorial")
p:SetAttribute("PlotSessionId", "tutorial")
p:SetAttribute("TutorialHintReady", true)
p:SetAttribute("TutorialStage", "Counter")
check(noHint() and #beams() == 0, "claim beam clears while initial counter navigation waits")
advance(2.9)
check(noHint(), "counter navigation waits three seconds after claiming")
advance(0.1)
check(
    hintContains("Head to your customer counter!")
        and highlights()[1].Adornee == counter
        and beams()[1].Attachment1.Parent == counter,
    "initial counter instruction appears three seconds after claiming"
)
p:SetAttribute("TutorialStage", "Order")
advance()
check(
    hintContains("Take the customer's order!") and beams()[1].Attachment1.Parent == customerRoot,
    "first order instruction guides to the active customer"
)
local navigationBeam = beams()[1]
customerRoot.Position = vec(65, 0, 0)
advance()
check(
    beams()[1] == navigationBeam and navigationBeam.Attachment1.Parent == customerRoot,
    "moving customer retains its attached endpoint and beam"
)
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
    beams()[1] == beam
        and beams("TutorialStashFlow")[1] == flow
        and not start.Destroyed
        and finish.Destroyed
        and beam.Attachment1 == inputMarker,
    "pickup retargets the same beam to the authored blender input attachment"
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
check(beams()[1] == beam and beam.Attachment1 == inputMarker, "repeated pickup/throw retargets without rebuilding")
for _ = 1, 2 do
    p:SetAttribute("TutorialStage", "Stash")
    check(beams()[1] == beam and beam.Attachment1.Parent == slot, "next ingredient returns to exact RED stash")
    p:SetAttribute("TutorialStage", "Blender")
    check(beams()[1] == beam and beam.Attachment1 == inputMarker, "next throw returns to blender until ingested")
end
check(
    not inputMarker.Destroyed and not turbineOrigin.Destroyed and not dispenserMarker.Destroyed,
    "retargeting never destroys authored interaction attachments"
)
-- Losing an authored endpoint recovers on the same outer/inner beam.
inputMarker:Destroy()
advance()
check(beams()[1] == beam and beam.Attachment1.Parent == input, "missing input marker falls back to the input part")
local temporaryEnd = beam.Attachment1
inputMarker = instance("Attachment")
inputMarker.Name, inputMarker.Parent = "VacuumTarget", input
advance()
check(
    beams()[1] == beam and beam.Attachment1 == inputMarker and temporaryEnd.Destroyed,
    "recreated interaction marker replaces only the temporary endpoint"
)
local foreignCustomer = instance("Model")
foreignCustomer.Parent = workspaceFake
foreignCustomer:SetAttribute("PlotSessionId", "someone-else")
part("HumanoidRootPart", foreignCustomer)
p:SetAttribute("TutorialStage", "Order")
customerTarget.Value = foreignCustomer
advance()
check(#beams() == 0 and #highlights() == 0, "foreign customer cannot receive local guidance")
customerTarget.Value = customer
advance()
check(beams()[1].Attachment1.Parent == customerRoot, "same-stage customer replacement recovers own target")
p:SetAttribute("PlotSessionId", nil)
check(#beams() == 0, "membership loss immediately removes the beam")
p:SetAttribute("PlotSessionId", "tutorial")
p:SetAttribute("TutorialStage", "Blender")
advance()
check(beams()[1].Attachment1 == inputMarker, "membership restoration resolves only the assigned plot")
banner.SetGlobalActive(true)
check(not label().Visible, "announcement priority hides tutorial synchronously")
p:SetAttribute("TutorialStage", "Turbine")
advance(20)
check(not label().Visible, "progress continues without visual overlap during announcements")
banner.SetGlobalActive(false)
check(
    hintContains("Spin to blend smoothie!") and beams()[1].Attachment1 == turbineOrigin,
    "turbine navigation uses its interaction origin"
)
-- Geometry can never suppress the single connected beam.
local originalBlockcast, originalRaycast = workspaceFake.Blockcast, workspaceFake.Raycast
local originalPath = services.PathfindingService.CreatePath
workspaceFake.Blockcast = function()
    error("beam must not query obstacles")
end
workspaceFake.Raycast = function()
    error("beam must not probe approaches")
end
services.PathfindingService.CreatePath = function()
    error("beam must not request routes")
end
local turbineBeam, turbineFlow = beams()[1], beams("TutorialStashFlow")[1]
local turbineStart, turbineFinish = turbineBeam.Attachment0, turbineBeam.Attachment1
local blade = turbine:FindFirstChild("blade")
services.CollectionService:AddTag(blade, "TurbineWheel")
local rotatingMarker = instance("Attachment")
rotatingMarker.Name, rotatingMarker.Parent = "TurbinePromptOrigin", blade
local stemConnectionPersisted = true
for index = 1, 30 do
    root.Position = vec(index * 2, -index, index)
    blade.CFrame = frame(index, index, index)
    advance(0.1)
    stemConnectionPersisted = stemConnectionPersisted
        and beams()[1] == turbineBeam
        and beams("TutorialStashFlow")[1] == turbineFlow
        and turbineBeam.Enabled
        and turbineFlow.Enabled
        and turbineBeam.Attachment0 == turbineStart
        and turbineBeam.Attachment1 == turbineFinish
        and turbineFinish.Parent == stem
end
check(stemConnectionPersisted, "movement, turbine rotation and intervening geometry preserve the fixed stem connection")
blade:Destroy()
turbine:FindFirstChild("anchor"):Destroy()
check(not turbineBeam.Destroyed, "decorative highlight destruction cannot remove the beam")
stem.Parent = wheel -- Stem remains replicated but decorative highlight paths disappear.
advance()
check(
    #highlights() == 0 and beams()[1] == turbineBeam and turbineBeam.Attachment1 == turbineOrigin,
    "turbine beam is independent of highlight target availability"
)
turbineOrigin.Parent = wheel -- Invalid marker is ignored; use a client attachment on the same fixed stem.
advance()
local localStemEnd = turbineBeam.Attachment1
check(
    beams()[1] == turbineBeam and localStemEnd.Parent == stem and localStemEnd.Position.Y == -3.5,
    "missing or invalid stable marker uses a fixed lower stem attachment without rebuilding"
)
advance(5)
check(
    beams()[1] == turbineBeam and turbineBeam.Attachment1 == localStemEnd and hintContains("Spin to blend smoothie!"),
    "stem fallback persists until authoritative progression changes"
)
turbineOrigin.Parent = stem
advance()
check(
    turbineBeam.Attachment1 == turbineOrigin and localStemEnd.Destroyed and not turbineOrigin.Destroyed,
    "valid authored stem marker is reused without retaining the temporary endpoint"
)
stem.Parent = nil
advance()
check(#beams() == 0, "streamed-out stem removes the invalid endpoint safely")
stem.Parent = turbine
part("anchor", turbine)
part("blade", turbine)
advance()
check(
    #beams() == 1 and beams()[1].Attachment1 == turbineOrigin,
    "replicated stem restores guidance without an objective reset"
)
workspaceFake.Blockcast, workspaceFake.Raycast = originalBlockcast, originalRaycast
services.PathfindingService.CreatePath = originalPath
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
local removedBeam = beams()[1]
local removedStart = removedBeam.Attachment0
p.CharacterRemoving:Fire(p.Character)
check(label() == nil and #beams() == 0 and removedStart.Destroyed, "respawn clears UI, beam and character attachment")
p.CharacterAdded:Fire(p.Character)
check(
    hintContains("Spin to blend smoothie!") and beams()[1].Attachment1 == turbineOrigin,
    "respawn resumes the current beam destination"
)
local oldCharacter = p.Character
local oldRoot = root
p.CharacterRemoving:Fire(oldCharacter)
local replacementCharacter = instance("Model")
replacementCharacter.Parent = workspaceFake
root = part("HumanoidRootPart", replacementCharacter)
local newHumanoid = instance("Humanoid")
newHumanoid.Health, newHumanoid.Parent = 100, replacementCharacter
p.Character = replacementCharacter
p.CharacterAdded:Fire(replacementCharacter)
check(
    beams()[1].Attachment0.Parent == root and beams()[1].Attachment0.Parent ~= oldRoot,
    "replacement character receives the only beam origin"
)
label().Parent:Destroy()
advance()
check(hintContains("Spin to blend smoothie!") and label() ~= previous, "GUI destruction is recovered")
p:SetAttribute("TutorialStage", "Dispenser")
check(
    hintContains("Dispense your smoothie!")
        and highlights()[1].Adornee == dispenser
        and beams()[1].Attachment1 == dispenserMarker,
    "ready smoothie shows the original dispensing instruction with dispenser highlight"
)
local dispenserBeam = beams()[1]
local dispensingStart = dispenserBeam.Attachment0
workspaceFake.Blockcast = function()
    error("dispenser beam must not query obstacles")
end
workspaceFake.Raycast = function()
    error("dispenser beam must not probe approaches")
end
services.PathfindingService.CreatePath = function()
    error("dispenser beam must not request routes")
end
local dispenserConnectionPersisted = true
for index = 1, 30 do
    root.Position = vec(-index * 3, index % 5, index * 2)
    advance(0.1)
    dispenserConnectionPersisted = dispenserConnectionPersisted
        and beams()[1] == dispenserBeam
        and dispenserBeam.Enabled
        and dispenserBeam.Attachment0 == dispensingStart
        and dispenserBeam.Attachment1 == dispenserMarker
        and beams("TutorialStashFlow")[1].Attachment1 == dispenserMarker
end
check(dispenserConnectionPersisted, "dispenser retains one connected pair through movement and geometry")
workspaceFake.Blockcast, workspaceFake.Raycast = originalBlockcast, originalRaycast
services.PathfindingService.CreatePath = originalPath
p:SetAttribute("TutorialStage", "Turbine")
check(
    beams()[1] == dispenserBeam and dispenserBeam.Attachment1 == turbineOrigin,
    "blending transition retargets the existing pair to the stationary stem"
)
p:SetAttribute("TutorialStage", "Dispenser")
check(
    beams()[1] == dispenserBeam and dispenserBeam.Attachment1 == dispenserMarker,
    "completed blend retargets the existing pair immediately to the dispenser"
)
check(
    hintContains("Dispense your smoothie!") and label().TextTransparency == 0,
    "dispensing readiness cancels an outgoing animation immediately"
)
p:SetAttribute("TutorialStage", "Serve")
advance()
check(
    hintContains("Serve customer and get PAYED!")
        and highlights()[1].Adornee == customer
        and beams()[1].Attachment1.Parent == customerRoot,
    "smoothie collection proceeds directly to serving, without relocating counter navigation"
)
advance(5)
check(
    hintContains("Serve customer and get PAYED!"),
    "failed serve without authoritative progression retains Serve guidance"
)
root.Position = vec(0, 0, 0)
for _, stage in { "BuyJump", "BuyBat" } do
    -- Stage replication can precede the new order index and its beam retirement latch.
    p:SetAttribute("TutorialStage", stage)
    check(
        #beams() == 0 and #beams("TutorialStashFlow") == 0 and #highlights() == 0,
        "entering " .. stage .. " clears the previous Serve beam and gleam before order-index replication"
    )
    p:SetAttribute("TutorialStage", "Serve")
    advance()
end
local serveBeam = beams()[1]
local serveStart, serveEnd = serveBeam.Attachment0, serveBeam.Attachment1
for _, index in { 2, 3 } do
    p:SetAttribute("TutorialOrderIndex", index)
    check(
        #beams() == 0 and #beams("TutorialStashFlow") == 0 and serveStart.Destroyed and serveEnd.Destroyed,
        "committed first serve immediately removes both beams and temporary endpoints"
    )
    p.CharacterRemoving:Fire(p.Character)
    p.CharacterAdded:Fire(p.Character)
    for _, stage in { "Order", "Stash", "Blender", "Turbine", "Dispenser", "Serve" } do
        p:SetAttribute("TutorialStage", stage)
        advance(20)
        check(noHint() and #beams() == 0, "later tutorial customers never show text or stash beams, even on hesitation")
        check(#highlights() > 0, "later customers retain yellow highlights for every objective")
    end
end
local text = loadModule("TutorialHintText")
for _, hint in
    {
        { Stage = "BuyJump", Order = 2, Ending = "JUMP 1!" },
        { Stage = "BuyBat", Order = 3, Ending = "a Bat Weapon!" },
    }
do
    for _, input in { "Touch", "KeyboardAndMouse", "Gamepad" } do
        local action = if input == "Touch" then "Tap" else "Click"
        check(
            text.Get(hint.Stage, env.Enum.PreferredInput[input], "R2") == action .. " Upgrade and buy " .. hint.Ending,
            hint.Stage .. " uses exact " .. input .. " wording"
        )
    end
    p:SetAttribute("TutorialStage", "NextCustomer")
    advance()
    check(#beams() == 1 and #highlights() > 0, "serve guidance exists before entering " .. hint.Stage)
    -- Stage can replicate before the next order index: cleanup must still be immediate.
    p:SetAttribute("TutorialStage", hint.Stage)
    p:SetAttribute("TutorialOrderIndex", hint.Order)
    local allowed, ready, stage, beamAllowed = presentation.Read(p)
    check(
        allowed and ready and stage == hint.Stage and not beamAllowed and presentation.IsActive(p, stage),
        hint.Stage .. " immediately bypasses retired text without allowing a beam"
    )
    check(#beams() == 0 and #highlights() == 0, "Buy stages clear world guidance immediately")
    advance(0.2) -- Existing banner exit animation; no order-dialogue read delay.
    check(
        hintContains("Click Upgrade and buy " .. hint.Ending)
            and #beams() == 0
            and #beams("TutorialStashFlow") == 0
            and #highlights() == 0,
        hint.Stage .. " clears previous guidance and shows the upgrade hint without a read delay"
    )
    p.CharacterRemoving:Fire(p.Character)
    check(noHint(), "upgrade hint hides while the character is removed")
    p.CharacterAdded:Fire(p.Character)
    advance()
    check(hintContains("Click Upgrade and buy " .. hint.Ending), "upgrade hint resumes after respawn")
end
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("TutorialStage", "Stash")
advance(20)
check(noHint() and #beams() == 0, "first-serve text suppression is latched for the entire session")
observedGlobal = false
remote.OnClientEvent:Fire({ Type = "MysteryAcquired", DisplayName = "Learner" })
flush()
check(observedGlobal and noHint(), "normal global broadcasts still work after tutorial text is disabled")
local market = instance("Model")
market.Name, market.Parent = "Central Market", workspaceFake
local marketBase = part("CentralMarketBase", market)
p:SetAttribute("TutorialStage", "NextCustomer")
advance()
check(hintContains("See what the next customer wants!"), "next customer bypasses opening retirement")
p:SetAttribute("TutorialStage", "Market")
advance(0)
check(noHint() and #beams() == 0, "market transition suppresses text and beam")
advance(2.49)
check(noHint() and #beams() == 0, "market read hold lasts 2.5 seconds")
advance(0.02)
check(
    hintContains("Collect more from the Central Market!") and beams()[1].Attachment1.Parent == marketBase,
    "market text and beam bypass first-serve retirement"
)
local jump = part("JUMP1HIGHLIGHT", market)
p:SetAttribute("TutorialStage", "MarketJump")
advance()
check(
    hintContains("Jump higher for valuable ingredients!") and highlights()[1].Adornee == jump,
    "jump hint and gleam bypass retirement"
)
p:SetAttribute("TutorialStage", "Market")
advance()
check(hintContains("Collect more from the Central Market!"), "market read delay only fires once per session")
p:SetAttribute("TutorialStage", "Complete")
p:SetAttribute("TutorialActive", false)
check(label() == nil, "completion removes tutorial GUI")
local farm = instance("Model")
farm.Name, farm.Parent = "Farm", plot
local row = instance("Model")
row.Name, row.Parent = "Row1", farm
local pad = part("PurchasePoint1", row)
local visual = instance("Model")
visual.Name, visual.Parent = "Visual", row
local pebble = part("Pebble", visual)
part("plank2", visual)
p:SetAttribute("TutorialHintReady", false)
p:SetAttribute("FarmTutorialStage", "BuyRow")
advance()
check(
    hintContains("Buy a farm row!") and beams()[1].Attachment1.Parent == pad,
    "farm purchase hint and beam present after opening completion"
)
p:SetAttribute("FarmTutorialStage", "Plant")
advance()
check(
    hintContains("Plant an ingredient!") and #highlights() == 2 and beams()[1].Attachment1.Parent == pebble,
    "farm planting shares hint UI and authored spots"
)
p:SetAttribute("FarmTutorialStage", "Harvest")
advance()
check(
    hintContains("Harvest your ingredients!") and #highlights() == 2,
    "harvest bypasses opening retirement with visual fallback"
)
local harvestProducts = {}
for index = 1, 3 do
    local product = part("Harvest" .. index, workspaceFake)
    harvestProducts[index] = product
    local reference = instance("ObjectValue")
    reference.Name, reference.Parent, reference.Value = "TutorialHarvestTarget", row, product
end
advance()
check(
    #highlights() == 3 and highlights()[1].Adornee == harvestProducts[1],
    "harvest flashes the three actual world products"
)
harvestProducts[1]:Destroy()
advance()
check(
    #highlights() == 2 and highlights()[1].Adornee == harvestProducts[2],
    "harvest updates as production is collected"
)
p:SetAttribute("FarmTutorialStage", "Done")
check(noHint() and #beams() == 0 and #highlights() == 0, "Done clears all farm presentation")
p:SetAttribute("FarmTutorialStage", "")
check(noHint(), "empty farm stage also presents nothing")
p:SetAttribute("TutorialHintReady", true)
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
    hintContains("Grab ingredients") and #beams() == 0,
    "beam retirement persists across membership changes; text can resume the still-valid pickup objective with a fresh delay"
)
p:SetAttribute("TutorialStage", "Blender")
advance()
check(#beams() == 0, "retired beam stays disabled on real objective change")
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

local routingArtifact = false
for _, object in allInstances do
    if
        not object.Destroyed
        and (
            object.Name == "TutorialBeamWaypoints"
            or object.Name == "TutorialRouteBeam"
            or object.Name == "TutorialRouteFlow"
        )
    then
        routingArtifact = true
    end
end
check(not routingArtifact, "single-beam guidance creates no routing artifacts")

local _, readLiteralCount = sources.TutorialPresentationState:gsub("2%.5", "")
local _, readUseCount = sources.TutorialPresentationState:gsub("os%.clock%(%) %+ ORDER_READ_SECONDS", "")
check(readLiteralCount == 1 and readUseCount == 2, "stash and market use one shared read-delay constant")

-- The market read hold shares the opening's cancellation guards and resets by session.
p:SetAttribute("PlotSessionId", "market-guard-session")
p:SetAttribute("TutorialActive", true)
p:SetAttribute("TutorialStage", "NextCustomer")
presentation.Read(p)
p:SetAttribute("TutorialStage", "Market")
local _, ready = presentation.Read(p)
check(not ready, "fresh session gets a fresh market read hold")
now += 1
presentation.CharacterRemoving(p.Character)
now += 5
local _, removedReady = presentation.Read(p)
check(not removedReady, "removed character cannot consume market read hold")
presentation.CharacterAdded()
presentation.Read(p)
now += 2.49
local _, earlyReady = presentation.Read(p)
check(not earlyReady, "respawn starts a fresh market reading interval")
p:SetAttribute("TutorialActive", false)
presentation.Read(p)
now += 5
p:SetAttribute("TutorialActive", true)
local _, resumedReady = presentation.Read(p)
check(not resumedReady, "inactive tutorial cancels its market deadline")
now += 2.5
local _, finalReady = presentation.Read(p)
check(finalReady, "valid resumed tutorial presents after the shared reading interval")
