--!strict
local MoneyFormat = require(script.Parent.MoneyFormat)
local Format = {}
export type Message = {
    Text: string,
    Duration: number,
    SoundType: string?,
    Priority: number,
    Immediate: boolean,
    CountdownEndsAt: number?,
}

function Format.Escape(value: string): string
    local escaped = value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
    return escaped
end

local function accent(value: string, color: string): string
    return '<font color="' .. color .. '">' .. Format.Escape(value) .. "</font>"
end

function Format.CleanupCountdownText(seconds: number): string
    local remaining = math.max(1, math.ceil(seconds))
    return accent("LOOSE INGREDIENTS", "#FF6666")
        .. " CLEAR IN "
        .. accent(tostring(remaining) .. (if remaining == 1 then " SECOND" else " SECONDS"), "#FF6666")
        .. "!"
end

-- A server deadline keeps countdowns aligned despite network/queue delays.
function Format.VisibleText(message: Message, serverTime: number): string?
    if message.CountdownEndsAt then
        local remaining = message.CountdownEndsAt - serverTime
        return if remaining > 0 then Format.CleanupCountdownText(remaining) else nil
    end
    return message.Text
end

function Format.Build(payload: any): Message?
    if typeof(payload) ~= "table" then
        return nil
    end
    local text: string
    local countdownEndsAt: number? = nil
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
    elseif
        payload.Type == "IngredientCleanupCountdown"
        and typeof(payload.EndsAt) == "number"
        and payload.EndsAt == payload.EndsAt
        and math.abs(payload.EndsAt) < math.huge
    then
        countdownEndsAt = payload.EndsAt
        text = Format.CleanupCountdownText(5)
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
        Immediate = countdownEndsAt ~= nil or (payload.Type == "ServerAnnouncement" and payload.Immediate == true),
        CountdownEndsAt = countdownEndsAt,
    }
end

-- Time-sensitive server notices lead the queue; ordinary priorities remain stable.
function Format.Enqueue(queue: { Message }, message: Message)
    for index, pending in queue do
        if
            (message.Immediate and not pending.Immediate)
            or (message.Immediate == pending.Immediate and message.Priority > pending.Priority)
        then
            table.insert(queue, index, message)
            return
        end
    end
    table.insert(queue, message)
end

function Format.ShouldInterrupt(queue: { Message }): boolean
    return queue[1] ~= nil and queue[1].Immediate
end

return Format
