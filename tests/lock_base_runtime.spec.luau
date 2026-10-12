-- Real lock service AND presentation at the same boundary: no presentation stub.
local security = loadModule("LockBaseService")
local tycoon = dependency.TycoonService
local owner = player()
prepareCharacter(owner)
local plot = tycoon.GetPlot(owner)
tycoon.RemovePlayer(owner)
local button, wall, visual, attachment, laser = securityAssets(plot)
local authored = visual:GetPivot()
button.CanCollide, button.CanQuery, button.CanTouch = false, false, false
local assembly = plot:FindFirstChild("LockBase"):FindFirstChild("LockButton")
services.CollectionService:AddTag(assembly, "PlayerOnlyCollision")
loadModule("PlayerOnlyCollisionService").Init()
security.Init(dependency)
tycoon.Init({
    SessionStarted = security.StartSession,
    MemberChanged = security.RefreshMembership,
    MemberRemoved = security.RefreshMembership,
    SessionEnded = security.CleanupSession,
})
check(workspaceFake:GetAttribute("LockBaseInitialized") == true, "bootstrap initialization is observable")
check(
    laser.Transparency == 1 and visual:GetPivot().Position.Y < authored.Position.Y and not wall.CanCollide,
    "unclaimed initialization hides authored raised lasers and disables walls"
)
local gui = attachment:FindFirstChild("LockBaseDisplay")
local label = gui:FindFirstChildOfClass("TextLabel")
check(
    attachment.Parent == button and button:IsA("BasePart") and gui.Adornee == attachment and not gui.Enabled,
    "exact nested attachment has valid host and no unclaimed countdown"
)
check(button.CanCollide and button.CanQuery and button.CanTouch, "binding repairs activation surface physics")
check(
    assembly.Transparency ~= 1 and #security.DiscoverWalls(plot, plot:FindFirstChild("LockBase")) == 1,
    "LockButton support part is never treated as a security wall"
)
local root = owner.Character:FindFirstChild("HumanoidRootPart")
standingOn[root.Position] = button
check(not security.Activate(owner, plot), "unclaimed plate cannot activate")
-- Claim while physically overlapping Button: this is not a new activation entry.
setup(tycoon.AssignPlot(owner, plot) == plot, "fresh claim invokes actual lifecycle")
check(
    not security.IsLocked(plot) and not wall.CanCollide and laser.Transparency == 1,
    "claim keeps security and lasers inactive"
)
check(
    gui:GetAttribute("LockBaseOccupied") == true and label.Text == "LOCK BASE",
    "claimed plot immediately displays only LOCK BASE"
)
heartbeat:Fire(0.1)
check(not security.IsLocked(plot), "claim placement on Button cannot auto-activate")
standingOn[root.Position] = nil
heartbeat:Fire(0.1)
local blackBase = assembly:FindFirstChild("BlackBase")
standingOn[root.Position], buttonRayHits[root.Position] = blackBase, button
check(security.CheckStanding(owner, plot), "overlapping BlackBase may support only a verified Button footprint")
buttonRayHits[root.Position] = nil
check(not security.CheckStanding(owner, plot), "standing beside Button on BlackBase cannot activate")
standingOn[root.Position] = button
heartbeat:Fire(0.1)
check(
    security.IsLocked(plot) and plot:GetAttribute("LockBaseLockedUntil") == now + 60 and label.Text == "LOCKED\n1:00",
    "fresh physical entry starts exactly 60 seconds"
)
local press = tweens[#tweens]
local manualRaise = tweens[#tweens - 1]
local hiddenY = visual:GetPivot().Position.Y
check(
    manualRaise.Played
        and manualRaise.Info.Duration == 0.35
        and hiddenY < authored.Position.Y
        and laser.Transparency == 0.2
        and wall.CanCollide,
    "activation shows lasers below authored position and starts upward tween with immediate walls"
)
manualRaise.Target.Value /= 2
manualRaise.Target.Changed:Fire()
check(
    visual:GetPivot().Position.Y > hiddenY and visual:GetPivot().Position.Y < authored.Position.Y,
    "complete Visual visibly moves upward during the tween"
)
manualRaise:Finish()
check(visual:GetPivot().Position.Y == authored.Position.Y, "manual rise finishes at exact authored pivot")
press:Finish()
tweens[#tweens]:Finish()
check(
    button.CFrame.Position.Y == button:GetAttribute("LockBaseButtonOrigin").Position.Y,
    "manual button performs quick press and release"
)
check(
    not security.Activate(owner, plot) and plot:GetAttribute("LockBaseLockedUntil") == now + 60,
    "repeated activation cannot extend active manual timer"
)
-- A late observer reads the same replicated deadline and persistent world GUI.
visual.Parent = nil
plot.DescendantRemoving:Fire(visual)
heartbeat:Fire(0.1)
check(security.IsLocked(plot) and wall.CanCollide, "missing Visual does not stop authoritative protection")
visual.Parent = assembly
plot.DescendantAdded:Fire(visual)
heartbeat:Fire(0.1)
local recoveredRaise = tweens[#tweens]
check(
    recoveredRaise.Played and visual:GetPivot().Position.Y < authored.Position.Y,
    "returned Visual animates upward from hidden state"
)
recoveredRaise:Finish()
gui = attachment:FindFirstChild("LockBaseDisplay")
label = gui:FindFirstChildOfClass("TextLabel")
check(
    visual:GetPivot().Position.Y == authored.Position.Y and label.Text == "LOCKED\n1:00",
    "Visual recovery preserves original pivot and running deadline"
)
now += 10
heartbeat:Fire(0.1)
check(
    label.Text == "LOCKED\n0:50" and plot:GetAttribute("LockBaseLockedUntil") == now + 50,
    "world timer and replicated deadline agree for late observers"
)
now += 50
heartbeat:Fire(0.1)
check(
    not security.IsLocked(plot) and not wall.CanCollide and label.Text == "LOCK BASE",
    "expiration immediately unlocks walls and restores plain idle text"
)
tweens[#tweens]:Finish()
check(
    laser.Transparency == 1 and visual:GetPivot().Position.Y < authored.Position.Y,
    "expiration finishes fully hidden and retracted"
)
heartbeat:Fire(0.1)
check(not security.IsLocked(plot), "remaining on plate through expiration cannot retrigger")
standingOn[root.Position] = nil
heartbeat:Fire(0.1)
standingOn[root.Position] = button
heartbeat:Fire(0.1)
check(
    security.IsLocked(plot) and label.Text == "LOCKED\n1:00",
    "step off and back on repeats manual activation without cooldown"
)
tycoon.RemovePlayer(owner)
check(
    not wall.CanCollide
        and gui:GetAttribute("LockBaseOccupied") == false
        and laser.Transparency == 1
        and visual:GetPivot().Position.Y < authored.Position.Y,
    "release immediately resets actual visual/wall/UI state"
)
standingOn[root.Position] = nil
-- Invalid authored attachment hosts are never repaired or moved by presentation.
local other = lockObject("Model", "InvalidAttachmentPlot", workspaceFake)
local otherButton, _, otherVisual, invalidAttachment = securityAssets(other, "Model")
local invalidHost = otherButton.Parent
invalidAttachment.Parent = invalidHost
local display = loadModule("LockBasePresentation").Bind(otherButton, invalidAttachment, otherVisual)
display.Update(true, now + 60, now)
check(
    invalidAttachment.Parent == invalidHost and not invalidAttachment:FindFirstChild("LockBaseDisplay"),
    "invalid attachment remains authored and does not generate a floating display"
)
display.Destroy()
-- Opt-in contacts report meaningful entries, rather than every touched limb/frame.
local messages = {}
env.print = function(message)
    table.insert(messages, message)
end
services.Players.GetPlayerFromCharacter = function(_, character)
    return if character == owner.Character then owner else nil
end
workspaceFake:SetAttribute("LockBaseDiagnostics", true)
button.Touched:Fire(root)
button.Touched:Fire(root)
check(
    #messages == 1 and string.find(messages[1], "reason=Unclaimed", 1, true),
    "duplicate touches log once with resolved membership and rejection reason"
)
button.TouchEnded:Fire(root)
button.Touched:Fire(root)
check(#messages == 2, "new contact after stepping off logs a new event")
workspaceFake:SetAttribute("LockBaseDiagnostics", false)
env.print = print
print("PASS LockBase runtime integration", count, "contracts", setupCount, "setup checks")
