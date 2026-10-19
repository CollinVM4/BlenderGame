--!strict
local Panel = {}

function Panel.Create(parent: PlayerGui)
    local gui = Instance.new("ScreenGui")
    gui.Name = "FilmCam"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10000
    gui.Enabled = false
    gui:SetAttribute("FilmCamDevUI", true)
    local bars = {}
    for i = 1, 2 do
        local bar = Instance.new("Frame")
        bar.Name = "Letterbox"
        bar.Size = UDim2.fromScale(1, 0.12)
        bar.Position = UDim2.fromScale(0, if i == 1 then 0 else 0.88)
        bar.BackgroundColor3 = Color3.new(0, 0, 0)
        bar.BorderSizePixel = 0
        bar.Visible = false
        bar.Parent = gui
        table.insert(bars, bar)
    end
    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Size = UDim2.fromOffset(340, 424)
    frame.Position = UDim2.new(0, 12, 0.14, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
    frame.Parent = gui
    local function control(class: string, text: string, x: number, y: number, width: number): any
        local object = Instance.new(class) :: any
        object.Size = UDim2.fromOffset(width, 28)
        object.Position = UDim2.fromOffset(x, y)
        object.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
        object.TextColor3 = Color3.new(1, 1, 1)
        object.TextSize = 14
        object.Font = Enum.Font.Code
        object.Text = text
        if object:IsA("TextBox") then
            object.ClearTextOnFocus = false
        end
        object.Parent = frame
        return object
    end
    local title = control("TextLabel", "FilmCam | F6 exit | F7 panel", 8, 6, 324)
    local name = control("TextBox", "", 8, 40, 324) :: TextBox
    name.PlaceholderText = "Take name (automatic if blank)"
    local record = control("TextButton", "Record", 8, 74, 102) :: TextButton
    local stop = control("TextButton", "Stop", 118, 74, 102) :: TextButton
    local play = control("TextButton", "Play", 228, 74, 104) :: TextButton
    local select = control("TextButton", "No takes | click to cycle", 8, 108, 324) :: TextButton
    local speed = control("TextBox", "1", 8, 142, 102) :: TextBox
    local ease = control("TextButton", "Ease: on", 118, 142, 102) :: TextButton
    local copy = control("TextButton", "Copy Take", 228, 142, 104) :: TextButton
    local push = control("TextButton", "Push-in", 8, 176, 102) :: TextButton
    local pull = control("TextButton", "Pull-out", 118, 176, 102) :: TextButton
    local orbit = control("TextButton", "Orbit", 228, 176, 104) :: TextButton
    local letterbox = control("TextButton", "Letterbox: off", 8, 210, 158) :: TextButton
    local hide = control("TextButton", "Hide UI: off", 174, 210, 158) :: TextButton
    local scrub = control("TextButton", "Seek / progress", 8, 244, 324) :: TextButton
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(80, 130, 175)
    fill.BackgroundTransparency = 0.5
    fill.BorderSizePixel = 0
    fill.Parent = scrub
    local status = control("TextLabel", "RMB drag | WASD/QE | speed 0.25-2", 8, 278, 324) :: TextLabel
    status.TextWrapped = true
    status.Size = UDim2.fromOffset(324, 48)
    local export = control("TextBox", "Copy Take puts JSON here; Ctrl+A / Ctrl+C", 8, 332, 324) :: TextBox
    export.Size = UDim2.fromOffset(324, 80)
    export.MultiLine = true
    export.TextWrapped = true
    export.TextSize = 11
    gui.Parent = parent
    return {
        Gui = gui,
        Frame = frame,
        Title = title,
        Name = name,
        Record = record,
        Stop = stop,
        Play = play,
        Select = select,
        Speed = speed,
        Ease = ease,
        Copy = copy,
        Push = push,
        Pull = pull,
        Orbit = orbit,
        Letterbox = letterbox,
        Hide = hide,
        Scrub = scrub,
        Fill = fill,
        Status = status,
        Export = export,
        Bars = bars,
    }
end

return Panel
