-- Stable endpoint selection; controller persistence/cleanup belongs to tutorial-hints.
shared.TutorialTargets = "TutorialTargets"
local Targets = loadModule("TutorialTargets")
local function object(class, name, owner)
    local result = instance(class)
    result.Name, result.Parent = name, owner
    return result
end
local own = object("Model", "OwnPlot", workspaceFake)
local other = object("Model", "OtherPlot", workspaceFake)
local function wheel(owner)
    local result = object("Model", "Turbine Wheel", owner)
    return object("Model", "turbine", result)
end
local turbine = wheel(own)
local foreignStem = object("Part", "stem", wheel(other))
foreignStem.Anchored = true
local blade = object("Part", "blade", turbine)
blade.Anchored = false
services.CollectionService:AddTag(blade, "TurbineWheel")
local movingMarker = object("Attachment", "TurbinePromptOrigin", blade)
check(
    Targets.ResolveBeam(own, "Turbine", nil, blade) == nil,
    "tagged spinning blade and foreign stationary stem cannot substitute for own stem"
)
local stem = object("Part", "stem", turbine)
stem.Anchored = true
check(
    Targets.ResolveBeam(own, "Turbine", nil, blade) == stem,
    "stationary central stem wins over the highlighted or tagged rotating component"
)
check(
    Targets.ResolveBeam(own, "FinishBatch") == stem,
    "recovery blending uses the same fixed stem without a highlight dependency"
)
local marker = object("Attachment", "TurbineBeamTarget", stem)
check(Targets.ResolveBeam(own, "Turbine") == marker, "stable authored stem attachment is reused")
marker.Parent = turbine
check(
    Targets.ResolveBeam(own, "Turbine") == stem,
    "attachment with a non-BasePart parent cannot become the turbine endpoint"
)
marker.Parent = blade
check(Targets.ResolveBeam(own, "Turbine") == stem, "rotating marker cannot replace the fixed stem")
stem.Anchored = false
check(Targets.ResolveBeam(own, "Turbine") == nil, "unanchored rotating shaft is rejected")
local stationaryRoot = object("Part", "StationarySupport", turbine)
stationaryRoot.Anchored = true
stem.AssemblyRootPart = stationaryRoot
check(Targets.ResolveBeam(own, "Turbine") == stem, "stem rigidly joined to an anchored assembly is stationary")
stem.Parent = nil
check(
    Targets.ResolveBeam(own, "Turbine") == nil,
    "missing replicated stem remains retryable without an unsafe fallback"
)
stem.Parent, stem.Anchored = turbine, true
check(Targets.ResolveBeam(own, "Turbine") == stem, "late replicated stem restores the current target")
stem.Name = "shaft"
check(Targets.ResolveBeam(own, "Turbine") == stem, "stationary shaft authoring resolves without spinning-tag fallback")
stem.Name = "stem"
local dispenser = object("Model", "Dispenser", own)
local output = object("Part", "Output", dispenser)
output.Anchored = true
local interaction = object("Attachment", "ActualInteraction", output)
object("ProximityPrompt", "Dispense", interaction)
local foreignOrigin = object("Attachment", "DispenserTextOrigin", foreignStem)
check(
    Targets.ResolveBeam(own, "Dispenser", nil, foreignStem) == interaction,
    "dispenser resolves the own-plot stable interaction independently of highlight geometry"
)
local namedOrigin = object("Attachment", "DispenserTextOrigin", output)
check(
    Targets.ResolveBeam(own, "Dispenser") == namedOrigin,
    "existing actual DispenserTextOrigin is preferred over a part fallback"
)
check(
    Targets.ResolveBeam(own, "DrainBatch") == namedOrigin,
    "recovery dispensing retains the actual stable interaction endpoint"
)
namedOrigin.Parent = blade
check(
    Targets.ResolveBeam(own, "Dispenser") == interaction,
    "a rotating named dispenser marker cannot override a stable interaction"
)
interaction.Parent = dispenser
check(
    Targets.ResolveBeam(own, "Dispenser") == output,
    "invalid interaction attachment falls back to the stable output BasePart"
)
output.Parent = nil
check(Targets.ResolveBeam(own, "Dispenser") == nil, "missing dispenser output has no foreign fallback")
output.Parent = dispenser
check(Targets.ResolveBeam(own, "Dispenser") == output, "dispenser replication can recover without stage changes")
