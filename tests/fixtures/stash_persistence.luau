-- Detached DataStore double: callbacks see the latest value and may be retried.
env.os.time = os.time
local storedStashes = {}
local storeFailure = false
local beforeStoreUpdate
local function detached(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in value do
        copy[key] = detached(item)
    end
    return copy
end
local stashStore = {
    UpdateAsync = function(_, key, transform)
        if storeFailure then
            error("DataStore unavailable")
        end
        if beforeStoreUpdate then
            local callback = beforeStoreUpdate
            beforeStoreUpdate = nil
            callback(key)
        end
        local result = transform(detached(storedStashes[key]))
        if result ~= nil then
            storedStashes[key] = detached(result)
        end
        return detached(result)
    end,
}
services.DataStoreService = {
    GetDataStore = function(_, name)
        setup(name == "PlayerStash_v1", "dedicated stash store")
        return stashStore
    end,
}
local shutdown
env.game.BindToClose = function(_, callback)
    shutdown = callback
end
