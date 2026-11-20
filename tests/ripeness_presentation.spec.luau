local state = loadModule("RipenessDisplayState")
local tutorial = loadModule("RipenessTutorialText")
local style = loadModule("RipenessPresentation")
local Color3 = env.Color3
-- The lightweight CLI fixture only needs value constructors for this UI view.
UDim = {
    new = function(scale, offset)
        return { Scale = scale, Offset = offset }
    end,
}
NumberSequenceKeypoint = {
    new = function(time, value)
        return { Time = time, Value = value }
    end,
}
NumberSequence = {
    new = function(points)
        return points
    end,
}
local radial = loadModule("RadialProgress")
local host = instance("Frame")
local first = radial.Create(host, style.IndicatorGold, Color3.fromRGB(58, 68, 62))
local second = radial.Create(host, style.IndicatorGold, Color3.fromRGB(58, 68, 62))
check(
    first.Root.Name == "RadialProgress" and first.Root.Size.X.Scale == 1 and first.Root.Size.X.Offset == 0,
    "aging view has a compact radial loader"
)
check(
    first.Root:FindFirstChild("Track") ~= nil and first.Root:FindFirstChild("InnerCutout") ~= nil,
    "radial view keeps a subtle unfilled track"
)
check(first.Root:FindFirstChild("RingSegment", true) == nil, "radial view contains no segmented markers")
for _, sample in { 0, 0.25, 0.5, 0.75, 1 } do
    radial.SetProgress(first, sample)
    check(first.Right.Rotation == math.min(sample * 360, 180), "first half fills clockwise up to 50 percent")
    check(first.Left.Rotation == math.max(sample * 360, 180), "second half continues clockwise to 100 percent")
end
radial.SetProgress(second, 0.25)
check(
    first.Left.Rotation == 360 and second.Left.Rotation == 180,
    "each physical ingredient owns independent fill state"
)
check(
    sources.RipenessPresentationController:find("view.RadialProgress.Root.Visible = not ripe", 1, true) ~= nil
        and sources.RipenessPresentationController:find(
                "view.Center.BackgroundColor3 = if ripe then gold else fresh",
                1,
                true
            )
            ~= nil,
    "Ripe hides the loader and uses the solid gold center"
)
check(style.StashMaxDistance == 35, "stash value and ripeness indicators share near visibility distance")
check(
    style.IndicatorGold.R == 1 and style.IndicatorGold.G == 221 / 255 and style.IndicatorGold.B == 48 / 255,
    "completed pip and progress ring use clear golden yellow"
)
local slot = instance("Part")
local display = instance("Folder")
display.Name, display.Parent = "StashDisplay", slot
local value = instance("BillboardGui")
value.Name, value.Parent = "SlotValue", display
check(style.ResolveOrigin(slot) == slot, "missing ripeness attachment safely uses the slot")
local malformed = instance("Part")
malformed.Name, malformed.Parent = "StashRipenessOrigin", slot
check(style.ResolveOrigin(slot) == slot, "a malformed origin cannot break ripeness presentation")
malformed:Destroy()
local origin = instance("Attachment")
origin.Name, origin.Parent = "StashRipenessOrigin", slot
local indicator = instance("BillboardGui")
style.ConfigureIndicator(indicator, slot)
check(
    indicator.Adornee == origin and indicator.Adornee ~= value,
    "ripeness resolves its own authored attachment independently of the value billboard"
)
check(
    indicator.Size.X.Scale == 3.84
        and indicator.Size.X.Offset == 0
        and indicator.Size.Y.Scale == 0.72
        and indicator.Size.Y.Offset == 0,
    "ripeness billboard keeps stud dimensions"
)
check(indicator.MaxDistance == 35, "ripeness billboard keeps nearby visibility")
display:Destroy()
style.ConfigureIndicator(indicator, slot)
check(indicator.Adornee == origin, "ripeness origin remains available without the value display")
check(
    tutorial.Copy == "Leave ingredients in the stash for 2 minutes.\nRipe ingredients are worth 25% more.",
    "tutorial tells players where to ripen ingredients, how long it takes, and the benefit"
)
check(tutorial.Rich():gsub("<[^>]+>", "") == tutorial.Copy, "rich tooltip preserves copy while emphasizing key terms")
check(
    tutorial.Rich():find("<b>2 minutes</b>", 1, true) and tutorial.Rich():find("<b>25% more</b>", 1, true),
    "tutorial highlights the wait and the bonus"
)

env.UDim2.new = function(xScale, xOffset, yScale, yOffset)
    return { X = UDim.new(xScale, xOffset), Y = UDim.new(yScale, yOffset) }
end
env.Enum.PreferredInput = { Touch = "Touch", KeyboardAndMouse = "KeyboardAndMouse" }
env.Enum.ScreenInsets = { CoreUISafeInsets = "CoreUISafeInsets" }
env.Enum.TextXAlignment.Left = "Left"
services.UserInputService = { PreferredInput = env.Enum.PreferredInput.Touch }
local expiry = {}
env.task.delay = function(seconds, callback)
    table.insert(expiry, { Seconds = seconds, Callback = callback })
end
local player = instance("Player")
local playerGui = instance("PlayerGui")
playerGui.Name, playerGui.Parent = "PlayerGui", player
player.WaitForChild = player.FindFirstChild
services.Players.LocalPlayer = player
services.CollectionService.GetInstanceAddedSignal = function()
    return signal()
end
local function setTutorialAttribute(shown)
    player:SetAttribute("RipenessTutorialShown", shown)
    player:GetAttributeChangedSignal("RipenessTutorialShown"):Fire()
end
local function findHint()
    return playerGui:FindFirstChild("RipenessTutorial")
end

loadModule("RipenessPresentationController").Init()
check(findHint() == nil, "hint waits for the first ingredient store")
setTutorialAttribute(true)
local hint = findHint()
local card = hint:FindFirstChild("Card")
local dot = card:FindFirstChild("RipePip")
local button = card:FindFirstChild("Dismiss")
check(
    hint.ScreenInsets == env.Enum.ScreenInsets.CoreUISafeInsets and card.AnchorPoint.Y == 0,
    "touch hint uses the upper safe area"
)
check(card:FindFirstChild("Instructions").Text == tutorial.Rich(), "shown hint uses the highlighted copy")
check(
    dot.BackgroundColor3 == style.IndicatorGold and card:FindFirstChild("RipeLegend").Text == "Gold dot = ripe",
    "card identifies the real ripe indicator"
)
check(expiry[1].Seconds == 12 and findHint() == hint, "hint grants a 12-second reading window")
check(button.Text == "GOT IT" and button.Size.Y.Offset >= 44, "GOT IT has a full-size tap target")
button.Activated:Fire()
check(findHint() == nil, "GOT IT dismisses the hint")
setTutorialAttribute(false)
setTutorialAttribute(true)
check(findHint() == nil, "later stores cannot reopen the one-time hint")

services.UserInputService.PreferredInput = env.Enum.PreferredInput.KeyboardAndMouse
loadModule("TutorialTooltip").Show(playerGui)
hint = findHint()
check(hint:FindFirstChild("Card").AnchorPoint.Y == 1, "desktop hint sits below the main tutorial")
expiry[1].Callback()
check(findHint() == hint, "the dismissed card's timer leaves a later card alone")
expiry[2].Callback()
check(findHint() == nil, "hint expires even if the player never presses GOT IT")

local pad = instance("Part")
pad:SetAttribute("RipenessSeconds", 120)
pad:SetAttribute("StashCount", 1)
pad:SetAttribute("StashItem1Id", "protected-item")
pad:SetAttribute("StashItem1StoredSeconds", 0)
pad:SetAttribute("StashItem1StoredAt", 100)
local protected = state.Read(pad, 100)
check(#protected == 1 and protected[1].Progress == 0, "protected slot has one fresh physical indicator")
check(state.Progress(pad, 1, 160) == 0.5, "active stash time uses server timestamp")
pad:SetAttribute("StashItem1StoredAt", nil)
pad:SetAttribute("StashItem1StoredSeconds", 60)
check(state.Progress(pad, 1, 500) == 0.5, "aging pauses outside stash")

pad:SetAttribute("StashCount", 3)
pad:SetAttribute("StashItem1StoredSeconds", 10)
pad:SetAttribute("StashItem1StoredAt", 100)
pad:SetAttribute("StashItem2Id", "aged-item")
pad:SetAttribute("StashItem2StoredSeconds", 40)
pad:SetAttribute("StashItem2StoredAt", 100)
pad:SetAttribute("StashItem3Id", "ripe-item")
pad:SetAttribute("StashItem3IsRipe", true)
pad:SetAttribute("StashItem3StoredSeconds", 120)
local items, signature = state.Read(pad, 120)
check(#items == 3, "normal slot has one indicator per physical ingredient")
check(items[1].Id == "ripe-item" and items[1].Ripe and items[1].Progress == 1, "ripe item is completed and first")
check(items[2].Id == "aged-item" and items[2].Progress == 0.5, "most-aged Fresh follows Ripe")
check(items[3].Id == "protected-item" and items[3].Progress == 30 / 120, "each item uses independent stored time")
check(items[2].Progress ~= items[3].Progress, "three physical timestamps produce independent progress")
local later, sameSignature = state.Read(pad, 121)
check(sameSignature == signature and later[1].Id == items[1].Id, "elapsed time updates without reordering content")
pad:SetAttribute("StashItem2IsRipe", true)
local changed, newSignature = state.Read(pad, 121)
check(newSignature ~= signature and changed[2].Ripe, "ripe transition changes display state once")
