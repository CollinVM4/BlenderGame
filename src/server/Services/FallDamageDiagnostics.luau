--!strict
-- Server-only, explicitly enabled per character. No remotes or gameplay writes.
local Diagnostics = {}
export type Trace = {
    Emit: (Trace, string, { [string]: any }?) -> (),
    SampleDue: (Trace, number) -> boolean,
    Stop: (Trace) -> (),
    Active: (Trace) -> boolean,
}

function Diagnostics.new(
    player: Player,
    snapshot: () -> { [string]: any },
    seconds: number?,
    maxRecords: number?
): Trace
    local duration = math.clamp(seconds or 30, 1, 60)
    local limit = math.floor(math.clamp(maxRecords or 240, 1, 600))
    local deadline = os.clock() + duration
    local elapsed, nextSample, records = 0, 0, 0
    local stopped = false
    local trace = {} :: Trace
    function trace:Active(): boolean
        return not stopped and records < limit and elapsed < duration and os.clock() < deadline
    end
    function trace:Stop()
        stopped = true
    end
    function trace:Emit(event, fields)
        if not self:Active() then
            return
        end
        records += 1
        local values = snapshot()
        if fields then
            for key, value in fields do
                values[key] = value
            end
        end
        values.event, values.player, values.userId = event, player.Name, player.UserId
        values.t, values.record = elapsed, records
        values.lastRecord = records == limit
        local keys = {}
        for key in values do
            table.insert(keys, key)
        end
        table.sort(keys)
        local parts = {}
        for _, key in keys do
            table.insert(parts, key .. "=" .. tostring(values[key]))
        end
        warn("[FallDamageDiagnostic] " .. table.concat(parts, " "))
    end
    function trace:SampleDue(dt): boolean
        elapsed += dt
        if not self:Active() or elapsed < nextSample then
            return false
        end
        nextSample = elapsed + 0.1
        return true
    end
    return trace
end

return Diagnostics
