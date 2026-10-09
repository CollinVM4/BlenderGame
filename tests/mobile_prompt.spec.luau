-- Real client modules, projected pixel geometry, and engine input/trigger doubles.
local targets = load("MobilePromptTouchTargets")
local controller = load("IngredientPickupPromptController")
local interaction = load("InteractionPromptController")
controller.Init()
interaction.Init()
local function near(a, b)
    return math.abs(a - b) < 0.001
end
local function item(x, model)
    local object = uiInstance(if model then "Model" else "Part", "Ingredient", workspaceFake)
    local part = if model then uiInstance("Part", "Fruit", object) else object
    part.Position, part.CFrame = vec(x, 2, 0), frame(x, 2, 0)
    part.Size, part.Transparency = vec(2, 4, 2), 0
    if model then
        local root = uiInstance("Part", "InvisibleRoot", object)
        root.Transparency, root.Size = 1, vec(100, 100, 100)
        object.PrimaryPart = root
    end
    object:SetAttribute("IngredientId", "Strawberry")
    services.CollectionService:AddTag(object, "IngredientWorldItem")
    local prompt = uiInstance("ProximityPrompt", "CarryPrompt", part)
    prompt.Style, prompt.Enabled, prompt.ActionText = "Custom", true, "Pickup"
    prompt:SetAttribute("IngredientPickupPrompt", true)
    prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
    prompt.ClickablePrompt, prompt.HoldDuration, prompt.MaxActivationDistance = true, 0, 10
    local calls = { Begin = 0, End = 0, Pickup = 0 }
    prompt.Triggered:Connect(function()
        calls.Pickup += 1
    end)
    function prompt:InputHoldBegin()
        calls.Begin += 1
        self.Triggered:Fire(services.Players.LocalPlayer)
    end
    function prompt:InputHoldEnd()
        calls.End += 1
    end
    prompts.PromptShown:Fire(prompt, "Touch")
    local gui = playerGui:GetChildren()[#playerGui:GetChildren()]
    return object, part, prompt, gui, gui:FindFirstChild("TouchTarget"), calls
end
local function finger(gui, target, dx, dy)
    local center = assert(renderedCenter(gui, target))
    return { UserInputType = "Touch", Position = vec(center.X + (dx or 0), center.Y + (dy or 0), 0) }
end
local a, ap, p, g, t, calls = item(0, false)
check(g:FindFirstChild("Action").Text == "[TAP]", "compact existing TAP hint")
check(t.Size.X.Offset == 80 and t.Size.Y.Offset == 80, "80 by 80 actual target")
check(g:FindFirstChild("Action"):IsA("TextLabel"), "visual row cannot add a second broad hitbox")
check(near(g.StudsOffsetWorldSpace.Y, -1.2), "30 percent below regular ingredient center")
check(p.MaxActivationDistance == 10 and ap.Position.Y == 2, "prompt range and physical geometry unchanged")
-- Roblox already delivered InputBegan to the rendered 80px button. Its input
-- coordinates account for the GUI inset; viewport projection does not.
local projected = assert(renderedCenter(g, t))
local insetPress = { UserInputType = "Touch", Position = vec(projected.X, projected.Y - 56, 0) }
t.InputBegan:Fire(insetPress)
check(calls.Pickup == 1, "engine-delivered touch with a nonzero GUI inset must reach Triggered")
services.UserInputService.InputEnded:Fire(insetPress)
calls.Begin, calls.End, calls.Pickup = 0, 0, 0
local press = finger(g, t, 35, 35)
t.InputBegan:Fire(press)
t.InputBegan:Fire(press)
check(
    calls.Pickup == 1 and g:FindFirstChild("Action").TextTransparency == 0.25,
    "padded corner dispatches once with instant feedback"
)
services.UserInputService.InputEnded:Fire({ UserInputType = "Touch" })
check(calls.End == 0, "unrelated finger release cannot end this press")
services.UserInputService.InputEnded:Fire(press)
check(calls.End == 1 and g:FindFirstChild("Action").TextTransparency == 0, "matching release restores feedback")
for _ = 1, 3 do
    local tap = finger(g, t)
    t.InputBegan:Fire(tap)
    services.UserInputService.InputEnded:Fire(tap)
end
check(calls.Pickup == 4, "rapid separate taps have no client debounce")
local b, bp, q, h, u, other = item(2, true)
check(near(h.StudsOffsetWorldSpace.Y, 0.8), "multipart lower position ignores invisible pivot bounds")
local overlap = finger(h, u, -5, 0)
-- Native stacking delivered the upper button first; do not reroute the finger.
u.InputBegan:Fire(overlap)
t.InputBegan:Fire(overlap)
check(calls.Pickup == 4 and other.Pickup == 1, "native source wins; one clustered tap cannot activate two prompts")
services.UserInputService.InputEnded:Fire(overlap)
local one, two = finger(g, t), finger(g, t)
t.InputBegan:Fire(one)
t.InputBegan:Fire(two)
services.UserInputService.InputEnded:Fire(two)
check(calls.Pickup == 5 and calls.End == 4, "multitouch cannot duplicate or release another finger's pickup")
services.UserInputService.InputEnded:Fire(one)
services.CollectionService:RemoveTag(b, "IngredientWorldItem")
local unregistered = finger(h, u)
u.InputBegan:Fire(unregistered)
check(other.Pickup == 1, "registration loss rejects touch before rendered cleanup")
services.CollectionService:AddTag(b, "IngredientWorldItem")
b:SetAttribute("OwnerUserId", 999)
u.InputBegan:Fire(finger(h, u))
check(other.Pickup == 1, "foreign ownership rejects touch before rendered cleanup")
services.RunService.RenderStepped:Fire()
check(h.Destroyed, "foreign ownership removes active presentation")
b:SetAttribute("OwnerUserId", 0)
prompts.PromptShown:Fire(q, "Touch")
h = playerGui:GetChildren()[#playerGui:GetChildren()]
u = h:FindFirstChild("TouchTarget")
local removal = finger(h, u)
u.InputBegan:Fire(removal)
prompts.PromptHidden:Fire(q)
t.InputBegan:Fire(removal)
u.InputBegan:Fire(removal)
check(
    other.Pickup == 2 and calls.Pickup == 5 and h.Destroyed,
    "removed prompt cannot reroute its already claimed touch"
)
local stale = finger(g, t)
p.Enabled = false
p.Changed:Fire("Enabled")
t.InputBegan:Fire(stale)
check(g.Destroyed and calls.Pickup == 5, "disabled/despawned view cannot activate")
p.Enabled = true
prompts.PromptShown:Fire(p, "Touch")
g = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
t = g:FindFirstChild("TouchTarget")
a.Parent = nil
p.AncestryChanged:Fire()
check(g.Destroyed, "ingredient removal cleans view without engine Hidden")
a.Parent = workspaceFake
prompts.PromptShown:Fire(p, "Touch")
g = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
a:SetAttribute("IngredientId", nil)
services.RunService.RenderStepped:Fire()
check(g.Destroyed, "lost ingredient identity clears stale touch target")
a:SetAttribute("IngredientId", "Strawberry")
prompts.PromptShown:Fire(p, "Touch")
g = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
ap.Position, ap.CFrame = vec(5, 4, 0), frame(5, 4, 0)
services.RunService.RenderStepped:Fire()
check(near(renderedCenter(g, g:FindFirstChild("TouchTarget")).X, 300), "moving ingredient updates target with visual")
for _, size in { vec2(320, 640), vec2(932, 430), vec2(768, 1024), vec2(1024, 768) } do
    workspaceFake.CurrentCamera.ViewportSize = size
    services.RunService.RenderStepped:Fire()
    check(
        near(renderedCenter(g, g:FindFirstChild("TouchTarget")).X, size.X / 2 + 100),
        "target projection follows phone/tablet orientation without an inset or stale layout"
    )
end
workspaceFake.CurrentCamera.ViewportSize = vec2(400, 600)
services.RunService.RenderStepped:Fire()
local low, high = view.Bounds(b)
check(near(low.Y, 0) and near(high.Y, 4), "multipart visible bounds")
bp.CFrame.UpVector, bp.CFrame.RightVector = vec(1, 0, 0), vec(0, 1, 0)
low, high = view.Bounds(b)
check(near(high.Y - low.Y, 2), "rotating geometry recalculates world vertical extent")
check(near(view.MobilePosition(vec(0, 0, 0), vec(1, 0.1, 1)).Y, 0.05), "tiny bounds clamp above bottom")
check(near(view.MobilePosition(vec(0, 0, 0), vec(1, 40, 1)).Y, 17.5), "oversized bounds cap downward displacement")
-- Steep camera projection keeps visible text above its projected bottom plane.
ap.Size = vec(0.1, 0.1, 0.1)
services.RunService.RenderStepped:Fire()
local center = renderedCenter(g, g:FindFirstChild("TouchTarget"))
local ground = workspaceFake.CurrentCamera:WorldToViewportPoint(vec(5, 3.95, 0))
check(center.Y + style.InputHeight / 2 <= ground.Y - 1.999, "visible TAP cannot clip into projected contact plane")
prompts.PromptHidden:Fire(p)
for _, kind in { "Keyboard", "Gamepad" } do
    prompts.PromptShown:Fire(p, kind)
    local desktop = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
    check(
        desktop:FindFirstChild("TouchTarget") == nil and desktop.Size.Y.Offset == 142,
        "desktop/console keep original UI and input row"
    )
    check(desktop.SizeOffset.Y == 0.5, "desktop/console remain above ingredient")
    prompts.PromptHidden:Fire(p)
end
-- Dispenser opts in through its existing authored origin, with no gameplay changes.
local dispenser = uiInstance("Model", "Dispenser", workspaceFake)
local origin = uiInstance("Attachment", "DispenserTextOrigin", dispenser)
local part = uiInstance("Part", "DispenseButton", dispenser)
local dispense, dispenseAttach, dispenseRequests = nil, nil, 0
local dispenseChunk = assert(loadstring(sources.DispenseButton, "DispenseButton"))
setfenv(
    dispenseChunk,
    setmetatable({
        script = { Parent = { Parent = { Services = { WorldUtil = "WorldUtil", AudioService = "AudioService" } } } },
        require = function(key)
            if key == "MobilePromptDebug" then
                return load("MobilePromptDebug")
            end
            if key == "AudioService" then
                local sound = { Play = function() end, Destroy = function() end }
                return {
                    CreateBlendGroup = function()
                        return { pourSound = sound, notReadySound = sound }
                    end,
                }
            end
            return {
                BindTag = function(_, attach)
                    dispenseAttach = attach
                end,
                Part = function()
                    return part
                end,
                Prompt = function(host, name, action)
                    dispense = uiInstance("ProximityPrompt", name, host)
                    dispense.ActionText, dispense.HoldDuration = action, 0
                    dispense.KeyboardKeyCode, dispense.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
                    return dispense
                end,
            }
        end,
    }, { __index = env })
)
dispenseChunk().Init({
    GameplayService = {
        RegisterPlotInteraction = function(prompt, callback)
            prompt.Triggered:Connect(function(actor)
                callback(actor, { RequestId = 1 })
            end)
        end,
    },
    TycoonService = {
        IsMember = function(actor)
            return actor == services.Players.LocalPlayer
        end,
    },
    BlendService = {
        Dispense = function(actor, button, context)
            check(
                actor == services.Players.LocalPlayer and button == part and context.RequestId == 1,
                "existing dispense callback retains actor, blender and gameplay context"
            )
            dispenseRequests += 1
            return true -- Service double; real readiness/capacity/replay contracts use smoothie-dispense.
        end,
    },
})
local dispenseDetach = dispenseAttach(part)
local dispenses = 0
function dispense:InputHoldBegin()
    dispenses += 1
end
function dispense:InputHoldEnd() end
prompts.PromptShown:Fire(dispense, "Touch")
local dg = playerGui:FindFirstChild("InteractionPromptDisplay")
local dt = dg:FindFirstChild("TouchTarget")
check(
    dg.Adornee == origin and dt.Size.X.Offset == 220 and dt.Size.Y.Offset == 80,
    "dispenser uses 220 by 80 target at authored marker"
)
check(
    dg:FindFirstChild("Action").Text == "[TAP] DISPENSE" and dg:FindFirstChild("Action").TextSize == 24,
    "compact dispenser lettering unchanged"
)
dispense.HoldDuration = 0
local dispenseTriggered = 0
dispense.Triggered:Connect(function()
    dispenseTriggered += 1
end)
function dispense:InputHoldBegin()
    dispenses += 1
    self.Triggered:Fire(services.Players.LocalPlayer) -- Engine double, not native simulation.
end
local dp = finger(dg, dt, 100, 35)
dt.InputBegan:Fire(dp)
services.UserInputService.InputEnded:Fire(dp)
check(
    dispenses == 1 and dispenseTriggered == 1 and dispenseRequests == 1,
    "dispenser padding reaches mocked Triggered once"
)
-- Acceptance of an engine-hit button must not depend on projection, GUI inset,
-- current camera availability, or the manually modeled canvas rectangle.
local camera = workspaceFake.CurrentCamera
workspaceFake.CurrentCamera = nil
local noProjection = { UserInputType = "Touch", Position = vec(-500, -500, 0) }
dt.InputBegan:Fire(noProjection)
services.UserInputService.InputEnded:Fire(noProjection)
workspaceFake.CurrentCamera = camera
check(dispenses == 2 and dispenseTriggered == 2, "native button dispatch needs no camera or coordinate re-test")
local cancel = finger(dg, dt)
dt.InputBegan:Fire(cancel)
cancel.UserInputState = "Cancel"
services.UserInputService.InputChanged:Fire(cancel)
local beforeCancel = dispenses
local afterCancel = finger(dg, dt)
dt.InputBegan:Fire(afterCancel)
services.UserInputService.InputEnded:Fire(afterCancel)
check(dispenses == beforeCancel + 1, "matching cancellation releases the prompt without a hold delay")
local emulatorMouse = { UserInputType = "MouseButton1", Position = vec(0, 0, 0) }
dispense.ClickablePrompt = true
dt.InputBegan:Fire(emulatorMouse)
services.UserInputService.InputEnded:Fire(emulatorMouse)
check(dispenses == beforeCancel + 2, "touch UI preserves original clickable mouse/emulator input")
dispense.ClickablePrompt = false
dt.InputBegan:Fire({ UserInputType = "MouseButton1", Position = vec(0, 0, 0) })
check(dispenses == beforeCancel + 2, "nonclickable prompt still rejects mouse input")
origin.Parent = nil
workspaceFake.DescendantRemoving:Fire(origin)
dt.InputBegan:Fire(finger({
    Adornee = part,
    StudsOffset = vec(0, 0, 0),
    StudsOffsetWorldSpace = vec(0, 0, 0),
    SizeOffset = vec2(0, 0),
    Size = dg.Size,
}, dt))
check(dg.Destroyed and dispenses == beforeCancel + 2, "removed dispenser origin cannot activate stale target")
-- Customer touch UI retains its original direct Action button and key bindings.
local customerPart = uiInstance("Part", "CustomerRoot", workspaceFake)
local customerOrigin = uiInstance("Attachment", "CustomerOrigin", customerPart)
local customerPrompt = uiInstance("ProximityPrompt", "ServePrompt", customerPart)
customerPrompt.KeyboardKeyCode, customerPrompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
customerPrompt.Enabled, customerPrompt.ClickablePrompt, customerPrompt.ActionText = true, true, "SERVE"
local served = 0
function customerPrompt:InputHoldBegin()
    served += 1
end
function customerPrompt:InputHoldEnd() end
local customerCleanup, customerGui = load("InteractionPromptPresentation").Create(
    customerPrompt,
    customerOrigin,
    playerGui,
    "Touch",
    { CustomerAction = "Serve", ActionText = "SERVE" }
)
check(
    customerGui:FindFirstChild("TouchTarget") == nil and customerGui:FindFirstChild("Action"):IsA("TextButton"),
    "customer UI keeps its original touch callback and compact display"
)
local customerFinger = { UserInputType = "Touch", Position = vec(0, 0, 0) }
customerGui:FindFirstChild("Action").InputBegan:Fire(customerFinger)
services.UserInputService.InputEnded:Fire(customerFinger)
check(served == 1, "customer interaction remains directly usable")
customerCleanup()
-- Only the dedicated CAS button can throw on touch hardware. No world listeners.
local actions, bindings, throws = {}, {}, 0
services.UserInputService.TouchEnabled = true
services.UserInputService.GetFocusedTextBox = function()
    return nil
end
services.Players.LocalPlayer.GetAttribute = function(_, name)
    return if name == "CarryCount" then 2 else nil
end
services.ReplicatedStorage.Shared.Events = {
    WaitForChild = function()
        return {
            FireServer = function(_, action)
                if action == "ThrowHeld" then
                    throws += 1
                end
            end,
        }
    end,
}
services.ContextActionService = {
    BindAction = function(_, name, callback, touch, ...)
        actions[name] = callback
        bindings[name] = { Touch = touch, Inputs = { ... } }
    end,
    SetTitle = function() end,
}
modules.MobileControlLayout = { Register = function() end }
env.Enum.ContextActionResult = { Pass = "Pass", Sink = "Sink" }
env.Enum.UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel" }
env.Enum.KeyCode = { ButtonR2 = "ButtonR2" }
load("CarryInputController").Init()
check(
    bindings.ThrowHeld.Touch
        and bindings.ThrowHeld.Inputs[1] == "ButtonR2"
        and not bindings.ThrowHeldMouse.Touch
        and bindings.ThrowHeldMouse.Inputs[1] == "MouseButton1",
    "mobile Throw and desktop primary input have separate bindings"
)
prompts.PromptShown:Fire(p, "Touch")
g = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
t = g:FindFirstChild("TouchTarget")
local pickupAndMouse = finger(g, t)
local beforePickup = calls.Pickup
t.InputBegan:Fire(pickupAndMouse)
actions.ThrowHeldMouse("ThrowHeldMouse", "Begin", pickupAndMouse)
services.UserInputService.InputEnded:Fire(pickupAndMouse)
actions.ThrowHeldMouse("ThrowHeldMouse", "End", pickupAndMouse)
check(calls.Pickup == beforePickup + 1 and throws == 0, "same mobile touch can pick up but cannot throw")
origin.Parent = dispenser
prompts.PromptShown:Fire(dispense, "Touch")
dg = playerGui:FindFirstChild("InteractionPromptDisplay")
dt = dg:FindFirstChild("TouchTarget")
local dispenseAndMouse = finger(dg, dt)
local beforeDispense = dispenseRequests
dt.InputBegan:Fire(dispenseAndMouse)
actions.ThrowHeldMouse("ThrowHeldMouse", "Begin", dispenseAndMouse)
services.UserInputService.InputEnded:Fire(dispenseAndMouse)
check(dispenseRequests == beforeDispense + 1 and throws == 0, "same mobile dispense press cannot throw")
prompts.PromptHidden:Fire(dispense)
dispenseDetach()
services.UserInputService.InputBegan = signal()
services.UserInputService.TouchTapInWorld = signal()
for _, source in { "DISPENSE", "STORE", "TAKE", "UI", "CameraDrag", "Joystick", "SecondFinger" } do
    local inputObject = { UserInputType = "Touch", Position = vec(0, 0, 0), Source = source }
    services.UserInputService.InputBegan:Fire(inputObject, true)
    services.UserInputService.InputEnded:Fire(inputObject)
    services.UserInputService.TouchTapInWorld:Fire(vec2(0, 0), true)
end
actions.ThrowHeldMouse("ThrowHeldMouse", "Begin")
actions.ThrowHeldMouse("ThrowHeldMouse", "End")
check(throws == 0, "UI, camera, joystick, release and synthesized primary input have no touch throw binding")
prompts.PromptHidden:Fire(p)
actions.ThrowHeld("ThrowHeld", "Begin")
actions.ThrowHeld("ThrowHeld", "End")
actions.ThrowHeld("ThrowHeld", "Cancel")
check(throws == 1, "intentional Throw press sends once; release/cancel never throw")
services.UserInputService.TouchEnabled = false
actions.ThrowHeldMouse("ThrowHeldMouse", "Begin")
actions.ThrowHeldMouse("ThrowHeldMouse", "End")
actions.ThrowHeld("ThrowHeld", "Begin")
check(throws == 3, "desktop mouse and console trigger still throw on press")
-- One native prompt activation still reaches exactly one existing pickup adapter.
local attach, generated, pickupDispatches = nil, nil, 0
local chunk = assert(loadstring(sources.IngredientPickup, "IngredientPickup"))
setfenv(
    chunk,
    setmetatable({
        script = { Parent = { Parent = { Services = { WorldUtil = "WorldUtil" } } } },
        require = function(key)
            if key == "MobilePromptDebug" then
                return load("MobilePromptDebug")
            end
            return {
                BindTag = function(_, callback)
                    attach = callback
                end,
                Part = function()
                    return ap
                end,
                Prompt = function(part, name, action)
                    generated = uiInstance("ProximityPrompt", name, part)
                    generated.ActionText = action
                    generated.KeyboardKeyCode, generated.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
                    return generated
                end,
            }
        end,
    }, { __index = env })
)
chunk().Init({
    IngredientService = {
        GetRecord = function()
            return { Id = "Strawberry", Claimable = true }
        end,
    },
    InventoryService = {
        CarryWorldItem = function(actor, object)
            check(
                actor == services.Players.LocalPlayer and object == a,
                "original actor and world identity reach inventory"
            )
            pickupDispatches += 1
        end,
    },
})
local detach = attach(a)
generated.HoldDuration = 0
local debugStart = #logs
workspaceFake:SetAttribute("DebugMobilePrompts", true)
function generated:InputHoldBegin()
    self.Triggered:Fire(services.Players.LocalPlayer)
end
function generated:InputHoldEnd() end
prompts.PromptShown:Fire(generated, "Touch")
g = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
t = g:FindFirstChild("TouchTarget")
local dispatched = finger(g, t, 35, 35)
t.InputBegan:Fire(dispatched)
t.InputBegan:Fire(dispatched)
check(pickupDispatches == 1, "padded TAP uses sole server pickup adapter exactly once")
detach()
t.InputBegan:Fire(dispatched)
check(g.Destroyed and pickupDispatches == 1, "component despawn disables old touch dispatch")
local stages = {}
for index = debugStart + 1, #logs do
    for _, stage in
        { "SHOWN", "REGISTERED", "TOUCH RECEIVED", "TARGET SELECTED", "HOLD BEGIN", "TRIGGERED", "ACTION DISPATCHED" }
    do
        if string.find(logs[index], "[MobilePrompt] " .. stage, 1, true) then
            stages[stage] = true
        end
    end
end
for _, stage in
    { "SHOWN", "REGISTERED", "TOUCH RECEIVED", "TARGET SELECTED", "HOLD BEGIN", "TRIGGERED", "ACTION DISPATCHED" }
do
    check(stages[stage], "enabled diagnostics report " .. stage .. " without claiming server acceptance")
end
workspaceFake:SetAttribute("DebugMobilePrompts", false)
local debugCount = #logs
load("MobilePromptDebug").Log(generated, "TRIGGERED", "must be silent")
check(#logs == debugCount, "diagnostic flag is off by default and silent when disabled")
workspaceFake:SetAttribute("DebugMobilePrompts", true)
studio = false
load("MobilePromptDebug").Log(generated, "TRIGGERED", "must be silent outside Studio")
check(#logs == debugCount, "debug flag cannot enable published-game logging")
studio = true
workspaceFake:SetAttribute("DebugMobilePrompts", false)
print(string.format("PASS: %d mobile prompt/input assertions (mocked Roblox boundary).", count))
