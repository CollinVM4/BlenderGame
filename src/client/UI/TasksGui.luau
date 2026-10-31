--!strict
local Registry = require(script.Parent.UIRegistry)
local Gui = {}
export type Entry = { Objective: TextLabel, Progress: TextLabel, Reward: TextLabel }
export type View = { Serve: Entry, Steal: Entry }
local function importedChild(parent: Instance?, exported: string, class: string): Instance?
    return Registry.Child(parent, exported, { exported }, class)
end
local function entry(panel: Instance, name: string): Entry?
    local row = importedChild(panel, name, "GuiObject")
    local objective = importedChild(row, "Objective", "TextLabel")
    local progress = importedChild(row, "Progress", "TextLabel")
    local reward = importedChild(row, "Reward", "TextLabel")
    if objective and progress and reward then
        return { Objective = objective :: TextLabel, Progress = progress :: TextLabel, Reward = reward :: TextLabel }
    end
    return nil
end
function Gui.Resolve(playerGui: PlayerGui): View?
    local selected: View? = nil
    for _, desktop in Registry.Desktops(playerGui) do
        if Registry.ActiveRoot(desktop, playerGui) then
            local panel = Registry.Child(Registry.Content(desktop), "Panel:Tasks", { "Tasks" }, "GuiObject")
            if panel then
                local serve, steal = entry(panel, "ServeTask"), entry(panel, "StealTask")
                if serve and steal then
                    if selected then
                        return nil
                    end
                    selected = { Serve = serve, Steal = steal }
                end
            end
        end
    end
    return selected
end
return Gui
