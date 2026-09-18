-- Local ownership changes and streamed customer lifecycle, independent of serving.
services.Players.LocalPlayer.UserId = 123
local customer = uiInstance("Model", "CustomerNPC", workspaceFake)
local root = uiInstance("Part", "HumanoidRootPart", customer)
local serveOrigin = uiInstance("Attachment", "ServePromptOrigin", root)
local serve = uiInstance("ProximityPrompt", "ServePrompt", root)
serve.Style, serve.Enabled = "Custom", true
serve.KeyboardKeyCode, serve.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
serve:SetAttribute("InteractionOrigin", "ServePromptOrigin")
serve:SetAttribute("InteractionActionText", "SERVE")
check(gui() == nil, "spawned serve has no UI before engine eligibility")
prompts.PromptShown:Fire(serve, "Keyboard")
check(
    gui().Adornee == serveOrigin and gui():FindFirstChild("Action").Text == "[E] SERVE",
    "dynamic serve uses shared view"
)
serve.Enabled = false
serve.Changed:Fire("Enabled")
check(gui() == nil, "successful serve disables and removes view")
serve.Enabled = true
prompts.PromptShown:Fire(serve, "Gamepad")
check(gui():FindFirstChild("Action").Text == "[ButtonX] SERVE", "serve supports engine gamepad eligibility")
workspaceFake.DescendantRemoving:Fire(serve)
check(gui() == nil, "customer removal cleans serve view without waiting for PromptHidden")
local bubble = uiInstance("BillboardGui", "OrderBubble", root)
local orders = module("CustomerOrderController", {})
orders.Init()
check(bubble.Enabled == false, "missing owner fails closed")
customer:SetAttribute("OwnerUserId", 123)
check(bubble.Enabled == true, "local owner sees order")
customer:SetAttribute("OwnerUserId", 456)
check(bubble.Enabled == false, "nearby non-owner cannot see order")
customer:SetAttribute("OwnerUserId", nil)
check(bubble.Enabled == false, "cleared owner hides order")
customer:SetAttribute("OwnerUserId", 123)
workspaceFake.DescendantRemoving:Fire(bubble)
bubble.Parent = nil
customer:SetAttribute("OwnerUserId", 456)
customer:SetAttribute("OwnerUserId", 123)
check(bubble.Enabled == false, "removed customer display stays hidden")
bubble.Parent = root
workspaceFake.DescendantAdded:Fire(bubble)
check(bubble.Enabled == true, "streamed display rebinds ownership")
local lateBubble = uiInstance("BillboardGui", "OrderBubble", root)
workspaceFake.DescendantAdded:Fire(lateBubble)
check(lateBubble.Enabled == true, "dynamically spawned order resolves owner")
print("PASS: customer order ownership and streaming visibility")
