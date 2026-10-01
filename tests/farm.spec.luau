-- Real farm, shared cash/session, inventory consumption, and ingredient spawning.
-- Engine signals, authored geometry and elapsed time are controlled at the boundary.
local tycoon = dependency.TycoonService
local config = loadModule("FarmConfig")
local audio = loadModule("GameplaySfxService")
local sounds = {}
audio.Emit = function(id, position)
    table.insert(sounds, { Id = id, Position = position })
end
local owner, humanoid = player()
local peer = player()
local outsider = player()
tycoon.RemovePlayer(peer)
setup(tycoon.JoinSession(peer, owner, tycoon.GetRequestContext(owner)), "join farm team")
local plot = tycoon.GetPlot(owner)
local folder = instance("Folder")
folder.Name, folder.Parent = "Farm", plot
local rows = {}
for index = 1, 3 do
    local row = instance("Model")
    row.Name, row.Parent = "Row" .. index, folder
    local pad = part("PurchasePoint" .. index, row)
    pad.Touched = signal()
    local visual = instance("Model")
    visual.Name, visual.Parent = "Visual", row
    local dirt = part("Dirt", visual)
    dirt.CFrame = frame(index, 7, 3)
    local markers = part("FarmMarkers", row)
    local plantPoint = instance("Attachment")
    plantPoint.Name, plantPoint.Parent, plantPoint.WorldPosition = "PlantPoint", markers, vec(0, 0, 0)
    for n = 1, 3 do
        local growPoint = instance("Attachment")
        growPoint.Name, growPoint.Parent = "Grow" .. n, markers
        growPoint.WorldCFrame = frame(n, 4, index)
    end
    rows[index] = { Object = row, Pad = pad, Dirt = dirt, Plant = plantPoint }
end
services.Players.GetPlayerFromCharacter = function(_, character)
    for _, p in { owner, peer, outsider } do
        if p.Character == character then
            return p
        end
    end
    return nil
end
local motions = {}
env.Enum.EasingStyle, env.Enum.EasingDirection = { Back = "Back" }, { Out = "Out" }
env.TweenInfo = {
    new = function(...)
        return { ... }
    end,
}
services.TweenService = {
    Create = function(_, target, _, goal)
        local tween = { Completed = signal() }
        function tween:Play() end
        function tween:Cancel()
            self.Cancelled = true
        end
        function tween:Finish()
            if not self.Cancelled then
                target.CFrame = goal.CFrame
                self.Completed:Fire()
            end
        end
        table.insert(motions, tween)
        return tween
    end,
}
local detach
cache.WorldUtil.BindTag = function(_, attach)
    detach = attach(plot)
end
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { Seconds = seconds, Run = callback })
end
dependency.MovementService = loadModule("MovementService")
local farm = loadModule("FarmService")
farm.Init(dependency)
tycoon.Init({ SessionStarted = farm.StartSession, SessionEnded = farm.CleanupSession })
farm.StartSession(owner)
local function touch(index, p)
    rows[index].Pad.Touched:Fire(p.Character:FindFirstChild("HumanoidRootPart"))
end
local function plantRow(index, p)
    rows[index].Plant:FindFirstChild("FarmPlantPrompt").Triggered:Fire(p)
end
local function state(index)
    return rows[index].Object:GetAttribute("FarmState")
end
check(rows[1].Pad.CanTouch and not rows[2].Pad.CanTouch and not rows[3].Pad.CanTouch, "only first pad starts available")
for _, row in rows do
    check(row.Dirt.Transparency == 1, "all dirt starts hidden")
end
tycoon.SetCash(owner, 470000)
touch(1, outsider)
touch(2, owner)
check(
    tycoon.GetCash(owner) == 470000 and state(1) == "LOCKED" and state(2) == "LOCKED",
    "outsiders and skipped rows cannot buy"
)
tycoon.SetCash(owner, 19999)
touch(1, peer)
check(state(1) == "LOCKED" and tycoon.GetCash(owner) == 19999, "insufficient shared cash is preserved")
tycoon.SetCash(owner, 470000)
local originalSetAttribute = peer.SetAttribute
function peer:SetAttribute(key, value)
    originalSetAttribute(self, key, value)
    if key == "playerCash" then
        touch(1, owner)
    end
end
touch(1, peer)
touch(1, owner)
check(
    tycoon.GetCash(owner) == 450000 and state(1) == "EMPTY",
    "teammate purchase and duplicate/reentrant touches charge once"
)
check(
    not rows[1].Pad.CanTouch and rows[2].Pad.CanTouch and rows[1].Dirt.Transparency == 0,
    "purchase reveals row and advances pad"
)
for _, motion in motions do
    motion:Finish()
end
check(rows[1].Dirt.CFrame.Position.Y == 7, "reveal ends at authored transform")
touch(3, peer)
touch(2, owner)
touch(3, peer)
check(
    tycoon.GetCash(peer) == 0 and tycoon.GetUpgrade(peer, "FarmRows") == 4,
    "all rows use sequential shared upgrades and configured prices"
)
carry(owner, "Apple")
local selected = tool(owner)
carry(owner, "Banana")
humanoid:EquipTool(selected)
owner:SetAttribute("HeldIngredientId", "Crab")
table.clear(sounds) -- Start planting observations after the successful setup pickups.
plantRow(1, outsider)
check(#sounds == 0, "rejected planting emits nothing")
check(state(1) == "EMPTY" and inventory.GetCarryCount(owner) == 2, "outsider cannot plant")
plantRow(1, owner)
check(
    state(1) == "GROWING" and inventory.GetCarryCount(owner) == 1 and selected.Destroyed,
    "plant consumes exactly the selected authoritative instance"
)
check(timers[#timers].Seconds == 30, "common duration")
check(rows[1].Object:GetAttribute("FarmGrowEnd") == now + 30, "client receives synchronized growth deadline")
check(
    #sounds == 1 and sounds[1].Id == "IngredientPlant" and sounds[1].Position == rows[1].Plant.WorldPosition,
    "plant sound only follows successful consumption"
)
farm.StartSession(peer)
check(state(1) == "GROWING", "repeated session binding preserves live crop")
plantRow(1, owner)
check(inventory.GetCarryCount(owner) == 1 and #timers == 1, "growing row rejects additional planting and timers")
local spawned = {}
local realSpawn = ingredients.Spawn
ingredients.Spawn = function(...)
    local object = realSpawn(...)
    table.insert(spawned, object)
    return object
end
timers[1].Run()
check(#spawned == 3 and state(1) == "READY", "growth creates exactly three normal world ingredients")
check(rows[1].Object:GetAttribute("FarmGrowEnd") == nil, "ready clears countdown deadline")
check(#sounds == 1, "growth and rejected growing-row plant emit nothing")
for n, object in spawned do
    check(
        object:GetAttribute("SpawnSource") == "Farm" and object:GetAttribute("FarmSpawnTime") == now,
        "harvest carries presentation context before publication"
    )
    check(
        ingredients.GetRecord(object).Id == "Apple" and object.CFrame.Position.X == n,
        "exact planted identity at authored grow marker"
    )
end
plantRow(1, owner)
check(inventory.GetCarryCount(owner) == 1, "ready row blocks planting")
setup(inventory.CarryWorldItem(peer, spawned[1]), "teammate harvest pickup")
setup(inventory.CarryWorldItem(outsider, spawned[2]), "harvest uses normal public pickup rules")
check(state(1) == "READY", "remaining harvest blocks replanting")
spawned[3]:Destroy()
check(
    #sounds == 3 and sounds[2].Id == "IngredientPickup" and sounds[3].Id == "IngredientPickup",
    "only successful pickups pluck; expiry is silent"
)
check(state(1) == "EMPTY", "last legitimate removal empties row")
ingredients.Spawn = realSpawn
inventory.ClearHeld(owner)
local definition = ingredients.GetDefinition("Apple")
local originalRarity = definition.Rarity
for rarity, seconds in { Uncommon = 45, Rare = 90, Mystery = 180, Unknown = 30 } do
    definition.Rarity = rarity
    carry(owner, "Apple")
    plantRow(1, owner)
    check(timers[#timers].Seconds == seconds, rarity .. " duration/fallback")
    timers[#timers].Run()
    for _, object in services.CollectionService:GetTagged("IngredientWorldItem") do
        if ingredients.GetRecord(object) then
            object:Destroy()
        end
    end
    check(state(1) == "EMPTY", "removed harvest permits next crop")
end
definition.Rarity = originalRarity
carry(owner, "Apple")
definition.Farmable = false
plantRow(1, owner)
check(state(1) == "EMPTY" and inventory.GetCarryCount(owner) == 1, "nonfarmable ingredient is retained")
definition.Farmable = nil
inventory.ClearHeld(owner)
for _, id in { "Potato", "Tomato", "GoldenTomato" } do
    carry(owner, id)
    plantRow(1, owner)
    check(state(1) == "GROWING", id .. " remains plantable")
    timers[#timers].Run()
    for _, object in services.CollectionService:GetTagged("IngredientWorldItem") do
        if ingredients.GetRecord(object) then object:Destroy() end
    end
    inventory.ClearHeld(owner)
end
carry(owner, "Dragon_Fruit")
plantRow(1, owner)
check(state(1) == "EMPTY" and inventory.GetCarryCount(owner) == 1, "Dragon Fruit cannot be planted")
inventory.ClearHeld(owner)
carry(owner, "Apple")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 0
plantRow(1, owner)
check(state(1) == "EMPTY" and inventory.GetCarryCount(owner) == 1, "dead actor cannot consume a seed")
owner.Character:FindFirstChildOfClass("Humanoid").Health = 100
owner.Character:FindFirstChild("HumanoidRootPart").Position = vec(100, 0, 0)
plantRow(1, owner)
check(state(1) == "EMPTY", "server rejects distant prompt activation")
owner.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, 0)
plantRow(1, owner)
local stale = timers[#timers]
local session = tycoon.GetSessionId(owner)
tycoon.RemovePlayer(owner)
check(tycoon.GetSessionId(peer) == session and state(1) == "GROWING", "owner promotion retains session crop")
carry(peer, "Banana")
plantRow(2, peer)
timers[#timers].Run()
local harvest = {}
for _, object in services.CollectionService:GetTagged("IngredientWorldItem") do
    if ingredients.GetRecord(object) then
        table.insert(harvest, object)
    end
end
local beforeCleanup = #sounds
tycoon.RemovePlayer(peer)
check(#sounds == beforeCleanup, "session destruction never plucks harvests")
for _, object in harvest do
    check(object.Destroyed, "session cleanup removes surviving harvest")
end
check(state(1) == "LOCKED" and rows[1].Pad.CanTouch and rows[1].Dirt.Transparency == 1, "release resets farm")
setup(tycoon.AssignPlot(owner, plot), "reclaim same plot")
local spawnCount = 0
ingredients.Spawn = function(...)
    spawnCount += 1
    return realSpawn(...)
end
local beforeStale = #sounds
stale.Run()
check(#sounds == beforeStale, "stale growth callback is silent")
check(spawnCount == 0 and state(1) == "LOCKED", "stale timer cannot spawn into replacement session")
check(tycoon.GetUpgrade(owner, "FarmRows") == 1, "new session clears row upgrades")
tycoon.SetCash(owner, 20000)
touch(1, owner)
detach()
for _, motion in motions do
    motion:Finish()
end
check(
    rows[1].Dirt.Transparency == 1 and rows[1].Dirt.CFrame.Position.Y == 7,
    "cleanup cancels reveal and restores hidden authored position"
)
print("PASS: farm")
