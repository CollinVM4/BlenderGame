--!strict
local Players = game:GetService("Players")
local RespawnConfig = require(game:GetService("ReplicatedStorage").Shared.Constants.RespawnConfig)
local StudioServices = require(script.Services.StudioServices)
StudioServices.BeginBootstrap()
Players.RespawnTime = RespawnConfig.RespawnDelaySeconds
local services: { [string]: any } = {
    AdminService = require(script.Admin.AdminService),
    AnnouncementService = require(script.Services.AnnouncementService),
    DiscoveryService = require(script.Services.DiscoveryService),
    PlayerDataService = require(script.Services.PlayerDataService),
    MovementService = require(script.Services.MovementService),
    RagdollService = require(script.Services.RagdollService),
    FallDamageService = require(script.Services.FallDamageService),
    HealthRegenService = require(script.Services.HealthRegenService),
    CharacterPhysicsService = require(script.Services.CharacterPhysicsService),
    SprintService = require(script.Services.SprintService),
    TycoonService = require(script.Services.TycoonService),
    InitialSpawnService = require(script.Services.InitialSpawnService),
    TutorialService = require(script.Services.TutorialService),
    IngredientService = require(script.Services.IngredientService),
    PlayerHeadDropService = require(script.Services.PlayerHeadDropService),
    FarmService = require(script.Services.FarmService),
    SmoothieWorldItemService = require(script.Services.SmoothieWorldItemService),
    InventoryService = require(script.Services.InventoryService),
    BlendService = require(script.Services.BlendService),
    MuncherService = require(script.Services.MuncherService),
    CustomerService = require(script.Services.CustomerService),
    GameService = require(script.Services.GameService),
    MarketService = require(script.Services.MarketService),
    CombatService = require(script.Services.CombatService),
    IceGunService = require(script.Services.IceGunService),
    IceGunProjectileService = require(script.Services.IceGunProjectileService),
    IceGunEffects = require(script.Services.IceGunEffects),
    FreezeStatusService = require(script.Services.FreezeStatusService),
    DevContentService = require(script.Services.DevContentService),
    GameplayService = require(script.Services.GameplayService),
}

require(script.Services.FilmingUtil).Init()
require(script.Services.GameplaySfxService).Init()
require(script.Services.PlayerOnlyCollisionService).Init()

-- Inject dependencies once; service modules never require one another in cycles.
services.AnnouncementService.Init(services)
services.IngredientService.Init(services)
services.PlayerHeadDropService.Init(services)
services.DiscoveryService.Init(services)
services.MovementService.Init(services)
services.SprintService.Init(services)
services.PlayerDataService.BindRuntimeAuthority(services.TycoonService)
services.InitialSpawnService.Init(services)
services.TutorialService.Init(services)
services.TycoonService.Init({
    SessionStarted = function(player)
        services.FarmService.StartSession(player)
        services.BlendService.Reset(player)
        services.MuncherService.Reset(player)
        local seeded, reason = services.InventoryService.InitializeTutorialStash(player)
        if not seeded then
            warn("[TutorialInit] Starter stash unavailable: " .. tostring(reason))
            return false
        end
        services.CustomerService.ActivateForPlayer(player, true)
        services.TutorialService.MembershipChanged(player)
        return true
    end,
    MemberChanged = function(player)
        services.InventoryService.BindPlayer(player)
        services.InitialSpawnService.ClearReservation(player)
        services.TutorialService.MembershipChanged(player)
        services.MovementService.RefreshPlayer(player)
        services.CombatService.RefreshPlayer(player)
        services.BlendService.BindPlayer(player)
        services.CustomerService.BindPlayer(player)
    end,
    MemberRemoved = function(player)
        services.TutorialService.MembershipChanged(player)
        services.MovementService.RefreshPlayer(player)
        services.CombatService.RefreshPlayer(player)
        services.BlendService.RemovePlayer(player)
        services.CustomerService.RemovePlayer(player)
        services.MuncherService.RemovePlayer(player)
    end,
    SessionEnded = function(id)
        services.FarmService.CleanupSession(id)
        services.InventoryService.CleanupSession(id)
        services.CustomerService.CleanupSession(id)
        services.BlendService.CleanupSession(id)
        services.MuncherService.CleanupSession(id)
    end,
})
for _, name in
    {
        "InventoryService",
        "BlendService",
        "MuncherService",
        "GameService",
        "MarketService",
        "CombatService",
        "DevContentService",
        "FallDamageService",
    }
do
    services[name].Init(services)
end
services.FreezeStatusService.Init(services)
services.IceGunProjectileService.Init(services)
services.IceGunService.Init(services)
services.HealthRegenService.Init()
services.AdminService.Init(services)
services.CustomerService.Init(services, services.GameService.CustomerServed, services.GameService.IsServing)

-- Migrate existing named plot fixtures to tags without yielding for absent assets.
local folder = workspace:FindFirstChild("Plots")
local roots = if folder then folder:GetChildren() else {}
for _, plot in game:GetService("CollectionService"):GetTagged("PlayerPlot") do
    if not table.find(roots, plot) then
        table.insert(roots, plot)
    end
end
local direct = workspace:FindFirstChild("Blender")
if direct then
    table.insert(roots, direct)
end
for _, plot in roots do
    services.TycoonService.AutoTagLegacyPlot(plot)
end
services.FarmService.Init(services)
require(script.Services.StashExpansionService).Init(services)

local characterConnections: { [Player]: RBXScriptConnection } = {}
local removingConnections: { [Player]: RBXScriptConnection } = {}
local initialized: { [Player]: boolean } = {}
local function addPlayer(player: Player)
    if initialized[player] then
        return
    end
    initialized[player] = true
    services.TutorialService.AddPlayer(player)
    services.PlayerDataService.AddPlayer(player)
    services.DiscoveryService.PlayerAdded(player)
    services.TycoonService.RefreshUpgradeAttributes(player)
    services.MovementService.RefreshPlayer(player)
    services.IceGunService.AddPlayer(player)
    services.InventoryService.AddPlayer(player)
    services.GameService.AddPlayer(player)
    local function onCharacterAdded(character: Model)
        services.InitialSpawnService.ApplyCharacter(player, character)
        services.TutorialService.ApplyCharacter(player, character)
        services.PlayerHeadDropService.ApplyCharacter(player, character)
        services.CharacterPhysicsService.ApplyCharacter(player, character, services.RagdollService.PrepareCharacter)
        services.InventoryService.CleanupCharacter(player)
        services.FreezeStatusService.ApplyCharacter(player, character)
        services.IceGunService.ApplyCharacter(player, character)
        services.CombatService.ApplyCharacter(player, character)
        services.MovementService.ApplyCharacter(player, character)
        services.SprintService.ResetCharacter(player)
        services.FallDamageService.ApplyCharacter(player, character)
        services.HealthRegenService.ApplyCharacter(player, character)
    end
    removingConnections[player] = player.CharacterRemoving:Connect(services.RagdollService.CleanupCharacter)
    characterConnections[player] = player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end
Players.PlayerAdded:Connect(addPlayer)
for _, player in Players:GetPlayers() do
    addPlayer(player)
end
require(script.Services.JackedNoobService).Init(services)
Players.PlayerRemoving:Connect(function(player)
    services.InitialSpawnService.RemovePlayer(player)
    services.TutorialService.RemovePlayer(player)
    services.TycoonService.RemovePlayer(player, function()
        if characterConnections[player] then
            characterConnections[player]:Disconnect()
            characterConnections[player] = nil
        end
        if removingConnections[player] then
            removingConnections[player]:Disconnect()
            removingConnections[player] = nil
        end
        if player.Character then
            services.RagdollService.CleanupCharacter(player.Character)
        end
        for _, name in
            {
                "CustomerService",
                "GameService",
                "BlendService",
                "MuncherService",
                "IceGunService",
                "IceGunProjectileService",
                "FreezeStatusService",
                "CombatService",
                "InventoryService",
                "IngredientService",
                "PlayerHeadDropService",
                "GameplayService",
                "SprintService",
                "MovementService",
                "CharacterPhysicsService",
                "DiscoveryService",
                "PlayerDataService",
                "FallDamageService",
                "HealthRegenService",
            }
        do
            services[name].RemovePlayer(player)
        end
        initialized[player] = nil
    end)
end)

services.GameplayService.Init(services)
require(script.Services.StandIdentityService).Init(services)
require(script.Services.PlotClaimZones).Init(services)
local components: { { Init: (any) -> () } } = {
    require(script.Components.Dispenser),
    require(script.Components.BlenderInput),
    require(script.Components.Muncher),
    require(script.Components.BlenderVacuum),
    require(script.Components.IngredientPickup),
    require(script.Components.SmoothiePickup),
    require(script.Components.IngredientSpawn),
    require(script.Components.AnnouncedIngredientSpawn),
    require(script.Components.TurbineWheel),
    require(script.Components.BlendProgressLights),
    require(script.Components.BlenderReadyIndicator),
    require(script.Components.BlenderStatusPresentation),
    require(script.Components.BlendVFX),
    require(script.Components.DispenseButton),
    require(script.Components.MarketPedestal),
    require(script.Components.IceGunDisplay),
    require(script.Components.BlenderKillScript),
    require(script.Components.Stash),
    require(script.Components.DayButton),
}
for _, component in components do
    component.Init(services)
end
StudioServices.Publish(services)
print("[Be a Blender!] MVP services initialized. Persistence is in-memory; see docs/MVP_ARCHITECTURE.md.")
