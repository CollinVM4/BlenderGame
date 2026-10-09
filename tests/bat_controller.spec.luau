-- Input contracts are independent of the separately tested touch layout.
cache.MobileControlLayout = { Register = function() end }
-- Local presentation/input boundary. Combat authority lives in the combat integration suite.
local config = loadModule("BatConfig")
env.Enum.AnimationPriority = { Idle = "Idle", Action = "Action" }
local p = instance("Player")
p.Name = "BatInputPlayer"
p.CharacterAdded, p.CharacterRemoving = signal(), signal()
p:SetAttribute("PlotSessionId", "active-session")
services.Players.LocalPlayer = p
local tracks, requests = {}, {}
local remote = instance("RemoteEvent")
remote.Name, remote.Parent = "GameplayRequest", shared.Events
function remote:FireServer(...)
    table.insert(requests, { ... })
end
local function character()
    local model = instance("Model")
    model.ChildAdded = signal()
    local humanoid = instance("Humanoid")
    humanoid.Parent, humanoid.Health, humanoid.Died = model, 100, signal()
    local animator = instance("Animator")
    animator.Parent = humanoid
    function animator:LoadAnimation(animation)
        if animation.AnimationId == "bad" then
            error("unavailable asset")
        end
        local track = { Plays = 0, IsPlaying = false, Destroyed = false, Ended = signal(), Name = animation.Name }
        function track:Play(_, _, speed)
            self.Plays += 1
            self.IsPlaying = true
            self.Speed = speed
        end
        function track:Stop()
            self.IsPlaying = false
        end
        function track:Destroy()
            self.Destroyed = true
        end
        table.insert(tracks, track)
        return track
    end
    return model, humanoid
end
local function bat(id)
    local tool = instance("Tool")
    tool.Name = "Bat"
    tool:SetAttribute("BatLevel", 1)
    if id then
        local animation = instance("Animation")
        animation.Name, animation.AnimationId, animation.Parent = "SwingAnimation", id, tool
    end
    return tool
end
local model, humanoid = character()
p.Character = model
local tool = bat("rbxassetid://test")
tool.Parent = model
local controller = loadModule("BatController")
controller.Init()
controller.Init()
check(#tracks == 1 and not tracks[1].IsPlaying, "equipping prepares a single track without autoplay")
local inputTrace = {}
-- Model the input boundary: a passing carry action allows Roblox Tool activation.
local carryAction
services.ContextActionService = {
    BindAction = function(_, _, callback)
        carryAction = callback
    end,
    SetTitle = function() end,
}
services.UserInputService = {
    GetFocusedTextBox = function()
        return nil
    end,
}
env.Enum.ContextActionResult = { Pass = "Pass", Sink = "Sink" }
env.Enum.UserInputState = { Begin = "Begin" }
env.Enum.UserInputType = { MouseButton1 = "MouseButton1" }
env.Enum.KeyCode = { ButtonR2 = "ButtonR2" }
function shared.Events:WaitForChild(name)
    return self:FindFirstChild(name)
end
p:SetAttribute("CarryCount", 3)
loadModule("CarryInputController").Init()
local previousPrint = env.print
env.print = function(message)
    table.insert(inputTrace, message)
end
studio = true
local carryResult = carryAction("ThrowHeld", "Begin")
check(carryResult == "Pass", "Bat plus overhead ingredients passes primary input to Tool")
if carryResult == "Pass" then
    tool.Activated:Fire()
end
check(
    #requests == 1 and requests[1][1] == "SwingBat" and p:GetAttribute("CarryCount") == 3,
    "shared primary input swings Bat without a throw request or carry change"
)
local inputLog = table.concat(inputTrace, "\n")
check(
    string.find(inputLog, "[BatInput] Tool.Activated", 1, true) ~= nil
        and string.find(inputLog, "[BatInput] sending SwingBat", 1, true) ~= nil
        and string.find(inputLog, "[BatInput] FireServer returned: SwingBat", 1, true) ~= nil,
    "Studio activation/send boundaries are visible without a replicated debug flag"
)
p:SetAttribute("BatDebugNextSwing", true)
tool.Activated:Fire()
check(
    string.find(table.concat(inputTrace, "\n"), "activation rejected: local swing cooldown", 1, true) ~= nil
        and p:GetAttribute("BatDebugNextSwing") == true,
    "local rejection is observable and leaves the server debug flag intact"
)
studio = false
env.print = previousPrint
p:SetAttribute("BatDebugNextSwing", nil)
check(
    tracks[1].Plays == 1 and tracks[1].IsPlaying and tracks[1].Speed == 1,
    "activation immediately plays at contact-timing speed"
)
check(tracks[1].Priority == "Action" and not tracks[1].Looped, "swing is a nonlooped Action track")
check(#requests == 1 and #requests[1] == 1 and requests[1][1] == "SwingBat", "activation sends intent only")
for _ = 1, 20 do
    tool.Activated:Fire()
end
check(tracks[1].Plays == 1 and #requests == 1, "spam cannot restart or stack local swings")
local first = tracks[1]
tool.Parent = nil
tool.Unequipped:Fire()
check(not first.IsPlaying and first.Destroyed, "unequip stops and releases track")
tool.Parent = model
model.ChildAdded:Fire(tool)
tool.Activated:Fire()
check(#requests == 1 and tracks[2].Plays == 0, "re-equip cannot bypass existing cooldown")
now += config.SwingCooldown
tool.Activated:Fire()
check(#requests == 2 and tracks[2].Plays == 1, "new swing is allowed at shared cooldown")
now += config.SwingCooldown
tool.Activated:Fire()
check(#tracks == 2 and tracks[2].Plays == 2, "successive swings reuse one track")
humanoid.Health = 0
humanoid.Died:Fire()
check(tracks[2].Destroyed and not tracks[2].IsPlaying, "death stops active track")
now += config.SwingCooldown
tool.Activated:Fire()
check(#requests == 3, "dead/cleaned tool cannot request another swing")
local replacement, replacementHumanoid = character()
p.CharacterRemoving:Fire(model)
p.Character = replacement
p.CharacterAdded:Fire(replacement)
local newTool = bat("rbxassetid://test")
newTool.Parent = replacement
replacement.ChildAdded:Fire(newTool)
p:SetAttribute("Stunned", true)
newTool.Activated:Fire()
check(#requests == 3 and tracks[3].Plays == 0, "stunned activation does not play or request")
p:SetAttribute("Stunned", false)
p:SetAttribute("PlotSessionId", nil)
newTool.Activated:Fire()
check(#requests == 3, "unassigned activation is ignored")
p:SetAttribute("PlotSessionId", "new-session")
newTool.Activated:Fire()
check(#requests == 4 and tracks[3].IsPlaying, "respawn binds new valid tool")
newTool:Destroy()
check(tracks[3].Destroyed and not tracks[3].IsPlaying, "destruction stops and releases track")
now += config.SwingCooldown
local silent = bat(nil)
silent.Parent = replacement
replacement.ChildAdded:Fire(silent)
silent.Activated:Fire()
check(#requests == 5 and #tracks == 3, "missing optional animation does not break gameplay intent")
silent.Parent = nil
silent.AncestryChanged:Fire()
now += config.SwingCooldown
local invalid = bat("bad")
invalid.Parent = replacement
replacement.ChildAdded:Fire(invalid)
invalid.Activated:Fire()
check(#requests == 6, "unavailable animation cannot block gameplay request")
invalid.Parent = nil
invalid.Unequipped:Fire()
now += config.SwingCooldown
local finalTool = bat("rbxassetid://test")
finalTool.Parent = replacement
replacement.ChildAdded:Fire(finalTool)
finalTool.Activated:Fire()
p.CharacterRemoving:Fire(replacement)
check(tracks[4].Destroyed and not tracks[4].IsPlaying, "character removal releases playing track")
local before = #requests
model.ChildAdded:Fire(tool)
tool.Activated:Fire()
finalTool.Activated:Fire()
check(#requests == before, "stale character/tool callbacks cannot activate after cleanup")

-- Full authored animation set and transitions, including late completion callbacks.
local function fullBat()
    local result = bat("rbxassetid://swing")
    for _, name in { "Idle", "Equip", "Unequip" } do
        local animation = instance("Animation")
        animation.Name, animation.AnimationId, animation.Parent = name .. "Animation", "rbxassetid://" .. name, result
    end
    return result
end
local function loadedSince(index)
    local result = {}
    for i = index + 1, #tracks do
        result[tracks[i].Name] = tracks[i]
    end
    return result
end
local function finish(track)
    track.IsPlaying = false
    track.Ended:Fire()
end
local fullCharacter, fullHumanoid = character()
p.Character = fullCharacter
p.CharacterAdded:Fire(fullCharacter)
local full = fullBat()
local authoredGrip = { Orientation = vec(-78, 0, 0) }
full.Grip = authoredGrip
local countBefore = #tracks
full.Parent = fullCharacter
fullCharacter.ChildAdded:Fire(full)
local loaded = loadedSince(countBefore)
check(
    loaded.IdleAnimation.Priority == "Idle" and loaded.IdleAnimation.Looped,
    "idle has explicit Idle priority and loops"
)
for _, name in { "EquipAnimation", "SwingAnimation", "UnequipAnimation" } do
    check(loaded[name].Priority == "Action" and not loaded[name].Looped, name .. " is explicitly Action and nonlooped")
end
check(loaded.EquipAnimation.IsPlaying and not loaded.IdleAnimation.IsPlaying, "equip precedes idle")
finish(loaded.EquipAnimation)
check(loaded.IdleAnimation.IsPlaying, "natural equip completion starts idle")
full.Activated:Fire()
check(not loaded.IdleAnimation.IsPlaying and loaded.SwingAnimation.IsPlaying, "activation replaces idle with swing")
local sentBefore = #requests
full.Activated:Fire()
check(#requests == sentBefore and loaded.SwingAnimation.Plays == 1, "full animation set respects swing cooldown")
loaded.EquipAnimation.Ended:Fire()
check(
    loaded.SwingAnimation.IsPlaying and not loaded.IdleAnimation.IsPlaying,
    "late equip completion cannot interrupt swing"
)
finish(loaded.SwingAnimation)
check(loaded.IdleAnimation.IsPlaying, "natural swing completion resumes idle")
now += config.SwingCooldown
full.Activated:Fire()
local backpack = instance("Backpack")
backpack.Parent = p
full.Parent = backpack
full.AncestryChanged:Fire()
full.Unequipped:Fire()
check(
    loaded.UnequipAnimation.IsPlaying and loaded.UnequipAnimation.Plays == 1,
    "unequip plays outro once across both signals"
)
check(
    not loaded.IdleAnimation.IsPlaying and not loaded.SwingAnimation.IsPlaying and not loaded.EquipAnimation.IsPlaying,
    "unequip stops idle/swing/equip"
)
finish(loaded.SwingAnimation)
check(
    not loaded.IdleAnimation.IsPlaying and loaded.UnequipAnimation.IsPlaying,
    "late swing completion cannot restart idle after unequip"
)
countBefore = #tracks
full.Parent = fullCharacter
fullCharacter.ChildAdded:Fire(full)
local reequip = loadedSince(countBefore)
check(
    loaded.UnequipAnimation.Destroyed and reequip.EquipAnimation.IsPlaying,
    "re-equip cancels old outro and plays fresh equip"
)
full.Activated:Fire()
check(#requests == sentBefore + 1 and reequip.SwingAnimation.Plays == 0, "re-equip does not bypass swing cooldown")
finish(loaded.UnequipAnimation)
check(reequip.EquipAnimation.IsPlaying, "stale outro completion cannot clear new equip")
now += config.SwingCooldown
full.Activated:Fire()
check(
    reequip.SwingAnimation.IsPlaying and not reequip.EquipAnimation.IsPlaying,
    "activation may interrupt equip after cooldown"
)
finish(reequip.EquipAnimation)
check(reequip.SwingAnimation.IsPlaying and not reequip.IdleAnimation.IsPlaying, "interrupted equip cannot restart idle")
full.Parent = backpack
full.Unequipped:Fire()
finish(reequip.UnequipAnimation)
for _, track in reequip do
    check(track.Destroyed and not track.IsPlaying, "completed outro releases " .. track.Name)
end
check(full.Grip == authoredGrip, "controller preserves authored minus-78-degree grip")
-- Destroying/death/teardown also cancel the outro, rather than waiting for completion.
for _, reason in { "death", "destruction", "teardown" } do
    countBefore = #tracks
    local temporary = fullBat()
    temporary.Parent = fullCharacter
    fullHumanoid.Health = 100
    fullCharacter.ChildAdded:Fire(temporary)
    local temporaryTracks = loadedSince(countBefore)
    temporary.Parent = backpack
    temporary.Unequipped:Fire()
    if reason == "death" then
        fullHumanoid.Health = 0
        fullHumanoid.Died:Fire()
    elseif reason == "destruction" then
        temporary:Destroy()
    else
        controller.Destroy()
    end
    local allReleased = true
    for _, track in temporaryTracks do
        allReleased = allReleased and track.Destroyed and not track.IsPlaying
    end
    check(allReleased, reason .. " cleans all tracks during outro")
end
local stoppedRequests = #requests
local late = fullBat()
late.Parent = fullCharacter
fullCharacter.ChildAdded:Fire(late)
p.CharacterAdded:Fire(fullCharacter)
late.Activated:Fire()
check(#requests == stoppedRequests, "controller teardown disconnects player and character subscriptions")
controller.Destroy()
fullHumanoid.Health = 100
controller.Init()
check(tracks[#tracks - 2].IsPlaying, "controller can initialize again after teardown")
controller.Destroy()
