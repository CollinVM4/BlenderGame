--!strict
-- Extra checks for known words after Roblox's broadcast filter.
local Sanitizer = {}
local terms = {
    "fuck",
    "fucks",
    "fucked",
    "fucker",
    "fuckers",
    "fucking",
    "shit",
    "shits",
    "shitty",
    "bullshit",
    "bitch",
    "bitches",
    "ass",
    "asshole",
    "assholes",
    "bastard",
    "bastards",
    "cunt",
    "cunts",
    "dick",
    "dicks",
    "cock",
    "cocks",
    "motherfucker",
    "motherfucking",
}
function Sanitizer.ContainsBlockedWord(text: string): boolean
    for _, term in terms do
        -- ASCII token boundaries include digits/underscore/non-ASCII bytes to
        -- avoid masking inside longer names. Only punctuation, never spaces,
        -- may separate letters (f.u.c.k); do not join unrelated words.
        local letters = {}
        for index = 1, #term do
            local letter = string.sub(term, index, index)
            table.insert(letters, "[" .. letter .. string.upper(letter) .. "]")
        end
        local pattern = "%f[%w_\128-\255]" .. table.concat(letters, "[%p]*") .. "%f[^%w_\128-\255]"
        if string.find(text, pattern) then
            return true
        end
    end
    return false
end

return Sanitizer
