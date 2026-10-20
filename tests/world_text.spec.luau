env.UDim2.fromOffset = function(x, y)
    return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
env.Enum.TextXAlignment = { Center = "Center" }
env.Enum.TextYAlignment = { Center = "Center" }
env.typeof = function(value)
    return if type(value) == "table" and value.ClassName then "Instance" else typeof(value)
end
-- These modules must function without any prompt, input, camera, or frame service.
env.game.GetService = function(_, name)
    assert(name == "ReplicatedStorage", "Unexpected service dependency: " .. name)
    return {
        Shared = {
            WorldBillboardStyle = "WorldBillboardStyle",
            Constants = { DialogueTextStyle = "DialogueTextStyle" },
        },
    }
end
env.Instance.new = function(class)
    assert(class == "BillboardGui" or class == "TextLabel" or class == "UIStroke", "visual-only code created " .. class)
    return instance(class)
end
local modules = {}
local function module(name)
    local chunk = assert(loadstring(sources[name], name))
    setfenv(
        chunk,
        setmetatable({
            script = {
                Parent = {
                    WorldBillboardStyle = "WorldBillboardStyle",
                    Parent = { UI = { WorldTextPresentation = "WorldTextPresentation" } },
                },
            },
            require = function(key)
                return assert(modules[key])
            end,
        }, { __index = env })
    )
    return chunk()
end
modules.WorldBillboardStyle = module("WorldBillboardStyle")
modules.DialogueTextStyle = module("DialogueTextStyle")
local worldText = module("WorldTextPresentation")
local root = instance("Model")
root.Parent = workspaceFake
local origin = instance("Attachment")
origin.Name, origin.Parent = "ArbitraryOrigin", root
local handle, reason = worldText.Create({ Origin = origin, Text = "READY" })
check(handle ~= nil and reason == nil, "valid Attachment creates a handle without a prompt")
local gui = origin:FindFirstChild("WorldTextDisplay")
local text = gui:FindFirstChild("Text")
check(#origin:GetChildren() == 1 and gui:IsA("BillboardGui"), "one BillboardGui created")
check(gui.Adornee == origin, "authored Attachment is exact Adornee")
check(text:IsA("TextLabel") and text.Text == "READY", "plain authored text without key affordance")
check(not gui.Active and not text.Active and not text.Selectable, "label cannot capture interaction")
check(gui.Size.X.Scale == 9.6 and gui.Size.Y.Scale == 2.4, "canvas uses world studs")
check(gui.Size.X.Offset == 0 and gui.Size.Y.Offset == 0, "canvas has no pixel offsets")
check(gui.AlwaysOnTop and not gui.ResetOnSpawn, "shared billboard treatment")
check(text.TextSize == 24 and text.TextScaled, "font scales with the frame")
check(text.TextXAlignment == "Center" and text.TextYAlignment == "Center", "text is centered")
check(text.BackgroundTransparency == 1 and text.TextStrokeTransparency == 0.2, "transparent outlined text")
check(text.Font == "GothamBold" and text.TextWrapped, "prompt font and wrapping retained")
local initialSize = gui.Size
local allocations = #allInstances
for index = 1, 10 do
    handle:SetText("BLENDING " .. index .. "%")
    handle:SetVisible(index % 2 == 0)
end
check(#allInstances == allocations and #origin:GetChildren() == 1, "updates never allocate another view")
check(text.Text == "BLENDING 10%", "SetText updates original label")
handle:SetVisible(false)
check(not gui.Enabled, "SetVisible(false) hides billboard")
handle:SetText("BLEND COMPLETE")
handle:SetVisible(true)
check(gui.Enabled and text.Text == "BLEND COMPLETE", "show retains text updated while hidden")
check(gui.Size == initialSize and text.TextSize == 24, "updates preserve fixed canvas and font")
handle:Destroy()
check(gui.Destroyed and text.Destroyed and #origin:GetChildren() == 0, "Destroy removes GUI and descendants")
handle:Destroy()
handle:SetText("ignored")
handle:SetVisible(true)
check(text.Text == "BLEND COMPLETE" and #origin:GetChildren() == 0, "destroy is idempotent; later updates are harmless")

local offset = vec(0, 2, 0)
local second = assert(worldText.Create({
    Origin = origin,
    Text = "3 / 3 INGREDIENTS",
    WidthStuds = 10.7,
    HeightStuds = 2.1,
    TextSize = 28,
    StudsOffset = offset,
    MaxDistance = 60,
}))
local secondGui = origin:FindFirstChild("WorldTextDisplay")
check(secondGui.Size.X.Scale == 10.7 and secondGui.Size.Y.Scale == 2.1, "optional canvas uses studs")
check(secondGui:FindFirstChild("Text").TextSize == 28, "optional font size")
check(secondGui.StudsOffset == offset and secondGui.MaxDistance == 60, "offset and engine distance culling applied")
origin:Destroy()
check(secondGui.Destroyed, "origin destruction automatically destroys owned GUI")
second:SetText("ignored")
second:SetVisible(false)
second:Destroy()
check(secondGui:FindFirstChild("Text") == nil, "handle remains safe after external destruction")

local beforeInvalid = #allInstances
for _, settings in { {}, { Origin = root }, { Origin = "bad" }, { Origin = {} }, { Origin = origin } } do
    local invalid, rejection = worldText.Create(settings)
    check(invalid == nil and type(rejection) == "string", "invalid or destroyed origin safely rejected")
end
local missing, missingReason = worldText.Create()
check(missing == nil and missingReason ~= nil, "missing settings safely rejected")
check(#allInstances == beforeInvalid, "invalid input never allocates a GUI")

-- All rendering uses engine billboard projection; no scaling or polling path exists.
for _, source in sources do
    -- The style checks IsStudio only for invalid configuration; no frame connection.
    for _, forbidden in
        { "ProximityPrompt", "UserInputService", "RenderStepped", "Heartbeat", "CurrentCamera", "UIScale", "task." }
    do
        check(not string.find(source, forbidden, 1, true), "no interaction/frame dependency: " .. forbidden)
    end
end
print(string.format("PASS: %d world text assertions (mocked Roblox boundary).", count))
