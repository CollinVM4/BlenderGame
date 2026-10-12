--!strict
-- Read-only: paste into the SERVER Command Bar during a multiplayer Play test.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
assert(RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(), "Use Server Command Bar in Play")
local bridge = game:GetService("ServerStorage"):FindFirstChild("StudioServiceCalls")
local function call(method: string, ...: any): any
    if not bridge or not bridge:IsA("BindableFunction") then
        return nil
    end
    local ok, result = pcall(function(...: any)
        return bridge:Invoke("LockBaseService", method, ...)
    end, ...)
    if not ok then
        warn("[LockBaseInspect] " .. tostring(result))
        return nil
    end
    return result
end
local function path(object: Instance?): string
    return if object then object:GetFullName() .. " [" .. object.ClassName .. "]" else "MISSING"
end
print(
    "[LockBaseInspect] initialized=",
    workspace:GetAttribute("LockBaseInitialized"),
    "bootstrapBridge=",
    bridge ~= nil,
    "diagnostics=",
    workspace:GetAttribute("LockBaseDiagnostics")
)
local plots = CollectionService:GetTagged("PlayerPlot")
local folder = workspace:FindFirstChild("Plots")
if folder then
    for _, plot in folder:GetChildren() do
        if not table.find(plots, plot) then
            table.insert(plots, plot)
        end
    end
end
local legacy = workspace:FindFirstChild("Blender")
if legacy and not table.find(plots, legacy) then
    table.insert(plots, legacy)
end
for _, plot in plots do
    local lock = if plot.Name == "LockBase" then plot else plot:FindFirstChild("LockBase", true)
    local assembly = lock and lock:FindFirstChild("LockButton")
    local button = assembly and assembly:FindFirstChild("Button")
    local attachment = assembly and assembly:FindFirstChild("LockAttachment", true)
    local visual = assembly and assembly:FindFirstChild("Visual")
    local base = assembly and assembly:FindFirstChild("BlackBase")
    local gui = attachment and attachment:FindFirstChild("LockBaseDisplay")
    local laserCount, baseCount = 0, 0
    if visual then
        for _, part in visual:GetDescendants() do
            if part:IsA("BasePart") then
                if part.Name == "Laser" then
                    laserCount += 1
                end
                if part.Name == "LaserBase" then
                    baseCount += 1
                end
                if part.CanCollide then
                    warn("[LockBaseInspect] Collidable visual: " .. path(part))
                end
            end
        end
    end
    local walls = call("DiscoverWalls", plot, lock)
    if not walls then
        -- Read-only fallback also works when bootstrap stopped before publication.
        walls = {}
        for _, part in CollectionService:GetTagged("PlayerOnlyCollision") do
            if
                not part:IsA("BasePart")
                or not part:IsDescendantOf(plot)
                or part == button
                or part == base
                or part == assembly
                or (base and part:IsDescendantOf(base))
                or (visual and part:IsDescendantOf(visual))
            then
                continue
            end
            local associated = (lock ~= nil and part:IsDescendantOf(lock)) or part:GetAttribute("LockBaseWall") == true
            local ancestor: Instance? = part
            while ancestor and ancestor ~= plot do
                if ancestor.Name == "Wall" or ancestor.Name == "Walls" then
                    associated = true
                end
                ancestor = ancestor.Parent
            end
            if associated then
                table.insert(walls, part)
            end
        end
    end
    print(
        string.format(
            "[LockBaseInspect] plot=%s owner=%s session=%s locked=%s remaining=%d assetsReady=%s",
            path(plot),
            tostring(plot:GetAttribute("OwnerUserId")),
            tostring(plot:GetAttribute("LockBaseSessionId")),
            tostring(plot:GetAttribute("LockBaseLocked")),
            math.max(0, math.ceil((plot:GetAttribute("LockBaseLockedUntil") or 0) - workspace:GetServerTimeNow())),
            tostring(plot:GetAttribute("LockBaseAssetsReady"))
        )
    )
    print("  LockBase:", path(lock), "LockButton:", path(assembly))
    local validButton = button ~= nil
        and button:IsA("BasePart")
        and button:IsDescendantOf(workspace)
        and button.Anchored
        and button.CanCollide
        and button.CanQuery
    print("  Button:", path(button), "activationGeometryValid=", validButton)
    if button and button:IsA("BasePart") then
        print(
            "    CanCollide=",
            button.CanCollide,
            "CanQuery=",
            button.CanQuery,
            "CanTouch=",
            button.CanTouch,
            "size=",
            button.Size,
            "position=",
            button.Position
        )
        for _, player in game:GetService("Players"):GetPlayers() do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if
                root
                and root:IsA("BasePart")
                and (root.Position - button.Position).Magnitude <= 12
                and bridge
                and bridge:IsA("BindableFunction")
            then
                local ok, standing, reason = pcall(function()
                    return bridge:Invoke("LockBaseService", "CheckStanding", player, plot)
                end)
                print("    player=", player.Name, "standing=", if ok then standing else false, "reason=", reason)
            end
        end
    end
    print(
        "  LockAttachment:",
        path(attachment),
        "host=",
        path(if attachment then attachment.Parent else nil),
        "valid=",
        attachment ~= nil
            and attachment:IsA("Attachment")
            and attachment.Parent ~= nil
            and attachment.Parent:IsA("BasePart")
            and attachment:IsDescendantOf(workspace)
    )
    print("  Visual:", path(visual), "Laser=", laserCount, "LaserBase=", baseCount, "walls=", #walls)
    if visual and visual:IsA("Model") then
        print("    pivot=", visual:GetPivot(), "authoredRaisedPivot=", visual:GetAttribute("LockBaseRaisedPivot"))
    end
    print("  BillboardGui:", path(gui), "Enabled=", gui ~= nil and gui:IsA("BillboardGui") and gui.Enabled)
    if gui and gui:IsA("BillboardGui") then
        print("    Adornee=", path(gui.Adornee), "offset=", gui.StudsOffsetWorldSpace, "MaxDistance=", gui.MaxDistance)
        local text = gui:FindFirstChildOfClass("TextLabel")
        if text then
            print(
                "    text=",
                text.Text,
                "font=",
                text.Font,
                "transparency=",
                text.TextTransparency,
                "ZIndex=",
                text.ZIndex
            )
        end
    end
    for _, wall in walls do
        print(
            "  wall:",
            path(wall),
            "group=",
            wall.CollisionGroup,
            "CanCollide=",
            wall.CanCollide,
            "transparency=",
            wall.Transparency
        )
    end
    if not lock or not validButton or laserCount == 0 or baseCount == 0 or #walls == 0 then
        warn("[LockBaseInspect] Incomplete authored security setup in " .. path(plot))
    end
end
-- A model outside the claimed plot hierarchy cannot be associated automatically.
for _, object in workspace:GetDescendants() do
    if object.Name == "LockBase" then
        local associated = false
        for _, plot in plots do
            if object == plot or object:IsDescendantOf(plot) then
                associated = true
            end
        end
        if not associated then
            warn("[LockBaseInspect] LockBase is OUTSIDE known plots: " .. path(object))
        end
    end
end
