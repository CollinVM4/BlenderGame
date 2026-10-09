local viewer = fighter("A")
services.Players.LocalPlayer = viewer
local attributesChanged = signal()
function viewer:GetAttributeChangedSignal()
    return attributesChanged
end
local gui = instance("PlayerGui")
gui.Name, gui.Parent = "PlayerGui", viewer
function viewer:WaitForChild(name)
    return self:FindFirstChild(name)
end
local request = instance("RemoteEvent")
request.Name, request.Parent = "IceGunRequest", replicated
local actions = {}
function request:FireServer(action)
    table.insert(actions, action)
end
env.Enum.InfoType = { GamePass = "GamePass" }
env.Enum.ProximityPromptInputType = { Keyboard = "Keyboard", Gamepad = "Gamepad", Touch = "Touch" }
env.Enum.UserInputType = {
    MouseButton1 = "MouseButton1",
    MouseMovement = "MouseMovement",
    Keyboard = "Keyboard",
    Touch = "Touch",
    Gamepad1 = "Gamepad1",
}
services.UserInputService = {
    GetStringForKeyCode = function(_, key)
        return key.Name
    end,
}
local prices = 0
services.MarketplaceService.GetProductInfoAsync = function()
    prices += 1
    return { PriceInRobux = 137, IsForSale = true }
end
local adapter = loadModule("IceGunShopAdapter")
adapter.Init()
flush()
check(
    adapter.GetSnapshot().Price == 137 and not adapter.GetSnapshot().CanBuy and not adapter.GetSnapshot().Owned,
    "unknown ownership stays loading with localized market price"
)
viewer:SetAttribute("IceGunOwnership", "Unowned")
attributesChanged:Fire()
check(
    adapter.GetSnapshot().CanBuy and adapter.GetSnapshot().PriceText == "137 ROBUX",
    "market price drives unowned presentation"
)
adapter.RequestPurchase()
check(actions[#actions] == "Purchase", "future shop sends purchase intent to same server entry point")
viewer:SetAttribute("IceGunOwnership", "Owned")
attributesChanged:Fire()
check(
    adapter.GetSnapshot().Owned and adapter.GetSnapshot().CanEquip and not adapter.GetSnapshot().CanBuy,
    "shop updates after verified ownership without reopening"
)
adapter.RequestEquip()
check(actions[#actions] == "Equip", "shop equip uses same grant authority")
check(prices == 1, "ownership updates do not constantly poll marketplace pricing")
local shown, hidden = signal(), signal()
services.ProximityPromptService = { PromptShown = shown, PromptHidden = hidden }
services.RunService.RenderStepped = signal()
services.CollectionService.GetInstanceAddedSignal = function()
    return signal()
end
services.CollectionService.GetInstanceRemovedSignal = function()
    return signal()
end
workspaceFake.DescendantRemoving = signal()
cache.DialogueTextStyle = {
    Apply = function(text)
        text.Font = "FredokaOne"
    end,
}
-- Execute the shared renderer; the old stub could not catch camera culling.
local propertySignals = {}
local rendererNew = env.Instance.new
env.Instance.new = function(class)
    local object = rendererNew(class)
    object.InputBegan = signal()
    object.Visible, object.Enabled = true, true
    function object:GetAttributeChangedSignal()
        return signal()
    end
    function object:GetPropertyChangedSignal(name)
        propertySignals[self] = propertySignals[self] or {}
        propertySignals[self][name] = propertySignals[self][name] or signal()
        return propertySignals[self][name]
    end
    return object
end
function gui:GetAttributeChangedSignal()
    return signal()
end
services.UserInputService.InputEnded = signal()
services.UserInputService.WindowFocusReleased = signal()
local realPresentation = loadModule("InteractionPromptPresentation")
local settings, label, retired, billboard = nil, nil, false, nil
cache.InteractionPromptPresentation = {
    Create = function(prompt, origin, parent, input, config)
        settings = config
        local cleanup, view = realPresentation.Create(prompt, origin, parent, input, config)
        billboard = view
        label = view:FindFirstChild("Action")
        return function()
            cleanup()
            retired = true
        end, view
    end,
}
local controller = loadModule("IceGunDisplayController")
controller.Init()
local attachment = instance("Attachment")
local prompt = env.Instance.new("ProximityPrompt")
prompt.Style, prompt.Enabled = "Custom", true
prompt.PromptButtonHoldBegan, prompt.PromptButtonHoldEnded = signal(), signal()
local holds = 0
function prompt:InputHoldBegin()
    holds += 1
end
function prompt:InputHoldEnd() end
attachment.Parent = workspaceFake
prompt.Parent, prompt.ActionText = attachment, "LOADING"
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
prompt:SetAttribute("IceGunPurchase", true)
shown:Fire(prompt, "Keyboard")
check(
    billboard.Parent == gui and billboard.Adornee == attachment and billboard.MaxDistance == math.huge,
    "live custom renderer is parented and cannot be culled by a third-person camera beyond eight studs"
)
check(
    label.Text == "ICE GUN\nOWNED\n[E] EQUIP" and label.Font == "FredokaOne",
    "owned world point uses existing Fredoka prompt style"
)
check(prompt.ActionText == "LOADING", "per-player presentation never mutates replicated ownership text")
check(
    settings.FormatText("TAP", true) == "ICE GUN\nOWNED\n[TAP] EQUIP",
    "prompt press formatting preserves ownership on mobile"
)
viewer:SetAttribute("IceGunEquipped", true)
attributesChanged:Fire()
check(label.Text == "ICE GUN\nOWNED\n[E] EQUIPPED", "equipped server snapshot updates the existing GUI")
viewer:SetAttribute("IceGunEquipped", false)
viewer:SetAttribute("IceGunOwnership", "Unowned")
attributesChanged:Fire()
check(label.Text == "ICE GUN\n137 ROBUX\n[E] BUY", "visible world view updates locally with localized price")
local teammate = fighter("A")
teammate:SetAttribute("IceGunOwnership", "Owned")
check(label.Text == "ICE GUN\n137 ROBUX\n[E] BUY", "another player ownership cannot change this client purchase state")
viewer:SetAttribute("IceGunOwnership", "Unavailable")
attributesChanged:Fire()
check(label.Text == "ICE GUN\nUNAVAILABLE\n[E] RETRY", "marketplace error never implies free ownership")
hidden:Fire(prompt)
check(retired, "removed/hidden prompt cleans its existing touch presentation")
check(billboard.Destroyed, "shared renderer destroys the actual billboard on hide")
viewer:SetAttribute("IceGunOwnership", "Unowned")
attributesChanged:Fire()
shown:Fire(prompt, "Touch")
check(label.Text == "ICE GUN\n137 ROBUX\n[TAP] BUY", "touch purchase label uses the same renderer")
label.InputBegan:Fire({ UserInputType = "Touch" })
check(holds == 1, "touch action forwards to the normal prompt API")
hidden:Fire(prompt)
shown:Fire(prompt, "Gamepad")
check(label.Text == "ICE GUN\n137 ROBUX\n[ButtonX] BUY", "gamepad purchase label preserves native prompt key")
workspaceFake.DescendantRemoving:Fire(prompt)
check(billboard.Destroyed, "display removal cleans the real view")
local unrelated = instance("ProximityPrompt")
local previous = billboard
shown:Fire(unrelated, "Keyboard")
check(billboard == previous, "Ice Gun renderer does not capture unrelated prompts")
print("PASS: Ice Gun local ownership/price presentation")
