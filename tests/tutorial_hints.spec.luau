-- Presentation contracts use the real banner, wording and tutorial controller.
env.Enum.PreferredInput = { KeyboardAndMouse = "Mouse", Touch = "Touch", Gamepad = "Gamepad" }
env.Enum.KeyCode = { ButtonR2 = { EnumType = "KeyCode", Name = "ButtonR2" } }
env.Enum.KeyCode.ButtonR2.EnumType = env.Enum.KeyCode
env.Enum.ScreenInsets = { CoreUISafeInsets = "Safe" }
env.Enum.EasingStyle = { Back = "Back", Quad = "Quad" }
env.Enum.EasingDirection = { Out = "Out", In = "In" }
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
local p = instance("Player")
p.Parent, p.Character = workspaceFake, instance("Model")
p.Character.Parent = workspaceFake
p.CharacterAdded = signal()
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
    return chunk()
end
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
p:SetAttribute("PlotSessionId", "tutorial")
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("TutorialActive", true)
p:SetAttribute("TutorialHintReady", true)
p:SetAttribute("TutorialStage", "Order")
controller.Init()
check(hintContains("Take the customer's order!"), "first customer receives immediate order instruction")
check(
    label().Font == "FredokaOne" and label().BackgroundTransparency == 1,
    "hints reuse outlined announcement typography without a panel"
)
p:SetAttribute("TutorialStage", "Blender")
advance()
check(hintContains("CLICK TO THROW INTO THE BLENDER!"), "mouse wording")
services.UserInputService.PreferredInput = "Touch"
preferredChanged:Fire()
advance()
check(hintContains("TAP THROW TO TOSS IT IN!"), "preferred touch switches the displayed hint")
services.UserInputService.PreferredInput = "Gamepad"
preferredChanged:Fire()
advance()
check(hintContains("PRESS R2 TO THROW INTO THE BLENDER!"), "controller wording reads the live carry binding")
services.UserInputService.GetStringForKeyCode = function()
    return "RT"
end
advance()
advance()
check(hintContains("PRESS RT"), "platform binding label can change while the objective persists")
banner.SetGlobalActive(true)
check(not label().Visible, "announcement priority hides tutorial synchronously")
p:SetAttribute("TutorialStage", "Turbine")
advance(20)
check(not label().Visible, "progress continues without visual overlap during announcements")
banner.SetGlobalActive(false)
check(hintContains("Spin to Blend!"), "priority release resumes the current objective")
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
check(hintContains("Spin to Blend!"), "real announcement drain restores the ongoing tutorial")
local previous = label()
p.CharacterRemoving:Fire(p.Character)
check(label() == nil, "respawn clears visible UI")
p.CharacterAdded:Fire(p.Character)
check(hintContains("Spin to Blend!"), "respawn resumes current stage rather than restarting")
label().Parent:Destroy()
advance()
check(hintContains("Spin to Blend!") and label() ~= previous, "GUI destruction is recovered")
p:SetAttribute("TutorialOrderIndex", 2)
p:SetAttribute("TutorialStage", "Stash")
advance()
check(hintContains("Grab ingredients"), "cold reinforces the first occurrence of each action")
p:SetAttribute("TutorialStage", "Blender")
advance()
p:SetAttribute("TutorialStage", "Stash")
check(not label().Visible, "cold suppresses repeated pickup while proceeding")
advance(6)
check(hintContains("Grab ingredients"), "cold hesitation reveals contextual help")
p:SetAttribute("TutorialOrderIndex", 3)
p:SetAttribute("TutorialStage", "Dispenser")
check(not label().Visible, "yellow primarily leaves world highlighting in control")
advance(7)
check(not label().Visible, "yellow text waits for hesitation without gating gameplay")
advance(1)
check(hintContains("Dispense your smoothie!"), "yellow contextual dispenser help")
p:SetAttribute("TutorialStage", "Complete")
p:SetAttribute("TutorialActive", false)
check(label() == nil, "completion removes tutorial GUI")
p:SetAttribute("TutorialStage", "Order")
p:SetAttribute("TutorialOrderIndex", 1)
p:SetAttribute("PlotSessionId", "fresh-session")
p:SetAttribute("TutorialActive", true)
advance()
check(hintContains("Take the customer's order!"), "a fresh plot session can restart guidance after completion")
controller.Destroy()
preferredChanged:Fire()
advance(20)
check(label() == nil, "shutdown cannot resurrect tutorial UI")
