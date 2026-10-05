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
local prompt = instance("ProximityPrompt")
prompt.ActionText = "REJECT"
prompt:SetAttribute("RejectButtonPrompt", true)
prompt.PromptButtonHoldBegan, prompt.PromptButtonHoldEnded = signal(), signal()
prompt.GetPropertyChangedSignal = function()
    return signal()
end
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
services.UserInputService = {
    GetStringForKeyCode = function()
        return "E"
    end,
    InputEnded = signal(),
    WindowFocusReleased = signal(),
}
env.Instance.new = function(class)
    local object = instance(class)
    if class == "TextButton" then
        object.InputBegan = signal()
    end
    return object
end
env.Enum.ProximityPromptInputType = { Touch = "Touch", Gamepad = "Gamepad", Keyboard = "Keyboard" }
local cleanup, gui = loadModule("InteractionPromptPresentation").Create(prompt, origin, model, "Keyboard", {})
local text = gui:FindFirstChild("Action")
check(
    text.Text == "REJECT" and text.Font == "FredokaOne" and text.TextSize == 24 and not text.TextScaled,
    "reject view uses fixed Fredoka REJECT lettering"
)
check(
    gui.Adornee == origin and gui.MaxDistance == 40 and text.TextColor3.R == 1,
    "reject view stays at authored origin with red identity and finite culling"
)
local size = gui.Size
prompt.PromptButtonHoldBegan:Fire()
prompt.PromptButtonHoldEnded:Fire()
check(gui.Size == size and text.TextSize == 24 and text.Text == "REJECT", "press feedback cannot resize or move label")
cleanup()
check(gui.Destroyed, "prompt view cleans normally")
print("PASS bad customer presentation", count, "assertions;", setupCount, "setup")
