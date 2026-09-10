--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StudioServices = require(script.Services.StudioServices)
StudioServices.BeginBootstrap()
local services: { [string]: any } = {
    PlayerDataService = require(script.Services.PlayerDataService),
    MovementService = require(script.Services.MovementService),
    SprintService = require(script.Services.SprintService),
    TycoonService = require(script.Services.TycoonService),
    IngredientService = require(script.Services.IngredientService),
    InventoryService = require(script.Services.InventoryService),
    BlendService = require(script.Services.BlendService),
    CustomerService = require(script.Services.CustomerService),
    GameService = require(script.Services.GameService),
    MarketService = require(script.Services.MarketService),
    CombatService = require(script.Services.CombatService),
    DevContentService = require(script.Services.DevContentService),
    GameplayService = require(script.Services.GameplayService),
}

require(script.Services.FilmingUtil).Init()

-- Inject dependencies once; service modules never require one another in cycles.
services.MovementService.Init(services)
services.SprintService.Init(services)
services.TycoonService.Init(services.PlayerDataService)
for _, name in
    { "InventoryService", "BlendService", "GameService", "MarketService", "CombatService", "DevContentService" }
do
    services[name].Init(services)
end
services.CustomerService.Init(services, services.GameService.CustomerServed, services.GameService.IsServing)

-- Migrate existing named plot fixtures to tags without yielding for absent assets.
local folder = workspace:FindFirstChild("Plots")
local roots = if folder then folder:GetChildren() else {}
local direct = workspace:FindFirstChild("Blender")
if direct then
    table.insert(roots, direct)
end
for _, plot in roots do
    services.TycoonService.AutoTagLegacyPlot(plot)
end

local characterConnections: { [Player]: RBXScriptConnection } = {}
local initialized: { [Player]: boolean } = {}
local function addPlayer(player: Player)
    if initialized[player] then
        return
    end
    initialized[player] = true
    services.PlayerDataService.AddPlayer(player)
    services.MovementService.RefreshPlayer(player)
    services.InventoryService.AddPlayer(player)
    services.BlendService.Reset(player)
    services.GameService.AddPlayer(player)
    services.TycoonService.AssignPlot(player)
    local function onCharacterAdded(character: Model)
        services.BlendService.ClearCup(player)
        services.InventoryService.DropHeld(player)
        player:SetAttribute("StunnedUntil", 0)
        services.MovementService.ApplyCharacter(player, character)
        services.SprintService.ResetCharacter(player)
    end
    characterConnections[player] = player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end
Players.PlayerAdded:Connect(addPlayer)
for _, player in Players:GetPlayers() do
    addPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end
    for _, name in
        {
            "CustomerService",
            "GameService",
            "BlendService",
            "CombatService",
            "InventoryService",
            "IngredientService",
            "GameplayService",
            "TycoonService",
            "SprintService",
            "MovementService",
            "PlayerDataService",
        }
    do
        services[name].RemovePlayer(player)
    end
    initialized[player] = nil
end)

if RunService:IsStudio() then
    require(script.Services.StudioJumpTestService).Init(services)
end
services.GameplayService.Init(services)
local components: { { Init: (any) -> () } } = {
    require(script.Components.Dispenser),
    require(script.Components.BlenderInput),
    require(script.Components.IngredientPickup),
    require(script.Components.IngredientSpawn),
    require(script.Components.TurbineWheel),
    require(script.Components.BlendProgressLights),
    require(script.Components.BlendVFX),
    require(script.Components.DispenseButton),
    require(script.Components.MarketPedestal),
    require(script.Components.Stash),
    require(script.Components.DayButton),
}
for _, component in components do
    component.Init(services)
end
StudioServices.Publish(services)
print("[Be a Blender!] MVP services initialized. Persistence is in-memory; see docs/MVP_ARCHITECTURE.md.")
