local p = instance("Player")
p.UserId = 1
local film = loadModule("FilmingUtil")
film.Init()
-- Run the real client startup with a fake replicated boundary and sprint controller.
do
    local remote = shared.Events:FindFirstChild("GameplayPresentation")
    film.Init()
    check(#shared.Events:GetChildren() == 1, "repeated filming Init keeps a single presentation remote")
    local connections, received = 0, 0
    local listener
    remote.OnClientEvent = {
        Connect = function(_, callback)
            connections += 1
            listener = callback
        end,
        Fire = function(_, ...)
            received += 1
            listener(...)
        end,
    }
    local fakeEvents = {
        WaitForChild = function(_, name)
            assert(name == "GameplayPresentation")
            return remote
        end,
    }
    local fakeShared = {
        WaitForChild = function(_, name)
            assert(name == "Events")
            return fakeEvents
        end,
    }
    local fakeReplicated = {
        WaitForChild = function(_, name)
            assert(name == "Shared")
            return fakeShared
        end,
    }
    local controllerChunk = assert(loadstring(sources.GameplayPresentationController, "GameplayPresentationController"))
    setfenv(
        controllerChunk,
        setmetatable({
            game = {
                GetService = function(_, name)
                    assert(name == "ReplicatedStorage")
                    return fakeReplicated
                end,
            },
        }, { __index = env })
    )
    local controller = controllerChunk()
    local sprintStarted = false
    local bootstrap = assert(loadstring(sources.ClientBootstrap, "ClientBootstrap"))
    setfenv(
        bootstrap,
        setmetatable({
            script = { Controllers = parent },
            require = function(name)
                if name == "GameplayPresentationController" then
                    return controller
                end
                if name ~= "SprintController" then
                    -- Other controllers have independent suites; additions need no fixture edits here.
                    return { Init = function() end }
                end
                return {
                    Init = function()
                        sprintStarted = true
                    end,
                }
            end,
        }, { __index = env })
    )
    bootstrap()
    controller.Init()
    check(sprintStarted, "presentation startup does not block sprint initialization")
    flush()
    check(connections == 1, "client bootstrap attaches exactly one presentation listener")
    for _, moment in
        {
            "BlendStarted",
            "BlendProgressChanged",
            "BlendCompleted",
            "SmoothieDispensed",
            "CustomerReaction",
            "FutureKind",
        }
    do
        check(pcall(listener, moment, p.UserId, {}), "listener safely accepts " .. moment)
    end
    check(pcall(listener, nil, nil, nil), "malformed presentation is safely ignored")
    remote:FireAllClients("FutureKind", p.UserId, {})
    check(received == 1, "server broadcast reaches client listener")
    table.remove(presentation) -- Synthetic event is not a gameplay transaction.
end
