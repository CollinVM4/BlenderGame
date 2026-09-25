-- Actual remote adapter: revision captured at submission, server checks current membership.
local tycoon = dependency.TycoonService
local actor, peer = player(), player()
tycoon.RemovePlayer(peer)
setup(tycoon.JoinSession(peer, actor, tycoon.GetRequestContext(actor)), "network test join")
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
        object.FireClient = function() end
    end
    return object
end
env.typeof = function(value)
    return if type(value) == "table" and value.IsA then "Instance" else type(value)
end
local gameplay = loadModule("GameplayService")
dependency.PlayerDataService = dataService
gameplay.Init(dependency)
local remote = shared.Events:FindFirstChild("GameplayRequest")
local prompt = instance("ProximityPrompt")
prompt.Parent, prompt.Enabled = references[actor].BlenderInput, true
local invoked = 0
gameplay.RegisterPlotInteraction(prompt, function(p, context)
    check(tycoon.ValidateActor(p, context), "handler gets validated request")
    invoked += 1
end)
local function request(p, action, target, tier, context)
    now += 0.2
    remote.OnServerEvent:Fire(p, action, target, tier, context)
end
local old = tycoon.GetRequestContext(peer)
request(peer, "PlotInteraction", prompt, nil, old)
check(invoked == 1, "registered prompt request delivered")
tycoon.RemovePlayer(peer)
setup(tycoon.JoinSession(peer, actor, tycoon.GetRequestContext(actor)), "network rejoin")
request(peer, "PlotInteraction", prompt, nil, old)
check(invoked == 1, "packet captured before leave/rejoin cannot invoke prompt")
request(peer, "PlotInteraction", prompt, nil, nil)
check(invoked == 1, "missing context cannot invoke prompt")
local unregistered = instance("ProximityPrompt")
unregistered.Parent, unregistered.Enabled = prompt.Parent, true
request(peer, "PlotInteraction", unregistered, nil, tycoon.GetRequestContext(peer))
check(invoked == 1, "unregistered instance cannot dispatch")
local context = tycoon.GetRequestContext(actor)
tycoon.SetCash(actor, 10000)
request(actor, "PurchaseUpgrade", "Jump", 2, context)
request(peer, "PurchaseUpgrade", "Jump", 2, tycoon.GetRequestContext(peer))
check(
    tycoon.GetUpgrade(peer, "Jump") == 2 and tycoon.GetCash(actor) == 8000,
    "two same-tier network requests purchase once"
)
tycoon.RemovePlayer(actor)
request(peer, "PurchaseUpgrade", "Jump", 3, context)
check(
    tycoon.GetUpgrade(peer, "Jump") == 2 and tycoon.GetCash(peer) == 8000,
    "pre-promotion network request cannot spend"
)
local absent = instance("Player")
request(absent, "PurchaseUpgrade", "Jump", 3, tycoon.GetRequestContext(peer))
check(tycoon.GetCash(peer) == 8000, "visitor cannot borrow context to spend")
-- The unchanged prompt UI submits a captured context through the new client adapter.
services.Players.LocalPlayer = peer
services.ProximityPromptService = { PromptTriggered = signal() }
services.ReplicatedStorage.WaitForChild = function()
    return shared
end
shared.WaitForChild = function()
    return shared.Events
end
shared.Events.WaitForChild = function()
    return remote
end
local sent
remote.FireServer = function(_, ...)
    sent = { ... }
end
local controller = loadModule("SessionInteractionController")
controller.Init()
flush()
services.ProximityPromptService.PromptTriggered:Fire(prompt)
check(
    sent
        and sent[1] == "PlotInteraction"
        and sent[2] == prompt
        and sent[4].PlotSessionId == tycoon.GetSessionId(peer)
        and sent[4].MembershipRevision == tycoon.GetRequestContext(peer).MembershipRevision,
    "client submits the current actor revision with the native prompt"
)
sent = nil
services.ProximityPromptService.PromptTriggered:Fire(unregistered)
check(sent == nil, "ordinary prompts keep their existing handlers")
-- Closing session personal cleanup runs after the accepted transaction, including reentrancy.
local captured = tycoon.GetRequestContext(peer)
local token = tycoon.BeginTransaction(peer, captured)
local cleaned = false
tycoon.RemovePlayer(peer, function()
    cleaned = tycoon.GetSessionId(peer) == nil
end)
check(not cleaned, "personal cleanup waits for membership transition")
tycoon.CreditTransaction(token, 50)
tycoon.EndTransaction(token)
check(cleaned, "personal cleanup runs after transition")
request(peer, "PlotInteraction", prompt, nil, captured)
check(invoked == 1, "closed session request cannot invoke prompt")
