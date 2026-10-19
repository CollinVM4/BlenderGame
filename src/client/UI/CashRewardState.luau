--!strict
local State = {}

-- Each consumed smoothie has a server-generated GUID. Remember it for the
-- client session, including skipped effects and respawns, so replay never animates.
function State.New(): (any, any, any, number) -> (boolean, string)
    local seen: { [string]: boolean } = {}
    return function(moment: any, owner: any, payload: any, localUserId: number): (boolean, string)
        if moment ~= "CustomerReaction" then
            return false, "wrong moment"
        elseif owner ~= localUserId then
            return false, "owner mismatch"
        elseif type(payload) ~= "table" then
            return false, "bad payload"
        end
        local id, payout = payload.BlendId, payload.Payout
        if type(id) ~= "string" or id == "" then
            return false, "bad BlendId"
        end
        if type(payout) ~= "number" or payout ~= payout or payout <= 0 or payout == math.huge then
            return false, "bad payout"
        end
        if seen[id] then
            return false, "duplicate"
        end
        seen[id] = true
        return true, "accepted"
    end
end

return State
