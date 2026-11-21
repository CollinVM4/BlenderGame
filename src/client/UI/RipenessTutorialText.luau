--!strict
local Ripeness = require(game:GetService("ReplicatedStorage").Shared.Constants.Ripeness)
local Text = {}

local seconds = Ripeness.RipenessSeconds
local duration = if seconds == 60
    then "1 minute"
    elseif seconds % 60 == 0 then ("%g minutes"):format(seconds / 60)
    else ("%g seconds"):format(seconds)
local bonus = ("%g%% more"):format((Ripeness.RipenessValueMultiplier - 1) * 100)
local message = "Leave ingredients in the stash to ripen.\nRipe ingredients are worth 25% more."

Text.Copy = message:format(duration, bonus)

local function highlight(value: string): string
    return '<font color="#FFDE73"><b>' .. value .. "</b></font>"
end

function Text.Rich(): string
    return message:format(highlight(duration), highlight(bonus))
end

return Text
