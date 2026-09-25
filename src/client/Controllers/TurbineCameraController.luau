--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Controller = {}
local DURATION = 0.3
local BEFORE_CAMERA = "TurbineCameraPrepare"
local AFTER_CAMERA = "TurbineCameraRender"
local cleanup: (() -> ())? = nil

type View = {
    Camera: Camera,
    Root: BasePart,
    Humanoid: Humanoid,
    Zone: BasePart,
    Target: BasePart,
    Leaving: boolean,
    Elapsed: number,
    From: CFrame,
    FromFocus: CFrame,
    Normal: CFrame,
    NormalFocus: CFrame,
    RootPosition: Vector3,
}

local function inside(zone: BasePart, position: Vector3): boolean
    local point = zone.CFrame:PointToObjectSpace(position)
    local half = zone.Size * 0.5
    return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function Controller.Destroy()
    if cleanup then
        cleanup()
        cleanup = nil
    end
end

function Controller.Init()
    if cleanup then
        return
    end
    local player = Players.LocalPlayer
    local plot: Instance? = nil
    local view: View? = nil
    local removingCharacter: Model? = nil
    local connections: { RBXScriptConnection } = {}
    local plots: { [Instance]: { RBXScriptConnection } } = {}

    local function humanoid(): Humanoid?
        local character = player.Character
        return if character then character:FindFirstChildOfClass("Humanoid") else nil
    end

    local function restore()
        local current = view
        if not current then
            return
        end
        view = nil
        current.Camera.CameraType = Enum.CameraType.Custom
        current.Camera.CameraSubject = humanoid()
        current.Camera.CFrame = current.Normal
        current.Camera.Focus = current.NormalFocus
    end

    local function resolvePlot()
        local assigned: Instance? = nil
        local session = player:GetAttribute("PlotSessionId")
        if type(session) == "string" then
            for candidate in plots do
                if candidate:IsDescendantOf(workspace) and candidate:GetAttribute("PlotSessionId") == session then
                    assigned = candidate
                    break
                end
            end
        end
        if assigned ~= plot then
            restore()
            plot = assigned
        end
    end

    local function track(candidate: Instance)
        if plots[candidate] then
            return
        end
        plots[candidate] = {
            candidate:GetAttributeChangedSignal("PlotSessionId"):Connect(resolvePlot),
            candidate.AncestryChanged:Connect(resolvePlot),
        }
        resolvePlot()
    end

    table.insert(connections, CollectionService:GetInstanceAddedSignal("PlayerPlot"):Connect(track))
    table.insert(
        connections,
        CollectionService:GetInstanceRemovedSignal("PlayerPlot"):Connect(function(candidate)
            local listeners = plots[candidate]
            if listeners then
                for _, connection in listeners do
                    connection:Disconnect()
                end
                plots[candidate] = nil
            end
            resolvePlot()
        end)
    )
    table.insert(
        connections,
        player:GetAttributeChangedSignal("PlotSessionId"):Connect(function()
            restore()
            resolvePlot()
        end)
    )
    table.insert(
        connections,
        player.CharacterRemoving:Connect(function(character)
            removingCharacter = character
            restore()
        end)
    )
    table.insert(
        connections,
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if view then
                restore()
                local camera = workspace.CurrentCamera
                if camera then
                    camera.CameraType = Enum.CameraType.Custom
                    camera.CameraSubject = humanoid()
                end
            end
        end)
    )
    for _, candidate in CollectionService:GetTagged("PlayerPlot") do
        track(candidate)
    end

    -- Before Roblox's camera update, restore its unblended view during the exit.
    -- Otherwise our rendered interpolation would feed back into its next update.
    RunService:BindToRenderStep(BEFORE_CAMERA, Enum.RenderPriority.Camera.Value - 1, function()
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local subject = humanoid()
        local camera = workspace.CurrentCamera
        local assigned = plot
        local blender = if assigned and assigned:IsDescendantOf(workspace)
            then assigned:FindFirstChild("Blender")
            else nil
        -- Only three direct lookups on the cached plot; also handles streamed/replaced parts.
        local zone = if blender then blender:FindFirstChild("TurbineCameraZone") else nil
        local target = if blender then blender:FindFirstChild("TurbineCamera") else nil
        if
            not character
            or character == removingCharacter
            or not character:IsDescendantOf(workspace)
            or not root
            or not root:IsA("BasePart")
            or not subject
            or subject.Health <= 0
            or not camera
            or not camera:IsDescendantOf(workspace)
            or not zone
            or not zone:IsA("BasePart")
            or not target
            or not target:IsA("BasePart")
        then
            restore()
            return
        end

        local current = view
        if
            current
            and (
                current.Camera ~= camera
                or current.Root ~= root
                or current.Humanoid ~= subject
                or current.Zone ~= zone
                or current.Target ~= target
            )
        then
            restore()
            return
        end

        if inside(zone, root.Position) then
            if not current then
                current = {
                    Camera = camera,
                    Root = root,
                    Humanoid = subject,
                    Zone = zone,
                    Target = target,
                    Leaving = false,
                    Elapsed = 0,
                    From = camera.CFrame,
                    FromFocus = camera.Focus,
                    Normal = camera.CFrame,
                    NormalFocus = camera.Focus,
                    RootPosition = root.Position,
                }
                view = current
            elseif current.Leaving then
                current.Leaving = false
                current.Elapsed = 0
                current.From = camera.CFrame
                current.FromFocus = camera.Focus
                current.RootPosition = root.Position
            end
            camera.CameraType = Enum.CameraType.Scriptable
        elseif current and not current.Leaving then
            current.Leaving = true
            current.Elapsed = 0
            current.From = camera.CFrame
            current.FromFocus = camera.Focus
            local displacement = root.Position - current.RootPosition
            current.Normal += displacement
            current.NormalFocus += displacement
            camera.CameraSubject = subject
            camera.CameraType = Enum.CameraType.Custom
        end
        if current and current.Leaving then
            camera.CFrame = current.Normal
            camera.Focus = current.NormalFocus
        end
    end)

    RunService:BindToRenderStep(AFTER_CAMERA, Enum.RenderPriority.Camera.Value + 1, function(dt)
        local current = view
        if not current then
            return
        end
        if workspace.CurrentCamera ~= current.Camera then
            restore()
            return
        end
        current.Elapsed = math.min(current.Elapsed + dt, DURATION)
        local t = current.Elapsed / DURATION
        local alpha = t * t * (3 - 2 * t)
        local camera = current.Camera
        if current.Leaving then
            -- Sample Roblox's live result, including zoom, orbit and collision handling.
            current.Normal = camera.CFrame
            current.NormalFocus = camera.Focus
            camera.CFrame = current.From:Lerp(current.Normal, alpha)
            camera.Focus = current.FromFocus:Lerp(current.NormalFocus, alpha)
            if t == 1 then
                view = nil
            end
        else
            camera.CFrame = current.From:Lerp(current.Target.CFrame, alpha)
            camera.Focus = current.FromFocus:Lerp(CFrame.new(current.Root.Position), alpha)
        end
    end)

    cleanup = function()
        RunService:UnbindFromRenderStep(BEFORE_CAMERA)
        RunService:UnbindFromRenderStep(AFTER_CAMERA)
        for _, connection in connections do
            connection:Disconnect()
        end
        for _, listeners in plots do
            for _, connection in listeners do
                connection:Disconnect()
            end
        end
        restore()
    end
    table.insert(connections, script.Destroying:Connect(Controller.Destroy))
end

return Controller
