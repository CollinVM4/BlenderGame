--!strict
-- One module instance per client. Only Warm may prepare or evict; Lease/Release
-- never clone, destroy, yield, or schedule work.
local Viewport = require(script.Parent.IngredientViewport)
local Cache = { Capacity = 24, CopiesPerIngredient = 3, BuildInterval = 0.1 }
local entries: { any } = {}
local queue: { any } = {}
local retryAt: { [string]: number } = {}
local nextBuild = 0
local serial = 0
local stats = { Builds = 0, Destroys = 0, Hits = 0, Misses = 0, WorstBuildMs = 0, Attempts = 0 }

function Cache.Snapshot(): any
    local snapshot: any = table.clone(stats)
    snapshot.Count, snapshot.Leased, snapshot.Pending = #entries, 0, #queue
    for _, entry in entries do
        if entry.Owner then
            snapshot.Leased += 1
        end
    end
    return snapshot
end

function Cache.Release(owner: any)
    for _, entry in entries do
        if entry.Owner == owner then
            entry.Preview.Release()
            entry.Owner = nil
        end
    end
end

function Cache.Lease(owner: any, image: ImageLabel, id: string): boolean
    for _, entry in entries do
        if entry.Id == id and not entry.Owner then
            serial += 1
            entry.Used, entry.Owner = serial, owner
            entry.Preview.Attach(image)
            stats.Hits += 1
            return true
        end
    end
    stats.Misses += 1
    return false
end

-- Requests describe only currently eligible nearby views. Rebuilding the one
-- deduplicated queue cancels stale tier/output/removal work immediately.
function Cache.Warm(requests: { any }, blocked: boolean, now: number)
    table.clear(queue)
    if blocked then
        return
    end
    local priorities: { [string]: number } = {}
    for _, request in requests do
        priorities[request.Id] = math.max(priorities[request.Id] or -math.huge, request.Priority)
    end
    local ordered = {}
    for id, priority in priorities do
        table.insert(ordered, { Id = id, Priority = priority })
    end
    table.sort(ordered, function(a, b)
        return if a.Priority == b.Priority then a.Id < b.Id else a.Priority > b.Priority
    end)
    -- Keep a stable working set rather than endlessly evicting a full tier.
    local desired: { [string]: boolean } = {}
    for index = 1, math.min(#ordered, math.floor(Cache.Capacity / Cache.CopiesPerIngredient)) do
        local request = ordered[index]
        desired[request.Id] = true
        local copies = 0
        for _, entry in entries do
            if entry.Id == request.Id then
                copies += 1
            end
        end
        if copies < Cache.CopiesPerIngredient and now >= (retryAt[request.Id] or 0) then
            table.insert(queue, request)
        end
    end
    if #queue == 0 or now < nextBuild then
        return
    end
    nextBuild = now + Cache.BuildInterval -- No accumulated/catch-up burst.
    if #entries >= Cache.Capacity then
        local victim: number? = nil
        for index, entry in entries do
            if not entry.Owner and not desired[entry.Id] then
                if not victim or entry.Used < entries[victim].Used then
                    victim = index
                end
            end
        end
        if not victim then
            return
        end
        local removed = assert(table.remove(entries, victim))
        removed.Preview.Destroy()
        stats.Destroys += 1
    end
    local id = queue[1].Id
    local started = os.clock()
    local preview = Viewport.Prepare(id)
    stats.WorstBuildMs = math.max(stats.WorstBuildMs, (os.clock() - started) * 1000)
    stats.Attempts += 1
    if not preview then
        retryAt[id] = now + 5
        return
    end
    serial += 1
    table.insert(entries, { Id = id, Preview = preview, Used = serial })
    stats.Builds += 1
end

function Cache.Dispose()
    for _, entry in entries do
        entry.Preview.Destroy()
        stats.Destroys += 1
    end
    table.clear(entries)
    table.clear(queue)
    table.clear(retryAt)
    nextBuild = 0
end

return Cache
