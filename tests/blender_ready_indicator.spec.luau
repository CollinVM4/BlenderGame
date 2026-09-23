local function new(class, name, parentObject)
    local object = instance(class)
    object.Name, object.Parent = name, parentObject
    local signals = {}
    function object:GetAttributeChangedSignal(attribute)
        signals[attribute] = signals[attribute] or signal()
        return signals[attribute]
    end
    function object:SetAttribute(attribute, value)
        local previous = self.Attributes[attribute]
        self.Attributes[attribute] = value
        if previous ~= value and signals[attribute] then
            signals[attribute]:Fire()
        end
    end
    return object
end
services.Players.PlayerRemoving = signal()
env.Enum.PartType = { Cylinder = "Cylinder" }
env.Enum.Material = { Neon = "Neon", SmoothPlastic = "SmoothPlastic" }
-- Exercise the actual tag lifecycle, with engine tag events supplied by the boundary.
local added, removed = signal(), signal()
services.CollectionService.GetInstanceAddedSignal = function()
    return added
end
services.CollectionService.GetInstanceRemovedSignal = function()
    return removed
end
cache.WorldUtil = nil
local plots, owners, markers, bulbs = {}, {}, {}, {}
for i = 1, 2 do
    local plot = new("Model", "Plot" .. i, workspaceFake)
    local blender = new("Model", "Blender", plot)
    local body = new("Part", "Body", blender)
    local marker =
        new(if i == 1 then "Part" else "Attachment", "ReadyIndicatorOrigin", if i == 1 then blender else body)
    marker.Position, marker.WorldPosition = vec(i * 20, 3, 8), vec(i * 20, 3, 8)
    local folder = new("Folder", "BlendProgressLights", blender)
    new("Model", "Light1", folder) -- Earlier bulbs may be absent; no click sound required.
    local light = new("Model", "Light5", folder)
    local bulb = new("Part", "Bulb", light)
    bulb.Material = "SmoothPlastic"
    local point = new("PointLight", "PointLight", bulb)
    point.Brightness = 1.5
    new("Part", "Light", light)
    local owner = new("Player", "Owner" .. i)
    plot:SetAttribute("OwnerUserId", i)
    plots[i], owners[plot], markers[i], bulbs[i] = plot, owner, marker, point
    services.CollectionService:AddTag(plot, "PlayerPlot")
end
local dependencies = { TycoonService = {
    GetOwner = function(plot)
        return owners[plot]
    end,
} }
loadModule("BlenderReadyIndicator").Init(dependencies)
loadModule("BlendProgressLights").Init(dependencies)
local function disk(i)
    return markers[i]:FindFirstChild("BlenderReadyFloorIndicator")
end
local function visible(i, expected, message)
    check((disk(i).Transparency < 1) == expected and bulbs[i].Enabled == expected, message .. " (disk and fifth light)")
end
for i = 1, 2 do
    visible(i, false, "initially hidden")
    local part = disk(i)
    check(part.Color.G == 1 and part.Color.R == 0 and part.Material == "Neon", "bright green neon")
    check(
        part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,
        "inert and shadow-free"
    )
    check(
        part.Shape == "Cylinder" and part.Size.X == 0.15 and part.Size.Y == 6 and part.Size.Z == 6,
        "thin readable disk"
    )
    check(
        part.CFrame.Position.X == i * 20 and math.abs(part.CFrame.Position.Y - 3.1) < 0.001,
        "uses BasePart/Attachment world origin plus floor clearance"
    )
end
local owner = owners[plots[1]]
owner:SetAttribute("BlendState", "READY")
owner:SetAttribute("BlendProgress", 50)
visible(1, false, "partial progress is hidden")
owner:SetAttribute("BlendState", "BLENDING")
owner:SetAttribute("BlendProgress", 100)
visible(1, false, "full progress alone is not dispensable")
owner:SetAttribute("BlendState", "COMPLETE")
visible(1, true, "complete batch visible")
visible(2, false, "foreign player state cannot light another plot")
owner:SetAttribute("BlendState", "DISPENSED")
visible(1, false, "dispense immediately hides even with stale full progress")
owner:SetAttribute("BlendState", "EMPTY")
visible(1, false, "reset hidden")
owner:SetAttribute("BlendState", "COMPLETE")
owner:SetAttribute("BlendProgress", 0)
visible(1, false, "completion attribute alone does not bypass progress")
for _ = 1, 5 do
    owner:SetAttribute("BlendProgress", 100)
    visible(1, true, "repeated completion shows")
    owner:SetAttribute("BlendState", "LOADING")
    visible(1, false, "new batch hides")
    owner:SetAttribute("BlendState", "COMPLETE")
end
check(#markers[1]:GetChildren() == 1, "transitions never duplicate disks")
local replacement = owners[plots[2]]
owners[plots[1]] = replacement
plots[1]:SetAttribute("OwnerUserId", 2)
visible(1, false, "ownership reassignment clears old readiness")
owner:SetAttribute("BlendState", "EMPTY")
owner:SetAttribute("BlendState", "COMPLETE")
visible(1, false, "old owner no longer drives plot")
replacement:SetAttribute("BlendState", "COMPLETE")
replacement:SetAttribute("BlendProgress", 100)
visible(1, true, "replacement state drives reassigned plot")
plots[1]:SetAttribute("OwnerUserId", nil)
visible(1, false, "unowned plot hidden")
services.Players.PlayerRemoving:Fire(replacement)
visible(2, false, "departure hides")
replacement:SetAttribute("BlendProgress", 90)
visible(2, false, "departed player cannot relight plot")
local oldDisk = disk(1)
services.CollectionService:RemoveTag(plots[1], "PlayerPlot")
removed:Fire(plots[1])
check(oldDisk.Parent == nil and disk(1) == nil, "tag removal destroys disk")
services.CollectionService:AddTag(plots[1], "PlayerPlot")
added:Fire(plots[1])
added:Fire(plots[1])
check(#markers[1]:GetChildren() == 1, "retag restores exactly one disk")
plots[1].Parent = nil
plots[1].AncestryChanged:Fire()
check(disk(1) == nil, "leaving Workspace destroys disk")
print(string.format("PASS: %d floor indicator/light presentation assertions", count))
