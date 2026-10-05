--!strict
-- Conservative presentation mask; Roblox TextService remains the moderation authority.
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
-- Match inflections before their shorter roots, including separated spellings.
table.sort(terms, function(a, b)
    return #a > #b
end)

function Sanitizer.Mask(text: string): string
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
        text = string.gsub(text, pattern, "****")
    end
    return text
end

function Sanitizer.BroadcastDisplay(text: string): string
    return (string.gsub(text, "#+", "****"))
end

return Sanitizer
