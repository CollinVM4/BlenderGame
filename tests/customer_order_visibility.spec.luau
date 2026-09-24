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
check(bubble.Enabled == false, "unrevealed order remains hidden from owner")
customer:SetAttribute("OrderRevealed", true)
check(bubble.Enabled == true, "local owner sees revealed order")
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

-- Both customer actions reuse actual input labels and owner-only presentation.
serve:SetAttribute("InteractionCustomerAction", "Serve")
serve:SetAttribute("InteractionOwnerUserId", 123)
serve.KeyboardKeyCode = { Name = "F" }
serve.GamepadKeyCode = { Name = "ButtonY" }
local takeColor
for _, action in { "TakeOrder", "Serve" } do
    serve:SetAttribute("InteractionCustomerAction", action)
    serve:SetAttribute("InteractionActionText", if action == "TakeOrder" then "TAKE ORDER" else "SERVE")
    for _, kind in { "Keyboard", "Gamepad", "Touch" } do
        prompts.PromptShown:Fire(serve, kind)
        local display = gui()
        local text = display:FindFirstChild("Action")
        local key = if kind == "Keyboard" then "F" elseif kind == "Gamepad" then "ButtonY" else "TAP"
        check(
            text.Text == "[" .. key .. "] " .. serve:GetAttribute("InteractionActionText"),
            "customer input follows device and binding"
        )
        check(
            display.StudsOffset.Magnitude == 0
                and display.Size.X.Scale == 0
                and display.Size.Y.Scale == 0
                and not text.TextScaled,
            "prompt uses only pixel sizing and spacing with no camera-relative offset"
        )
        check(
            display.Size.X.Offset == 220 and text.BackgroundTransparency == 1,
            "compact customer prompt without dark box"
        )
        check(
            text.Font == "FredokaOne" and text:FindFirstChildOfClass("UIStroke").Thickness >= 2,
            "bold outlined action"
        )
        check(
            -display.SizeOffset.Y * display.Size.Y.Offset - display.Size.Y.Offset / 2 == 12,
            "prompt pixel bounds stay below full dialogue at all camera distances"
        )
        if action == "TakeOrder" then
            takeColor = text.TextColor3
        else
            check(text.TextColor3 ~= takeColor, "action color and wording distinguish serve from take")
        end
        prompts.PromptHidden:Fire(serve)
    end
end
serve:SetAttribute("InteractionOwnerUserId", nil)
prompts.PromptShown:Fire(serve, "Keyboard")
check(gui() == nil, "customer prompt with missing ownership fails closed")
serve:SetAttribute("InteractionOwnerUserId", 456)
check(gui() == nil, "non-owner cannot see customer action")
serve:SetAttribute("InteractionOwnerUserId", 123)
check(gui() ~= nil, "owner replication enables eligible custom action")
serve:SetAttribute("InteractionOwnerUserId", 456)
check(gui() == nil, "ownership change removes active custom action")
prompts.PromptHidden:Fire(serve)
print("PASS: compact customer prompts, input modes, ownership, and spacing")
