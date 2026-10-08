-- Real TycoonService integration; only the Roblox chat/identity boundary is simulated.
local players = services.Players
players.PlayerAdded, players.PlayerRemoving = signal(), signal()
local function makePlayer(id, name)
    local p = instance("Player")
    p.UserId, p.Name, p.Parent = id, name, players
    p.Chatted = signal()
    return p
end
local owner = makePlayer(701, "ConfiguredAdmin")
local teammate = makePlayer(702, "Eatandpoop")
local visitor = makePlayer(703, "KarmaReaper2")
local absent = makePlayer(704, "NoPlot")
local failedLookup = makePlayer(705, "snipernosniping1234")
local roster = { owner, teammate, visitor, absent, failedLookup }
players.GetPlayers = function()
    return roster
end
players.GetPlayerByUserId = function(_, id)
    for _, p in roster do
        if p.UserId == id then
            return p
        end
    end
    return nil
end
local lookups = {}
players.GetUserIdFromNameAsync = function(_, name)
    lookups[name] = (lookups[name] or 0) + 1
    if name == "Eatandpoop" then
        return teammate.UserId
    end
    error("lookup unavailable")
end
local clock = 0
env.os = {
    clock = function()
        return clock
    end,
}
env.Enum.ChatVersion = { TextChatService = "Modern", LegacyChatService = "Legacy" }
local modern = not adminLegacy
services.TextChatService = instance("TextChatService")
services.TextChatService.ChatVersion = if modern then "Modern" else "Legacy"
local newInstance = env.Instance.new
env.Instance.new = function(className)
    local object = newInstance(className)
    if className == "TextChatCommand" then
        object.Triggered = signal()
    end
    return object
end
local config = loadModule("AdminConfig")
config.AdminUserIds = { owner.UserId, absent.UserId }
local admin = loadModule("AdminService")
local tycoon = sessionTestAuthority
assignTestSession(owner)
assignTestSession(teammate)
tycoon.RemovePlayer(teammate)
setup(tycoon.JoinSession(teammate, owner, tycoon.GetRequestContext(owner)), "join shared admin stand")
assignTestSession(visitor)
admin.Init({ TycoonService = tycoon })
check(not admin.HandleCommand(teammate, ";addCash 100"), "unresolved name grants no permission")
flush()
check(not admin.HandleCommand(visitor, ";addCash 100"), "failed username resolution fails closed")
check(not admin.HandleCommand(failedLookup, ";addCash 100"), "another unresolved identity cannot execute")
check(not admin.HandleCommand(absent, ";addCash 100"), "admin without active session safely rejected")
check(admin.HandleCommand(owner, ";ADDCASH    1000"), "configured ID accepts case-insensitive command and whitespace")
check(tycoon.GetSession(owner).SharedCash == 1000, "command credits authoritative shared balance")
check(
    owner:GetAttribute("playerCash") == 1000 and teammate:GetAttribute("playerCash") == 1000,
    "normal publish synchronizes both clients"
)
check(not admin.HandleCommand(owner, ";addCash 1000") and tycoon.GetCash(owner) == 1000, "rapid duplicate rejected")
clock += config.CommandCooldownSeconds
check(
    admin.HandleCommand(owner, ";addcash 12.9") and tycoon.GetCash(teammate) == 1012,
    "decimal award intentionally floors"
)
clock += 1
for _, text in { "0", "-1", "banana", "1000000001", "1e309", "nan", "0.9", "1000000000.1", "", "100 other" } do
    check(
        not admin.HandleCommand(owner, ";addCash " .. text) and tycoon.GetCash(owner) == 1012,
        "invalid amount rejected: " .. text
    )
end
check(not admin.HandleCommand(owner, ";exec print(1)"), "unknown commands cannot execute")
check(
    admin.HandleCommand(teammate, ";addCash 100") and tycoon.GetCash(owner) == 1112,
    "resolved bootstrap ID credits same session"
)
check(
    admin.HandleCommand(owner, ";addCash 1000000000") and tycoon.GetCash(owner) == 1000001112,
    "ceiling is inclusive and failed commands do not consume cooldown"
)
local spoof = makePlayer(706, "Eatandpoop")
check(not admin.HandleCommand(spoof, ";addCash 1"), "matching name cannot substitute for canonical ID")
clock += 1
local function chat(p, text)
    if modern then
        local command = services.TextChatService:FindFirstChild("Admin_addcash")
        setup(command and command.PrimaryAlias == ";addcash", "modern command registered")
        command.Triggered:Fire({ UserId = p.UserId }, text)
    else
        p.Chatted:Fire(text)
    end
end
chat(owner, ";addCash 25")
check(tycoon.GetCash(teammate) == 1000001137, "server chat callback dispatches through cash authority")
chat(visitor, ";addCash 25")
check(tycoon.GetCash(visitor) == 0, "chat invocation independently enforces permissions")
chat(owner, "normal chat")
check(tycoon.GetCash(owner) == 1000001137, "ordinary chat leaves gameplay unchanged")
players.PlayerRemoving:Fire(owner)
owner.Parent = nil
chat(owner, ";addCash 25")
check(tycoon.GetCash(teammate) == 1000001137, "departed player cannot execute")
owner.Parent = players
players.PlayerAdded:Fire(owner)
check(admin.HandleCommand(owner, ";addCash 1"), "rejoining player has no stale cooldown")
admin.Init({})
for _, name in config.BootstrapUsernames do
    check(lookups[name] == 1, "bootstrap identity resolved once: " .. name)
end
