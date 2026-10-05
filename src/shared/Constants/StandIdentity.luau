--!strict
local Config = {
    MaxCharacters = 27,
    -- Resource ceiling, separate from visible length: combined graphemes can be many bytes.
    MaxInputBytes = 4096,
    ZoneInterval = 0.15,
    SaveCooldown = 1,
    CameraInSeconds = 0.48,
    CameraOutSeconds = 0.35,
}

function Config.Count(value: string): number?
    if not utf8.len(value) then
        return nil
    end
    local count = 0
    for _first, _last in utf8.graphemes(value) do
        count += 1
    end
    return count
end

-- Truncate editor input or trusted display transformations only. Normalize
-- rejects oversized raw submissions before the server uses this helper.
function Config.Truncate(value: string, maximum: number?): string
    if not utf8.len(value) then
        return ""
    end
    local count, last = 0, 0
    for _first, finish in utf8.graphemes(value) do
        count += 1
        if count > (maximum or Config.MaxCharacters) then
            return string.sub(value, 1, last)
        end
        last = finish
    end
    return value
end

function Config.DefaultName(displayName: string): string
    local suffix = "'s Stand"
    return Config.Truncate(displayName, Config.MaxCharacters - (Config.Count(suffix) or 0)) .. suffix
end

function Config.Normalize(value: any): string?
    if type(value) ~= "string" or #value > Config.MaxInputBytes or not utf8.len(value) then
        return nil
    end
    -- Preserve accents/emoji; Roblox has no general NFC normalizer. Canonicalize
    -- Unicode horizontal spaces and reject controls, line breaks and bidi overrides.
    for _, code in utf8.codes(value) do
        if
            code < 32
            or (code >= 127 and code <= 159)
            or code == 0x2028
            or code == 0x2029
            or (code >= 0x202A and code <= 0x202E)
            or (code >= 0x2066 and code <= 0x2069)
        then
            return nil
        end
    end
    local text = value
    for _, code in
        {
            0xA0,
            0x1680,
            0x2000,
            0x2001,
            0x2002,
            0x2003,
            0x2004,
            0x2005,
            0x2006,
            0x2007,
            0x2008,
            0x2009,
            0x200A,
            0x202F,
            0x205F,
            0x3000,
        }
    do
        text = string.gsub(text, utf8.char(code), " ")
    end
    text = string.match(text, "^ *(.-) *$") or ""
    local length = Config.Count(text)
    if not length or length == 0 or length > Config.MaxCharacters then
        return nil
    end
    return text
end

return Config
