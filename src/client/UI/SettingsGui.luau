--!strict
-- Imported artwork only. Panel visibility remains owned by FramewispMenus.
local Registry = require(script.Parent.UIRegistry)
local Input = game:GetService("UserInputService")
local Gui = {}
export type View = {
    Root: ScreenGui,
    Panel: GuiObject,
    Modes: { [string]: GuiButton },
    MusicOn: GuiButton?,
    MusicOff: GuiButton?,
    Status: TextLabel?,
    Rename: GuiButton?,
    Kick: GuiButton?,
    Track: GuiObject?,
    Thumb: GuiObject?,
    Fill: GuiObject?,
    Outer: GuiObject?,
    Dragging: boolean,
    Issues: { string },
}

function Gui.Resolve(playerGui: PlayerGui): View?
    local selected: Instance? = nil
    local root: ScreenGui? = nil
    for _, desktop in Registry.Desktops(playerGui) do
        local candidate = Registry.ActiveRoot(desktop, playerGui)
        if candidate then
            if selected then
                return nil
            end
            selected, root = desktop, candidate
        end
    end
    if not selected or not root then
        return nil
    end
    local panel =
        Registry.Child(Registry.Content(selected), "Panel:Settings", { "Settings", "Settings_panel" }, "GuiObject")
    if not panel then
        return nil
    end
    local issues: { string } = {}
    local function child(parent: Instance?, role: string, names: { string }, class: string): Instance?
        local result = Registry.Child(parent, role, names, class)
        if not result then
            table.insert(issues, role)
        end
        return result
    end
    local plot = child(panel, "PLOT", { "PLOT" }, "GuiObject")
    local music = child(panel, "MUSIC", { "MUSIC" }, "GuiObject")
    local modes: { [string]: GuiButton } = {}
    local names: { [string]: { string } } = {
        FriendsOnly = { "Friends", "Friends_button_smooth" },
        Open = { "Open", "Open_button_smooth", "All", "All_button_smooth" },
        Closed = { "Closed", "Closed_button_smooth" },
    }
    for mode, fallbacks in names do
        local row = child(plot, mode, fallbacks, "GuiButton")
        if row then
            modes[mode] = row :: GuiButton
        end
    end
    local track = child(music, "Slider", { "Slider" }, "GuiObject")
    local thumb = child(track, "Knob", { "Knob" }, "GuiObject")
    local fill = child(track, "ProgressBar", { "ProgressBar" }, "GuiObject")
    return {
        Root = root,
        Panel = panel :: GuiObject,
        Modes = modes,
        MusicOn = child(music, "MusicOn", { "MusicOn", "MusicOn_button_smooth" }, "GuiButton") :: GuiButton?,
        MusicOff = child(music, "MusicOff", { "MusicOff", "MusicOff_button_smooth" }, "GuiButton") :: GuiButton?,
        Status = child(plot, "Title", { "Title" }, "TextLabel") :: TextLabel?,
        Rename = child(plot, "Rename", { "Rename", "Rename_button_smooth" }, "GuiButton") :: GuiButton?,
        Kick = child(plot, "Kick", { "Kick", "Kick_button_smooth" }, "GuiButton") :: GuiButton?,
        Track = track :: GuiObject?,
        Thumb = thumb :: GuiObject?,
        Fill = fill :: GuiObject?,
        Outer = Registry.Child(track, "OuterSlider", { "OuterSlider" }, "GuiObject") :: GuiObject?,
        Dragging = false,
        Issues = issues,
    }
end

local function bounds(view: View): GuiObject?
    local track = view.Track
    if track and track.AbsoluteSize.X > 0 then
        return track
    end
    local outer = view.Outer
    return if outer and outer.AbsoluteSize.X > 0 then outer else nil
end

local function renderVolume(view: View, value: number)
    local track, thumb, fill = view.Track, view.Thumb, view.Fill
    if not track or not thumb or not fill then
        return
    end
    local range = bounds(view)
    local offset = if range and range ~= track then range.AbsolutePosition.X - track.AbsolutePosition.X else 0
    local widthOffset = if range and range ~= track then value * range.AbsoluteSize.X else 0
    local position, size, fillPosition = thumb.Position, fill.Size, fill.Position
    thumb.Position = UDim2.new(value, offset + widthOffset, position.Y.Scale, position.Y.Offset)
    fill.Size = UDim2.new(value, widthOffset, size.Y.Scale, size.Y.Offset)
    -- The export centers ProgressBar's anchor. Keep its left edge at the
    -- track's left while changing width, without altering its anchor or Y.
    fill.Position = UDim2.new(
        value * fill.AnchorPoint.X,
        offset + widthOffset * fill.AnchorPoint.X,
        fillPosition.Y.Scale,
        fillPosition.Y.Offset
    )
end

function Gui.RefreshVolume(view: View, value: number)
    if not view.Dragging then
        renderVolume(view, value)
    end
end

function Gui.Select(button: GuiButton, selected: boolean)
    local scale = Registry.Child(button, "SelectionScale", { "SelectionScale" }, "UIScale") :: UIScale?
    if scale then
        scale.Scale = if selected then 1.1 else 1
    end
    local background = Registry.Child(button, "BuyBackground", { "BuyBackground" }, "GuiObject") :: GuiObject?
    if background then
        background.BackgroundColor3 = if selected then Color3.fromRGB(45, 159, 123) else Color3.fromRGB(43, 56, 70)
        local stroke = Registry.Child(background, "UIStroke", { "UIStroke" }, "UIStroke") :: UIStroke?
        if stroke then
            stroke.Color = if selected then Color3.fromRGB(255, 222, 115) else Color3.fromRGB(18, 22, 30)
            stroke.Thickness = if selected then 3.5 else 2
        end
    end
end

function Gui.Observe(
    playerGui: PlayerGui,
    changed: (View?) -> (),
    mode: (string) -> (),
    enabled: (boolean) -> (),
    volume: (number) -> number,
    rename: (() -> ())?,
    kick: (() -> ())?
): () -> ()
    local connections: { RBXScriptConnection } = {}
    local lifetime: { RBXScriptConnection } = {}
    local restoreInput: (() -> ())? = nil
    local stopped, queued = false, false
    local lastIssue = ""
    local view: View? = nil
    local schedule: () -> ()
    local function clear()
        if restoreInput then
            restoreInput()
            restoreInput = nil
        end
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
    end
    local function scan()
        queued = false
        if stopped then
            return
        end
        local current = Gui.Resolve(playerGui)
        local issue = if current
            then table.concat(current.Issues, ", ")
            else "Settings panel missing or desktop ambiguous"
        if issue ~= "" and issue ~= lastIssue then
            warn("SettingsGui: missing, wrong-class or ambiguous binding: " .. issue)
        end
        lastIssue = issue
        local previous = view
        if
            current
            and previous
            and current.Root == previous.Root
            and current.Panel == previous.Panel
            and current.MusicOn == previous.MusicOn
            and current.MusicOff == previous.MusicOff
            and current.Status == previous.Status
            and current.Rename == previous.Rename
            and current.Kick == previous.Kick
            and current.Track == previous.Track
            and current.Thumb == previous.Thumb
            and current.Fill == previous.Fill
            and current.Outer == previous.Outer
        then
            local same = true
            for _, modeName in { "Open", "FriendsOnly", "Closed" } do
                if current.Modes[modeName] ~= previous.Modes[modeName] then
                    same = false
                end
            end
            if same then
                return
            end
        end
        clear()
        view = current
        -- Root visibility changes can select a different imported desktop.
        for _, desktop in Registry.Desktops(playerGui) do
            local ancestor: Instance? = desktop
            while ancestor and ancestor ~= playerGui do
                if ancestor:IsA("GuiObject") or ancestor:IsA("ScreenGui") then
                    table.insert(
                        connections,
                        ancestor
                            :GetPropertyChangedSignal(if ancestor:IsA("ScreenGui") then "Enabled" else "Visible")
                            :Connect(schedule)
                    )
                end
                ancestor = ancestor.Parent
            end
        end
        if current then
            for value, button in current.Modes do
                table.insert(
                    connections,
                    button.Activated:Connect(function()
                        if current.Panel.Visible and button.Active then
                            mode(value)
                        end
                    end)
                )
            end
            local function bindAction(button: GuiButton?, callback: (() -> ())?)
                if button and callback then
                    table.insert(
                        connections,
                        button.Activated:Connect(function()
                            if current.Panel.Visible and button.Visible and button.Active then
                                callback()
                            end
                        end)
                    )
                end
            end
            bindAction(current.Rename, rename)
            bindAction(current.Kick, kick)
            local function bindMusic(button: GuiButton?, value: boolean)
                if button then
                    table.insert(
                        connections,
                        button.Activated:Connect(function()
                            enabled(value)
                        end)
                    )
                end
            end
            bindMusic(current.MusicOn, true)
            bindMusic(current.MusicOff, false)
            local track = current.Track
            if track and current.Thumb and current.Fill then
                local drag: InputObject? = nil
                local oldActive = track.Active
                track.Active = current.Panel.Visible or oldActive
                restoreInput = function()
                    current.Dragging = false
                    track.Active = oldActive
                end
                local function update(input: InputObject)
                    local range = bounds(current)
                    if range then
                        local value = volume(
                            math.clamp((input.Position.X - range.AbsolutePosition.X) / range.AbsoluteSize.X, 0, 1)
                        )
                        renderVolume(current, value)
                    end
                end
                local function begin(input: InputObject)
                    if
                        current.Panel.Visible
                        and bounds(current) ~= nil
                        and drag ~= input
                        and (
                            input.UserInputType == Enum.UserInputType.Touch
                            or input.UserInputType == Enum.UserInputType.MouseButton1
                        )
                    then
                        drag = input
                        current.Dragging = true
                        update(input)
                    end
                end
                table.insert(connections, track.InputBegan:Connect(begin))
                for _, surface in track:GetChildren() do
                    if surface:IsA("GuiObject") then
                        table.insert(connections, surface.InputBegan:Connect(begin))
                    end
                end
                table.insert(
                    connections,
                    Input.InputChanged:Connect(function(input: InputObject)
                        local held = drag
                        if
                            held
                            and current.Panel.Visible
                            and (
                                input == held
                                or (
                                    held.UserInputType == Enum.UserInputType.MouseButton1
                                    and input.UserInputType == Enum.UserInputType.MouseMovement
                                )
                            )
                        then
                            update(input)
                        end
                    end)
                )
                table.insert(
                    connections,
                    Input.InputEnded:Connect(function(input: InputObject)
                        local held = drag
                        if
                            input == held
                            or (
                                held
                                and held.UserInputType == Enum.UserInputType.MouseButton1
                                and input.UserInputType == Enum.UserInputType.MouseButton1
                            )
                        then
                            drag = nil
                            current.Dragging = false
                            changed(current)
                        end
                    end)
                )
                -- A layout pass can replace the fallback bounds after opening.
                local layoutSurfaces: { GuiObject } = { track }
                if current.Outer then
                    table.insert(layoutSurfaces, current.Outer)
                end
                for _, surface in layoutSurfaces do
                    for _, property in { "AbsolutePosition", "AbsoluteSize" } do
                        table.insert(
                            connections,
                            surface:GetPropertyChangedSignal(property):Connect(function()
                                changed(current)
                            end)
                        )
                    end
                end
                -- Active is input presentation only; no instances are created.
                table.insert(
                    connections,
                    current.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
                        drag = nil
                        current.Dragging = false
                        track.Active = if current.Panel.Visible then true else oldActive
                    end)
                )
            end
            table.insert(
                connections,
                current.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
                    changed(current)
                end)
            )
        end
        changed(current)
    end
    schedule = function()
        if stopped or queued then
            return
        end
        queued = true
        task.defer(scan)
    end
    table.insert(lifetime, playerGui.DescendantAdded:Connect(schedule))
    table.insert(
        lifetime,
        playerGui.DescendantRemoving:Connect(function(instance)
            local current = view
            if current then
                local affected = instance == current.Root
                    or instance == current.Panel
                    or current.Panel:IsDescendantOf(instance)
                local bindings: { Instance } = {}
                for _, button in current.Modes do
                    table.insert(bindings, button)
                end
                local optionalBindings: { Instance? } = {
                    current.MusicOn,
                    current.MusicOff,
                    current.Status,
                    current.Track,
                    current.Thumb,
                    current.Fill,
                    current.Outer,
                    current.Rename,
                    current.Kick,
                }
                for _, bound in optionalBindings do
                    if bound then
                        table.insert(bindings, bound)
                    end
                end
                for _, bound in bindings do
                    if bound == instance or bound:IsDescendantOf(instance) then
                        affected = true
                    end
                end
                if affected then
                    clear()
                    view = nil
                    changed(nil)
                end
            end
            schedule()
        end)
    )
    scan()
    return function()
        stopped = true
        clear()
        for _, connection in lifetime do
            connection:Disconnect()
        end
        changed(nil)
    end
end

return Gui
