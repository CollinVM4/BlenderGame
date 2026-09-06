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
    local input = deps.TycoonService.GetReference(player, "BlenderInput")
    if not input then
        warn("[DevContentService] Missing BlenderInput")
        return nil
    end
    return deps.IngredientService.Spawn(id, input.CFrame * CFrame.new(0, 4, 0), player)
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
    local input = deps.TycoonService.GetReference(player, "BlenderInput")
    if not input then
        warn("[DevContentService] Missing BlenderInput")
        return false
    end
    deps.IngredientService.RemovePlayer(player)
    deps.BlendService.Reset(player)
    for _, id in ids do
        local object = deps.IngredientService.Spawn(id, input.CFrame, player)
        if not object or not deps.BlendService.TryInput(player, object, input) then
            if object then
                deps.IngredientService.Consume(object)
            end
            deps.BlendService.Reset(player)
            return false
        end
    end
    return deps.BlendService.Ready(player)
end
function DevContentService.SpawnCustomer(player: Player): Model?
    if not allowed(player) then
        return nil
    end
    return deps.CustomerService.SpawnForPlayer(player)
end
function DevContentService.ForceReaction(player: Player, reaction: string?): boolean
    return allowed(player) and deps.CustomerService.SetForcedReaction(player, reaction)
end
function DevContentService.ResetScene(player: Player): boolean
    if not allowed(player) then
        return false
    end
    deps.GameService.Reset(player)
    deps.BlendService.Reset(player)
    deps.BlendService.ClearCup(player)
    deps.IngredientService.RemovePlayer(player)
    return true
end
return DevContentService
