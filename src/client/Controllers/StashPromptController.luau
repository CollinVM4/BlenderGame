--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true

    local visible: { [ProximityPrompt]: boolean } = {}
    local function update(prompt: ProximityPrompt)
        local slot = prompt.Parent
        if not slot then
            visible[prompt] = nil
            return
        end
        local player = Players.LocalPlayer
        local session = player:GetAttribute("PlotSessionId")
        local friendly = session ~= nil and session == slot:GetAttribute("StashSessionId")
        local direction = if friendly and (player:GetAttribute("HeldItemType") or player:GetAttribute("HeldIngredientId"))
            then "STORE"
            else "TAKE"
        if friendly
            and player:GetAttribute("StashDirectionSessionId") == session
            and workspace:GetServerTimeNow() < (player:GetAttribute("StashDirectionExpiresAt") or 0)
        then
            direction = player:GetAttribute("StashDirection") or direction
        end
        prompt.ActionText = direction
    end

    ProximityPromptService.PromptShown:Connect(function(prompt)
        if prompt:GetAttribute("PlayerStashPrompt") then
            visible[prompt] = true
            update(prompt)
        end
    end)
    ProximityPromptService.PromptHidden:Connect(function(prompt)
        visible[prompt] = nil
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0
        for prompt in visible do
            update(prompt)
        end
    end)
end

return Controller
