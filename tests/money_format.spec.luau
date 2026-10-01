local MoneyFormat = require("../src/shared/MoneyFormat")

for _, case in
    {
        { 500, "$0.5K" },
        { 1000, "$1K" },
        { 1500, "$1.5K" },
        { 3000, "$3K" },
        { 6500, "$6.5K" },
        { 12000, "$12K" },
        { 0, "$0K" },
        { 249, "$0K" },
        { 250, "$0.5K" },
        { 749, "$0.5K" },
        { 750, "$1K" },
        { 1249.99, "$1K" },
        { 1250, "$1.5K" },
        { 100000, "$100K" },
        { 165000, "$165K" },
        { 1000000, "$1M" },
        { 1200000, "$1.2M" },
        { -249, "$0K" },
        { -250, "-$0.5K" },
        { -1500, "-$1.5K" },
    }
do
    assert(MoneyFormat.Compact(case[1]) == case[2], "Unexpected formatting for " .. tostring(case[1]))
end
print("PASS: compact money examples, rounding boundaries, zero, large values, and negatives")
