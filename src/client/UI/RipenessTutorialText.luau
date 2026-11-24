--!strict
local Ripeness = require(game:GetService("ReplicatedStorage").Shared.Constants.Ripeness)
local Text = {}

local bonus = ("%g%% more"):format((Ripeness.RipenessValueMultiplier - 1) * 100)
local message = "Leave ingredients in the stash to ripen.\nRipe ingredients are worth %s."

Text.Copy = message:format(bonus)

local function highlight(value: string): string
    return '<font color="#FFDE73"><b>' .. value .. "</b></font>"
end

function Text.Rich(): string
    return message:format(highlight(bonus))
end

return Text
