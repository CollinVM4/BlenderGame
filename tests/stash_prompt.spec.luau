-- Execute the actual client controller on each input surface.
services.ProximityPromptService = { PromptShown = signal(), PromptHidden = signal(), PromptTriggered = signal() }
services.RunService.Heartbeat = signal()
local bindings = {}
services.ContextActionService = {
    BindAction = function(_, name, callback, _, keyboard, controller)
        bindings[name] = { Callback = callback, Keyboard = keyboard, Controller = controller }
    end,
    UnbindAction = function(_, name)
        bindings[name] = nil
    end,
}
services.GuiService = { MenuIsOpen = false }
local focusedTextBox = nil
services.UserInputService = {
    LastInputTypeChanged = signal(),
    GetFocusedTextBox = function()
        return focusedTextBox
    end,
    GetImageForKeyCode = function(_, key)
        return "controller-icon-" .. key
    end,
}
env.Enum.ProximityPromptInputType = { Keyboard = "Keyboard", Touch = "Touch", Gamepad = "Gamepad" }
env.Enum.KeyCode = { E = "E", R = "R", ButtonX = "ButtonX", ButtonY = "ButtonY" }
env.Enum.ContextActionResult = { Pass = "Pass", Sink = "Sink" }
env.Enum.UserInputState = { Begin = "Begin", End = "End" }
env.Enum.HighlightDepthMode = { Occluded = "Occluded" }
env.Enum.UserInputType = { Touch = "Touch" }
env.UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}
shared.WaitForChild = function(_, name)
    return shared[name]
end
shared.Events.WaitForChild = function(self, name)
    return self:FindFirstChild(name)
end
local p = instance("Player")
services.Players.LocalPlayer = p
p:SetAttribute("PlotSessionId", "home")
p:SetAttribute("PlotMembershipRevision", 7)
p:SetAttribute("CarryCapacity", 3)
p:SetAttribute("CarryCount", 0)
p:SetAttribute("HeldItemType", "Ingredient")
local playerGui = instance("PlayerGui")
playerGui.Name, playerGui.Parent = "PlayerGui", p
p.WaitForChild = function(self, name)
    return self:FindFirstChild(name)
end
p.Character = instance("Model")
p.Character.Parent = workspaceFake
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", p.Character
local humanoid = instance("Humanoid")
humanoid.Health, humanoid.Parent = 100, p.Character
local function focusedSlot()
    local slot = instance("Part")
    slot.Parent = workspaceFake
    slot:SetAttribute("StashSessionId", "home")
    slot:SetAttribute("StashItemType", "Ingredient")
    slot:SetAttribute("StashCount", 2)
    slot:SetAttribute("StashCapacity", 3)
    local prompt = instance("ProximityPrompt")
    prompt.Enabled, prompt.Parent = true, slot
    prompt.KeyboardKeyCode, prompt.GamepadKeyCode = "E", "ButtonX"
    prompt:SetAttribute("PlayerStashPrompt", true)
    return slot, prompt
end
local slot, prompt = focusedSlot()
local remote = instance("RemoteFunction")
remote.Name, remote.Parent = "StashAction", shared.Events
local requests = {}
local reject = nil
function remote:InvokeServer(target, action, context)
    table.insert(requests, { Prompt = target, Action = action, Context = context })
    return reject == nil, reject
end
loadModule("StashPromptController").Init()
flush()
local gui = playerGui:FindFirstChild("StashActions")
local panel = gui:FindFirstChild("Actions")
local store, take = panel:FindFirstChild("STORE"), panel:FindFirstChild("TAKE")
local title, feedback = panel:FindFirstChild("Count"), panel:FindFirstChild("Feedback")
local unavailable = loadModule("StashPromptController").Unavailable
for _, input in { "Touch", "Keyboard", "Gamepad" } do
    services.ProximityPromptService.PromptShown:Fire(prompt, input)
    check(gui.Enabled and title.Text == "STASH 2/3", "one compact panel shows focused capacity")
    check(
        prompt.KeyboardKeyCode == "E" and bindings.StashTAKE.Keyboard == "R",
        "distinct discoverable desktop bindings"
    )
    check(
        prompt.GamepadKeyCode == "ButtonX" and bindings.StashTAKE.Controller == "ButtonY",
        "distinct console bindings"
    )
    if input == "Keyboard" then
        check(store.Text == "[E] STORE" and take.Text == "[R] TAKE", "desktop hints match STORE and TAKE bindings")
    end
    if input == "Touch" then
        check(store.Text == "STORE" and take.Text == "TAKE", "touch actions have separate stable meanings")
        store.Activated:Fire()
        take.Activated:Fire()
        flush()
        check(requests[#requests].Action == "STORE", "pending touch request blocks duplicate/opposite requests")
        take.Activated:Fire()
        flush()
    else
        -- Native prompt input consumes E / ButtonX before contextual action callbacks.
        local before = #requests
        services.ProximityPromptService.PromptTriggered:Fire(prompt, p)
        services.ProximityPromptService.PromptTriggered:Fire(prompt, p)
        flush()
        check(
            #requests == before + 1 and requests[#requests].Action == "STORE",
            input .. " native prompt activation sends exactly one STORE"
        )
        bindings.StashTAKE.Callback(nil, "Begin")
        flush()
    end
    check(
        requests[#requests - 1].Action == "STORE" and requests[#requests].Action == "TAKE",
        input .. " dispatches explicit intended action"
    )
    local context = requests[#requests].Context
    check(
        context.PlotSessionId == "home" and context.MembershipRevision == 7 and context.TargetSessionId == "home",
        "all platforms submit actor revision and selected target session"
    )
    if input == "Gamepad" then
        check(
            store:FindFirstChild("InputIcon").Image == "controller-icon-ButtonX"
                and take:FindFirstChild("InputIcon").Image == "controller-icon-ButtonY",
            "console uses platform-specific controller icons"
        )
        check(
            services.GuiService.SelectedObject == store
                and store.NextSelectionRight == take
                and take.NextSelectionLeft == store,
            "console focus and left/right navigation are usable without mouse"
        )
        take.Activated:Fire()
        flush()
        check(requests[#requests].Action == "TAKE", "controller GUI activation preserves TAKE")
    end
    services.ProximityPromptService.PromptHidden:Fire(prompt)
    check(not gui.Enabled and not bindings.StashSTORE and not bindings.StashTAKE, "hidden focus dismisses actions")
end
services.ProximityPromptService.PromptShown:Fire(prompt, "Touch")
local positionStore, positionTake = store.Position, take.Position
p:SetAttribute("HeldItemType", nil)
check(unavailable(p, slot, "STORE") == "NOTHING TO STORE!", "empty carry disables STORE")
store.Activated:Fire()
check(feedback.Text == "NOTHING TO STORE!", "unavailable press gives concise feedback")
p:SetAttribute("HeldItemType", "Ingredient")
slot:SetAttribute("StashCount", 3)
check(unavailable(p, slot, "STORE") == "SLOT FULL!", "full slot disables STORE")
slot:SetAttribute("StashCount", 0)
check(unavailable(p, slot, "TAKE") == "SLOT EMPTY!", "empty slot disables TAKE")
slot:SetAttribute("StashCount", 2)
p:SetAttribute("CarryCount", 3)
check(unavailable(p, slot, "TAKE") == "CARRY FULL!", "full carry disables TAKE")
p:SetAttribute("CarryCount", 0)
slot:SetAttribute("StashItemType", "Smoothie")
check(unavailable(p, slot, "STORE") == "SLOT FULL!", "smoothie occupies entire slot")
slot:SetAttribute("StashItemType", "Ingredient")
slot:SetAttribute("StashSessionId", "away")
check(unavailable(p, slot, "STORE") == "PROTECTED!", "enemy cannot STORE")
slot:SetAttribute("StashProtected", true)
check(unavailable(p, slot, "TAKE") == "PROTECTED!", "protected slot disables enemy TAKE")
slot:SetAttribute("StashProtected", false)
slot:SetAttribute("StashRaidEndsAt", now + 6)
slot:SetAttribute("StashProtectionEndsAt", now + 36)
check(unavailable(p, slot, "TAKE") == nil, "raid allows exposed TAKE")
now += 6
check(unavailable(p, slot, "TAKE") == "PROTECTED!", "protection starts at deadline")
now += 30
check(unavailable(p, slot, "TAKE") == nil, "protection ends at deadline")
slot:SetAttribute("StashSessionId", "home")
services.RunService.Heartbeat:Fire(0.1)
check(
    store.Position == positionStore and take.Position == positionTake and store.Text == "STORE" and take.Text == "TAKE",
    "carry and permissions never move or swap buttons"
)
reject = "SLOT FULL!"
store.Activated:Fire()
flush()
check(feedback.Text == "SLOT FULL!", "server rejection is visible")
reject = nil
local otherSlot, otherPrompt = focusedSlot()
services.ProximityPromptService.PromptShown:Fire(otherPrompt, "Touch")
services.ProximityPromptService.PromptHidden:Fire(prompt)
check(gui.Enabled, "old hidden prompt cannot dismiss new focus")
local beforeNative = #requests
services.ProximityPromptService.PromptTriggered:Fire(prompt, p)
services.ProximityPromptService.PromptTriggered:Fire(otherPrompt, instance("Player"))
services.GuiService.MenuIsOpen = true
services.ProximityPromptService.PromptTriggered:Fire(otherPrompt, p)
services.GuiService.MenuIsOpen = false
focusedTextBox = instance("TextBox")
services.ProximityPromptService.PromptTriggered:Fire(otherPrompt, p)
focusedTextBox = nil
flush()
check(#requests == beforeNative, "native STORE ignores stale focus, other actors, menus, and typing")
services.ProximityPromptService.PromptTriggered:Fire(otherPrompt, p)
flush()
check(
    #requests == beforeNative + 1
        and requests[#requests].Prompt == otherPrompt
        and requests[#requests].Action == "STORE",
    "native STORE follows the newly focused slot"
)
take.Activated:Fire()
flush()
check(requests[#requests].Prompt == otherPrompt, "switching focus targets only the new slot")
root.Position = vec(100, 0, 0)
services.RunService.Heartbeat:Fire(0.1)
check(not gui.Enabled, "moving away dismisses controls")

local afterHide = #requests
services.ProximityPromptService.PromptTriggered:Fire(otherPrompt, p)
flush()
check(#requests == afterHide, "native STORE cannot act after focus dismisses")
