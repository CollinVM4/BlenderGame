local tasks = loadModule("TasksService")
local tier, failCredit, reenter = 0, false, nil
local authority = setmetatable({
    GetJumpTier = function()
        return tier
    end,
    CreditTransaction = function(id, amount)
        if reenter then
            local callback = reenter
            reenter = nil
            callback()
        end
        if failCredit then
            error("injected credit failure")
        end
        return sessionTestAuthority.CreditTransaction(id, amount)
    end,
}, { __index = sessionTestAuthority })
tasks.Init({ TycoonService = authority })
local function actor(complete, historical)
    local p = instance("Player")
    p.Name, p.DisplayName, p.UserId = "TaskPlayer", "Task Player", #allInstances
    local setAttribute = p.SetAttribute
    p.SetAttribute = function(self, name, value)
        local old = self:GetAttribute(name)
        setAttribute(self, name, value)
        if old ~= value then
            self:GetAttributeChangedSignal(name):Fire()
        end
    end
    assignTestSession(p)
    p:SetAttribute("TutorialStage", if complete then "Complete" else "ServeCustomer")
    tasks.AddPlayer(p, historical)
    return p
end
local function serve(p, success, freeloader, event)
    local id = authority.BeginTransaction(p, authority.GetRequestContext(p))
    setup(id, "serve transaction")
    local bonus = tasks.RecordServe(p, success ~= false, freeloader == true, id, event or {})
    authority.EndTransaction(id)
    return bonus
end
local p = actor(false)
check(p:GetAttribute("TasksServeReward") == 9000, "first reward locks before tutorial serves")
serve(p, false)
serve(p, true, true)
check(p:GetAttribute("TasksServeTotal") == 0, "failed and Freeloader observations excluded")
serve(p)
serve(p)
local event = {}
check(serve(p, true, false, event) == 9000, "third tutorial serve pays Serve 3")
check(
    p:GetAttribute("TasksServeTotal") == 3 and p:GetAttribute("TasksServeThreshold") == 10,
    "next milestone displays cumulative 3/10"
)
local before = authority.GetCash(p)
check(serve(p, true, false, event) == 0 and authority.GetCash(p) == before, "same customer cannot pay or count twice")
check(p:GetAttribute("TasksTutorialComplete") == false, "background counting independent of tutorial text")
local id = authority.BeginTransaction(p, authority.GetRequestContext(p))
p:SetAttribute("TutorialStage", "Complete")
check(authority.GetCash(p) == before, "tutorial cannot nest into final serve transaction")
authority.EndTransaction(id)
flush()
check(
    authority.GetCash(p) == before + 5000 and p:GetAttribute("TasksTutorialComplete"),
    "observed completion pays separately after transaction"
)
p:SetAttribute("TutorialStage", "Other")
p:SetAttribute("TutorialStage", "Complete")
flush()
check(authority.GetCash(p) == before + 5000, "tutorial reward pays once per session")
tier = 3
check(p:GetAttribute("TasksServeReward") == 21000, "active milestone stays locked after tier change")
for _ = 4, 10 do
    serve(p)
end
check(
    p:GetAttribute("TasksServeThreshold") == 20 and p:GetAttribute("TasksServeReward") == 400000,
    "new tier applies at next activation"
)
tier = 0
for _ = 11, 50 do
    serve(p)
end
check(
    p:GetAttribute("TasksServeThreshold") == 60 and p:GetAttribute("TasksServeTotal") == 50,
    "20/30/40/50 advance cumulatively and indefinitely"
)
check(p:GetAttribute("TasksServeReward") == 400000, "next reward never decreases after tier drop")
local historical = actor(true, 23)
check(
    authority.GetCash(historical) == 0 and historical:GetAttribute("TasksServeThreshold") == 30,
    "historical count reconciles with no cash"
)
check(historical:GetAttribute("TasksTutorialComplete"), "already Complete activation skips tutorial display")
flush()
check(authority.GetCash(historical) == 0, "already Complete has no retroactive tutorial reward")
for _ = 24, 30 do
    serve(historical)
end
check(authority.GetCash(historical) == 30000, "historical reconciliation does not suppress next live crossing")
local retry = actor(true)
serve(retry)
serve(retry)
local retryEvent = {}
failCredit = true
check(
    serve(retry, true, false, retryEvent) == 0 and authority.GetCash(retry) == 0,
    "failed credit cannot consume milestone"
)
failCredit = false
reenter = function()
    check(
        tasks.RecordServe(retry, true, false, authority.GetSessionId(retry), retryEvent) == 0,
        "reentrant crossing rejected"
    )
end
check(serve(retry, true, false, retryEvent) == 9000, "failed crossing can retry once")
check(
    serve(retry, true, false, retryEvent) == 0 and authority.GetCash(retry) == 9000,
    "retried successful crossing cannot pay twice"
)
for _, example in { { 10000, 2500 }, { 1000000, 50000 }, { 10000000, 500000 } } do
    local thief = actor(true)
    authority.SetCash(thief, example[1])
    check(thief:GetAttribute("TasksStealReward") == example[2], "cash changes refresh server estimate")
    for _ = 1, 10 do
        tasks.RecordSteal(thief)
    end
    check(
        authority.GetCash(thief) == example[1] + example[2] and thief:GetAttribute("TasksStealProgress") == 0,
        "steal formula and atomic reset"
    )
    local cash = authority.GetCash(thief)
    for _ = 1, 10 do
        tasks.RecordSteal(thief)
    end
    check(
        authority.GetCash(thief) == cash + math.floor(math.max(2500, 0.05 * cash)),
        "steal immediately repeats using current shared cash"
    )
    check(thief:GetAttribute("TasksServeTotal") == 0, "stealing independent of serving")
end
local thief = actor(true)
for _ = 1, 9 do
    tasks.RecordSteal(thief)
end
failCredit = true
tasks.RecordSteal(thief)
check(
    thief:GetAttribute("TasksStealProgress") == 10 and authority.GetCash(thief) == 0,
    "steal payment failure preserves completion opportunity"
)
failCredit = false
tasks.RecordSteal(thief)
check(
    thief:GetAttribute("TasksStealProgress") == 1 and authority.GetCash(thief) == 2500,
    "next theft settles pending completion and counts the new transfer"
)
local leaving = actor(false)
leaving:SetAttribute("TutorialStage", "Complete")
tasks.RemovePlayer(leaving)
flush()
check(authority.GetCash(leaving) == 0, "leave cancels queued tutorial payment")
leaving:SetAttribute("TutorialStage", "Other")
leaving:SetAttribute("TutorialStage", "Complete")
flush()
check(authority.GetCash(leaving) == 0, "removed player no longer observes transitions")
tasks.AddPlayer(leaving)
check(
    leaving:GetAttribute("TasksServeTotal") == 0 and leaving:GetAttribute("TasksStealProgress") == 0,
    "fresh session starts from zero without saved state"
)

for _, sample in { { 0, 9000 }, { 1, 45000 }, { 2, 90000 }, { 3, 120000 } } do
    tier = sample[1]
    local scaled = actor(true)
    check(scaled:GetAttribute("TasksServeReward") == sample[2], "each configured Jump tier locks its initial reward")
end
tier = 0
local teamOwner, teamThief = actor(true), actor(true)
authority.RemovePlayer(teamThief)
setup(
    authority.JoinSession(teamThief, teamOwner, authority.GetRequestContext(teamOwner)),
    "task actor joins shared pot"
)
authority.SetCash(teamOwner, 1000000)
for _ = 1, 10 do
    tasks.RecordSteal(teamThief)
end
check(
    authority.GetCash(teamOwner) == 1050000 and authority.GetCash(teamThief) == 1050000,
    "steal percentage reads and credits team shared cash"
)
local tutorialRetry = actor(false)
failCredit = true
tutorialRetry:SetAttribute("TutorialStage", "Complete")
flush()
check(authority.GetCash(tutorialRetry) == 0, "failed tutorial credit does not mark transition paid")
failCredit = false
authority.SetCash(tutorialRetry, 100)
flush()
check(authority.GetCash(tutorialRetry) == 5100, "pending tutorial transition retries on cash publication")

loadModule("FilmingUtil").Init()
local rounded = actor(true)
authority.SetCash(rounded, 1000001)
for _ = 1, 10 do
    tasks.RecordSteal(rounded)
end
check(
    authority.GetCash(rounded) == 1050001 and presentation[#presentation].Payload.Payout == 50000,
    "standalone feedback reports whole dollars actually credited by cash authority"
)
