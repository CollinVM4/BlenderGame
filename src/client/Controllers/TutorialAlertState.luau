--!strict
-- Session-only presentation state; replicated attributes remain authoritative.
local Upgrades: { [string]: { { Cost: number, Value: number } } } =
    require(game:GetService("ReplicatedStorage").Shared.Constants.Upgrades)
local State = {}
State.Beats = {
    { Id = "Jump1", TrackId = "Jump", ArrowName = "Jump1Alert_pulse" },
    { Id = "Bat1", TrackId = "Bat", ArrowName = "BatAlert_pulse" },
}
export type Inputs = {
    TutorialActive: boolean,
    Stage: string?,
    Cash: number,
    Levels: { [string]: number },
    PanelOpen: boolean,
}
export type Output = { MenuVisible: boolean, PanelArrow: string? }

function State.new()
    local latched: { [string]: boolean } = {}
    local cleared: { [string]: boolean } = {}
    local finished = false
    return {
        Evaluate = function(inputs: Inputs): Output
            if inputs.Stage == "Complete" then
                finished = true
            end
            for _, beat in State.Beats do
                if (inputs.Levels[beat.TrackId] or 0) >= 1 then
                    cleared[beat.Id] = true
                end
                if inputs.Cash >= Upgrades[beat.TrackId][2].Cost then
                    latched[beat.Id] = true
                end
            end
            if inputs.TutorialActive == true and not finished then
                for _, beat in State.Beats do
                    if latched[beat.Id] and not cleared[beat.Id] then
                        return {
                            MenuVisible = not inputs.PanelOpen,
                            PanelArrow = if inputs.PanelOpen then beat.ArrowName else nil,
                        }
                    end
                end
            end
            return { MenuVisible = false, PanelArrow = nil }
        end,
    }
end

return State
