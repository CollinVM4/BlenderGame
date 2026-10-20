--!strict
-- Eligibility uses the same UpgradeDisplay.Row prices as the panel.
local State = {}
function State.new()
    return {
        Refresh = function(eligible: { [string]: number }, _open: boolean, blocked: boolean): boolean
            return next(eligible) ~= nil and not blocked
        end,
        Reset = function() end,
    }
end
return State
