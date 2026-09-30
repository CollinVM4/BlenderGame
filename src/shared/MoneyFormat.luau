--!strict
local MoneyFormat = {}

-- Display-only rounding to the nearest $500 (halfway values round away from zero).
-- Keep thousands as the unit so half-thousand increments remain visible.
function MoneyFormat.Compact(value: number): string
    local rounded = math.floor(math.abs(value) / 500 + 0.5) * 500
    local thousands = rounded / 1000
    local amount = if rounded % 1000 == 0 then string.format("%.0f", thousands) else string.format("%.1f", thousands)
    return (if value < 0 and rounded > 0 then "-$" else "$") .. amount .. "K"
end

return MoneyFormat
