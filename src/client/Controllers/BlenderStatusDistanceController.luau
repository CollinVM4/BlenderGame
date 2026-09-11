--!strict
local RunService = game:GetService("RunService")
local Controller = {}
local started = false

type Profile = { BandDistances: { number }, Scales: { number }, FadeDistance: number, HideDistance: number }
local BAND_HYSTERESIS = 1 -- Studs on either side of a boundary before switching.
local PROFILES: { [string]: Profile } = {
    IngredientCountDisplay = {
        BandDistances = { 15, 35 },
        Scales = { 1, 0.72, 0.55 },
        FadeDistance = 50,
        HideDistance = 60,
    },
    TurbineStatusDisplay = {
        BandDistances = { 12, 25 },
        Scales = { 1, 0.70, 0.55 },
        FadeDistance = 30,
        HideDistance = 40,
    },
}
type Display = {
    Gui: BillboardGui,
    Text: TextLabel,
    Scale: UIScale,
    Profile: Profile,
    Band: number?,
    TextTransparency: number,
    StrokeTransparency: number,
}

local function smoothstep(start: number, finish: number, distance: number): number
    local t = math.clamp((distance - start) / (finish - start), 0, 1)
    return t * t * (3 - 2 * t)
end

local function update(display: Display, camera: Camera?)
    local origin = display.Gui.Adornee
    if not camera or not origin or not origin:IsDescendantOf(workspace) then
        display.Text.Visible = false
        return
    end
    local position: Vector3
    if origin:IsA("Attachment") then
        position = origin.WorldPosition
    elseif origin:IsA("BasePart") then
        position = origin.Position
    else
        display.Text.Visible = false
        return
    end
    local distance = (camera.CFrame.Position - position).Magnitude
    local profile = display.Profile
    local band: number = display.Band or 1
    if display.Band == nil then
        -- Initial/streamed-in displays choose directly without traversal history.
        while band <= #profile.BandDistances and distance > profile.BandDistances[band] do
            band += 1
        end
    else
        while band <= #profile.BandDistances and distance > profile.BandDistances[band] + BAND_HYSTERESIS do
            band += 1
        end
        while band > 1 and distance < profile.BandDistances[band - 1] - BAND_HYSTERESIS do
            band -= 1
        end
    end
    if display.Band ~= band then
        display.Band = band
        display.Scale.Scale = profile.Scales[band]
    end
    local fade = smoothstep(profile.FadeDistance, profile.HideDistance, distance)
    display.Text.TextTransparency = display.TextTransparency + (1 - display.TextTransparency) * fade
    display.Text.TextStrokeTransparency = display.StrokeTransparency + (1 - display.StrokeTransparency) * fade
    display.Text.Visible = distance < profile.HideDistance
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local displays: { [TextLabel]: Display } = {}
    local function register(object: Instance)
        if not object:IsA("TextLabel") or object.Name ~= "Status" or displays[object] then
            return
        end
        local gui = object.Parent
        if not gui or not gui:IsA("BillboardGui") then
            return
        end
        local profile = PROFILES[gui.Name]
        if not profile then
            return
        end
        -- One local scale per replicated label; no UI rebuilds or server writes.
        local scale = Instance.new("UIScale")
        scale.Name = "CameraDistanceScale"
        scale.Parent = object
        object.AnchorPoint = Vector2.new(0.5, 0.5)
        object.Position = UDim2.fromScale(0.5, 0.5)
        object.TextScaled = false
        gui.MaxDistance = profile.HideDistance
        local display: Display = {
            Gui = gui,
            Text = object,
            Scale = scale,
            Profile = profile,
            TextTransparency = object.TextTransparency,
            StrokeTransparency = object.TextStrokeTransparency,
        }
        displays[object] = display
        update(display, workspace.CurrentCamera)
    end
    -- Listen before scanning so late replication and streamed-in plots also bind.
    workspace.DescendantAdded:Connect(register)
    workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("TextLabel") then
            local display = displays[object]
            if display then
                displays[object] = nil
                display.Scale:Destroy()
                object.TextTransparency = display.TextTransparency
                object.TextStrokeTransparency = display.StrokeTransparency
                object.Visible = true
            end
        end
    end)
    for _, object in workspace:GetDescendants() do
        register(object)
    end
    RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        for _, display in displays do
            update(display, camera)
        end
    end)
end

return Controller
