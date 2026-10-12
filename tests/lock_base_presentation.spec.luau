-- Real presentation module; fake tween endpoints cannot prove rendered smoothness.
local plot = lockObject("Model", "Plot", workspaceFake)
local button, wall, visual, attachment, laser, base = securityAssets(plot)
button.CFrame = env.CFrame.new(1, 2, 3)
attachment.Position = vec(0.4, 1.2, -0.3)
attachment.WorldCFrame = env.CFrame.new(1.4, 3.2, 2.7)
local authoredPosition, authoredWorld = attachment.Position, attachment.WorldCFrame
local original = visual:GetPivot()
local presentation = loadModule("LockBasePresentation")
local display = presentation.Bind(button, attachment, visual)
local gui = attachment:FindFirstChild("LockBaseDisplay")
local label = gui:FindFirstChildOfClass("TextLabel")
check(
    gui.Adornee == attachment
        and attachment.Parent == button
        and attachment.Position == authoredPosition
        and attachment.WorldCFrame == authoredWorld,
    "display uses exact authored Button attachment without changing transforms"
)
check(
    gui.StudsOffset.Magnitude == 0 and gui.StudsOffsetWorldSpace.Magnitude == 0,
    "display has no extra world or camera offset"
)
check(
    gui.MaxDistance >= 65 and label.TextSize == 24 and label:FindFirstChild("DialogueOutline").Thickness == 2.5,
    "compact Fredoka lettering retains outline and third-person camera allowance"
)
check(
    laser.Transparency == 1 and base.Transparency == 1 and visual:GetPivot().Position.Y < original.Position.Y,
    "inactive authored geometry is hidden and retracted"
)
check(not laser.CanCollide and not base.CanCollide, "visual lasers never enforce physical collision")
display.Update(true, 0, now)
check(
    gui:GetAttribute("LockBaseOccupied") == true
        and label.Text == "LOCK BASE"
        and label.TextXAlignment == "Center"
        and label.TextYAlignment == "Center",
    "idle claimed display is centered with no READY subtitle"
)
display.SetLocked(true)
local raise = tweens[#tweens]
check(raise.Info.Duration == 0.35, "laser rise uses configured quick duration")
raise:Finish()
check(
    visual:GetPivot().Position.Y == original.Position.Y and laser.Transparency == 0.2 and base.Transparency == 0.1,
    "raise reaches exact authored placement and transparencies"
)
display.Update(true, now + 59, now)
check(
    gui:GetAttribute("LockBaseOccupied") == true and label.Text == "LOCKED\n0:59" and label.Font == "FredokaOne",
    "Fredoka world display shows deadline countdown"
)
display.Update(true, now + 59, now + 1)
check(label.Text == "LOCKED\n0:58", "countdown follows server time")
display.Press()
local press = tweens[#tweens]
press:Finish()
check(button.CFrame.Position.Y < 2, "valid activation depresses existing button")
tweens[#tweens]:Finish()
check(button.CFrame.Position.Y == 2, "button release restores authored position")
display.SetLocked(false)
local lower = tweens[#tweens]
check(lower.Info.Duration == 0.25, "laser lowering uses configured quick duration")
display.SetLocked(true)
lower:Finish()
tweens[#tweens]:Finish()
check(
    laser.Transparency == 0.2 and visual:GetPivot().Position.Y == original.Position.Y,
    "canceled lowering cannot hide a newly raised model"
)
display.SetLocked(false)
tweens[#tweens]:Finish()
local hiddenY = visual:GetPivot().Position.Y
check(hiddenY < original.Position.Y and laser.Transparency == 1, "lowering reaches hidden inactive state")
display.Update(false, 0, now)
check(gui:GetAttribute("LockBaseOccupied") == false, "release revokes display occupancy")
display.Destroy()
local rebound = presentation.Bind(button, attachment, visual)
check(#attachment:GetChildren() == 1 and gui.Destroyed, "rebind replaces the display without duplicate billboards")
rebound.SetLocked(true, true)
check(
    visual:GetPivot().Position.Y == original.Position.Y and laser.Transparency == 0.2,
    "rebind uses absolute authored transforms without accumulated offsets"
)
rebound.SetLocked(false, true)
check(visual:GetPivot().Position.Y == hiddenY, "rebind preserves consistent retraction endpoint")
rebound.Destroy()
local missing = presentation.Bind(nil, nil, nil)
missing.SetLocked(true)
tweens[#tweens]:Finish()
missing.Update(true, now + 30, now)
missing.Destroy()
check(true, "missing visuals do not break timer presentation lifecycle")
print("PASS LockBase presentation", count, "contracts")
