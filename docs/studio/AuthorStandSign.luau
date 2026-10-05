-- Run in Studio's Command Bar after selecting the editable Dynamic Sign Text root.
-- Uses Customer Area.Sign.board; deleted ThreeDText contents stay deleted.
-- This helper never removes authored geometry or touches another text asset.
local selected = game:GetService("Selection"):Get()[1]
assert(selected and selected.Name == "Dynamic Sign Text", "Select Customer Area > Dynamic Sign Text")
assert(selected.Parent and selected.Parent.Name == "Customer Area", "Expected storefront Customer Area child")
local sign = selected.Parent:FindFirstChild("Sign")
local face = if sign then sign:FindFirstChild("board") else nil
assert(face and face:IsA("BasePart"), "Expected physical sign face at Customer Area > Sign > board")
local existing = selected:FindFirstChild("SurfaceGui")
local gui = if existing and existing:IsA("SurfaceGui") then existing else Instance.new("SurfaceGui")
gui.Name, gui.Adornee = "SurfaceGui", face
gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(800, 320)
gui.AlwaysOnTop, gui.LightInfluence, gui.ClipsDescendants = false, 0, false
gui.Parent = selected
-- Face and physical transforms are authored in Studio, never repositioned here.
local root = gui:FindFirstChild("TextRoot") or Instance.new("Frame")
root.Name, root.Parent = "TextRoot", gui
for _, name in { "Shadow", "Depth2", "Depth1", "Main" } do
    if not root:FindFirstChild(name) then
        local label = Instance.new("TextLabel")
        label.Name, label.Parent = name, root
    end
end
local presentation = require(game.ServerScriptService.Server.Services.StandSignPresentation)
presentation.Style(selected)
presentation.SetStandName(selected, "Collin's Stand")
print("Authored layered stand sign. Set SurfaceGui.Face and inspect short/long previews before publishing.")
