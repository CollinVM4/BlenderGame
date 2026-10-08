shared.TutorialTargets = "TutorialTargets"
local targets = loadModule("TutorialTargets")
services.CollectionService.GetTags = function(_, target)
    local names = {}
    for tag, objects in tags do
        if table.find(objects, target) then
            table.insert(names, tag)
        end
    end
    return names
end
local function object(class, name, parentObject)
    local result = instance(class)
    result.Name, result.Parent, result.Transparency = name, parentObject, 0
    if class == "UnionOperation" then
        local inherited = result.IsA
        result.IsA = function(self, wanted)
            return wanted == "BasePart" or inherited(self, wanted)
        end
        local cloneUnion = result.Clone
        result.Clone = function(self)
            local clone = cloneUnion(self)
            if clone then
                clone.GetAttributes = function(self)
                    return table.clone(self.Attributes)
                end
                for _, tag in services.CollectionService:GetTags(self) do
                    services.CollectionService:AddTag(clone, tag)
                end
            end
            return clone
        end
    end
    return result
end
local plot = object("Model", "OwnPlot", workspaceFake)
local other = object("Model", "OtherPlot", workspaceFake)
local stash = object("Model", "AuthoredStorage", plot)
services.CollectionService:AddTag(stash, "PlayerStash")
local foreign = object("Model", "Stash", other)
services.CollectionService:AddTag(foreign, "PlayerStash")
local stashSlots = {}
local stashBases = {}
for index = 1, 5 do
    stashSlots[index] = object("Part", "Slot" .. index, stash)
    stashSlots[index]:SetAttribute("SlotIndex", index)
    stashBases[index] = object("Part", "base", stashSlots[index])
end
local stashBase = stashBases[3]
local stashTargets = targets.Resolve(plot, "Stash", 3)
check(
    #stashTargets == 2 and stashTargets[1] == stashSlots[3] and stashTargets[2] == stashBase,
    "stash selects only exact own slot three and authored base"
)
check(#targets.Resolve(plot, "Stash") == 0, "missing slot never falls back to whole stash")
local unrelatedBase = object("Part", "base", stash)
check(
    not table.find(targets.Resolve(plot, "Stash", 3), unrelatedBase),
    "stash-level geometry cannot replace exact Slot3/base"
)
local identity = object("Folder", "PlotIdentity", plot)
local visual = object("UnionOperation", "ClaimVisual", identity)
object("Part", "ClaimZone", identity)
check(targets.Resolve(plot, "ClaimPlot")[1] == visual, "claim targets visible pad only")
local ladder = object("Model", "Ladder", plot)
check(targets.Resolve(plot, "Ladder")[1] == ladder, "whole ladder model supported")
local wheel = object("Model", "Turbine Wheel", plot)
local turbine = object("Model", "turbine", wheel)
for _, name in { "anchor", "blade", "stem", "protector shell", "Invis Wall" } do
    object("Part", name, turbine)
end
local group = targets.Resolve(plot, "Turbine")
check(
    #group == 3 and group[1].Name == "anchor" and group[2].Name == "blade" and group[3].Name == "stem",
    "turbine gleams exact grouped pieces"
)
local area = object("Model", "Customer Area", plot)
local counter = object("Model", "Counter", area)
local structure = object("Model", "Base Structure", counter)
local base = object("Part", "Base", structure)
check(targets.Resolve(plot, "Counter")[1] == base, "exact counter base")
check(#targets.Resolve(plot, "Dispenser") == 0, "temporarily missing target safe")
local dispenser = object("Model", "Dispenser", plot)
check(targets.Resolve(plot, "Dispenser")[1] == dispenser, "newly created targets re-resolve")
dispenser:Destroy()
check(#targets.Resolve(plot, "Dispenser") == 0, "destroyed target no longer resolves")
check(#targets.Resolve(nil, "Ladder") == 0, "no plot means no owned gleam")

-- Exercise the actual local controller with engine Tween/attribute signal doubles.
services.CollectionService:AddTag(plot, "PlayerPlot")
plot:SetAttribute("PlotSessionId", "local-session")
local player = object("Player", "LocalLearner", workspaceFake)
player.Character = object("Model", "Character", workspaceFake)
player.CharacterAdded = signal()
player.ChildAdded, player.ChildRemoved = signal(), signal()
local humanoid = object("Humanoid", "Humanoid", player.Character)
humanoid.Health = 100
services.Players.LocalPlayer = player
env.Enum.Material = { Glass = "Glass" }
env.Enum.HighlightDepthMode = { AlwaysOnTop = "AlwaysOnTop" }
env.Enum.EasingStyle = { Sine = "Sine" }
env.Enum.EasingDirection = { InOut = "InOut" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
local animation = {}
services.TweenService = {
    Create = function(_, target, info, goal)
        local tween = { Target = target, Info = info, Goal = goal }
        tween.Play = function(self)
            self.Played = true
        end
        tween.Cancel = function(self)
            self.Cancelled = true
        end
        table.insert(animation, tween)
        return tween
    end,
}
local changes = {}
player.GetAttributeChangedSignal = function(_, name)
    changes[name] = changes[name] or signal()
    return changes[name]
end
local setter = player.SetAttribute
player.SetAttribute = function(self, name, value)
    setter(self, name, value)
    if changes[name] then
        changes[name]:Fire()
    end
end
player:SetAttribute("PlotSessionId", "local-session")
player:SetAttribute("TutorialActive", true)
player:SetAttribute("TutorialStage", "Turbine")
player:SetAttribute("TutorialHintReady", false)
local controllerScript = instance("ModuleScript")
local chunk = assert(loadstring(sources.TutorialGleamController))
setfenv(chunk, setmetatable({ script = controllerScript }, { __index = env }))
local controller = chunk()
controller.Init()
local function gleams()
    local result = {}
    for _, object in allInstances do
        if object.ClassName == "Highlight" and not object.Destroyed then
            table.insert(result, object)
        end
    end
    return result
end
check(#gleams() == 0, "conditional wait produces no local visual")
player:SetAttribute("TutorialHintReady", true)
local active = gleams()
check(
    #active == 3 and active[1].DepthMode == "AlwaysOnTop" and active[1].FillTransparency == 0.70,
    "local turbine group creates soft through-wall highlights"
)
check(
    animation[1].Played
        and animation[1].Goal.FillTransparency == 0.35
        and animation[1].Info[4] == -1
        and animation[1].Info[5],
    "gleam pulse repeats and reverses"
)
player:SetAttribute("TutorialStage", "Ladder")
check(
    active[1].Destroyed and animation[1].Cancelled and #gleams() == 1 and gleams()[1].Adornee == ladder,
    "stage change cancels pulses and destroys previous gleams immediately"
)
humanoid.Health = 0
heartbeat:Fire(0.1)
check(#gleams() == 0, "death removes visuals")
humanoid.Health = 100
player.CharacterAdded:Fire(player.Character)
check(#gleams() == 1, "respawn restores unfinished stage")
ladder:Destroy()
heartbeat:Fire(0.1)
check(#gleams() == 0, "missing target removes stale gleam")
ladder = object("Model", "Ladder", plot)
heartbeat:Fire(0.1)
check(#gleams() == 1 and gleams()[1].Adornee == ladder, "recreated target restores hint")
player:SetAttribute("PlotSessionId", nil)
check(#gleams() == 0, "membership loss removes owned target immediately")
player:SetAttribute("PlotSessionId", "local-session")
player:SetAttribute("TutorialActive", false)
check(#gleams() == 0, "completion destroys active tween visuals immediately")

-- Every non-Blender teaching stage remains a direct Highlight target.
player:SetAttribute("TutorialActive", true)
local visibleDispenser = object("Model", "Dispenser", plot)
for stage, target in { Ladder = ladder, Dispenser = visibleDispenser, Counter = base } do
    player:SetAttribute("TutorialStage", stage)
    check(#gleams() == 1 and gleams()[1].Adornee == target, stage .. " always uses direct Highlight")
end
player:SetAttribute("TutorialStage", "Stash")
for index = 3, 5 do
    player:SetAttribute("TutorialStashSlot", index)
    check(
        #gleams() == 2 and gleams()[1].Adornee == stashSlots[index] and gleams()[2].Adornee == stashBases[index],
        "only current stash slot and base gleam"
    )
    controller.Init()
    heartbeat:Fire(0.1)
    check(#gleams() == 2, "controller recreation cannot duplicate stash gleams")
end
player:SetAttribute("TutorialStashSlot", nil)
check(#gleams() == 0, "slot loss clears previous stash gleams without broad fallback")
-- Claim presentation uses only the replicated arrival target, with no membership.
player:SetAttribute("TutorialActive", true)
player:SetAttribute("PlotSessionId", nil)
player:SetAttribute("TutorialStage", "ClaimPlot")
check(#gleams() == 0, "claim never substitutes an unrelated free plot when arrival target is nil")
local reserved = object("ObjectValue", "TutorialSpawnTarget", player)
local valueChanged = signal()
reserved.GetPropertyChangedSignal = function(_, property)
    setup(property == "Value", "subscribe to replicated arrival target Value")
    return valueChanged
end
plot:SetAttribute("PlotSessionId", nil)
reserved.Value = plot
player:SetAttribute("TutorialHintReady", false)
player.ChildAdded:Fire(reserved)
check(#gleams() == 0, "arrival target cannot render before conditional hint activation")
player:SetAttribute("TutorialHintReady", true)
check(
    #gleams() == 1 and gleams()[1].Adornee == visual,
    "late arrival ObjectValue resolves ClaimVisual without assigned plot"
)
local secondIdentity = object("Folder", "PlotIdentity", other)
local secondVisual = object("Model", "ClaimVisual", secondIdentity)
object("Part", "VisiblePad", secondVisual)
local oldClaim = gleams()[1]
reserved.Value = other
valueChanged:Fire()
check(
    oldClaim.Destroyed and #gleams() == 1 and gleams()[1].Adornee == secondVisual,
    "arrival target Value change immediately replaces claim gleam"
)
reserved.Value = nil
valueChanged:Fire()
check(#gleams() == 1 and gleams()[1].Adornee == secondVisual, "reservation expiry retains pinned direct claim gleam")
local pinnedGleam = gleams()[1]
for _ = 1, 40 do
    heartbeat:Fire(1)
end
check(gleams()[1] == pinnedGleam, "active claim gleam persists beyond reservation lifetime without restarting pulse")
other:SetAttribute("PlotSessionId", "occupied")
heartbeat:Fire(0.1)
check(#gleams() == 0, "pinned claim target is abandoned when the plot becomes owned")
other:SetAttribute("PlotSessionId", nil)
reserved.Value = other
valueChanged:Fire()
pinnedGleam = gleams()[1]
reserved.Parent = nil
player.ChildRemoved:Fire(reserved)
check(gleams()[1] == pinnedGleam, "arrival ObjectValue removal also preserves active claim pin")
local replacement = object("ObjectValue", "TutorialSpawnTarget", player)
replacement.GetPropertyChangedSignal = function()
    return signal()
end
replacement.Value = other
player.ChildAdded:Fire(replacement)
check(#gleams() == 1 and gleams()[1].Adornee == secondVisual, "replaced arrival ObjectValue rebinds")
-- Claim membership is the presentation completion condition.
player:SetAttribute("PlotSessionId", "local-session")
check(#gleams() == 0, "successful membership immediately removes claim gleam")
plot:SetAttribute("PlotSessionId", "local-session")
player:SetAttribute("TutorialStage", "Counter")
check(#gleams() == 1 and gleams()[1].Adornee == base, "after claim counter becomes first owned target")
local servingTarget = object("ObjectValue", "TutorialCustomerTarget", player)
local currentCustomer = object("Model", "TutorialCustomer", workspaceFake)
currentCustomer:SetAttribute("PlotSessionId", "local-session")
servingTarget.Value = currentCustomer
player:SetAttribute("TutorialStage", "Serve")
check(#gleams() == 1 and gleams()[1].Adornee == currentCustomer, "serving gleams the current scripted customer")
currentCustomer:SetAttribute("PlotSessionId", "foreign-session")
heartbeat:Fire(0.1)
check(#gleams() == 0, "foreign customer can never gleam")
-- Named Blender/Glass follows current membership; retry needs no stage change.
player:SetAttribute("PlotSessionId", "local-session")
player:SetAttribute("TutorialStage", "Blender")
check(#gleams() == 0, "missing Blender Glass is safe")
local blender = object("Model", "Blender", plot)
local glass = object("UnionOperation", "Glass", blender)
glass.Transparency, glass.LocalTransparencyModifier, glass.Material = 0.66, 0, "SmoothPlastic"
glass.CanCollide, glass.CanTouch, glass.CanQuery, glass.Anchored, glass.CastShadow = true, true, true, false, true
glass:SetAttribute("IngredientId", "CopiedMetadata")
services.CollectionService:AddTag(glass, "SourceGeometryOnly")
object("Script", "UnwantedRuntime", glass)
object("Attachment", "UnwantedAttachment", glass)
heartbeat:Fire(0.1)
check(
    #gleams() == 1 and gleams()[1].Adornee ~= glass and gleams()[1].Enabled,
    "Blender retries same stage and adorns local Glass proxy with enabled Highlight"
)
local proxy = gleams()[1].Adornee
check(
    proxy.ClassName == "UnionOperation" and proxy.CFrame == glass.CFrame and proxy.Size == glass.Size,
    "proxy clones the UnionOperation and preserves authored silhouette bounds"
)
check(
    proxy.Parent == workspaceFake
        and proxy.Anchored
        and not proxy.CanCollide
        and not proxy.CanTouch
        and not proxy.CanQuery
        and not proxy.CastShadow
        and proxy.Transparency == 1
        and proxy.Material == "Glass"
        and #proxy:GetChildren() == 0,
    "proxy is local noninteractive invisible geometry stripped of children"
)
check(
    glass.Transparency == 0.66
        and glass.Material == "SmoothPlastic"
        and glass.CanCollide
        and glass.CanTouch
        and glass.CanQuery
        and not glass.Anchored
        and glass.CastShadow
        and #glass:GetChildren() == 2,
    "real Glass render, physics and children remain unchanged"
)
check(
    proxy:GetAttribute("IngredientId") == nil
        and #services.CollectionService:GetTags(proxy) == 0
        and glass:GetAttribute("IngredientId") == "CopiedMetadata"
        and services.CollectionService:HasTag(glass, "SourceGeometryOnly"),
    "proxy strips gameplay metadata without mutating source tags or attributes"
)
local oldGlass = gleams()[1]
glass:Destroy()
check(
    oldGlass.Destroyed and proxy.Destroyed and #gleams() == 0,
    "Glass destruction immediately removes proxy and highlight"
)
local recreatedGlass = object("UnionOperation", "Glass", blender)
recreatedGlass.Transparency = 0.66
heartbeat:Fire(0.1)
local rebuiltProxy = gleams()[1].Adornee
check(
    rebuiltProxy ~= proxy and rebuiltProxy.ClassName == "UnionOperation",
    "same-stage Glass recreation rebuilds union proxy"
)
player:SetAttribute("PlotMembershipRevision", 2)
check(rebuiltProxy.Destroyed and #gleams() == 1, "membership revision immediately discards old proxy")
local memberProxy = gleams()[1].Adornee
player:SetAttribute("TutorialStage", "Ladder")
check(memberProxy.Destroyed and gleams()[1].Adornee == ladder, "leaving Blender destroys proxy; Ladder stays direct")
player:SetAttribute("TutorialStage", "Blender")
local activeProxy = gleams()[1].Adornee
player:SetAttribute("TutorialActive", false)
check(activeProxy.Destroyed and #gleams() == 0, "tutorial deactivation immediately destroys Glass proxy")
player:SetAttribute("TutorialActive", true)
recreatedGlass:Destroy()
heartbeat:Fire(0.1)
local glassModel = object("Model", "Glass", blender)
object("Part", "Pane", glassModel)
heartbeat:Fire(0.1)
check(#gleams() == 1 and gleams()[1].Adornee == glassModel, "recreated Glass model remains a supported target")
-- Diagnostics sample render properties and construction once per meaningful transition.
workspaceFake.ClassName = "Workspace"
workspaceFake.GetFullName = function()
    return "Workspace"
end
local debugOutput = {}
env.print = function(message)
    table.insert(debugOutput, message)
end
player:SetAttribute("DebugTutorialGleam", true)
local printed = #debugOutput
heartbeat:Fire(0.1)
heartbeat:Fire(0.1)
check(printed > 0 and #debugOutput == printed, "debug logging does not repeat per frame")
local output = table.concat(debugOutput, "\n")
check(
    string.find(output, "class=Model", 1, true)
        and string.find(output, "LocalTransparencyModifier=", 1, true)
        and string.find(output, "Enabled=true", 1, true)
        and string.find(output, "Adornee=", 1, true),
    "diagnostics include raw geometry properties and created Highlight state"
)
player:SetAttribute("DebugTutorialGleam", false)
player:SetAttribute("TutorialStage", "Ladder")
player:SetAttribute("TutorialActive", true)
player.CharacterRemoving:Fire(player.Character)
heartbeat:Fire(0.1)
check(#gleams() == 0, "removing character cannot recreate stale visuals before Character changes")
player.CharacterAdded:Fire(player.Character)
glassModel:Destroy()
local shutdownGlass = object("UnionOperation", "Glass", blender)
player:SetAttribute("TutorialStage", "Blender")
local shutdownProxy = gleams()[1].Adornee
controllerScript:Destroy()
heartbeat:Fire(0.1)
check(
    shutdownProxy.Destroyed and #gleams() == 0,
    "controller shutdown destroys Glass proxy and cannot recreate visuals"
)
local leaked = 0
for _, object in allInstances do
    if object.Name == "TutorialGlassGleamProxy" and not object.Destroyed then
        leaked += 1
    end
end
check(leaked == 0, "no Glass proxies leak after lifecycle transitions")
-- A new local controller reconstructs only the current target after teardown.
local rebuiltScript = instance("ModuleScript")
local rebuiltChunk = assert(loadstring(sources.TutorialGleamController))
setfenv(rebuiltChunk, setmetatable({ script = rebuiltScript }, { __index = env }))
local rebuiltController = rebuiltChunk()
rebuiltController.Init()
check(
    #gleams() == 1 and gleams()[1].Adornee.Name == "TutorialGlassGleamProxy",
    "fresh controller recreates one current Glass proxy after shutdown"
)
rebuiltScript:Destroy()
check(#gleams() == 0, "reconstructed controller also cleans every gleam")
-- A slot Model owns its base geometry; do not overlay a second Highlight.
stashSlots[3]:Destroy()
local slotModel = object("Model", "Slot3", stash)
local modelBase = object("Part", "base", slotModel)
modelBase:SetAttribute("SlotIndex", 3)
local modelTargets = targets.Resolve(plot, "Stash", 3)
check(#modelTargets == 1 and modelTargets[1] == slotModel, "authored Slot3 model includes base with one gleam")
