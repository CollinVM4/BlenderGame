--!strict
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local DevContentService = {}
local deps: any
function DevContentService.Init(services)
    deps = services
end
function DevContentService.IsEnabled(): boolean
    return RunService:IsStudio() and ServerStorage:GetAttribute("EnableDevContent") == true
end
local function allowed(player: Player): boolean
    return DevContentService.IsEnabled() and player.Parent == game:GetService("Players")
end
function DevContentService.ResetBlender(player: Player): boolean
    if not allowed(player) then
        return false
    end
    deps.BlendService.Reset(player)
    return true
end
function DevContentService.SpawnIngredient(player: Player, id: string): Instance?
    if not allowed(player) then
        return nil
    end
    deps.TycoonService.AssignPlot(player)
    local stage = deps.TycoonService.GetReference(player, "IngredientSpawn")
    if not stage then
        warn("[DevContentService] Missing IngredientSpawn staging surface in your plot")
        return nil
    end
    if not deps.IngredientService.GetDefinition(id) then
        warn("[DevContentService] Unknown ingredient: " .. tostring(id))
        return nil
    end
    return deps.IngredientService.Spawn(id, stage.CFrame * CFrame.new(0, stage.Size.Y / 2 + 2, 0), player)
end
function DevContentService.PrepareCombination(player: Player, ids: { string }): boolean
    if not allowed(player) or #ids < 1 or #ids > Economy.MaxIngredients then
        return false
    end
    for _, id in ids do
        if not deps.IngredientService.GetDefinition(id) then
            return false
        end
    end
    deps.TycoonService.AssignPlot(player)
    local stage = deps.TycoonService.GetReference(player, "IngredientSpawn")
    if not stage then
        warn("[DevContentService] Missing IngredientSpawn staging surface in your plot")
        return false
    end
    deps.InventoryService.ClearHeld(player)
    deps.IngredientService.RemovePlayer(player)
    deps.BlendService.Reset(player)
    for index, id in ids do
        local at = stage.CFrame * CFrame.new((index - (#ids + 1) / 2) * 3, stage.Size.Y / 2 + 2, 0)
        if not deps.IngredientService.Spawn(id, at, player) then
            deps.IngredientService.RemovePlayer(player)
            return false
        end
    end
    return true
end
function DevContentService.SpawnCustomer(player: Player): Model?
    if not allowed(player) then
        return nil
    end
    local existing = deps.CustomerService.GetSnapshot(player)
    if existing then
        return existing.Model
    end
    local ok, reason
    if deps.GameService.IsServing(player) then
        ok = deps.GameService.ResumeDay(player)
    else
        ok, reason = deps.GameService.StartDay(player)
    end
    if not ok then
        warn("[DevContentService] " .. (reason or "Customer spawn failed; check plot markers"))
        return nil
    end
    local customer = deps.CustomerService.GetSnapshot(player)
    return customer and customer.Model
end
function DevContentService.ForceReaction(player: Player, reaction: string?): boolean
    return allowed(player) and deps.CustomerService.SetForcedReaction(player, reaction)
end
function DevContentService.ResetScene(player: Player): boolean
    if not allowed(player) then
        return false
    end
    deps.InventoryService.ClearHeld(player)
    deps.GameService.Reset(player)
    deps.BlendService.Reset(player)
    deps.BlendService.ClearCup(player)
    deps.IngredientService.RemovePlayer(player)
    return true
end
-- Keep legacy names callable; all aliases retain the same Studio/opt-in gate.
DevContentService.ClearBlender = DevContentService.ResetBlender
DevContentService.ResetPlot = DevContentService.ResetScene
return DevContentService
