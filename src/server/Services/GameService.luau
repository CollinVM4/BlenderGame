--!strict
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local GameService = {}
local deps: any
type Session = { State: Types.DayState, Day: number, Grades: { Types.Grade }, Grade: Types.Grade? }
local sessions: { [Player]: Session } = {}
local function publish(player: Player)
    local session = sessions[player]
    player:SetAttribute("DayState", session.State)
    player:SetAttribute("DayNumber", session.Day)
    player:SetAttribute("CustomersServedToday", #session.Grades)
    player:SetAttribute("DayGrade", session.Grade or "")
end
function GameService.Init(services)
    deps = services
end
function GameService.AddPlayer(player: Player)
    sessions[player] = { State = "PREP", Day = 0, Grades = {}, Grade = nil }
    publish(player)
end
function GameService.GetSnapshot(player: Player): Session?
    local session = sessions[player]
    if not session then
        return nil
    end
    return { State = session.State, Day = session.Day, Grades = table.clone(session.Grades), Grade = session.Grade }
end
function GameService.StartDay(player: Player): (boolean, string?)
    local session = sessions[player]
    if not session or session.State == "SERVING" then
        return false, "Day already active"
    end
    deps.TycoonService.AssignPlot(player)
    local button = deps.TycoonService.GetReference(player, "StartDayButton")
        or deps.TycoonService.GetReference(player, "CustomerCounter")
    if not WorldUtil.Near(player, button, Economy.InteractionDistance) then
        return false, "Stand at your counter / Start Day button"
    end
    local ok, reason = deps.CustomerService.CanSpawn(player)
    if not ok then
        return false, reason
    end
    local previous = sessions[player]
    sessions[player] = { State = "SERVING", Day = session.Day + 1, Grades = {}, Grade = nil }
    local customer = deps.CustomerService.SpawnForPlayer(player)
    if not customer then
        sessions[player] = previous
        return false, "Customer spawn failed"
    end
    publish(player)
    return true
end
function GameService.IsServing(player: Player): boolean
    return sessions[player] ~= nil and sessions[player].State == "SERVING"
end
function GameService.FinishDay(player: Player): boolean
    local session = sessions[player]
    if not session or session.State ~= "SERVING" or #session.Grades ~= Economy.CustomersPerDay then
        return false
    end
    local total = 0
    for _, grade in session.Grades do
        total += Economy.GradeScore[grade]
    end
    local mean = total / #session.Grades
    session.Grade = if mean >= 3.5 then "A" elseif mean >= 2.5 then "B" elseif mean >= 1.5 then "C" else "D"
    session.State = "FINISHED"
    publish(player)
    return true
end
-- Called only by the injected customer-served callback, after an authoritative cup transaction.
function GameService.CustomerServed(player: Player, grade: Types.Grade)
    local session = sessions[player]
    if not session or session.State ~= "SERVING" then
        return
    end
    table.insert(session.Grades, grade)
    if #session.Grades == Economy.CustomersPerDay then
        GameService.FinishDay(player)
    else
        publish(player)
        if not deps.CustomerService.SpawnForPlayer(player) then
            warn("[GameService] Next customer unavailable; restore markers and call ResumeDay(player).")
        end
    end
end
function GameService.ResumeDay(player: Player): boolean
    return GameService.IsServing(player) and deps.CustomerService.SpawnForPlayer(player) ~= nil
end
function GameService.Reset(player: Player)
    deps.CustomerService.RemovePlayer(player)
    GameService.AddPlayer(player)
end
function GameService.RemovePlayer(player: Player)
    sessions[player] = nil
end
return GameService
