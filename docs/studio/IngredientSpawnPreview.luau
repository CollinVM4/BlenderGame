--!strict
-- Paste this ENTIRE file into Studio's Command Bar in Edit mode after Rojo sync.
-- Re-run to replace the session. _G.IngredientSpawnPreview.Stop() removes it.
-- Intentionally outside default.project.json: never install as a runtime Script.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsEdit(), "[IngredientSpawnPreview] Run in Studio Edit mode")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local server = game:GetService("ServerScriptService"):WaitForChild("Server")
local Spawn = require(server.Components.IngredientSpawn)
local Geometry = require(server.Services.IngredientGeometry)
local WorldUtil = require(server.Services.WorldUtil)
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local SESSION = "IngredientSpawnPreview"
local CONTAINER = "_IngredientSpawnPreviews"
local OWNER = "IngredientSpawnPreviewContainer"
local previous = _G[SESSION]
if previous then
    previous.Stop()
end
for _, child in workspace:GetChildren() do
    if child.Name == CONTAINER then
        assert(child:GetAttribute(OWNER) == true, "[IngredientSpawnPreview] Rename unrelated " .. CONTAINER)
        child:Destroy()
    end
end
local folder = Instance.new("Folder")
folder.Name = CONTAINER
folder.Archivable = false -- Omit transient visuals from saves and place clones.
folder:SetAttribute(OWNER, true)
folder.Parent = workspace
local stopped = false
local queued = false
local records: { [BasePart]: any } = {}
local connections: { RBXScriptConnection } = {}
local templateConnections: { RBXScriptConnection } = {}
local session = {} :: { Stop: () -> (), Refresh: () -> () }

local function disconnect(list: { RBXScriptConnection })
    for _, connection in list do
        connection:Disconnect()
    end
    table.clear(list)
end
local function clear(record: any)
    if record.Group then
        record.Group:Destroy()
        record.Group = nil
        record.Visual = nil
    end
end
local function warnOnce(marker: BasePart, record: any, message: string)
    if record.Warning ~= message then
        record.Warning = message
        warn("[IngredientSpawnPreview] " .. message .. " marker=" .. marker:GetFullName())
    end
end
local function ghostPart(part: BasePart)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Locked = true
    part.Transparency = math.max(part.Transparency, 0.5)
end
local function sanitize(visual: Instance)
    local children = visual:GetDescendants()
    table.insert(children, visual)
    for _, child in children do
        for _, tag in CollectionService:GetTags(child) do
            CollectionService:RemoveTag(child, tag)
        end
        for attribute in child:GetAttributes() do
            child:SetAttribute(attribute, nil)
        end
        -- Pure geometry allowlist: removes all interaction, scripts, effects,
        -- ObjectValues and joints/constraints (including external references).
        if child:IsA("BasePart") then
            ghostPart(child)
        elseif child:IsA("Decal") then
            child.Transparency = math.max(child.Transparency, 0.5)
        elseif
            not (
                child:IsA("Model")
                or child:IsA("Folder")
                or child:IsA("DataModelMesh")
                or child:IsA("SurfaceAppearance")
                or child:IsA("Attachment")
            )
        then
            child:Destroy()
        end
    end
    visual.Archivable = false
end
local function position(marker: BasePart, record: any)
    if stopped or not RunService:IsEdit() or not record.Visual then
        return
    end
    local at = Spawn.GetSpawnCFrame(marker)
    record.Visual:PivotTo(at)
    -- Cyan three-stroke arrow beside the ghost; tip points along local -Z.
    local arrow = at * CFrame.new(2, 0, 0)
    record.Arrow[1].CFrame = arrow * CFrame.new(0, 0, -1.5)
    record.Arrow[2].CFrame = arrow * CFrame.new(-0.35, 0, -2.65) * CFrame.Angles(0, math.rad(-45), 0)
    record.Arrow[3].CFrame = arrow * CFrame.new(0.35, 0, -2.65) * CFrame.Angles(0, math.rad(45), 0)
end
local function rebuild(marker: BasePart, record: any)
    clear(record)
    if
        stopped
        or not RunService:IsEdit()
        or not marker:IsDescendantOf(workspace)
        or marker:GetAttribute("ShowSpawnPreview") ~= true
    then
        record.Warning = nil
        return
    end
    local id = marker:GetAttribute("IngredientId")
    local definition = if typeof(id) == "string" then (Definitions :: any)[id] else nil
    if not definition then
        warnOnce(marker, record, "unknown IngredientId=" .. tostring(id))
        return
    end
    local templates = ServerStorage:FindFirstChild("Ingredients")
    local template = templates and templates:FindFirstChild(id :: string)
    if not template or not (template:IsA("BasePart") or template:IsA("Model")) or not WorldUtil.Part(template) then
        warnOnce(marker, record, "template missing BasePart geometry ingredient=" .. tostring(id))
        return -- Runtime fallback cubes are deliberately not presented as authored assets.
    end
    local ok, visual = pcall(Geometry.CreateVisual, id :: string, definition)
    if not ok or not visual then
        warnOnce(marker, record, "template cannot be cloned ingredient=" .. tostring(id) .. "; check Archivable")
        return
    end
    sanitize(visual)
    local group = Instance.new("Folder")
    group.Name = marker.Name .. "__" .. (id :: string) .. "__Preview"
    group.Archivable = false
    local source = Instance.new("ObjectValue")
    source.Name, source.Value, source.Parent = "SourceMarker", marker, group
    visual.Name, visual.Parent = "Ghost", group
    record.Group, record.Visual, record.Arrow = group, visual, {}
    for index = 1, 3 do
        local part = Instance.new("Part")
        part.Name = if index == 1 then "ForwardMinusZ" else "Arrowhead"
        part.Size = Vector3.new(0.12, 0.12, if index == 1 then 3 else 1)
        part.Color = Color3.fromRGB(0, 220, 255)
        part.Material = Enum.Material.Neon
        ghostPart(part)
        part.Parent = group
        table.insert(record.Arrow, part)
    end
    position(marker, record)
    group.Parent = folder -- Parent only after the clone is fully sanitized/positioned.
    record.Warning = nil
end
local function detach(marker: BasePart)
    local record = records[marker]
    if record then
        records[marker] = nil
        disconnect(record.Connections)
        clear(record)
    end
end
local function reconcile(object: Instance)
    if not object:IsA("BasePart") then
        return
    end
    if
        not (
            CollectionService:HasTag(object, "IngredientSpawn")
            or CollectionService:HasTag(object, "AnnouncedIngredientSpawn")
        )
    then
        detach(object)
        return
    end
    if records[object] or stopped then
        return
    end
    local record: any = { Connections = {} }
    records[object] = record
    for _, property in { "CFrame", "Size" } do
        table.insert(
            record.Connections,
            object:GetPropertyChangedSignal(property):Connect(function()
                position(object, record)
            end)
        )
    end
    for _, attribute in { "IngredientId", "ShowSpawnPreview" } do
        table.insert(
            record.Connections,
            object:GetAttributeChangedSignal(attribute):Connect(function()
                rebuild(object, record)
            end)
        )
    end
    table.insert(
        record.Connections,
        object:GetPropertyChangedSignal("Name"):Connect(function()
            rebuild(object, record)
        end)
    )
    table.insert(
        record.Connections,
        object.AncestryChanged:Connect(function()
            rebuild(object, record)
        end)
    )
    table.insert(
        record.Connections,
        object.Destroying:Connect(function()
            detach(object)
        end)
    )
    rebuild(object, record)
end
function session.Stop()
    if stopped then
        return
    end
    stopped = true
    disconnect(connections)
    disconnect(templateConnections)
    for marker in records do
        detach(marker)
    end
    folder:Destroy()
    if _G[SESSION] == session then
        _G[SESSION] = nil
    end
end
local function queueRefresh()
    if queued or stopped then
        return
    end
    queued = true
    task.defer(function()
        queued = false
        if not stopped then
            session.Refresh()
        end
    end)
end
function session.Refresh()
    if stopped then
        return
    end
    if not RunService:IsEdit() then
        session.Stop()
        return
    end
    disconnect(templateConnections)
    local templates = ServerStorage:FindFirstChild("Ingredients")
    if templates then
        local watched = templates:GetDescendants()
        table.insert(watched, templates)
        for _, object in watched do
            table.insert(templateConnections, object.Changed:Connect(queueRefresh))
        end
    end
    for _, tag in { "IngredientSpawn", "AnnouncedIngredientSpawn" } do
        for _, marker in CollectionService:GetTagged(tag) do
            reconcile(marker)
        end
    end
    for marker, record in records do
        rebuild(marker, record)
    end
end
_G[SESSION] = session
for _, tag in { "IngredientSpawn", "AnnouncedIngredientSpawn" } do
    table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(reconcile))
    table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(reconcile))
end
-- These also detect folder/template replacement, including recovery after deletion.
table.insert(connections, ServerStorage.DescendantAdded:Connect(queueRefresh))
table.insert(connections, ServerStorage.DescendantRemoving:Connect(queueRefresh))
table.insert(
    connections,
    RunService:GetPropertyChangedSignal("RunState"):Connect(function()
        if not RunService:IsEdit() then
            session.Stop()
        end
    end)
)
table.insert(connections, folder.Destroying:Connect(session.Stop))
session.Refresh()
print(
    "[IngredientSpawnPreview] Live Edit preview enabled; rerun after Play. _G.IngredientSpawnPreview.Stop() to remove."
)
