--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.LuckyBlockConfig)
local Presentation = require(game:GetService("ReplicatedStorage").Shared.Constants.LuckyBlockPresentation)
local Messages = {}
export type Entry = { Id: string, Text: string }
function Messages.Read(read: (string) -> any, now: number): { Entry }
    local entries: { Entry } = {}
    for _, reward in Config.Rewards do
        local timed = reward.DurationSeconds ~= nil
        local attribute = if timed
            then "LuckyBuff" .. reward.Id .. "ExpiresAt"
            else "LuckyInstant" .. reward.Id .. "Until"
        local expiry = read(attribute)
        if typeof(expiry) == "number" and expiry == expiry and expiry < math.huge then
            local seconds = math.ceil(math.max(0, expiry - now))
            if seconds > 0 then
                local name = string.upper(Presentation.Rewards[reward.Id].Name)
                table.insert(
                    entries,
                    { Id = reward.Id, Text = if timed then name .. " ? " .. seconds .. "s" else name .. " COLLECTED" }
                )
            end
        end
    end
    return entries
end
-- CoreUISafeInsets coordinates. Below the 104px tutorial/announcement banner,
-- central 36% away from thumbstick/CAS edges, above the hotbar/control region.
function Messages.Layout(width: number, height: number, count: number): (number, number, number, number)
    local top = math.ceil(height * 0.065 + 116)
    local bottom = height * (if height > width then 0.55 else 0.72)
    local row = math.min(26, math.max(1, (bottom - top) / math.max(1, count)))
    return width / 2, top, math.min(280, width * 0.36), row
end
return Messages
