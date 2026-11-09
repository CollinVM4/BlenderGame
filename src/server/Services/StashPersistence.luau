--!strict
-- A stash belongs to its founding owner's progression, even after promotion.
-- Acquire and create are one UpdateAsync: failed reads never mean "new player".
local Persistence = {}
local profiles: { [number]: any } = {}
local store: GlobalDataStore?
local LEASE_SECONDS = 180

local function database(): GlobalDataStore
    if not store then
        store = game:GetService("DataStoreService"):GetDataStore("PlayerStash_v1")
    end
    return store :: GlobalDataStore
end

function Persistence.Open(userId: number, create: () -> any): (any?, string?)
    if profiles[userId] then
        return nil, "StashAlreadyActive"
    end
    local profile: any = { Token = game:GetService("HttpService"):GenerateGUID(false), UserId = userId, Opening = true }
    profiles[userId] = profile
    local ok, result = pcall(function()
        return database():UpdateAsync("Player_" .. userId, function(old: any, info: DataStoreKeyInfo?)
            if old ~= nil and (type(old) ~= "table" or old.Version ~= 1 or type(old.Slots) ~= "table") then
                error("UnsupportedStashRecord") -- preserve existing data; never replace with starters
            end
            if old and old.Lock and old.Lock.Token ~= profile.Token and old.Lock.ExpiresAt > os.time() then
                return nil
            end
            local record: any = if old then table.clone(old) else { Version = 1, Slots = create() }
            record.Lock = { Token = profile.Token, ExpiresAt = os.time() + LEASE_SECONDS }
            return record, if info then info:GetUserIds() else { userId }, if info then info:GetMetadata() else {}
        end)
    end)
    if not ok or not result then
        profiles[userId] = nil
        return nil, if ok then "StashInUse" else tostring(result)
    end
    profile.Opening = false
    profile.Slots, profile.ExpiresAt = result.Slots, result.Lock.ExpiresAt
    return profile
end

function Persistence.IsWritable(profile: any): boolean
    return not profile.Opening and not profile.Closing and profile.ExpiresAt > os.time()
end

-- The caller supplies detached, DataStore-safe records; later mutations cannot
-- change an in-flight save. Staging during a write remains pending for the next save.
function Persistence.Stage(profile: any, slots: any)
    profile.Slots = slots
end

function Persistence.Save(profile: any, closing: boolean?): boolean
    if profile.Saving then
        return false
    end
    profile.Saving = true
    local slots = profile.Slots
    local ok, result = pcall(function()
        return database():UpdateAsync("Player_" .. profile.UserId, function(old: any, info: DataStoreKeyInfo?)
            if not old or not old.Lock or old.Lock.Token ~= profile.Token or old.Lock.ExpiresAt <= os.time() then
                return nil
            end
            local record = table.clone(old)
            record.Slots = slots
            record.Lock = if closing then nil else { Token = profile.Token, ExpiresAt = os.time() + LEASE_SECONDS }
            return record,
                if info then info:GetUserIds() else { profile.UserId },
                if info then info:GetMetadata() else {}
        end)
    end)
    profile.Saving = false
    if not ok or not result then
        warn("[StashPersistence] Save failed user=" .. profile.UserId .. " reason=" .. tostring(result))
        return false
    end
    if closing then
        profiles[profile.UserId] = nil
    else
        profile.ExpiresAt = result.Lock.ExpiresAt
    end
    return true
end

function Persistence.Close(profile: any)
    profile.Closing = true
    while profile.Saving do
        task.wait()
    end
    for attempt = 1, 3 do
        if Persistence.Save(profile, true) then
            return
        end
        task.wait(attempt)
    end
    -- Keep the lease/profile on failure. It cannot be opened again in this server
    -- or silently replaced; the periodic writer and shutdown will retry release.
end

function Persistence.Init()
    local elapsed = 0
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 30 then
            return
        end
        elapsed = 0
        for _, profile in profiles do
            if not profile.Opening then
                task.spawn(function()
                    Persistence.Save(profile, profile.Closing)
                end)
            end
        end
    end)
    game:BindToClose(function()
        local pending = 0
        for _, profile in profiles do
            if not profile.Opening then
                pending += 1
                task.spawn(function()
                    Persistence.Close(profile)
                    pending -= 1
                end)
            end
        end
        while pending > 0 do
            task.wait()
        end
    end)
end

return Persistence
