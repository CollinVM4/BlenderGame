--!strict
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Events = game:GetService("ReplicatedStorage").Shared.Events
local FilmingUtil = {}
local remote: RemoteEvent?

function FilmingUtil.Init()
    local event = Instance.new("RemoteEvent")
    event.Name = "GameplayPresentation"
    event.Parent = Events
    remote = event
end

-- Output only: no OnServerEvent listener, reward requests, or mutable service records.
function FilmingUtil.Emit(player: Player, moment: string, payload: any)
    if remote then
        remote:FireAllClients(moment, player.UserId, payload)
    end
end

function FilmingUtil.Log(scope: string, message: string)
    if RunService:IsStudio() and ServerStorage:GetAttribute("DebugFilmLoop") == true then
        print(string.format("[%s] %s", scope, message))
    end
end

return FilmingUtil
