local MoneyFormat = require("../src/shared/MoneyFormat")

for _, case in
    {
        { 0, "$0" },
        { 1000, "$1,000" },
        { 125000, "$125,000" },
        { 10000000, "$10,000,000" },
        { 10000000000, "$10,000,000,000" },
        { -125000, "-$125,000" },
    }
do
    assert(MoneyFormat.Full(case[1]) == case[2], "Full cash formatting " .. tostring(case[1]))
end
print("PASS: full cash formatting")
