-- Real farm, shared cash/session, inventory consumption, and ingredient spawning.
-- Engine signals, authored geometry and elapsed time are controlled at the boundary.
local tycoon = dependency.TycoonService
local config = loadModule("FarmConfig")
local economy = loadModule("Economy")
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
local detach, attachFarm
cache.WorldUtil.BindTag = function(_, attach)
    attachFarm = attach
    detach = attach(plot)
end
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { Seconds = seconds, Run = callback })
end
dependency.MovementService = loadModule("MovementService")
local passOwners, ownershipFailure, ownershipHook = {}, false, nil
local promptCount, promptFailure = 0, false
services.Players.PlayerRemoving = signal()
for _, member in { owner, peer, outsider } do
    member.Parent = services.Players
end
services.MarketplaceService = {
    PromptGamePassPurchaseFinished = signal(),
    UserOwnsGamePassAsync = function(_, id, pass)
        setup(pass == 2075211794, "farm pass ID")
        if ownershipHook then
            ownershipHook(id)
        end
        if ownershipFailure then
            error("ownership offline")
        end
        return passOwners[id] == true
    end,
    PromptGamePassPurchase = function(_, _, pass)
        setup(pass == 2075211794, "farm purchase ID")
        if promptFailure then
            error("prompt offline")
        end
        promptCount += 1
    end,
}
local farm = loadModule("FarmService")
farm.Init(dependency)
tycoon.Init({
    SessionStarted = farm.StartSession,
    SessionEnded = farm.CleanupSession,
    MemberChanged = farm.RefreshMembership,
    MemberRemoved = farm.RefreshMembership,
})
farm.StartSession(owner)
