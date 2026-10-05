--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Constants.StandIdentity)
local Editor = require(script.Parent.Parent.UI.StandNameEditor)
local TurbineCamera = require(script.Parent.TurbineCameraController)
local Controller = {}
local player = Players.LocalPlayer
type Sequence = {
    Plot: Instance,
    Marker: BasePart,
    Character: Model,
    Camera: Camera,
    Context: any,
    CameraType: Enum.CameraType,
    Subject: (Humanoid | BasePart)?,
    From: CFrame,
    RootPosition: Vector3,
    Tween: Tween?,
    Closing: boolean,
    Saving: boolean,
}
local current: Sequence? = nil
local ui: { Gui: ScreenGui, Box: TextBox, Status: TextLabel, Save: TextButton }
local remote: RemoteFunction
local initialized = false
local version = 0

local function humanoid(): Humanoid?
    return if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
end

local function restore(sequence: Sequence)
    if sequence.Tween then
        sequence.Tween:Cancel()
    end
    sequence.Camera:SetAttribute("StandNameEditorActive", nil)
    local subject = humanoid()
    sequence.Camera.CameraSubject = subject or sequence.Subject
    -- Never restore a borrowed Scriptable camera after this editor owns it.
    sequence.Camera.CameraType = if sequence.CameraType == Enum.CameraType.Scriptable
        then Enum.CameraType.Custom
        else sequence.CameraType
end

function Controller.Close(immediate: boolean?)
    version += 1
    local token = version
    local sequence = current
    if not sequence then
        return
    end
    local wasClosing = sequence.Closing
    sequence.Closing = true
    ui.Gui.Enabled = false
    ui.Box:ReleaseFocus()
    if sequence.Tween then
        sequence.Tween:Cancel()
    end
    if immediate or wasClosing then
        current = nil
        restore(sequence)
        return
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local offset = if root and root:IsA("BasePart") then root.Position - sequence.RootPosition else Vector3.zero
    local tween = TweenService:Create(
        sequence.Camera,
        TweenInfo.new(Config.CameraOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = sequence.From + offset }
    )
    sequence.Tween = tween
    tween:Play()
    task.spawn(function()
        tween.Completed:Wait()
        if token ~= version or current ~= sequence then
            return
        end
        current = nil
        restore(sequence)
    end)
end

local function valid(sequence: Sequence): boolean
    local subject = humanoid()
    return type(sequence.Context.PlotSessionId) == "string"
        and type(sequence.Context.MembershipRevision) == "number"
        and type(sequence.Context.StandNameRevision) == "number"
        and player.Parent ~= nil
        and player.Character == sequence.Character
        and sequence.Character:IsDescendantOf(workspace)
        and subject ~= nil
        and subject.Health > 0
        and workspace.CurrentCamera == sequence.Camera
        and sequence.Plot:IsDescendantOf(workspace)
        and sequence.Marker.Parent == sequence.Plot
        and sequence.Plot:FindFirstChild("SignCamera") == sequence.Marker
        and sequence.Plot:GetAttribute("OwnerUserId") == player.UserId
        and sequence.Plot:GetAttribute("PlotSessionId") == sequence.Context.PlotSessionId
        and player:GetAttribute("PlotSessionId") == sequence.Context.PlotSessionId
        and sequence.Plot:GetAttribute("PlotMembershipRevision") == sequence.Context.MembershipRevision
end

-- TODO(Settings): Reuse OpenNameEditor from Settings > Stand so the owner
-- can rename the stand after the initial claim sequence.
function Controller.OpenNameEditor(plot: Instance)
    Controller.Close(true)
    if not initialized then
        return
    end
    TurbineCamera.ReleaseCamera()
    local marker = plot:FindFirstChild("SignCamera")
    local camera, character = workspace.CurrentCamera, player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if
        not camera
        or not character
        or not root
        or not root:IsA("BasePart")
        or not marker
        or not marker:IsA("BasePart")
    then
        return
    end
    local sequence: Sequence = {
        Plot = plot,
        Marker = marker,
        Camera = camera,
        Character = character,
        Context = {
            PlotSessionId = plot:GetAttribute("PlotSessionId"),
            MembershipRevision = plot:GetAttribute("PlotMembershipRevision"),
            StandNameRevision = plot:GetAttribute("StandNameRevision"),
        },
        CameraType = camera.CameraType,
        Subject = camera.CameraSubject,
        From = camera.CFrame,
        RootPosition = root.Position,
        Closing = false,
        Saving = false,
    }
    if not valid(sequence) then
        return
    end
    current = sequence
    local token = version
    camera:SetAttribute("StandNameEditorActive", true)
    camera.CameraType = Enum.CameraType.Scriptable
    local tween = TweenService:Create(
        camera,
        TweenInfo.new(Config.CameraInSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        { CFrame = marker.CFrame }
    )
    sequence.Tween = tween
    tween:Play()
    task.spawn(function()
        tween.Completed:Wait()
        if token ~= version or current ~= sequence then
            return
        end
        if not valid(sequence) then
            Controller.Close(true)
            return
        end
        ui.Box.Text = tostring(plot:GetAttribute("StandName") or "")
        ui.Status.Text, ui.Save.Text = "", "SAVE"
        ui.Gui.Enabled = true
        ui.Box:CaptureFocus()
    end)
end

function Controller.Init()
    if initialized then
        return
    end
    initialized = true
    remote = ReplicatedStorage.Shared.Events:WaitForChild("SetStandName") :: RemoteFunction
    ui = Editor.Create(player:WaitForChild("PlayerGui"), function()
        local sequence = current
        if not sequence or sequence.Closing or sequence.Saving or not ui.Gui.Enabled then
            return
        end
        local raw = ui.Box.Text
        local text = Config.Normalize(raw)
        if not text then
            ui.Status.Text = string.format("Enter a name of 1–%d characters.", Config.MaxCharacters)
            return
        end
        sequence.Saving = true
        ui.Save.Text = "SAVING…"
        task.spawn(function()
            local ok, success, message = pcall(function()
                return remote:InvokeServer(sequence.Plot, raw, sequence.Context)
            end)
            if current ~= sequence or sequence.Closing then
                return
            end
            sequence.Saving = false
            ui.Save.Text = "SAVE"
            if ok and success then
                if type(message) == "string" then
                    ui.Box.Text = message
                end
                Controller.Close()
            else
                ui.Status.Text = if ok and type(message) == "string" then message else "Could not save. Try again."
            end
        end)
    end, function()
        Controller.Close()
    end)
    UserInputService.InputBegan:Connect(function(input)
        if ui.Gui.Enabled and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
            Controller.Close()
        end
    end)
    local function cancel()
        Controller.Close(true)
    end
    player.CharacterRemoving:Connect(cancel)
    player.CharacterAdded:Connect(cancel)
    player.AncestryChanged:Connect(function()
        if player.Parent == nil then
            cancel()
        end
    end)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cancel)
    ui.Gui.AncestryChanged:Connect(function()
        if not ui.Gui:IsDescendantOf(player) then
            cancel()
        end
    end)
    ui.Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if current and not current.Closing and not ui.Gui.Enabled then
            Controller.Close()
        end
    end)
    RunService.Heartbeat:Connect(function()
        if current and not valid(current) then
            cancel()
        end
    end)
    local claimed = ReplicatedStorage.Shared.Events:WaitForChild("PlotClaimed") :: RemoteEvent
    claimed.OnClientEvent:Connect(function(plot: Instance, id: string, revision: number)
        Controller.Close(true)
        local token = version
        -- Remote events and replicated attributes can arrive on different frames.
        task.spawn(function()
            local deadline = os.clock() + 3
            repeat
                if token ~= version or not plot:IsDescendantOf(workspace) then
                    return
                end
                if
                    plot:GetAttribute("PlotSessionId") == id
                    and player:GetAttribute("PlotSessionId") == id
                    and plot:GetAttribute("PlotMembershipRevision") == revision
                then
                    Controller.OpenNameEditor(plot)
                    return
                end
                RunService.Heartbeat:Wait()
            until os.clock() >= deadline
        end)
    end)
end

return Controller
