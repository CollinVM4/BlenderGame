--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Hud = require(script.Parent.Parent.UI.LuckyBlockHud)
local Messages = require(script.Parent.Parent.UI.LuckyBlockMessages)
local Controller = {}
local connection: RBXScriptConnection? = nil
function Controller.Init()
    if connection then
        return
    end
    local player = Players.LocalPlayer
    local view: { Gui: ScreenGui, Render: ({ Messages.Entry }) -> (), Destroy: () -> () }? = nil
    local elapsed = 0
    local function refresh()
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if view and (not playerGui or not view.Gui:IsDescendantOf(playerGui)) then
            view.Destroy()
            view = nil
        end
        if not playerGui then
            return
        end
        if not view then
            view = Hud.Create(playerGui)
        end
        local current = view
        if current then
            current.Render(Messages.Read(function(name)
                return player:GetAttribute(name)
            end, workspace:GetServerTimeNow()))
        end
    end
    refresh()
    connection = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 0.1 then
            elapsed = 0
            refresh()
        end
    end)
end
return Controller
