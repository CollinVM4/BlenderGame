--!strict
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local Diagnostics = {}
local count = 0
function Diagnostics.Log(event: string, input: BasePart, object: Instance?, reason: string?, source: string?)
    if
        not RunService:IsStudio()
        or ServerStorage:GetAttribute("DebugMuncherVacuum") ~= true
        or count >= Config.Vacuum.DiagnosticLimit
    then
        return
    end
    count += 1
    local model = input.Parent
    local plot = model and model.Parent
    print(
        string.format(
            "[MuncherVacuum] plot=%s ingredient=%s source=%s event=%s reason=%s",
            if plot then tostring(plot:GetAttribute("PlotSessionId")) else "unknown",
            if object then tostring(object:GetAttribute("IngredientId")) else "none",
            source or "WorldVacuum",
            event,
            reason or "none"
        )
    )
end
return Diagnostics
