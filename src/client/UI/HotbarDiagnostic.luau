--!strict
-- Temporary Pass 1 observer. Only loaded for Workspace.HotbarDiagnosticUserId.
-- API state is NOT evidence of what Roblox's native Backpack renders.
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local Diagnostic = {}
local moduleId = HttpService:GenerateGUID(false)

function Diagnostic.Start(player: Player, playerGui: PlayerGui, controller: Instance, session: number)
    local prefix = moduleId .. ":" .. tostring(session)
    local ids: { [Instance]: number } = {}
    local nextId = 0
    -- Share the report across cloned Client/ModuleScripts as well as restarts.
    local existingLog = playerGui:FindFirstChild("HotbarDiagnosticLog")
    local log: StringValue
    if existingLog and existingLog:IsA("StringValue") then
        log = existingLog
    else
        log = Instance.new("StringValue")
        log.Name, log.Value = "HotbarDiagnosticLog", ""
        log:SetAttribute("DroppedLines", 0)
        log.Parent = playerGui
    end
    local function dropped(): number
        return log:GetAttribute("DroppedLines") :: number
    end
    local connections: { RBXScriptConnection } = {}
    local cameraConnection: RBXScriptConnection? = nil
    local stopped, queued = false, false
    local captures = 0
    local function ref(object: Instance): string
        if not ids[object] then
            nextId += 1
            ids[object] = nextId
        end
        return tostring(ids[object]) .. ":" .. object:GetFullName()
    end
    local function record(kind: string, data: any)
        local line = "[HotbarDiagnostic] "
            .. HttpService:JSONEncode({
                session = prefix,
                t = os.clock(),
                kind = kind,
                data = data,
            })
        local buffer = log.Value .. line .. "\n"
        local removed = 0
        while #buffer > 1024 * 1024 do
            local newline = string.find(buffer, "\n", 1, true)
            if not newline then
                break
            end
            buffer = string.sub(buffer, newline + 1)
            removed += 1
        end
        log.Value = buffer
        log:SetAttribute("DroppedLines", dropped() + removed)
        print(line)
    end
    local function inspect(object: Instance, container: Instance): any
        local result: any = {
            instance = ref(object),
            class = object.ClassName,
            role = object:GetAttribute("BlenderUI"),
            reparented = object:GetAttribute("HotbarReparented"),
        }
        local gates = {}
        local shown = object:IsDescendantOf(container)
        local left, top, right, bottom = -math.huge, -math.huge, math.huge, math.huge
        if object:IsA("GuiObject") then
            local p, s = object.AbsolutePosition, object.AbsoluteSize
            result.position, result.size = { p.X, p.Y }, { s.X, s.Y }
            result.visible = object.Visible
            left, top, right, bottom = p.X, p.Y, p.X + s.X, p.Y + s.Y
        end
        local ancestor: Instance? = object
        while ancestor and ancestor ~= container do
            if ancestor:IsA("ScreenGui") then
                table.insert(gates, { instance = ref(ancestor), enabled = ancestor.Enabled })
                shown = shown and ancestor.Enabled
                result.root = ref(ancestor)
                result.displayOrder = ancestor.DisplayOrder
                result.insets = tostring(ancestor.ScreenInsets)
                local p, s = ancestor.AbsolutePosition, ancestor.AbsoluteSize
                left, top = math.max(left, p.X), math.max(top, p.Y)
                right, bottom = math.min(right, p.X + s.X), math.min(bottom, p.Y + s.Y)
            elseif ancestor:IsA("GuiObject") then
                local gate: any = { instance = ref(ancestor), visible = ancestor.Visible }
                shown = shown and ancestor.Visible
                if ancestor:IsA("CanvasGroup") then
                    gate.groupTransparency = ancestor.GroupTransparency
                    shown = shown and ancestor.GroupTransparency < 1
                end
                if ancestor.ClipsDescendants then
                    local p, s = ancestor.AbsolutePosition, ancestor.AbsoluteSize
                    left, top = math.max(left, p.X), math.max(top, p.Y)
                    right, bottom = math.min(right, p.X + s.X), math.min(bottom, p.Y + s.Y)
                    gate.clipPosition, gate.clipSize = { p.X, p.Y }, { s.X, s.Y }
                end
                table.insert(gates, gate)
            end
            ancestor = ancestor.Parent
        end
        result.visibilityGates = gates
        result.effectiveVisible = shown and right > left and bottom > top
        -- This checks ancestry/geometry only, not occlusion, CoreGui, or pixels.
        return result
    end

    local overlay = Instance.new("ScreenGui")
    overlay.Name = "HotbarDiagnostic_" .. prefix
    overlay.ResetOnSpawn = false
    overlay.DisplayOrder = 10000
    local capture = Instance.new("TextButton")
    capture.Name = "Capture"
    capture.Size = UDim2.fromOffset(170, 36)
    capture.Position = UDim2.new(0.5, -172, 0, 4)
    capture.Text = "Hotbar: capture"
    capture.TextSize = 14
    capture.Parent = overlay
    local report = Instance.new("TextButton")
    report.Name = "Report"
    report.Size = UDim2.fromOffset(170, 36)
    report.Position = UDim2.new(0.5, 2, 0, 4)
    report.Text = "Show / hide report"
    report.TextSize = 14
    report.Parent = overlay
    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.new(0, 8, 0, 44)
    scroll.Size = UDim2.new(1, -16, 1, -52)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.fromScale(0, 0)
    scroll.Visible = false
    scroll.Parent = overlay
    local text = Instance.new("TextBox")
    text.Size = UDim2.new(1, -16, 0, 0)
    text.AutomaticSize = Enum.AutomaticSize.Y
    text.TextSize = 14
    text.TextWrapped = true
    text.MultiLine = true
    text.ClearTextOnFocus = false
    text.TextEditable = false
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.Parent = scroll
    overlay.Parent = playerGui

    local function snapshot(reason: string)
        if stopped then
            return
        end
        local camera = workspace.CurrentCamera
        local viewport = if camera then camera.ViewportSize else Vector2.zero
        local ok, value = pcall(function()
            return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
        end)
        record("snapshot", {
            reason = reason,
            capture = captures,
            build = "4a8171a+hotbar-diagnostic-v1",
            placeId = game.PlaceId,
            placeVersion = game.PlaceVersion,
            jobId = game.JobId,
            orientation = tostring(playerGui.CurrentScreenOrientation),
            viewport = { viewport.X, viewport.Y },
            touch = UIS.TouchEnabled,
            backpackReadOK = ok,
            backpackReadResult = tostring(value),
            nativeRendered = "UNKNOWN: compare phone screenshot",
            droppedLogLines = dropped(),
        })
        local liveBars, effectiveBars = 0, 0
        for _, container in { playerGui, StarterGui } do
            for _, object in container:GetDescendants() do
                local name = string.lower(object.Name)
                local role = object:GetAttribute("BlenderUI")
                if
                    not object:IsDescendantOf(overlay)
                    and object ~= overlay
                    and string.sub(object.Name, 1, 17) ~= "HotbarDiagnostic_"
                    and (
                        object:IsA("ScreenGui")
                        or role == "Desktop"
                        or object.Name == "Be a Blender! Desktop"
                        or role == "Hotbar"
                        or (string.find(name, "hotbar", 1, true) ~= nil and object:IsA("GuiObject"))
                    )
                then
                    local details = inspect(object, container)
                    record(if container == playerGui then "liveGui" else "starterTemplate", details)
                    if container == playerGui and (role == "Hotbar" or name == "hotbar") then
                        liveBars += 1
                        if details.effectiveVisible then
                            effectiveBars += 1
                        end
                        for _, child in object:GetDescendants() do
                            if child:IsA("GuiButton") then
                                local button = inspect(child, container)
                                button.active, button.selectable = child.Active, child.Selectable
                                record("barButton", button)
                            end
                        end
                    end
                end
            end
        end
        local scripts = player:FindFirstChild("PlayerScripts")
        if scripts then
            for _, object in scripts:GetDescendants() do
                if object:IsA("LocalScript") or object.Name == "HotbarController" then
                    record("clientScript", { instance = ref(object), class = object.ClassName })
                end
            end
        end
        record("snapshotEnd", {
            reason = reason,
            capture = captures,
            liveBars = liveBars,
            effectiveBars = effectiveBars,
        })
    end
    local function geometryChanged()
        if queued or stopped then
            return
        end
        queued = true
        task.defer(function()
            queued = false
            snapshot("orientation/viewport changed (deferred)")
        end)
    end
    local function cameraChanged()
        if cameraConnection then
            cameraConnection:Disconnect()
        end
        local camera = workspace.CurrentCamera
        cameraConnection = if camera
            then camera:GetPropertyChangedSignal("ViewportSize"):Connect(geometryChanged)
            else nil
        geometryChanged()
    end
    table.insert(
        connections,
        capture.Activated:Connect(function()
            captures += 1
            snapshot("manual")
            capture.Text = "Captured #" .. tostring(captures)
        end)
    )
    table.insert(
        connections,
        report.Activated:Connect(function()
            text.Text = "Backpack API state is NOT rendered visibility. Dropped lines: "
                .. tostring(dropped())
                .. "\n"
                .. log.Value
            scroll.Visible = not scroll.Visible
        end)
    )
    table.insert(connections, playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(geometryChanged))
    table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged))
    record("controllerStart", { controller = ref(controller), playerGui = ref(playerGui), sessionNumber = session })
    snapshot("before controller setup")
    cameraChanged()
    return {
        Record = record,
        Bind = function(bar: Instance)
            record("controllerBar", { instance = ref(bar) })
        end,
        Stop = function()
            record("controllerStop", { controller = ref(controller) })
            stopped = true
            if cameraConnection then
                cameraConnection:Disconnect()
            end
            for _, connection in connections do
                connection:Disconnect()
            end
            overlay:Destroy()
        end,
    }
end
return Diagnostic
