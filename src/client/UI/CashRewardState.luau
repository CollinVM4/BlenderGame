--!strict
local State = {}

-- Each consumed smoothie has a server-generated GUID. Remember it for the
-- client session, including skipped effects and respawns, so replay never animates.
function State.New(): (any, any, any, number) -> boolean
    local seen: { [string]: boolean } = {}
    return function(moment: any, owner: any, payload: any, localUserId: number): boolean
        if moment ~= "CustomerReaction" or owner ~= localUserId or type(payload) ~= "table" then
            return false
        end
        local id, payout = payload.BlendId, payload.Payout
        if
            type(id) ~= "string"
            or id == ""
            or type(payout) ~= "number"
            or payout ~= payout
            or payout <= 0
            or payout == math.huge
            or seen[id]
        then
            return false
        end
        seen[id] = true
        return true
    end
end

return State
