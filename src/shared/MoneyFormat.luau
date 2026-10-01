--!strict
local MoneyFormat = {}

-- Announcement precision is independent of the established world-label rounding.
function MoneyFormat.Announcement(value: number): string
    local magnitude = math.abs(value)
    local divisor = if magnitude >= 1e6 then 1e6 elseif magnitude >= 1e3 then 1e3 else 1
    local suffix = if divisor == 1e6 then "M" elseif divisor == 1e3 then "K" else ""
    local amount = string.format("%.2f", magnitude / divisor):gsub("0+$", ""):gsub("%.$", "")
    return (if value < 0 then "-$" else "$") .. amount .. suffix
end

-- Display-only rounding to the nearest $500 (halfway values round away from zero).
function MoneyFormat.Compact(value: number): string
    local rounded = math.floor(math.abs(value) / 500 + 0.5) * 500
    if rounded == 0 then
        return "$0K"
    end
    return MoneyFormat.Announcement(if value < 0 then -rounded else rounded)
end

return MoneyFormat
