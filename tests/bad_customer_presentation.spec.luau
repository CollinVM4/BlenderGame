-- New feature presentation is separate from authoritative outcomes.
local presentation = loadModule("CustomerPresentation")
local model = instance("Model")
model.Parent = workspaceFake
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", model
local visual = loadModule("IngredientService").CreateVisual("Banana")
visual:SetAttribute("IngredientId", "Banana")
setup(presentation.AttachStolenIngredient(model, visual) == visual, "attach stolen cosmetic")
check(
    visual.Parent == model and not visual.CanCollide and not visual.CanTouch and not visual.CanQuery,
    "stolen geometry is inert"
)
check(
    not visual:GetAttribute("IngredientId") and not loadModule("IngredientService").GetRecord(visual),
    "stolen cosmetic has no authoritative item registration"
)
print("PASS bad customer inert stolen presentation", count, "assertions;", setupCount, "setup")
