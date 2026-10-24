-- Initial server projection and real upgrade requests, including missing/broken Bat assets.
local tycoon = dependency.TycoonService
local movement = loadModule("MovementService")
local combat = loadModule("CombatService")
local display = loadModule("UpgradeDisplay")
local upgrades = loadModule("Upgrades")
local sprintConfig = loadModule("SprintConfig")
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
local initialCash = 6000
for _, id in { "Jump", "Bat", "MovementSpeed", "SprintStamina" } do
    for _, tier in upgrades[id] do
        initialCash += tier.Cost
    end
end
tycoon.SetCash(actor, initialCash)
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
local sprintRemote = { OnServerEvent = signal() }
shared.Events.SprintEvents = "SprintEvents"
cache.SprintEvents = function()
    return sprintRemote
end
local sprint = loadModule("SprintService")
dependency.SprintService = sprint
sprint.Init(dependency)
sprint.ResetCharacter(actor)
local remote = shared.Events:FindFirstChild("GameplayRequest")
local response
remote.FireClient = function(_, recipient, action, value)
    setup(recipient == actor and action == "PurchaseUpgradeResult", "upgrade response delivered")
    response = value
end
local function purchase(id, tier)
    now += 0.2
    response = nil
    local beforeCash = tycoon.GetCash(actor)
    remote.OnServerEvent:Fire(actor, "PurchaseUpgrade", id, tier, tycoon.GetRequestContext(actor))
    check(response and response.success and response.level == tier - 1, "valid response for " .. id)
    check(row(id).Level == tier - 1, "replicated purchased tier for " .. id)
    check(tycoon.GetCash(actor) == beforeCash - upgrades[id][tier].Cost, "charges next catalog row once")
end
purchase("SprintStamina", 2)
check(movement.GetMaxStamina(actor) == 65 and row("SprintStamina").Price == 2000, "sprint value and next price")
purchase("Jump", 2)
check(humanoid.JumpPower == 85 and row("Jump").Price == upgrades.Jump[3].Cost, "jump value and next price")
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
for _, case in
    {
        { Id = "MovementSpeed", Rows = 16, Base = 26, Max = 41, Increment = 1, Total = 408000 },
        { Id = "SprintStamina", Rows = 15, Base = 60, Max = 130, Increment = 5, Total = 261500 },
    }
do
    local track = upgrades[case.Id]
    check(#track == case.Rows and track[1].Cost == 0 and track[1].Value == case.Base, "free base and catalog depth")
    check(track[#track].Value == case.Max, "preserves top-end stat")
    local total = 0
    for index = 2, #track do
        check(
            track[index].Value - track[index - 1].Value == case.Increment and track[index].Cost > track[index - 1].Cost,
            "uniform stat increments and increasing marginal prices"
        )
        total += track[index].Cost
    end
    check(total == case.Total, "approved full-track cost")
    for tier = tycoon.GetUpgrade(actor, case.Id) + 1, #track do
        purchase(case.Id, tier)
        if tier == 6 then
            if case.Id == "MovementSpeed" then
                -- SprintService owns the Humanoid speed application.
                loadModule("SprintService").ApplySpeed(actor)
                check(
                    humanoid.WalkSpeed == 31 and row(case.Id).Current == "SPEED 31",
                    "purchased speed step five applies"
                )
                check(
                    movement.GetSprintWalkSpeed(actor) == 31 * sprintConfig.SPRINT_SPEED_MULTIPLIER,
                    "mid-table speed retains sprint multiplier"
                )
            else
                check(
                    movement.GetMaxStamina(actor) == 85 and row(case.Id).Current == "STAMINA 85",
                    "purchased stamina step five applies"
                )
            end
        end
    end
    local beforeCash = tycoon.GetCash(actor)
    now += 0.2
    remote.OnServerEvent:Fire(actor, "PurchaseUpgrade", case.Id, #track + 1, tycoon.GetRequestContext(actor))
    check(
        response and not response.success and response.reason == "MaxLevel" and row(case.Id).Max,
        "past-end purchase reports MAX"
    )
    check(
        tycoon.GetCash(actor) == beforeCash and tycoon.GetUpgrade(actor, case.Id) == #track,
        "MAX rejection preserves cash and ownership"
    )
end
check(tycoon.GetCash(actor) == 6000, "all successful upgrades spend exact configured prices")

-- Studio tools accept the whole catalog without changing purchased ownership.
services.RunService.IsRunning = function()
    return true
end
services.RunService.IsServer = function()
    return true
end
services.Players.GetPlayers = function()
    return { actor }
end
env.typeof = function(value)
    return if type(value) == "table" and value.ClassName then "Instance" else typeof(value)
end
local dev = loadModule("DevContentService")
dev.Init(dependency)
studio = true
for _, case in
    {
        { Id = "MovementSpeed", Set = dev.SetMovementSpeedLevel },
        { Id = "SprintStamina", Set = dev.SetSprintStaminaLevel },
        { Id = "Jump", Set = dev.SetJumpLevel },
    }
do
    local track = upgrades[case.Id]
    local purchasedHeadline = row(case.Id).Current
    local middle = math.floor((#track - 1) / 2)
    for _, step in { 0, middle, #track - 1 } do
        check(case.Set(actor, step), "debug setter accepts catalog step")
        check(actor:GetAttribute(case.Id .. "Level") == step, "debug effective step is published")
        check(
            tycoon.GetUpgrade(actor, case.Id) == #track and row(case.Id).Current == purchasedHeadline,
            "effective override never changes purchased shop stat"
        )
        if case.Id == "MovementSpeed" then
            check(humanoid.WalkSpeed == track[step + 1].Value, "debug speed applies catalog value")
        elseif case.Id == "SprintStamina" then
            check(
                sprint.GetSnapshot(actor).StaminaCurrent == track[step + 1].Value,
                "debug stamina fills catalog capacity"
            )
        else
            check(humanoid.JumpPower == track[step + 1].Value, "debug Jump keeps capability tiers")
        end
    end
    for _, invalid in { -1, 0.5, #track, math.huge, 0 / 0 } do
        check(not case.Set(actor, invalid), "debug rejects invalid or past-end steps")
        check(not pcall(movement.SetStudioLevel, actor, case.Id, invalid), "movement validates catalog bounds too")
    end
end
movement.ResetStudioOverrides(actor)
studio = false
sprint.ResetCharacter(actor)
sprintRemote.OnServerEvent:Fire(actor, true)
services.RunService.Heartbeat:Fire(6.25)
check(
    sprint.GetSnapshot(actor).IsSprinting and sprint.GetSnapshot(actor).StaminaCurrent == 5,
    "top-end stamina lasts beyond six seconds"
)
services.RunService.Heartbeat:Fire(0.25)
check(
    not sprint.GetSnapshot(actor).IsSprinting
        and sprint.GetSnapshot(actor).StaminaCurrent == 0
        and humanoid.WalkSpeed == 41,
    "top-end exhausts at 6.5 seconds and restores purchased speed"
)
