-- Paste this entire file into Studio's Command Bar in EDIT mode, then Play.
-- Creates one isolated placeholder plot; refuses to replace existing plot content.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "Run in Studio Edit mode")
assert(not workspace:FindFirstChild("Blender"), "Move the legacy workspace.Blender before creating the reference plot")
assert(#CollectionService:GetTagged("PlayerPlot") == 0, "A tagged plot already exists; use that plot or a blank place")
local plots = workspace:FindFirstChild("Plots")
assert(
    not plots or #plots:GetChildren() == 0,
    "workspace.Plots already has content; use a blank place for this fixture"
)
if not plots then
    plots = Instance.new("Folder")
    plots.Name = "Plots"
    plots.Parent = workspace
end
local plot = Instance.new("Model")
plot.Name = "ReferencePlot"
plot.Parent = plots
CollectionService:AddTag(plot, "PlayerPlot")
local function part(name, position, size, tag, color)
    local object = Instance.new("Part")
    object.Name = name
    object.Anchored = true
    object.Position = position
    object.Size = size
    object.Color = color or Color3.fromRGB(100, 110, 125)
    object.Parent = plot
    if tag then
        CollectionService:AddTag(object, tag)
    end
    return object
end
part("Floor", Vector3.new(0, -0.5, 0), Vector3.new(50, 1, 50))
part("BlenderBase", Vector3.new(0, 0.5, -6), Vector3.new(10, 1, 8))
local input = part("BlenderInput", Vector3.new(0, 4, -6), Vector3.new(9, 7, 7), "BlenderInput")
input.CanCollide = false
input.CanQuery = true
input.Transparency = 1
local ingredientStation = part("IngredientSpawn", Vector3.new(0, 2, 9), Vector3.new(10, 1, 4), "IngredientSpawn")
ingredientStation:SetAttribute("IngredientId", "Strawberry")
ingredientStation:SetAttribute("RespawnSeconds", 5)
-- Free physical blade: push either end to spin it around the vertical axle.
local axle = part("TurbineAxle", Vector3.new(7, 2, -4), Vector3.new(0.5, 3, 0.5))
axle.CanCollide = false
local blade = part("blade", Vector3.new(7, 3, -4), Vector3.new(6, 0.5, 1), "TurbineWheel", Color3.fromRGB(70, 180, 240))
blade.Anchored = false
local fixedAttachment = Instance.new("Attachment")
fixedAttachment.Position = Vector3.new(0, 1, 0)
fixedAttachment.Axis = Vector3.yAxis
fixedAttachment.Parent = axle
local bladeAttachment = Instance.new("Attachment")
bladeAttachment.Axis = Vector3.yAxis
bladeAttachment.Parent = blade
local hinge = Instance.new("HingeConstraint")
hinge.Attachment0 = fixedAttachment
hinge.Attachment1 = bladeAttachment
hinge.ActuatorType = Enum.ActuatorType.None
hinge.Parent = axle
part("DispenseButton", Vector3.new(7, 3, 0), Vector3.new(2, 1, 2), "DispenseButton", Color3.fromRGB(100, 230, 120))
part("StartDayButton", Vector3.new(7, 3, 5), Vector3.new(2, 1, 2), "StartDayButton", Color3.fromRGB(250, 210, 70))
for name, position in
    {
        CustomerSpawn = Vector3.new(18, 3, 6),
        CustomerCounter = Vector3.new(11, 3, 2),
        CustomerExit = Vector3.new(18, 3, -8),
    }
do
    local marker = part(name, position, Vector3.new(1, 1, 1), name)
    marker.Transparency = 1
    marker.CanCollide = false
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "PlayerSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Position = Vector3.new(0, 0.5, 14)
spawn.Size = Vector3.new(6, 1, 4)
spawn.Parent = plot
print("ReferencePlot created. Play, enable DevContent, then follow docs/FILMING_VERTICAL_SLICE.md.")
