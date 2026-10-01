--!strict
local MoneyFormat = require(script.Parent.MoneyFormat)
local Format = {}
export type Message = { Text: string, Duration: number, SoundType: string?, Priority: number }

function Format.Escape(value: string): string
    local escaped = value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
    return escaped
end

local function accent(value: string, color: string): string
    return '<font color="' .. color .. '">' .. Format.Escape(value) .. "</font>"
end

function Format.Build(payload: any): Message?
    if typeof(payload) ~= "table" then
        return nil
    end
    local text: string
    local mystery = accent("MYSTERY ITEM", "#E19BFF")
    if
        payload.Type == "RareIngredientSpawned"
        and typeof(payload.DisplayName) == "string"
        and typeof(payload.LocationName) == "string"
    then
        text = "A "
            .. (if payload.Mystery then mystery else accent(string.upper(payload.DisplayName), "#FFDE73"))
            .. " HAS SPAWNED!"
        if payload.LocationName ~= "" then
            text ..= "\n" .. Format.Escape(payload.LocationName)
        end
    elseif payload.Type == "MysteryAcquired" and typeof(payload.DisplayName) == "string" then
        text = accent(payload.DisplayName, "#FFDE73") .. " IS CARRYING A " .. mystery .. "!"
    elseif
        payload.Type == "MysteryServed"
        and typeof(payload.DisplayName) == "string"
        and typeof(payload.Payout) == "number"
        and payload.Payout == payload.Payout
        and math.abs(payload.Payout) < math.huge
    then
        text = accent(payload.DisplayName, "#FFDE73")
            .. " SERVED A "
            .. accent(MoneyFormat.Announcement(payload.Payout), "#73FF8C")
            .. " "
            .. accent("MYSTERY SMOOTHIE", "#E19BFF")
            .. "!"
    elseif payload.Type == "ServerAnnouncement" and typeof(payload.Text) == "string" then
        text = if payload.RichText == true then payload.Text else Format.Escape(payload.Text)
    else
        return nil
    end
    local duration = if typeof(payload.Duration) == "number" and payload.Duration == payload.Duration
        then math.clamp(payload.Duration, 2, 8)
        else 3.5
    local priority = if typeof(payload.Priority) == "number" and payload.Priority == payload.Priority
        then math.clamp(payload.Priority, 0, 100)
        else 0
    return {
        Text = text,
        Duration = duration,
        SoundType = if typeof(payload.SoundType) == "string" then payload.SoundType else nil,
        Priority = priority,
    }
end

-- Stable priority order; the visible announcement always completes its hold.
function Format.Enqueue(queue: { Message }, message: Message)
    for index, pending in queue do
        if message.Priority > pending.Priority then
            table.insert(queue, index, message)
            return
        end
    end
    table.insert(queue, message)
end

return Format
