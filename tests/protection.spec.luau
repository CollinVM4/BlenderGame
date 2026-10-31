-- The shared Instance double stores attributes without firing their signals.
local function publishStage(p, stage)
    p:SetAttribute("TutorialStage", stage)
    p:GetAttributeChangedSignal("TutorialStage"):Fire()
end
local protection = loadModule("ProtectionService")
local function active(stage)
    local p = instance("Player")
    p.Parent = services.Players
    publishStage(p, stage or "ClaimPlot")
    return p
end
local complete = active("Complete")
services.Players.GetPlayers = function()
    return { complete }
end
protection.Init()
check(not protection.IsProtected(complete), "initially complete existing player is immediately unprotected")
publishStage(complete, "ClaimPlot")
check(not protection.IsProtected(complete), "completion is permanent")
local unknown = active()
check(not protection.IsProtected(unknown), "query never creates unknown player state")
protection.Forfeit(unknown)
protection.AddPlayer(unknown)
check(protection.IsProtected(unknown), "unknown forfeiture does not create a poisoned session")
local start = now
now = start + 0.75
local midTick = active()
protection.AddPlayer(midTick)
now = start + 127.25
services.RunService.Heartbeat:Fire(127.25)
now = start + 479
services.RunService.Heartbeat:Fire(351.75)
check(protection.IsProtected(unknown), "479 elapsed idle seconds remain protected")
now = start + 480
check(not protection.IsProtected(unknown), "gate settles 480 boundary without waiting for heartbeat")
check(protection.IsProtected(midTick), "mid-tick join is not charged before joining")
now += 0.75
check(not protection.IsProtected(midTick), "irregular ticks and exact personal cap")
publishStage(unknown, "ClaimPlot")
protection.AddPlayer(unknown)
check(not protection.IsProtected(unknown), "reinitialization and stage changes cannot reset timeout")
local observed = active()
protection.AddPlayer(observed)
now += 120
publishStage(observed, "Complete")
check(not protection.IsProtected(observed), "observed completion ends protection immediately between ticks")
publishStage(observed, "ClaimPlot")
now += 500
check(not protection.IsProtected(observed), "elapsed time and stage regression never undo completion")
local forfeited = active()
protection.AddPlayer(forfeited)
now += 20
protection.Forfeit(forfeited)
protection.Forfeit(forfeited)
forfeited.Character = instance("Model")
forfeited.Character = nil
forfeited.Character = instance("Model")
publishStage(forfeited, "Complete")
publishStage(forfeited, "ClaimPlot")
check(not protection.IsProtected(forfeited), "idempotent forfeiture survives respawn and stage changes")
local respawn = active()
protection.AddPlayer(respawn)
now += 300
respawn.Character = instance("Model")
protection.AddPlayer(respawn)
now += 180
check(not protection.IsProtected(respawn), "respawn does not reset the clock")
protection.RemovePlayer(forfeited)
publishStage(forfeited, "Complete")
protection.AddPlayer(forfeited)
check(not protection.IsProtected(forfeited), "complete rejoin has no protection")
protection.RemovePlayer(forfeited)
publishStage(forfeited, "ClaimPlot")
protection.AddPlayer(forfeited)
check(protection.IsProtected(forfeited), "incomplete rejoin gets fresh bookkeeping")
protection.RemovePlayer(forfeited)
publishStage(forfeited, "Complete")
services.RunService.Heartbeat:Fire(1)
check(not protection.IsProtected(forfeited), "removed state stays absent after callbacks and ticks")
local departed = active()
protection.AddPlayer(departed)
departed.Parent = nil
check(not protection.IsProtected(departed), "non-present player cannot receive protection")
-- State is deliberately private. Silence is also checked against the feature diff.
check(forfeited:GetAttribute("ProtectionForfeited") == nil, "protection bookkeeping is not replicated")
print("PASS: protection session lifecycle")
