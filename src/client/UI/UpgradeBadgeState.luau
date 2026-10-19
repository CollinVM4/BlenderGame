--!strict
-- Eligible keys come from UpgradeDisplay.Row, never from a second pricing model.
local State = {}
function State.new()
    local acknowledged: { [string]: number } = {}
    return {
        Refresh = function(eligible: { [string]: number }, open: boolean, blocked: boolean): boolean
            for id, level in acknowledged do
                if eligible[id] ~= level then
                    acknowledged[id] = nil
                end
            end
            local unseen = false
            for id, level in eligible do
                if open then
                    acknowledged[id] = level
                elseif acknowledged[id] ~= level then
                    unseen = true
                end
            end
            return unseen and not open and not blocked
        end,
        Reset = function()
            table.clear(acknowledged)
        end,
    }
end
return State
