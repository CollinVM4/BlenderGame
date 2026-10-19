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
    Track: GuiObject?,
    Thumb: GuiObject?,
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
    local names: { [string]: string } = { FriendsOnly = "Friends", Open = "All", Closed = "Closed" }
    for mode, name in names do
        local row = child(plot, name, { name, name .. "_button_smooth" }, "GuiButton")
        if row then
            modes[mode] = row :: GuiButton
        end
    end
    -- No slider exists in the checked-in export. Bind only an explicit semantic
    -- contract until the new export can be inspected; never guess from decoration.
    local track = child(music, "Music:VolumeTrack", {}, "GuiObject")
    local thumb = child(track, "Music:VolumeThumb", {}, "GuiObject")
    return {
        Root = root,
        Panel = panel :: GuiObject,
        Modes = modes,
        MusicOn = child(music, "MusicOn", { "MusicOn", "MusicOn_button_smooth" }, "GuiButton") :: GuiButton?,
        MusicOff = child(music, "MusicOff", { "MusicOff", "MusicOff_button_smooth" }, "GuiButton") :: GuiButton?,
        Status = child(plot, "Title", { "Title" }, "TextLabel") :: TextLabel?,
        Track = track :: GuiObject?,
        Thumb = thumb :: GuiObject?,
        Issues = issues,
    }
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
    volume: (number) -> ()
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
            and current.Track == previous.Track
            and current.Thumb == previous.Thumb
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
                        if current.Panel.Visible then
                            mode(value)
                        end
                    end)
                )
            end
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
            table.insert(
                connections,
                current.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
                    changed(current)
                end)
            )
            local track = current.Track
            if track and current.Thumb then
                local drag: InputObject? = nil
                local oldActive = track.Active
                track.Active = true
                restoreInput = function()
                    track.Active = oldActive
                end
                local function update(input: InputObject)
                    if track.AbsoluteSize.X > 0 then
                        volume(math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
                    end
                end
                local function begin(input: InputObject)
                    if
                        current.Panel.Visible
                        and (
                            input.UserInputType == Enum.UserInputType.Touch
                            or input.UserInputType == Enum.UserInputType.MouseButton1
                        )
                    then
                        drag = input
                        update(input)
                    end
                end
                table.insert(connections, track.InputBegan:Connect(begin))
                table.insert(connections, current.Thumb.InputBegan:Connect(begin))
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
                        if input == drag then
                            drag = nil
                        end
                    end)
                )
                -- Active is input presentation only; no instances are created.
                table.insert(
                    connections,
                    current.Panel:GetPropertyChangedSignal("Visible"):Connect(function()
                        drag = nil
                        track.Active = if current.Panel.Visible then true else oldActive
                    end)
                )
            end
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
                local optionalBindings: { Instance? } =
                    { current.MusicOn, current.MusicOff, current.Status, current.Track, current.Thumb }
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
