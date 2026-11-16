--!strict
-- Temporary, opt-in Studio diagnostics. Set Workspace.ProfilePlotClaim before Play.
-- No remotes, gameplay changes, hot-path prints, or descendant scans of its own.
local RunService = game:GetService("RunService")
local enabled = RunService:IsStudio() and workspace:GetAttribute("ProfilePlotClaim") == true
local Profile = {}
local CAPACITY = 12000
local rows: { any } = {}
local cursor, total = 0, 0
local frozen = false
local claimAt: number? = nil
local clientStarted = false
type Scope = { At: number, Name: string, Counts: { [string]: number }, Parent: Scope? }
local active: { [thread]: Scope? } = {}

local function record(row: any)
    if not enabled or frozen then
        return
    end
    row.At = row.At or os.clock()
    -- Clock for cross-process alignment; durations always use local os.clock.
    row.ServerAt = workspace:GetServerTimeNow() - (os.clock() - row.At)
    cursor = cursor % CAPACITY + 1
    rows[cursor] = row
    total += 1
end

function Profile.Mark(name: string, detail: any?)
    if not enabled or frozen then
        return
    end
    record({ Kind = "mark", Name = name, Detail = detail })
end

function Profile.Count(name: string, amount: number?)
    if not enabled or frozen then
        return
    end
    local scope: Scope? = active[coroutine.running()]
    while scope do
        scope.Counts[name] = (scope.Counts[name] or 0) + (amount or 1)
        scope = scope.Parent
    end
end

-- Only wrap synchronous callbacks: yielding phases use paired Mark calls instead.
function Profile.Wrap(name: string, callback: any): any
    if not enabled then
        return callback
    end
    return function(...: any): ...any
        if frozen then
            return callback(...)
        end
        local thread = coroutine.running()
        local scope: Scope = { At = os.clock(), Name = name, Counts = {}, Parent = active[thread] }
        active[thread] = scope
        debug.profilebegin("Claim/" .. name)
        local result = table.pack(pcall(callback, ...))
        debug.profileend()
        active[thread] = scope.Parent
        record({ Kind = "work", Name = name, At = scope.At, Ms = (os.clock() - scope.At) * 1000, Counts = scope.Counts })
        if not result[1] then
            error(result[2], 0)
        end
        return table.unpack(result, 2, result.n)
    end
end

function Profile.Snapshot(): { any }
    local snapshot = {}
    local count = math.min(total, CAPACITY)
    for index = 1, count do
        table.insert(snapshot, rows[(cursor - count + index - 1) % CAPACITY + 1])
    end
    return snapshot
end

function Profile.Dump()
    if not enabled then
        return
    end
    frozen = true
    local snapshot = Profile.Snapshot()
    local longest = 0
    local longestFrame: any = nil
    for _, row in snapshot do
        if row.Kind == "frame" and row.Name == "PreRender" and claimAt and row.At >= claimAt then
            if row.Ms > longest then
                longest, longestFrame = row.Ms, row
            end
        end
    end
    local overlap: { [string]: any } = {}
    local intervals: { { number } } = {}
    if longestFrame then
        local first, last = longestFrame.At, longestFrame.At + longestFrame.Ms / 1000
        for _, row in snapshot do
            if row.Kind == "work" then
                local left, right = math.max(first, row.At), math.min(last, row.At + row.Ms / 1000)
                if right > left then
                    table.insert(intervals, { left, right })
                    local group = overlap[row.Name] or { Calls = 0, InclusiveMs = 0, Counts = {} }
                    group.Calls += 1
                    group.InclusiveMs += (right - left) * 1000
                    for key, count in row.Counts do
                        group.Counts[key] = (group.Counts[key] or 0) + count
                    end
                    overlap[row.Name] = group
                end
            end
        end
    end
    table.sort(intervals, function(a, b)
        return a[1] < b[1]
    end)
    local unionSeconds, coveredUntil = 0, -math.huge
    for _, interval in intervals do
        unionSeconds += math.max(0, interval[2] - math.max(interval[1], coveredUntil))
        coveredUntil = math.max(coveredUntil, interval[2])
    end
    local json = game:GetService("HttpService")
    local side = if RunService:IsClient() then "client" else "server"
    print("[ClaimProfile] " .. json:JSONEncode({
        Side = side,
        BaseCommit = "42d136f57c0167abaa6d6c05fdfd09e66d254155",
        Retained = #snapshot,
        Overwritten = math.max(0, total - CAPACITY),
        LongestPostClaimPreRenderMs = longest,
        LongestFrame = longestFrame,
        OverlappingWork = overlap,
        WorkIntervalUnionMs = unionSeconds * 1000,
    }))
    -- Print only after capture is frozen. Chunk to avoid Studio Output truncation.
    for index = 1, #snapshot, 12 do
        local chunk = {}
        for offset = index, math.min(index + 11, #snapshot) do
            table.insert(chunk, snapshot[offset])
        end
        print("[ClaimProfile/" .. side .. "] " .. json:JSONEncode(chunk))
    end
end

function Profile.Claim(name: string, detail: any?)
    if not enabled or claimAt then
        return
    end
    claimAt = os.clock()
    Profile.Mark(name, detail)
    task.delay(if RunService:IsClient() then 10 else 15, function()
        frozen = true
        Profile.Dump()
    end)
end

function Profile.ObservePad(pad: BasePart)
    if not enabled then
        return
    end
    pad.AttributeChanged:Connect(function(attribute)
        if string.sub(attribute, 1, 5) == "Stash" then
            Profile.Mark(
                "pad.attribute",
                { Pad = pad:GetFullName(), Key = attribute, Value = pad:GetAttribute(attribute) }
            )
        end
    end)
end

function Profile.InitClient(registry: any?)
    if not enabled or clientStarted then
        return
    end
    clientStarted = true
    if registry then
        registry.SetClaimProfile(Profile)
    end
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local adds: { [string]: number } = {}
    local function added(prefix: string, object: Instance)
        if frozen then
            return
        end
        local key = prefix .. object.ClassName
        adds[key] = (adds[key] or 0) + 1
    end
    playerGui.DescendantAdded:Connect(function(object)
        added("PlayerGui/", object)
    end)
    workspace.DescendantAdded:Connect(function(object)
        added("Workspace/", object)
    end)
    local collection = game:GetService("CollectionService")
    local function observePlot(plot: Instance)
        plot.AttributeChanged:Connect(function(key)
            if
                key == "OwnerUserId"
                or key == "PlotSessionId"
                or key == "PlotOccupancy"
                or key == "PlotMembershipRevision"
                or key == "StandName"
                or key == "StandNameRevision"
            then
                Profile.Mark("plot.attribute", { Plot = plot:GetFullName(), Key = key, Value = plot:GetAttribute(key) })
            end
        end)
    end
    for _, plot in collection:GetTagged("PlayerPlot") do
        observePlot(plot)
    end
    collection:GetInstanceAddedSignal("PlayerPlot"):Connect(observePlot)
    for _, attribute in { "PlotSessionId", "TutorialStage", "TutorialHintReady", "TutorialActive", "TutorialStashSlot" } do
        player:GetAttributeChangedSignal(attribute):Connect(function()
            Profile.Mark("player.attribute", { Key = attribute, Value = player:GetAttribute(attribute) })
        end)
    end
    local previousRender, previousHeartbeat = os.clock(), os.clock()
    RunService.PreRender:Connect(function()
        local now = os.clock()
        record({
            Kind = "frame",
            Name = "PreRender",
            At = previousRender,
            Ms = (now - previousRender) * 1000,
            Counts = adds,
        })
        adds = {}
        previousRender = now
    end)
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - previousHeartbeat >= 0.05 then
            record({ Kind = "frame", Name = "Heartbeat", At = previousHeartbeat, Ms = (now - previousHeartbeat) * 1000 })
        end
        previousHeartbeat = now
    end)
end

return Profile
