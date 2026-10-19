--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.FilmCam)
local Path = require(Shared.FilmCamPath)
local Controller = {}
local cleanup: (() -> ())? = nil
local playTake: ((Path.Take, number?) -> boolean)? = nil
local stopTake: (() -> ())? = nil

-- Public presentation API remains inert until authorized Init and F6 entry.
function Controller.Play(take: Path.Take, speed: number?): boolean
    return if playTake then playTake(take, speed) else false
end

function Controller.Stop()
    if stopTake then
        stopTake()
    end
end

function Controller.Destroy()
    if cleanup then
        cleanup()
        cleanup = nil
    end
end

function Controller.Init()
    -- Hard boundary: no UI, listeners, camera access, input binding, or controller
    -- loading beyond this point for an ordinary live player.
    local player = Players.LocalPlayer
    if cleanup or not Path.Allowed(RunService:IsStudio(), player.UserId, Config.AllowedUserIds) then
        return
    end
    local Takes = require(script.Parent.Parent.UI.FilmCamTakes)
    local Panel = require(script.Parent.Parent.UI.FilmCamPanel)
    local Turbine = require(script.Parent.TurbineCameraController)
    local Stand = require(script.Parent.StandIdentityController)
    local gui = player:WaitForChild("PlayerGui") :: PlayerGui
    local ui = Panel.Create(gui)
    local connections: { RBXScriptConnection } = {}
    local takes: { Path.Take } = {}
    local selected = 0
    local active, recording, playing, easing = false, false, false, true
    local hidden, boxed, dragging = false, false, false
    local camera: Camera? = nil
    local original: any = nil
    local beforePlayback: any = nil
    local turbineSuspended, standSuspended = false, false
    local hiddenGuis: { [LayerCollector]: boolean } = {}
    local hiddenConnections: { [LayerCollector]: RBXScriptConnection } = {}
    local keys: { Path.Key } = {}
    local lastSample: Path.Key? = nil
    local recordTime, sampleTime, playTime, speed = 0, 0, 0, 1
    local track: Path.Track? = nil
    local yaw, pitch = 0, 0
    local mouseBehavior = Input.MouseBehavior
    local mouseIcon = Input.MouseIconEnabled
    local serial = 0

    local function syncPanelToggle()
        local inBar = boxed and not ui.Frame.Visible
        ui.HidePanel.Text = if ui.Frame.Visible then "Hide" else "Show"
        ui.HidePanel.AnchorPoint = if inBar then Vector2.new(0.5, 0.5) else Vector2.new(1, 0)
        ui.HidePanel.Position = if inBar then UDim2.fromScale(0.5, 0.06) else UDim2.new(1, -12, 0, 12)
    end
    local function togglePanel()
        ui.Frame.Visible = not ui.Frame.Visible
        syncPanelToggle()
    end

    local function connect(signal: RBXScriptSignal, fn: any)
        table.insert(connections, signal:Connect(fn))
    end
    local function snapshot(cam: Camera): any
        return {
            Type = cam.CameraType,
            Subject = cam.CameraSubject,
            Frame = cam.CFrame,
            Focus = cam.Focus,
            Fov = cam.FieldOfView,
        }
    end
    local function restore(cam: Camera, state: any)
        cam.CameraSubject = state.Subject
        cam.CFrame, cam.Focus, cam.FieldOfView = state.Frame, state.Focus, state.Fov
        cam.CameraType = state.Type
    end
    local function syncAngles()
        if camera then
            pitch, yaw = camera.CFrame:ToOrientation()
        end
    end
    local function releaseMouse()
        if not dragging then
            return
        end
        dragging = false
        Input.MouseBehavior, Input.MouseIconEnabled = mouseBehavior, mouseIcon
    end
    local function hideGui(child: Instance)
        if not child:IsA("LayerCollector") or child == ui.Gui or child:GetAttribute(Config.DevUIAttribute) then
            return
        end
        if hiddenGuis[child] ~= nil then
            return
        end
        hiddenGuis[child] = child.Enabled
        child.Enabled = false
        hiddenConnections[child] = child:GetPropertyChangedSignal("Enabled"):Connect(function()
            if hidden and child.Enabled then
                child.Enabled = false
            end
        end)
    end
    local function setHidden(value: boolean)
        hidden = value
        if value then
            for _, child in gui:GetDescendants() do
                hideGui(child)
            end
        else
            for child, enabled in hiddenGuis do
                hiddenConnections[child]:Disconnect()
                if child.Parent then
                    child.Enabled = enabled
                end
            end
            table.clear(hiddenGuis)
            table.clear(hiddenConnections)
        end
        ui.Hide.Text = if value then "Hide UI: on" else "Hide UI: off"
    end
    local function choose(index: number)
        selected = index
        local take = takes[index]
        ui.Select.Text = if take
            then string.format("%d/%d %s (%.1fs)", index, #takes, take.Name, take.Duration)
            else "No takes"
    end
    local function save(take: Path.Take)
        table.insert(takes, take)
        choose(#takes)
    end
    for _, json in require(Shared.Constants.FilmTakes) do
        local take, message = Takes.Decode(json)
        if take then
            save(take)
        else
            warn("[FilmCam] Skipped checked-in take: " .. message)
        end
    end
    local function stopPlayback()
        if not playing then
            return
        end
        playing = false
        if camera and beforePlayback then
            restore(camera, beforePlayback)
        end
        beforePlayback = nil
        syncAngles()
    end
    local function stopRecording()
        if not recording then
            return
        end
        recording = false
        local cam = camera
        if not cam then
            return
        end
        local duration = math.min(recordTime, Config.MaxDuration)
        if duration <= 0 then
            return
        end
        -- Endpoint is mandatory even for a held camera: preserve pauses and duration.
        local endpoint = Takes.Capture(duration, cam.CFrame, cam.FieldOfView)
        if keys[#keys].Time == duration then
            keys[#keys] = endpoint
        else
            table.insert(keys, endpoint)
        end
        serial += 1
        local name = string.sub(ui.Name.Text, 1, 100)
        save({ Version = 1, Name = if name == "" then "Take_" .. serial else name, Duration = duration, Keys = keys })
        ui.Status.Text = if duration >= Config.MaxDuration then "5 minute cap reached; take saved" else "Take saved"
    end
    local function stop()
        stopRecording()
        stopPlayback()
    end
    local function exit()
        if not active then
            return
        end
        stop()
        active = false
        releaseMouse()
        CAS:UnbindAction("FilmCamFly")
        RunService:UnbindFromRenderStep("FilmCamRender")
        setHidden(false)
        boxed = false
        for _, bar in ui.Bars do
            bar.Visible = false
        end
        ui.Letterbox.Text = "Letterbox: off"
        syncPanelToggle()
        if camera and original then
            restore(camera, original)
        end
        camera, original = nil, nil
        Turbine.SetSuspended(turbineSuspended)
        Stand.SetSuspended(standSuspended)
        ui.Gui.Enabled = false
    end
    local function drawPlayback()
        local cam, compiled = camera, track
        if not cam or not compiled then
            return
        end
        local time = Path.EasedTime(playTime, compiled.Duration / speed, easing) * speed
        local x, y, z, qx, qy, qz, qw, fov = Path.Evaluate(compiled, time)
        cam.CFrame = CFrame.new(x, y, z, qx, qy, qz, qw)
        cam.Focus = cam.CFrame * CFrame.new(0, 0, -20)
        cam.FieldOfView = fov
        ui.Fill.Size = UDim2.fromScale(math.clamp(playTime * speed / compiled.Duration, 0, 1), 1)
    end
    local function render(dt: number)
        local cam = camera
        if not cam then
            return
        end
        if workspace.CurrentCamera ~= cam then
            exit()
            return
        end
        cam.CameraType = Enum.CameraType.Scriptable
        if playing and track then
            playTime = math.min(playTime + dt, track.Duration / speed)
            drawPlayback()
            if playTime >= track.Duration / speed then
                stopPlayback()
            end
            return
        end
        if not Input:GetFocusedTextBox() then
            local x, y, z = 0, 0, 0
            if Input:IsKeyDown(Enum.KeyCode.A) then
                x -= 1
            end
            if Input:IsKeyDown(Enum.KeyCode.D) then
                x += 1
            end
            if Input:IsKeyDown(Enum.KeyCode.Q) then
                y -= 1
            end
            if Input:IsKeyDown(Enum.KeyCode.E) then
                y += 1
            end
            if Input:IsKeyDown(Enum.KeyCode.W) then
                z -= 1
            end
            if Input:IsKeyDown(Enum.KeyCode.S) then
                z += 1
            end
            local motion = Vector3.new(x, y, z)
            if motion.Magnitude > 0 then
                motion = motion.Unit * Config.FlySpeed * dt
            end
            cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.fromOrientation(pitch, yaw, 0) * CFrame.new(motion)
            cam.Focus = cam.CFrame * CFrame.new(0, 0, -20)
        end
        if recording then
            recordTime = math.min(recordTime + dt, Config.MaxDuration)
            sampleTime += dt
            if sampleTime >= Config.SampleInterval then
                sampleTime %= Config.SampleInterval
                local key = Takes.Capture(recordTime, cam.CFrame, cam.FieldOfView)
                if Path.ShouldSample(keys[#keys], key, Config.PositionThreshold, Config.RotationThreshold) then
                    -- Keep just the end of a stationary hold before movement resumes.
                    -- Skipped samples still do not accumulate a key every 0.1 seconds.
                    if
                        lastSample
                        and lastSample.Time > keys[#keys].Time
                        and not Path.ShouldSample(keys[#keys], lastSample, 0.000001, 0.000001)
                    then
                        table.insert(keys, lastSample)
                    end
                    table.insert(keys, key)
                end
                lastSample = key
            end
            ui.Status.Text = string.format("Recording %.1fs / 300s | %d keys", recordTime, #keys)
            if recordTime >= Config.MaxDuration then
                stopRecording()
            end
        end
    end
    local function enter()
        local cam = workspace.CurrentCamera
        if not cam then
            return
        end
        if cam:GetAttribute("StandNameEditorActive") then
            warn("[FilmCam] Finish or close the stand-name editor before filming")
            return
        end
        camera, original = cam, snapshot(cam)
        turbineSuspended = Turbine.SetSuspended(true)
        standSuspended = Stand.SetSuspended(true)
        active = true
        cam.CameraType = Enum.CameraType.Scriptable
        syncAngles()
        ui.Frame.Visible = true
        syncPanelToggle()
        ui.Gui.Enabled = true
        CAS:BindActionAtPriority(
            "FilmCamFly",
            function()
                return if playing or Input:GetFocusedTextBox()
                    then Enum.ContextActionResult.Pass
                    else Enum.ContextActionResult.Sink
            end,
            false,
            Enum.ContextActionPriority.High.Value + 100,
            Enum.KeyCode.W,
            Enum.KeyCode.A,
            Enum.KeyCode.S,
            Enum.KeyCode.D,
            Enum.KeyCode.Q,
            Enum.KeyCode.E
        )
        RunService:BindToRenderStep("FilmCamRender", Enum.RenderPriority.Camera.Value + 10, render)
    end
    playTake = function(take: Path.Take, requestedSpeed: number?): boolean
        if not active or not camera or not Path.Validate(take) then
            return false
        end
        stop()
        local requested = requestedSpeed or 1
        if requested ~= requested then
            requested = 1
        end
        speed = math.clamp(requested, 0.25, 2)
        ui.Speed.Text = tostring(speed)
        track = Path.Compile(take)
        beforePlayback = snapshot(camera)
        playTime, playing = 0, true
        releaseMouse()
        drawPlayback()
        ui.Status.Text = "Playing | perform live | Stop to restore framing"
        return true
    end
    stopTake = stop
    local function play()
        -- Stop may finish a recording and select the new take.
        stop()
        local take = takes[selected]
        if take then
            Controller.Play(take, tonumber(ui.Speed.Text) or 1)
        end
    end
    connect(ui.Record.Activated, function()
        if not active or not camera then
            return
        end
        stop()
        keys = { Takes.Capture(0, camera.CFrame, camera.FieldOfView) }
        lastSample = nil
        recordTime, sampleTime, recording = 0, 0, true
    end)
    connect(ui.Stop.Activated, stop)
    connect(ui.Play.Activated, play)
    connect(ui.Select.Activated, function()
        if #takes > 0 then
            choose(selected % #takes + 1)
        end
    end)
    connect(ui.Ease.Activated, function()
        easing = not easing
        ui.Ease.Text = if easing then "Ease: on" else "Ease: off"
    end)
    connect(ui.Copy.Activated, function()
        local take = takes[selected]
        if take then
            ui.Export.Text = Takes.Encode(take)
            ui.Export:CaptureFocus()
            ui.Export.SelectionStart = 1
            ui.Export.CursorPosition = #ui.Export.Text + 1
        end
    end)
    local function preset(kind: string)
        if not active or not camera then
            return
        end
        stop()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
        local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000, params)
        save(Takes.Preset(kind, camera.CFrame, camera.FieldOfView, if hit then hit.Position else nil))
        play()
    end
    connect(ui.Push.Activated, function()
        preset("Push-in")
    end)
    connect(ui.Pull.Activated, function()
        preset("Pull-out")
    end)
    connect(ui.Orbit.Activated, function()
        preset("Orbit")
    end)
    connect(ui.Letterbox.Activated, function()
        boxed = not boxed
        for _, bar in ui.Bars do
            bar.Visible = boxed
        end
        ui.Letterbox.Text = if boxed then "Letterbox: on" else "Letterbox: off"
        syncPanelToggle()
    end)
    connect(ui.Hide.Activated, function()
        setHidden(not hidden)
    end)
    connect(ui.HidePanel.MouseButton1Click, togglePanel)
    connect(ui.Scrub.InputBegan, function(input: InputObject)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not active then
            return
        end
        if not playing then
            play()
        end
        if track and playing then
            playTime = math.clamp((input.Position.X - ui.Scrub.AbsolutePosition.X) / ui.Scrub.AbsoluteSize.X, 0, 1)
                * track.Duration
                / speed
            drawPlayback()
        end
    end)
    connect(gui.DescendantAdded, function(child: Instance)
        if hidden then
            hideGui(child)
        end
    end)
    connect(Input.InputBegan, function(input: InputObject, processed: boolean)
        if input.KeyCode == Config.ToggleKey and not processed and not Input:GetFocusedTextBox() then
            if active then
                exit()
            else
                enter()
            end
        elseif active and input.KeyCode == Config.PanelKey and not processed then
            togglePanel()
        elseif
            active
            and not playing
            and not processed
            and not Input:GetFocusedTextBox()
            and input.UserInputType == Enum.UserInputType.MouseButton2
        then
            mouseBehavior, mouseIcon = Input.MouseBehavior, Input.MouseIconEnabled
            dragging = true
            Input.MouseBehavior, Input.MouseIconEnabled = Enum.MouseBehavior.LockCurrentPosition, false
        end
    end)
    connect(Input.InputChanged, function(input: InputObject)
        if active and not playing and dragging and camera and input.UserInputType == Enum.UserInputType.MouseWheel then
            camera.FieldOfView = math.clamp(camera.FieldOfView - input.Position.Z * 2, 1, 120)
        end
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            yaw -= input.Delta.X * Config.MouseSensitivity
            pitch = math.clamp(pitch - input.Delta.Y * Config.MouseSensitivity, -math.pi / 2 + 0.01, math.pi / 2 - 0.01)
        end
    end)
    connect(Input.InputEnded, function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            releaseMouse()
        end
    end)
    connect(Input.WindowFocusReleased, releaseMouse)
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"), exit)
    connect(script.Destroying, Controller.Destroy)
    connect(ui.Gui.Destroying, exit)
    cleanup = function()
        exit()
        for _, connection in connections do
            connection:Disconnect()
        end
        ui.Gui:Destroy()
        playTake, stopTake = nil, nil
    end
end

return Controller
