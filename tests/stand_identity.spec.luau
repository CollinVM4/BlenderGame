-- Observable zone/session/rename contracts. Geometry and filtering are engine doubles.
env.task.spawn = function(callback)
    local ok, err = coroutine.resume(coroutine.create(callback))
    assert(ok, err)
end
local t = dependency.TycoonService
local owner, peer, other = player(), player(), player()
local plot, second = t.GetPlot(owner), t.GetPlot(peer)
for _, p in { owner, peer, other } do
    t.RemovePlayer(p)
    p.Parent, p.Character.Parent = services.Players, workspaceFake
end
owner.DisplayName = "Collin"
services.CollectionService:AddTag(plot, "PlayerPlot")
services.CollectionService:AddTag(second, "PlayerPlot")
env.typeof = function(value)
    return if type(value) == "table" and value.IsA then "Instance" else type(value)
end
env.Enum.TextFilterContext = { PublicChat = "PublicChat" }
services.Players.GetPlayers = function()
    return { owner, peer, other }
end
services.Players.PlayerRemoving = signal()
local filter = function(text)
    return text
end
local filterCalls = 0
services.TextService = {
    FilterStringAsync = function(_, text, id, mode)
        check(id == owner.UserId and mode == "PublicChat", "filter uses author and public context")
        filterCalls += 1
        return {
            GetNonChatStringForBroadcastAsync = function()
                return filter(text)
            end,
        }
    end,
}
local intros = {}
local original = env.Instance.new
env.Instance.new = function(class)
    local object = original(class)
    if class == "RemoteEvent" then
        object.FireClient = function(_, p, target, id, revision)
            table.insert(intros, { p, target, id, revision })
        end
    end
    return object
end
local function authored(target)
    local identity = instance("Folder")
    identity.Name, identity.Parent = "PlotIdentity", target
    local claim = part("ClaimZone", identity)
    local join = part("TeammateZone", identity)
    local visual = part("ClaimVisual", identity)
    local teamVisual = part("TeammateVisual", identity)
    claim.Size, join.Size = vec(8, 8, 8), vec(8, 8, 8)
    join.CFrame = frame(20, 0, 0)
    claim.CFrame.PointToObjectSpace = function(_, point)
        return point
    end
    join.CFrame.PointToObjectSpace = function(_, point)
        return point - vec(20, 0, 0)
    end
    visual.Transparency, teamVisual.Transparency = 0.3, 0.4
    return claim, join, visual, teamVisual
end
local claim, join, visual, teamVisual = authored(plot)
local secondClaim = authored(second)
secondClaim.CFrame.PointToObjectSpace = function(_, point)
    return point - vec(100, 0, 0)
end
local zones = loadModule("PlotClaimZones")
zones.Init(dependency)
local names = loadModule("StandIdentityService")
names.Init(dependency)
local function context()
    local captured = t.GetRequestContext(owner)
    captured.StandNameRevision = plot:GetAttribute("StandNameRevision")
    return captured
end
local movement = loadModule("MovementService")
movement.SetStunned(owner, true)
check(not zones.Enter(owner, plot, claim), "zone entry preserves existing stunned-player restriction")
movement.SetStunned(owner, false)
zones.Refresh(plot)
check(
    claim:GetAttribute("PlotZoneActive")
        and not join:GetAttribute("PlotZoneActive")
        and visual.Transparency == 0.3
        and teamVisual.Transparency == 1,
    "empty plot exposes only claim pad"
)
owner.Character:FindFirstChildOfClass("Humanoid").Health = 0
check(not zones.Enter(owner, plot, claim), "dead character cannot claim")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 100
check(not zones.Enter(owner, second, claim), "zone must belong to exact plot")
zones.Step()
check(
    t.GetOwner(plot) == owner and t.GetPlot(peer) == nil and t.GetPlot(other) == nil,
    "simultaneous entrants commit one owner"
)
check(
    #intros == 1 and intros[1][1] == owner and intros[1][3] == t.GetSessionId(owner),
    "only committed winner receives intro"
)
zones.Step()
check(#intros == 1, "remaining inside never repeats intro")
check(
    plot:GetAttribute("StandName") == "Collin's Stand" and t.GetSession(owner).StandName == "Collin's Stand",
    "DisplayName default exists without editor"
)
check(
    not claim:GetAttribute("PlotZoneActive")
        and join:GetAttribute("PlotZoneActive")
        and visual.Transparency == 1
        and teamVisual.Transparency == 0.4,
    "owner-only exposes teammate pad"
)
owner.Character:FindFirstChild("HumanoidRootPart").Position = vec(100, 0, 0)
check(not zones.Enter(owner, second, secondClaim), "assigned owner cannot claim elsewhere")
owner.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, 0)
peer.Character:FindFirstChild("HumanoidRootPart").Position = vec(100, 0, 0)
check(not zones.Enter(peer, plot, join), "outside character cannot join")
peer.Character:FindFirstChild("HumanoidRootPart").Position = vec(20, 0, 0)
check(
    zones.Enter(peer, plot, join) and t.GetSessionId(peer) == t.GetSessionId(owner),
    "walk-in joins existing open session"
)
zones.Refresh(plot)
check(not join:GetAttribute("PlotZoneActive") and teamVisual.Transparency == 1, "full plot hides teammate pad")
check(not names.RequestName(peer, plot, "Peer name", context()), "teammate cannot rename")
t.RemovePlayer(peer)
zones.Refresh(plot)
check(join:GetAttribute("PlotZoneActive") and teamVisual.Transparency == 0.4, "departure restores join pad")
local config = loadModule("StandIdentity")
check(config.MaxCharacters == 27, "stand name contract is 27 visible characters")
check(
    config.DefaultName(string.rep("e\u{301}", 25)) == string.rep("e\u{301}", 19) .. "'s Stand",
    "long platform defaults fit limit and retain suffix"
)
check(config.Normalize("") == nil and config.Normalize("a") == "a", "empty rejected; one character accepted")
for _, grapheme in { "é", "e\u{301}", "😀", "👍🏽", "👩‍👩‍👧‍👦", "🇺🇸" } do
    local maximum = string.rep(grapheme, config.MaxCharacters)
    check(
        config.Count(maximum) == config.MaxCharacters and config.Normalize(maximum) == maximum,
        "27 complete graphemes accepted"
    )
    check(config.Normalize(maximum .. grapheme) == nil, "server rejects 28th grapheme")
    check(config.Truncate(maximum .. grapheme) == maximum, "editor truncation preserves UTF-8 clusters")
end
check(config.Normalize(string.rep("a", 50)) == nil, "exploit length is rejected rather than truncated")
check(config.Normalize("\u{A0}Shop\u{3000}") == "Shop", "Unicode whitespace normalized and trimmed")
check(
    config.Normalize("a\u{2028}b") == nil and config.Normalize("a\0b") == nil,
    "Unicode line separators and controls rejected"
)
local sanitizer = loadModule("StandNameSanitizer")
check(sanitizer.Mask("The Fucking Blender") == "The **** Blender", "explicit inflection masked")
check(
    sanitizer.Mask("ass class Scunthorpe bass passion") == "**** class Scunthorpe bass passion",
    "whole tokens avoid substring false positives"
)
check(sanitizer.Mask("The f.u.c.k Stand") == "The **** Stand", "obvious punctuation bypass masked")
check(sanitizer.Mask("F.u.c.k.i.n.g a.s.s.h.o.l.e") == "**** ****", "punctuated inflections mask whole known words")
check(
    sanitizer.Mask("compass-fuckery éfuck f u c k") == "compass-fuckery éfuck f u c k",
    "longer words and unrelated words remain intact"
)
check(config.Normalize("  Super Smoothies  ") == "Super Smoothies", "trim name")
check(
    config.Normalize(string.rep("é", config.MaxCharacters)) ~= nil
        and config.Normalize(string.rep("a", config.MaxCharacters + 1)) == nil,
    "limit counts UTF-8 characters"
)
check(config.Normalize("\255") == nil and config.Normalize("a\nb") == nil, "invalid UTF-8 and controls rejected")
check(not names.RequestName(owner, plot, "   ", context()) and filterCalls == 0, "blank input never reaches filter")
filter = function()
    return "Super Smoothies"
end
check(names.RequestName(owner, plot, "  raw name  ", context()), "filtered rename commits")
check(plot:GetAttribute("StandName") == "Super Smoothies", "only filtered result is replicated")
now += 2
local filterAsync = services.TextService.FilterStringAsync
services.TextService.FilterStringAsync = function()
    error("initial filtering outage")
end
check(
    not names.RequestName(owner, plot, "Other", context()) and plot:GetAttribute("StandName") == "Super Smoothies",
    "initial Roblox filter failure retains authoritative name"
)
services.TextService.FilterStringAsync = filterAsync
now += 2
local calls = filterCalls
check(
    not names.RequestName(owner, plot, string.rep("x", 50), context()) and filterCalls == calls,
    "oversized exploit rejected before Roblox filter"
)
now += 2
filter = function()
    error("filter outage")
end
check(
    not names.RequestName(owner, plot, "Other", context()) and plot:GetAttribute("StandName") == "Super Smoothies",
    "filter error retains prior name"
)
now += 2
filter = function()
    return "#####"
end
check(
    names.RequestName(owner, plot, "Other", context()) and plot:GetAttribute("StandName") == "****",
    "already censored broadcast output becomes stars"
)
now += 2
filter = function(text)
    check(text == "The **** Blender", "custom mask precedes Roblox filtering")
    return "The #### Blender"
end
check(names.RequestName(owner, plot, "The Fucking Blender", context()), "profanity is masked rather than rejected")
check(
    plot:GetAttribute("StandName") == "The **** Blender" and t.GetSession(owner).StandName == "The **** Blender",
    "only safe display value reaches session and replication"
)
now += 2
filter = function(text)
    return text
end
local expanded = "ass " .. string.rep("x", config.MaxCharacters - 4)
local success, safe = names.RequestName(owner, plot, expanded, context())
check(
    success and config.Count(safe) == config.MaxCharacters and string.sub(safe, 1, 4) == "****",
    "mask expansion fits validated final name without a profanity error"
)
now += 2
filter = function()
    return "Super Smoothies"
end
names.RequestName(owner, plot, "Restore", context())
now += 2
filter = function(text)
    coroutine.yield()
    return text
end
local saved
local captured = context()
local pendingSave = coroutine.create(function()
    saved = names.RequestName(owner, plot, "Old save", captured)
end)
check(coroutine.resume(pendingSave), "filter yields")
check(not names.RequestName(owner, plot, "Duplicate", captured), "duplicate save rejected while filtering")
t.SetJoinMode(owner, "Closed", t.GetRequestContext(owner))
check(
    coroutine.resume(pendingSave) and not saved and plot:GetAttribute("StandName") == "Super Smoothies",
    "revision change invalidates pending filter"
)
now += 2
pendingSave = coroutine.create(function()
    saved = names.RequestName(owner, plot, "Old lifetime", context())
end)
coroutine.resume(pendingSave)
t.RemovePlayer(owner)
zones.Refresh(plot)
check(
    claim:GetAttribute("PlotZoneActive")
        and visual.Transparency == 0.3
        and not join:GetAttribute("PlotZoneActive")
        and plot:GetAttribute("StandName") == nil,
    "final cleanup restores unclaimed identity"
)
check(
    t.ClaimPlot(owner, plot, { ClaimRevision = plot:GetAttribute("PlotClaimRevision") }),
    "replacement session claims"
)
check(
    coroutine.resume(pendingSave) and not saved and plot:GetAttribute("StandName") == "Collin's Stand",
    "old filter cannot write into replacement session"
)
now += 2
filter = function(text)
    return text
end
captured = context()
check(names.RequestName(owner, plot, string.rep("a", config.MaxCharacters), captured), "maximum length accepted")
now += 2
check(not names.RequestName(owner, plot, "Stale", captured), "old stand revision cannot overwrite newer name")

-- Existing FriendsOnly policy may yield. Zone sampling still records one entry.
t.SetJoinMode(owner, "FriendsOnly", t.GetRequestContext(owner))
local friendshipCalls, friendThread = 0, nil
peer.IsFriendsWithAsync = function()
    friendshipCalls += 1
    friendThread = coroutine.running()
    coroutine.yield()
    return true
end
zones.Step()
zones.Step()
check(friendshipCalls == 1, "repeated zone samples do not duplicate yielding join")
t.SetJoinMode(owner, "Closed", t.GetRequestContext(owner))
check(
    coroutine.resume(friendThread) and t.GetPlot(peer) == nil,
    "pending zone join cannot adopt a newer policy revision"
)
