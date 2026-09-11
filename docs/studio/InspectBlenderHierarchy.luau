-- Read-only: paste into the Command Bar in Edit mode, then again on the SERVER
-- during Play. Compare both outputs. No instances/properties/tags are changed.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio only")
local mode = if not RunService:IsRunning() then "EDIT" elseif RunService:IsServer() then "SERVER" else "CLIENT"
print("[BlenderHierarchy] mode=" .. mode)
local function inspect(object: Instance)
    print(
        string.format(
            "[BlenderHierarchy] path=%s class=%s archivable=%s",
            object:GetFullName(),
            object.ClassName,
            tostring(object.Archivable)
        )
    )
    if object:IsA("BasePart") then
        print(
            string.format(
                "[BlenderHierarchy] anchored=%s position=%s velocity=%s",
                tostring(object.Anchored),
                tostring(object.Position),
                tostring(object.AssemblyLinearVelocity)
            )
        )
    end
end
local plots = workspace:FindFirstChild("Plots")
if plots then
    inspect(plots)
end
local roots = {}
for _, object in workspace:GetDescendants() do
    if object.Name == "Blender" then
        table.insert(roots, object)
    end
end
print("[BlenderHierarchy] Blender roots=" .. #roots)
for _, blender in roots do
    if blender.Parent then
        inspect(blender.Parent)
    end
    inspect(blender)
    for _, child in blender:GetChildren() do
        inspect(child)
    end
    local count = 0
    for _, object in blender:GetDescendants() do
        if string.find(string.lower(object.Name), "liquid", 1, true) then
            count += 1
            inspect(object)
        elseif object:IsA("BaseScript") then
            print(
                "[BlenderHierarchy] authored script=" .. object:GetFullName() .. " enabled=" .. tostring(object.Enabled)
            )
        end
    end
    print("[BlenderHierarchy] liquid named descendants=" .. count)
end
-- Locate a liquid reparented outside the expected Blender path.
for _, object in game:GetDescendants() do
    if object:IsA("BasePart") and string.find(string.lower(object.Name), "liquid", 1, true) then
        print("[BlenderHierarchy] global liquid candidate=" .. object:GetFullName())
    end
end
