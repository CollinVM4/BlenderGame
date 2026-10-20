-- Exercise production modules at the engine boundary; no client economy model.
local accept = loadModule("CashRewardState").New()
local function event(id, payout, owner, moment)
    return accept(moment or "CustomerReaction", owner or 51, { BlendId = id, Payout = payout }, 51)
end
check(not event("foreign", 100, 99), "other players' payouts cannot animate")
for _, id in { "", 12, false } do
    local accepted, reason = event(id, 10)
    check(not accepted and reason == "bad BlendId", "bad blend IDs report rejection")
end
check(not event(nil, 10), "missing BlendId rejected")
for _, value in { 0, -100, math.huge, 0 / 0, "100" } do
    local accepted, reason = event("invalid", value)
    check(not accepted and reason == "bad payout", "nonpositive/nonfinite/malformed payout cannot animate")
end
check(not event("blend", 100, 51, "SmoothieDispensed"), "dispense is not confirmed payout")
check(not accept(nil, nil, nil, 51), "malformed event ignored")
check(event("served-1", 100), "committed positive local payout accepted")
local repeated, reason = event("served-1", 100)
check(not repeated and reason == "duplicate", "repeated committed event suppressed with diagnostic reason")
check(event("served-2", 50), "consecutive distinct serves accepted")
for index = 1, 1100 do
    event("long-session-" .. index, 10)
end
check(not event("served-1", 100), "long client sessions retain original replay protection")

local function ui(class, name, parent)
    local object = instance(class)
    local original = object.IsA
    object.IsA = function(self, kind)
        return original(self, kind)
            or (kind == "GuiObject" and (class == "Frame" or class == "TextLabel" or class == "ImageLabel"))
    end
    object.Name, object.Parent = name, parent
    object.Visible, object.Enabled = true, true
    object.AbsolutePosition, object.AbsoluteSize = vec(0, 0, 0), vec(360, 640, 0)
    object.GetPropertyChangedSignal = function()
        return signal()
    end
    if class == "UIScale" then
        object.Scale = 1
    end
    return object
end
env.Instance.new = function(class)
    return ui(class, class, nil)
end
env.Vector2.new = function(x, y)
    return vec(x, y, 0)
end
env.Enum.ScreenInsets = { CoreUISafeInsets = "CoreUISafeInsets" }
env.Random = {
    new = function()
        return {
            NextInteger = function(_, a, b)
                return b
            end,
            NextNumber = function(_, a, b)
                return (a + b) / 2
            end,
        }
    end,
}
local playerGui = ui("PlayerGui", "PlayerGui")
local function desktop(name)
    local screen = ui("ScreenGui", name, playerGui)
    local desktop = ui("Frame", "Be a Blender! Desktop", screen)
    local content = ui("Frame", "DesktopContent", desktop)
    local top = ui("Frame", "TOP", content)
    local cash = ui("Frame", "CashDisplay", top)
    ui("TextLabel", "{Coins}", cash)
    cash.AbsolutePosition, cash.AbsoluteSize = vec(70, 12, 0), vec(140, 40, 0)
    return screen, desktop, top, cash
end
local screen, firstDesktop, top, cash = desktop("GeneratedRoot")
local hud = loadModule("CashHud")
check(hud.Resolve(playerGui) == cash, "actual active Framewisp cash frame resolved")
local label = cash:FindFirstChild("{Coins}")
local content = top.Parent
label.Parent = top
check(hud.Resolve(playerGui) == label, "direct TOP {Coins} alias resolves without CashDisplay")
label.Parent = cash
cash.Parent = content
check(hud.Resolve(playerGui) == cash, "content-level cash fallback resolves")
cash.Parent = firstDesktop
check(hud.Resolve(playerGui) == cash, "desktop-level cash fallback resolves with optional Content")
cash.Parent = top
local originalParent = top.Parent
top.Parent = firstDesktop
check(hud.Resolve(playerGui) == cash, "desktop TOP resolves alongside content wrapper")
top.Parent = originalParent
label.Visible = false
check(hud.Resolve(playerGui) == nil, "hidden counter cannot receive punch")
label.Visible = true
local canvas = ui("Frame", "Canvas")
canvas.AbsolutePosition = vec(-7, -48, 0)
local center = hud.Center(cash, canvas)
check(center.X == 147 and center.Y == 80, "cash center converted using actual canvas inset origin")
cash.AbsolutePosition, cash.AbsoluteSize = vec(14, 25, 0), vec(90, 30, 0)
center = hud.Center(cash, canvas)
check(center.X == 66 and center.Y == 88, "resized mobile cash frame uses current center")
top.Visible = false
check(hud.Resolve(playerGui) == nil, "hidden ancestor cannot receive flight")
top.Visible = true
local secondScreen = desktop("Replacement")
check(hud.Resolve(playerGui) == nil, "ambiguous active imports never guess a destination")
secondScreen.Enabled = false
check(hud.Resolve(playerGui) == cash, "disabled import ignored")
cash.Name = "RenamedCash"
cash:SetAttribute("BlenderUI", "CashDisplay")
check(hud.Resolve(playerGui) == cash, "semantic rename survives reimport")
local duplicate = ui("Frame", "CashDisplay", top)
check(hud.Resolve(playerGui) == nil, "duplicate cash contract skipped")
duplicate:Destroy()
screen.Enabled = false
local alternate = ui("ScreenGui", "RenamedDesktop", playerGui)
alternate:SetAttribute("BlenderUI", "Desktop")
local alternateTop = ui("Frame", "TOP", alternate)
local alternateCash = ui("TextLabel", "Cash", alternateTop)
check(hud.Resolve(playerGui) == alternateCash, "semantic ScreenGui desktop without Content resolves Cash alias")
alternate.Enabled = false
screen.Enabled = true
local emptyDesktop = ui("ScreenGui", "Be a Blender! Desktop", playerGui)
check(hud.Resolve(playerGui) == cash, "empty alternate root does not veto valid cash target")
emptyDesktop:Destroy()

local player = instance("Player")
player.UserId, player.Character = 51, instance("Model")
playerGui.Parent = player
local root = instance("Part")
root.Name, root.Parent = "HumanoidRootPart", player.Character
local onScreen = true
workspaceFake.CurrentCamera = {
    ViewportSize = vec(360, 640, 0),
    WorldToScreenPoint = function()
        return vec(180, 320, 1), onScreen
    end,
}
local render = signal()
services.RunService.RenderStepped = render
local cues = {}
local logs, timers = {}, {}
env.warn = function(message)
    table.insert(logs, message)
end
env.task.delay = function(_, callback)
    table.insert(timers, callback)
end
env.Enum.AssetFetchStatus = { Success = "Success", Failure = "Failure" }
local fetchStatus = "Success"
services.ContentProvider = {
    PreloadAsync = function(_, _, callback)
        if fetchStatus then
            callback("test", fetchStatus)
        end
    end,
}
parent.Parent.Controllers = parent
cache.GameplayAudioController = {
    PlayCashFeedback = function(kind)
        table.insert(cues, kind)
    end,
}
services.Players.LocalPlayer = player
player:SetAttribute("playerCash", 1500)
local arrivalTicker = loadModule("CashTicker")
local originalSetTarget = arrivalTicker.SetTarget
local arrivalTargets = {}
arrivalTicker.SetTarget = function(value)
    table.insert(arrivalTargets, value)
    originalSetTarget(value)
end
local animation = loadModule("CashRewardAnimation")
local config = loadModule("CashFeedback")
config.Image = ""
animation.Play(player)
check(not playerGui:FindFirstChild("CashRewardEffects"), "unset uploaded icon skips without substituted artwork")
config.Image = "test://supplied-icon"
local function activeIcons()
    local count = 0
    for _, object in playerGui:GetDescendants() do
        if object.Name == "CashIcon" then
            count += 1
        end
    end
    return count
end
animation.Play(player)
check(activeIcons() == 8, "burst creates five to eight supplied icons")
now += 0.1
render:Fire()
local first = playerGui:FindFirstChild("CashIcon", true)
check(
    first.Visible and first.Image == config.Image and first.Size.X.Offset > first.Size.Y.Offset,
    "cash pops with supplied image and stretch"
)
animation.Play(player)
check(activeIcons() == 16, "new serve does not cancel previous burst")
animation.Play(player)
animation.Play(player)
check(activeIcons() == config.MaxIcons, "simultaneous icons bounded")
now += 0.15
render:Fire()
check(first.Visible and first.ImageTransparency == 0, "brief float stays readable before flight")
local floatPosition = vec(first.Position.X.Offset, first.Position.Y.Offset, 0)
now += 0.25
render:Fire()
local flying = vec(first.Position.X.Offset, first.Position.Y.Offset, 0)
local destination = hud.Center(cash, playerGui:FindFirstChild("CashRewardEffects"):FindFirstChildOfClass("Frame"))
local segment = destination - floatPosition
local traveled = flying - floatPosition
check(
    math.abs(segment.X * traveled.Y - segment.Y * traveled.X) > 1,
    "collection follows a curve rather than a straight line"
)
check(first.ImageTransparency > 0 and first.Size.X.Offset < 34, "flight shrinks and fades toward HUD")
now += 0.6
render:Fire()
check(activeIcons() == 0, "each completed icon removed")
check(arrivalTargets[1] == 1500, "arrival retargets ticker from current authoritative cash")
now += 0.1
render:Fire()
local scale = cash:FindFirstChildOfClass("UIScale")
check(scale and scale.Scale > 1 and scale.Scale <= 1.08, "arrival punches actual HUD subtly")
now += 0.2
render:Fire()
check(
    not playerGui:FindFirstChild("CashRewardEffects") and not cash:FindFirstChildOfClass("UIScale"),
    "completion restores HUD and removes temporary layer"
)
local authored = ui("UIScale", "AuthoredScale", cash)
authored.Scale = 0.85
animation.Play(player)
now += 1
render:Fire()
now += 0.1
render:Fire()
check(authored.Scale > 0.85, "existing authored scale receives relative punch")
animation.Clear()
check(authored.Scale == 0.85, "respawn cleanup restores authored scale")
animation.Play(player)
top.Visible = false
render:Fire()
check(activeIcons() == 8, "disappearing HUD preserves pending burst")
now += 1
render:Fire()
check(activeIcons() == 0, "centered fallback completes without HUD")
animation.Play(player)
check(activeIcons() == 8, "missing HUD still starts centered burst")
local fallbackIcon = playerGui:FindFirstChild("CashIcon", true)
render:Fire()
check(
    fallbackIcon.Position.X.Offset == 180 and fallbackIcon.Position.Y.Offset == 320,
    "missing HUD pops at screen center"
)
animation.Clear()
top.Visible = true
onScreen = false
animation.Play(player)
check(activeIcons() == 0, "offscreen player skips safely")
onScreen = true
-- Test the actual controller subscription, including duplicate and respawn handling.
services.ReplicatedStorage.WaitForChild = function(_, name)
    return services.ReplicatedStorage[name]
end
services.Players.LocalPlayer = player
shared.WaitForChild = function(_, name)
    return shared[name]
end
local remote = instance("RemoteEvent")
remote.Name, remote.Parent, remote.OnClientEvent = "GameplayPresentation", shared.Events, signal()
shared.Events.WaitForChild = shared.Events.FindFirstChild
local controller = loadModule("CashRewardController")
controller.Init()
controller.Init()
flush()
remote.OnClientEvent:Fire("CustomerReaction", 99, { BlendId = "other", Payout = 100 })
check(activeIcons() == 0, "controller ignores remote payout for another player")
remote.OnClientEvent:Fire("CustomerReaction", 51, { BlendId = "controller-1", Payout = 100 })
remote.OnClientEvent:Fire("CustomerReaction", 51, { BlendId = "controller-1", Payout = 100 })
check(activeIcons() == 8, "confirmed event animates once through real controller")
player.CharacterRemoving:Fire()
check(activeIcons() == 0, "respawn cancels transient presentation")
remote.OnClientEvent:Fire("CustomerReaction", 51, { BlendId = "controller-1", Payout = 100 })
check(activeIcons() == 0, "respawn does not reset replay protection")
remote.OnClientEvent:Fire("CustomerReaction", 51, { BlendId = "consolation", Payout = 1, Grade = "D" })
check(activeIcons() == 8, "positive D consolation animates through controller")
animation.Clear()
remote.OnClientEvent:Fire("CustomerReaction", 51, { BlendId = "unpaid", Payout = 0 })
check(activeIcons() == 0, "non-paying event cannot start burst")
screen:Destroy()
secondScreen.Enabled = true
local replacementCash = secondScreen:FindFirstChild("CashDisplay", true)
check(hud.Resolve(playerGui) == replacementCash, "new active import replaces detached HUD")
remote.OnClientEvent:Fire("CustomerReaction", 51, { BlendId = "controller-2", Payout = 100 })
check(activeIcons() == 8, "subsequent serve uses replacement HUD")
now += 1
render:Fire()
check(replacementCash:FindFirstChildOfClass("UIScale") ~= nil, "arrival reacts on replacement frame")
animation.Clear()
-- Diagnostics exercise actual image observations and engine fetch outcomes.
local debug = loadModule("CashRewardDebug")
check(not debug.Enabled(player), "diagnostics default off")
player:SetAttribute("CashRewardDebug", true)
studio = false
check(not debug.Enabled(player), "diagnostics disabled outside Studio even with attribute")
studio = true
now += 5
table.clear(logs)
config.Image = ""
animation.Play(player)
check(string.find(logs[1], "asset failed to load: empty image", 1, true), "empty asset identifies the failing gate")
config.Image = "test://invalid"
fetchStatus = "Failure"
animation.Play(player)
flush()
check(string.find(logs[#logs], "asset failed to load", 1, true), "failed fetch is diagnosed")
animation.Clear()
config.Image = "test://valid"
fetchStatus = "Success"
animation.Play(player)
flush()
check(string.find(logs[#logs], "asset loaded", 1, true), "successful fetch is diagnosed")
animation.Clear()
fetchStatus = nil
animation.Play(player)
flush()
for _, callback in timers do
    callback()
end
check(string.find(logs[#logs], "five-second timeout", 1, true), "pending fetch has bounded timeout diagnosis")
animation.Clear()
table.clear(timers)
local cached = ui("ImageLabel", "CachedIcon")
cached.Image, cached.IsLoaded = config.Image, true
debug.WatchImage(player, cached)
check(string.find(logs[#logs], "ImageLabel.IsLoaded", 1, true), "cached label reports loaded")
now += 5
table.clear(logs)
for _ = 1, 40 do
    debug.Log(player, "bounded")
end
check(#logs == 20, "diagnostic output bounded per five seconds")
player:SetAttribute("CashRewardDebug", false)
print("PASS: cash reward presentation contracts")
