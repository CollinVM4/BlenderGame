-- CLI Luau lacks Roblox's grapheme iterator. Model only the Unicode sequences
-- in these naming vectors; real UAX segmentation remains a Studio smoke check.
env.utf8.graphemes = function(text)
    local spans = {}
    local joinNext, regional = false, false
    for first, code in utf8.codes(text) do
        local finish = (utf8.offset(text, 2, first) or (#text + 1)) - 1
        local mark = (code >= 0x300 and code <= 0x36F) or code == 0xFE0F or (code >= 0x1F3FB and code <= 0x1F3FF)
        local flag = code >= 0x1F1E6 and code <= 0x1F1FF
        if #spans > 0 and (mark or joinNext or code == 0x200D or (flag and regional)) then
            spans[#spans][2] = finish
        else
            table.insert(spans, { first, finish })
        end
        joinNext = code == 0x200D
        regional = flag and not regional
    end
    local index = 0
    return function()
        index += 1
        local span = spans[index]
        if span then
            return span[1], span[2]
        end
        return nil
    end
end
