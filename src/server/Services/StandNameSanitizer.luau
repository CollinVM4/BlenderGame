--!strict
-- Extra checks for known words after Roblox's broadcast filter.
local Sanitizer = {}

-- Match explicit profanity even when it is part of a compound.
local compoundTerms = {
    "fuck",
    "asshole",
    "asshat",
    "asswipe",
    "bitchass",
    "bitchface",
    "bullshit",
    "cocksucker",
    "dickface",
    "dickhead",
    "dipshit",
    "dumbass",
    "shitface",
    "shithead",
    "shitshow",
    "shitty",
    "sonofabitch",
}

-- Short terms can also occur inside ordinary names such as Scunthorpe.
local wholeTerms = {
    "shit",
    "shits",
    "bitch",
    "bitches",
    "ass",
    "bastard",
    "bastards",
    "cunt",
    "cunts",
    "dick",
    "dicks",
    "cock",
    "cocks",
}

local function termPattern(term: string): string
    return table.concat(string.split(term, ""), "[%p]*")
end

local patterns: { string } = {}
for _, term in compoundTerms do
    table.insert(patterns, termPattern(term))
end
for _, term in wholeTerms do
    table.insert(patterns, "%f[%w_\128-\255]" .. termPattern(term) .. "%f[^%w_\128-\255]")
end

function Sanitizer.ContainsBlockedWord(text: string): boolean
    local lower = string.lower(text)
    for _, pattern in patterns do
        if string.find(lower, pattern) then
            return true
        end
    end
    return false
end

return Sanitizer
