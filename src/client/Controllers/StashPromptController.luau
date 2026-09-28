--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy).NormalStash
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Constants.Upgrades)
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
        return if definition then definition.DisplayName or id else id
    end
    local function update(prompt: ProximityPrompt)
        local slot = prompt.Parent
        if not slot then
            visible[prompt] = nil
            return
        end
        local player = Players.LocalPlayer
        local heldAttribute = player:GetAttribute("HeldIngredientId")
        local held = if typeof(heldAttribute) == "string" then heldAttribute else nil
        local heldType = player:GetAttribute("HeldItemType")
        local slotType = slot:GetAttribute("StashItemType")
        local idAttribute = slot:GetAttribute("StashIngredientId")
        local id = if typeof(idAttribute) == "string" then idAttribute else nil
        local countAttribute = slot:GetAttribute("StashCount")
        local count = if typeof(countAttribute) == "number" then countAttribute else 0
        local now = workspace:GetServerTimeNow()
        local session = player:GetAttribute("PlotSessionId")
        local friendly = session ~= nil and session == slot:GetAttribute("StashSessionId")
        local capacityAttribute = slot:GetAttribute("StashCapacity")
        local capacity = if typeof(capacityAttribute) == "number" then capacityAttribute else Config.IngredientCapacity
        local carryCapacity = player:GetAttribute("CarryCapacity") or Upgrades.CarryCapacity[1].Value
        local full = (player:GetAttribute("CarryCount") or 0) >= carryCapacity
        local direction = if heldType or held then "STORE" else "TAKE"
        if
            player:GetAttribute("StashDirectionSessionId") == session
            and now < (player:GetAttribute("StashDirectionExpiresAt") or 0)
        then
            direction = player:GetAttribute("StashDirection") or direction
        end
        if not session or not slot:GetAttribute("StashSessionId") then
            prompt.ActionText = "Unavailable"
        elseif not friendly then
            local raidEnd = slot:GetAttribute("StashRaidEndsAt") or 0
            local protectionEnd = slot:GetAttribute("StashProtectionEndsAt") or 0
            if slot:GetAttribute("StashProtected") or (now >= raidEnd and now < protectionEnd) then
                prompt.ActionText = "Protected"
            elseif full then
                prompt.ActionText = "Inventory full"
            else
                prompt.ActionText = if count > 0 then "Steal" else "Empty slot"
            end
        elseif direction == "TAKE" then
            if full then
                prompt.ActionText = "Inventory full"
            elseif slotType == "Smoothie" and count > 0 then
                prompt.ActionText = "Take smoothie"
            elseif id and count > 0 then
                prompt.ActionText = "Take " .. label(id) .. " (" .. count .. "/" .. capacity .. ")"
            else
                prompt.ActionText = "Hold an item to store"
            end
        elseif not held and heldType ~= "Smoothie" then
            prompt.ActionText = "Hold an item to store"
        elseif heldType == "Smoothie" then
            prompt.ActionText = if count > 0 then "Slot occupied" else "Store smoothie"
        elseif slotType == "Smoothie" then
            prompt.ActionText = "Slot occupied"
        elseif count >= capacity then
            prompt.ActionText = "Slot full (" .. count .. "/" .. capacity .. ")"
        elseif held then
            prompt.ActionText = "Store "
                .. label(held)
                .. (if count > 0 then " (" .. count .. "/" .. capacity .. ")" else "")
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
