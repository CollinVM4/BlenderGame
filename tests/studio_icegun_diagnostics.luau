-- Studio Play Command Bar only; run once on Server, then once on Client.
-- Read-only snapshot. Enable IceGunConfig.DebugLogging before starting a fresh Play.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local revision = "icegun-circle-2026-10-09"
local function inspectModule(module)
    if not module then
        warn("[IceGun snapshot] MISSING module")
        return
    end
    local ok, source = pcall(function()
        return module.Source
    end)
    print(
        "[IceGun snapshot] module",
        module:GetFullName(),
        "current revision",
        ok and string.find(source, revision, 1, true) ~= nil
    )
end
local function inspectTool(player)
    print(
        "[IceGun snapshot] player",
        player.Name,
        "ownership",
        player:GetAttribute("IceGunOwnership"),
        "Stunned",
        player:GetAttribute("Stunned"),
        "Frozen",
        player:GetAttribute("Frozen")
    )
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    print(
        "[IceGun snapshot] character",
        character,
        "health",
        humanoid and humanoid.Health,
        "PlatformStand",
        humanoid and humanoid.PlatformStand
    )
    for _, container in { character, player:FindFirstChildOfClass("Backpack") } do
        if container then
            for _, tool in container:GetChildren() do
                if tool:IsA("Tool") and tool.Name == "IcicleGun" then
                    local handle = tool:FindFirstChild("Handle")
                    local barrel = handle and handle:FindFirstChild("GunBarrel")
                    print(
                        "[IceGun snapshot] Tool",
                        tool:GetFullName(),
                        "issue",
                        tool:GetAttribute("IceGunIssueId"),
                        "weapon",
                        tool:GetAttribute("IceGunWeapon"),
                        "Enabled",
                        tool.Enabled,
                        "ManualActivationOnly",
                        tool.ManualActivationOnly,
                        "RequiresHandle",
                        tool.RequiresHandle,
                        "muzzle/root distance",
                        if barrel and root then (barrel.WorldPosition - root.Position).Magnitude else nil
                    )
                end
            end
        end
    end
end
print("[IceGun snapshot] side", if RunService:IsServer() then "server" else "client")
local fireRemotes = 0
for _, child in ReplicatedStorage:GetChildren() do
    if child.Name == "IceGunFire" then
        fireRemotes += 1
        print("[IceGun snapshot] remote", child:GetFullName(), child.ClassName)
    end
end
print("[IceGun snapshot] IceGunFire count (expected 1)", fireRemotes)
if RunService:IsServer() then
    local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
    local services = server and server:FindFirstChild("Services")
    if services then
        inspectModule(services:FindFirstChild("IceGunService"))
        inspectModule(services:FindFirstChild("IceGunProjectileService"))
        local gun = require(services.IceGunService)
        local movement = require(services.MovementService)
        local tycoon = require(services.TycoonService)
        for _, player in Players:GetPlayers() do
            inspectTool(player)
            print(
                "[IceGun snapshot] session",
                tycoon.GetSessionId(player),
                "action allowed",
                movement.CanPerformGameplayAction(player),
                "exact issued equipped",
                gun.GetEquipped(player)
            )
        end
    else
        warn("[IceGun snapshot] Server.Services missing")
    end
else
    local player = Players.LocalPlayer
    local scripts = player:FindFirstChild("PlayerScripts")
    local client = scripts and scripts:FindFirstChild("Client")
    local controllers = client and client:FindFirstChild("Controllers")
    inspectModule(controllers and controllers:FindFirstChild("IceGunController"))
    inspectTool(player)
    local input = game:GetService("UserInputService")
    print(
        "[IceGun snapshot] preferred input",
        input.PreferredInput,
        "mouse behavior",
        input.MouseBehavior,
        "mouse location",
        input:GetMouseLocation(),
        "cursor visible",
        input.MouseIconEnabled
    )
end
