--!strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.LuckyBlockConfig)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    local models: { [Model]: boolean } = {}
    local function add(object: Instance)
        if object:IsA("Model") then
            models[object] = true
        end
    end
    CollectionService:GetInstanceAddedSignal(Config.WorldTag):Connect(add)
    CollectionService:GetInstanceRemovedSignal(Config.WorldTag):Connect(function(object)
        if object:IsA("Model") then
            models[object] = nil
        end
    end)
    for _, object in CollectionService:GetTagged(Config.WorldTag) do
        add(object)
    end
    RunService.RenderStepped:Connect(function()
        local now = workspace:GetServerTimeNow()
        for model in models do
            local origin = model:GetAttribute("LuckyBlockOrigin")
            local spawned = model:GetAttribute("LuckyBlockSpawnTime")
            if model:IsDescendantOf(workspace) and typeof(origin) == "CFrame" and typeof(spawned) == "number" then
                local elapsed = now - spawned
                local bob = math.sin(elapsed * 2 * math.pi / Config.Animation.BobPeriodSeconds)
                    * Config.Animation.BobAmplitude
                model:PivotTo(
                    origin
                        * CFrame.new(0, bob, 0)
                        * CFrame.Angles(0, math.rad(elapsed * Config.Animation.RotationDegreesPerSecond), 0)
                )
            end
        end
    end)
end

return Controller
