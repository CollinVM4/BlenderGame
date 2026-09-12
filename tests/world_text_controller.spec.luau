local controllerStartCount = count
modules.WorldTextPresentation = worldText
local workspaceMethods = instance("Folder")
workspaceFake.GetChildren = workspaceMethods.GetChildren
workspaceFake.GetDescendants = workspaceMethods.GetDescendants
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
local function authored(class, value)
    local object = instance(class)
    object.Parent = root
    object.AttributeChanged = signal()
    function object:SetAttribute(name, attributeValue)
        self.Attributes[name] = attributeValue
        self.AttributeChanged:Fire(name)
    end
    object:SetAttribute("WorldText", value)
    return object
end
local labelOrigin = authored("Attachment", "JUMP I ZONE")
local bare = authored("Attachment", nil)
local empty = authored("Attachment", "")
local invalid = authored("Attachment", 123)
local part = authored("Part", "NOT A LABEL")
local function display(object)
    return object:FindFirstChild("WorldTextDisplay")
end
local controller = module("WorldTextController")
controller.Init()
controller.Init()
check(#labelOrigin:GetChildren() == 1, "startup and repeated Init create one label")
local firstGui = display(labelOrigin)
check(firstGui:FindFirstChild("Text").Text == "JUMP I ZONE", "startup reads authored text")
check(not display(bare) and not display(empty) and not display(invalid), "missing empty and nonstring text ignored")
check(not display(part), "non-Attachment ignored")
labelOrigin:SetAttribute("WorldText", "JUMP II ZONE")
check(
    display(labelOrigin) == firstGui and firstGui:FindFirstChild("Text").Text == "JUMP II ZONE",
    "text updates same GUI"
)
labelOrigin:SetAttribute("WorldTextVisible", false)
check(not firstGui.Enabled, "visibility attribute hides existing GUI")
labelOrigin:SetAttribute("WorldText", "VIP")
check(not firstGui.Enabled and display(labelOrigin) == firstGui, "hidden text update preserves GUI and visibility")
labelOrigin:SetAttribute("WorldTextVisible", nil)
check(firstGui.Enabled, "missing visibility defaults true")
labelOrigin:SetAttribute("WorldTextMaxDistance", 50)
local configuredGui = display(labelOrigin)
check(
    firstGui.Destroyed and configuredGui.MaxDistance == 50 and #labelOrigin:GetChildren() == 1,
    "distance change replaces without duplicate"
)
labelOrigin:SetAttribute("WorldTextTextSize", 32)
configuredGui = display(labelOrigin)
check(configuredGui:FindFirstChild("Text").TextSize == 32, "optional text size applied")
check(configuredGui.Size.X.Scale == 0 and configuredGui.Size.Y.Scale == 0, "optional settings keep pixel canvas")
labelOrigin:SetAttribute("WorldTextMaxDistance", -1)
labelOrigin:SetAttribute("WorldTextTextSize", "bad")
configuredGui = display(labelOrigin)
check(
    configuredGui.MaxDistance == math.huge and configuredGui:FindFirstChild("Text").TextSize == 24,
    "invalid settings use defaults"
)
labelOrigin:SetAttribute("Unrelated", "ignored")
check(display(labelOrigin) == configuredGui, "unrelated attributes do not rebuild")
labelOrigin:SetAttribute("WorldText", "")
check(configuredGui.Destroyed and not display(labelOrigin), "empty text destroys label")
labelOrigin:SetAttribute("WorldText", "DANGER")
check(#labelOrigin:GetChildren() == 1, "restoring text recreates one label")
labelOrigin:SetAttribute("WorldText", nil)
check(not display(labelOrigin), "removed text destroys label")
bare:SetAttribute("WorldText", "LATE ATTRIBUTE")
check(display(bare) ~= nil, "bare Attachment can opt in later")
local later = authored("Attachment", "LATE OBJECT")
workspaceFake.DescendantAdded:Fire(later)
workspaceFake.DescendantAdded:Fire(later)
check(#later:GetChildren() == 1, "late Attachment and repeated discovery create one view")
local lateGui = display(later)
-- Engine DescendantRemoving fires before the object's ancestry changes.
workspaceFake.DescendantRemoving:Fire(later)
later.Parent = nil
check(lateGui.Destroyed and not display(later), "streaming/removal cleans owned GUI")
later:SetAttribute("WorldText", "OUTSIDE")
check(not display(later), "removed Attachment attribute listener disconnected")
later.Parent = root
workspaceFake.DescendantAdded:Fire(later)
check(
    #later:GetChildren() == 1 and display(later):FindFirstChild("Text").Text == "OUTSIDE",
    "reentry binds current text once"
)
check(display(bare) ~= nil, "removing one origin leaves other labels intact")
workspaceFake.DescendantRemoving:Fire(later)
later:Destroy()
check(not display(later), "origin destruction after removal remains safe")
print(
    string.format("PASS: %d world text controller assertions (mocked Roblox boundary).", count - controllerStartCount)
)
