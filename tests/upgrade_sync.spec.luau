-- Initial server projection and real upgrade requests, including missing/broken Bat assets.
local tycoon = dependency.TycoonService
local movement = loadModule("MovementService")
local combat = loadModule("CombatService")
local display = loadModule("UpgradeDisplay")
dependency.MovementService, dependency.CombatService, dependency.PlayerDataService = movement, combat, dataService
movement.Init(dependency)
combat.Init(dependency)
workspaceFake.Gravity = 196.2
tycoon.Init({
    MemberChanged = function(p)
        movement.RefreshPlayer(p)
        combat.RefreshPlayer(p)
    end,
})
local actor = instance("Player")
actor.UserId, actor.Name, actor.Parent, actor.Neutral = 12345, "NewArrival", services.Players, true
actor.Character = instance("Model")
local humanoid = instance("Humanoid")
humanoid.Parent, humanoid.Health, humanoid.UseJumpPower = actor.Character, 100, true
part("HumanoidRootPart", actor.Character)
local backpack = instance("Backpack")
backpack.Parent = actor
-- Match the bootstrap: personal data, authoritative upgrade projection, movement.
dataService.AddPlayer(actor)
tycoon.RefreshUpgradeAttributes(actor)
movement.RefreshPlayer(actor)
combat.RefreshPlayer(actor)
local function row(id)
    local track
    for _, definition in display.Tracks do
        if definition.Id == id then
            track = definition
        end
    end
    return display.Row(id, actor:GetAttribute(id .. "PurchasedLevel"), actor:GetAttribute(track.Attribute))
end
check(tycoon.GetSessionId(actor) == nil, "arrival does not allocate a plot")
for _, id in { "SprintStamina", "Jump", "Bat" } do
    check(row(id) ~= nil and row(id).Level == 0, "unassigned server projection loads " .. id)
end
check(backpack:FindFirstChild("Bat") == nil, "new level-zero arrival has no bat")
local plot = instance("Model")
plot.Name, plot.Parent = "UpgradeSyncPlot", workspaceFake
services.CollectionService:AddTag(plot, "PlayerPlot")
setup(tycoon.AssignPlot(actor, plot) == plot, "claim active plot")
tycoon.SetCash(actor, 50000)
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "RemoteEvent" then
        object.OnServerEvent = signal()
    end
    return object
end
local gameplay = loadModule("GameplayService")
gameplay.Init(dependency)
local remote = shared.Events:FindFirstChild("GameplayRequest")
local response
remote.FireClient = function(_, recipient, action, value)
    setup(recipient == actor and action == "PurchaseUpgradeResult", "upgrade response delivered")
    response = value
end
local function purchase(id, tier)
    now += 0.2
    response = nil
    remote.OnServerEvent:Fire(actor, "PurchaseUpgrade", id, tier, tycoon.GetRequestContext(actor))
    check(response and response.success and response.level == tier - 1, "valid response for " .. id)
    check(row(id).Level == tier - 1, "replicated purchased tier for " .. id)
end
purchase("SprintStamina", 2)
check(movement.GetMaxStamina(actor) == 80 and row("SprintStamina").Price == 5000, "sprint values/prices unchanged")
purchase("Jump", 2)
check(humanoid.JumpPower == 85 and row("Jump").Price == 5000, "jump values/prices unchanged")
purchase("Bat", 2)
check(
    not backpack:FindFirstChild("Bat") and tycoon.GetUpgrade(actor, "Bat") == 2,
    "absent asset does not roll back purchase"
)
purchase("Jump", 3)
purchase("SprintStamina", 3)
check(
    row("Bat").Level == 1 and row("Jump").Level == 2 and row("SprintStamina").Level == 2,
    "absent asset never blocks shared state"
)
local malformed = instance("Tool")
malformed.Name, malformed.Parent = "Bat", storage
purchase("Bat", 3)
purchase("Jump", 4)
check(row("Jump").Max and row("Bat").Level == 2, "malformed asset does not wedge transaction/response")
local handle = part("Handle", malformed)
local hitbox = part("Hitbox", malformed)
hitbox.Size, hitbox.CFrame = vec(0.867, 0.597, 4.703), frame(0.2, 0.1, -2.35)
handle.Archivable = false
purchase("Bat", 4)
check(
    row("Bat").Max and not backpack:FindFirstChild("Bat"),
    "nonarchivable child fails granting but preserves level-three response"
)
handle.Archivable = true
combat.RefreshPlayer(actor)
local bat = backpack:FindFirstChild("Bat")
check(bat and bat:GetAttribute("BatLevel") == 3, "fixed root-level asset grants purchased level")
check(
    math.abs(bat:FindFirstChild("Hitbox").Size.Z - 4.703 * 1.25) < 0.0001,
    "level three derives from authored baseline"
)
check(
    math.abs(bat:FindFirstChild("Hitbox").CFrame.Position.Z - (-2.35 * 1.25)) < 0.0001,
    "authored hitbox offset scales with tool"
)
purchase("SprintStamina", 4)
check(tycoon.GetCash(actor) == 6000, "all successful upgrades spend exact configured prices")
