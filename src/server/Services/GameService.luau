--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local GameService = {}
local deps: any
type Session = { State: Types.DayState, Day: number, Grades: { Types.Grade }, Grade: Types.Grade?, Served: number }
local sessions: { [Player]: Session } = {}
local function publish(player: Player)
    local session = sessions[player]
    player:SetAttribute("DayState", session.State)
    player:SetAttribute("DayNumber", session.Day)
    player:SetAttribute("CustomersServedToday", session.Served)
    player:SetAttribute("DayGrade", session.Grade or "")
end
function GameService.Init(services)
    deps = services
end
function GameService.AddPlayer(player: Player)
    sessions[player] = { State = "PREP", Day = 0, Grades = {}, Grade = nil, Served = 0 }
    publish(player)
end
function GameService.GetSnapshot(player: Player): Session?
    local session = sessions[player]
    if not session then
        return nil
    end
    return {
        State = session.State,
        Day = session.Day,
        Grades = table.clone(session.Grades),
        Grade = session.Grade,
        Served = session.Served,
    }
end
-- Legacy remote/Studio entry point. Idempotently activates flow; never spawns a day batch.
function GameService.StartDay(player: Player): (boolean, string?)
    deps.TycoonService.AssignPlot(player)
    local ok = deps.CustomerService.ActivateForPlayer(player)
    return ok, if ok then nil else "No active plot"
end
function GameService.IsServing(player: Player): boolean
    return player:GetAttribute("CustomerFlowState") == "PLOT_ACTIVE"
end
-- Retained for callers compiled against the old API. Endless flow has no day completion.
function GameService.FinishDay(_player: Player): boolean
    return false
end
function GameService.CustomerServed(player: Player, grade: Types.Grade)
    local session = sessions[player]
    if not session then
        return
    end
    session.State = "SERVING"
    session.Served += 1
    session.Grade = grade
    session.Grades = { grade } -- Bounded legacy summary; lifetime stats belong to PlayerDataService.
    publish(player)
end
function GameService.ResumeDay(player: Player): boolean
    return deps.CustomerService.ActivateForPlayer(player)
end
function GameService.Reset(player: Player)
    deps.CustomerService.DeactivateForPlayer(player)
    GameService.AddPlayer(player)
end
function GameService.RemovePlayer(player: Player)
    sessions[player] = nil
end
return require(script.Parent.StudioServices).Wrap("GameService", GameService)
