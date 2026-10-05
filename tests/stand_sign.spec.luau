-- Presentation only: layered sign, unrelated ThreeDText assets remain untouched.
local plot = instance("Model")
local area = instance("Folder")
area.Name, area.Parent = "Customer Area", plot
local counter = instance("Part")
counter.Name, counter.Parent = "Counter", area
local physicalSign = instance("Model")
physicalSign.Name, physicalSign.Parent = "Sign", area
local board = instance("Part")
board.Name, board.Parent, board.CFrame = "board", physicalSign, frame(3, 5, 7)
local authoredTransform = board.CFrame
local sign = instance("Folder")
sign.Name, sign.Parent = "Dynamic Sign Text", area
local gui = instance("SurfaceGui")
gui.Name, gui.Parent, gui.Adornee = "SurfaceGui", sign, board
local root = instance("Frame")
root.Name, root.Parent = "TextRoot", gui
local labels = {}
for _, name in { "Main", "Depth1", "Depth2", "Shadow" } do
    local label = instance("TextLabel")
    label.Name, label.Parent = name, root
    labels[name] = label
end
local unrelated = instance("Model")
unrelated.Name = "ThreeDText"
local presentation = loadModule("StandSignPresentation")
for _, name in { "Bob's Stand", "Collin's Stand", "Super Smoothies", "Noob Smoothies", string.rep("a", 32) } do
    presentation.SetStandName(sign, name)
    for _, label in labels do
        check(label.Text == name, "all layers use same authoritative string")
    end
end
check(not unrelated.Destroyed and #unrelated:GetChildren() == 0, "sign updates leave unrelated text geometry alone")
presentation.SetStandName(instance("Model"), "Missing authored GUI")
check(true, "missing authored sign safely ignored")

env.UDim2.new = function(a, b, c, d)
    return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } }
end
env.UDim2.fromScale = function(a, b)
    return env.UDim2.new(a, 0, b, 0)
end
presentation.Style(sign)
check(
    labels.Main.Font == env.Enum.Font.FredokaOne and labels.Main.TextScaled and labels.Main.TextWrapped,
    "authored sign uses responsive Fredoka"
)
check(
    labels.Main:FindFirstChildOfClass("UIStroke").Thickness == 3
        and labels.Main:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize == 20,
    "outline and readable sizing constraint"
)

plot:SetAttribute("StandName", "Authored Storefront")
loadModule("PlotClaimZones").Refresh(plot)
for _, label in labels do
    check(label.Text == "Authored Storefront", "runtime resolves direct Customer Area sign root")
end
check(
    gui.Adornee == board and board.CFrame == authoredTransform,
    "runtime preserves authored board Adornee and physical transform"
)

-- A teammate pad may be authored hidden for the initial unclaimed state.
local identity = instance("Folder")
identity.Name, identity.Parent = "PlotIdentity", plot
local claimPad = instance("Part")
claimPad.Name, claimPad.Parent, claimPad.Transparency = "ClaimVisual", identity, 0.3
local joinPad = instance("Part")
joinPad.Name, joinPad.Parent, joinPad.Transparency = "TeammateVisual", identity, 1
local claimZone = instance("Part")
claimZone.Name, claimZone.Parent = "ClaimZone", identity
local joinZone = instance("Part")
joinZone.Name, joinZone.Parent = "TeammateZone", identity
local zones = loadModule("PlotClaimZones")
for _, occupancy in { 0, 1, 1, 2, 1, 0 } do
    plot:SetAttribute("PlotOccupancy", occupancy)
    zones.Refresh(plot)
    check((claimPad.Transparency < 1) == (occupancy == 0), "claim pad follows occupancy")
    check(
        (joinPad.Transparency < 1) == (occupancy == 1),
        "initially hidden teammate pad stays visible in owner-only state"
    )
    check(
        claimZone:GetAttribute("PlotZoneActive") == (occupancy == 0)
            and joinZone:GetAttribute("PlotZoneActive") == (occupancy == 1),
        "detector activation follows occupancy"
    )
end
check(claimZone.Parent == identity and joinZone.Parent == identity, "presentation never removes detectors")
