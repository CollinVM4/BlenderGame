--!strict
local Text = {}
Text.Copy = "Ingredients can RIPEN while stored.\nRIPE Ingredients are worth +25%"

function Text.Rich(): string
    local message = Text.Copy:gsub("RIPEN", '<font color="#FFDE73">RIPEN</font>')
    message = message:gsub("RIPE Ingredients", '<font color="#FFDE73">RIPE</font> Ingredients')
    message = message:gsub("%+25%%", '<font color="#FFDE73">+25%%</font>')
    return message
end

return Text
