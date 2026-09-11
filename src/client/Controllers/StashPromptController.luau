--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local Controller = {}
local started = false
function Controller.Init()
    if started then
        return
    end
    started = true
    local visible: { [ProximityPrompt]: boolean } = {}
    local function label(id: string): string
        local definition = Definitions[id]
        return if definition then definition.DisplayName else id
    end
    local function update(prompt: ProximityPrompt)
        local slot = prompt.Parent
        if not slot then
            visible[prompt] = nil
            return
        end
        local player = Players.LocalPlayer
        local held = player:GetAttribute("HeldIngredientId")
        local id = slot:GetAttribute("StashIngredientId")
        local count = slot:GetAttribute("StashCount") or 0
        if slot:GetAttribute("StashOwnerUserId") ~= player.UserId then
            prompt.ActionText = "Owner only"
        elseif held then
            if count >= 5 then
                prompt.ActionText = "Slot full (5/5)"
            elseif id and id ~= held then
                prompt.ActionText = "Different ingredient"
            else
                prompt.ActionText = "Store " .. label(held) .. (if count > 0 then " (" .. count .. "/5)" else "")
            end
        elseif id and count > 0 then
            prompt.ActionText = "Take " .. label(id) .. " (" .. count .. "/5)"
        else
            prompt.ActionText = "Hold an ingredient to store"
        end
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
