--!strict
-- No service requires here. Bootstrap owns initialization and publishes its live instances.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StudioServices = {}
local isRuntime = false
local bridgeName = "StudioServiceCalls"

local function assertStudioServer()
    assert(
        RunService:IsStudio() and RunService:IsServer() and RunService:IsRunning(),
        "[StudioServices] Use the Server Command Bar in Play mode"
    )
end

function StudioServices.BeginBootstrap()
    if RunService:IsStudio() then
        assertStudioServer()
        isRuntime = true
    end
end

function StudioServices.Publish(services: { [string]: any })
    if not RunService:IsStudio() then
        return
    end
    assertStudioServer()
    assert(isRuntime, "[StudioServices] Only server bootstrap can publish services")
    assert(not ServerStorage:FindFirstChild(bridgeName), "[StudioServices] Runtime already published")
    local bridge = Instance.new("BindableFunction")
    bridge.Name = bridgeName
    bridge.OnInvoke = function(serviceName: string, methodName: string, ...: any)
        assertStudioServer()
        assert(methodName ~= "Init", "[StudioServices] Service initialization belongs to bootstrap")
        local service = services[serviceName]
        local method = service and service[methodName]
        assert(type(method) == "function", "[StudioServices] Unknown service method")
        return method(...)
    end
    -- Parent only after the callback is ready; tooling never waits on an unbound callback.
    bridge.Parent = ServerStorage
end

function StudioServices.Wrap(name: string, service: any): any
    if not RunService:IsStudio() or isRuntime then
        return service
    end
    local proxy = {}
    for methodName, method in service do
        if type(method) == "function" then
            proxy[methodName] = function(...: any)
                assertStudioServer()
                assert(methodName ~= "Init", "[StudioServices] Service initialization belongs to bootstrap")
                local bridge = ServerStorage:FindFirstChild(bridgeName)
                assert(
                    bridge and bridge:IsA("BindableFunction"),
                    "[StudioServices] Runtime unavailable; wait for the server initialized message"
                )
                return bridge:Invoke(name, methodName, ...)
            end
        end
    end
    return proxy
end

return StudioServices
