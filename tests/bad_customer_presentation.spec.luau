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
local origin = instance("Attachment")
origin.Name, origin.Parent = "Attachment", model
local cleanup = loadModule("RejectFloorButton").Bind(root, origin, function()
    return nil
end, function()
    return false
end, function()
    error("visual-only floor button cannot activate gameplay")
end)
local gui = root:FindFirstChild("RejectFloorDisplay")
local text = gui:FindFirstChild("Action")
check(
    text.Text == "STAND TO REJECT" and text.Font == "FredokaOne" and text.TextSize == 22 and not text.TextScaled,
    "floor view explains standing with fixed Fredoka lettering"
)
check(
    gui.Adornee == origin and gui.MaxDistance == 40 and text.TextColor3.R == 1,
    "shared floor view uses the authored origin with red identity and finite culling"
)
local line = gui:FindFirstChild("Progress")
check(line.Size.Y.Offset == 6 and line.BackgroundColor3.R == 1, "floor view retains the thicker red progress line")
cleanup()
check(gui.Destroyed, "floor display cleans normally")
print("PASS bad customer presentation", count, "assertions;", setupCount, "setup")
