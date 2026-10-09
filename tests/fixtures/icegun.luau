services.RunService.IsServer = function()
    return true
end
-- Ice Gun engine boundary: no real commerce or physical collision is performed.
local timers = {}
env.task.delay = function(seconds, callback)
    table.insert(timers, { At = now + seconds, Callback = callback })
end
local function advance(seconds)
    now += seconds
    local pending = timers
    timers = {}
    for _, timer in pending do
        if timer.At <= now then
            timer.Callback()
        else
            table.insert(timers, timer)
        end
    end
    services.RunService.Heartbeat:Fire(seconds)
end
local oldNew = env.Instance.new
env.Instance.new = function(class)
    local object = oldNew(class)
    object.OnServerEvent = signal()
    object.ChildAdded = signal()
    object.ChildRemoved = signal()
    object.Died = signal()
    object.HealthChanged = signal()
    return object
end
env.typeof = function(value)
    if type(value) == "table" and getmetatable(value) == vector then
        return "Vector3"
    end
    return typeof(value)
end
local replicated = instance("Folder")
replicated.Shared = shared
services.ReplicatedStorage = replicated
local roster = {}
local sessions = {}
local upgrades = { MovementSpeed = 1, Jump = 1, SprintStamina = 1 }
local tycoon = {
    GetUpgrade = function(_, track)
        return upgrades[track] or 1
    end,
    GetSessionId = function(p)
        return sessions[p]
    end,
}
local function fighter(session)
    local p = env.Instance.new("Player")
    p.Parent, p.Name, p.UserId, p.Neutral = services.Players, "Fighter", #roster + 1, true
    p.Character = env.Instance.new("Model")
    p.Character.Parent = workspaceFake
    local h = env.Instance.new("Humanoid")
    h.Parent, h.Health, h.UseJumpPower = p.Character, 100, true
    function h:TakeDamage(amount)
        self.Health -= amount
        self.HealthChanged:Fire(self.Health)
        if self.Health <= 0 then
            self.Died:Fire()
        end
    end
    function h:EquipTool(tool)
        tool.Parent = self.Parent
        tool.AncestryChanged:Fire()
    end
    local root = env.Instance.new("Part")
    root.Name, root.Parent = "HumanoidRootPart", p.Character
    local backpack = env.Instance.new("Backpack")
    backpack.Parent = p
    sessions[p] = session
    table.insert(roster, p)
    return p, h
end
services.Players.GetPlayers = function()
    return roster
end
services.Players.GetPlayerFromCharacter = function(_, character)
    for _, p in roster do
        if p.Character == character then
            return p
        end
    end
    return nil
end
local authoredConfig = loadModule("IceGunConfig")
local config = table.clone(authoredConfig)
config.IceGunGamePassId = 123
cache.IceGunConfig = config
local ownership, marketplaceCalls, prompts = {}, 0, 0
local marketplaceFailure = false
local marketplaceHook = nil
services.MarketplaceService = {
    PromptGamePassPurchaseFinished = signal(),
    UserOwnsGamePassAsync = function(_, id, pass)
        marketplaceCalls += 1
        setup(pass == 123, "configured pass forwarded")
        if marketplaceHook then
            marketplaceHook()
        end
        if marketplaceFailure then
            error("marketplace offline")
        end
        return ownership[id] == true
    end,
    PromptGamePassPurchase = function(_, _, pass)
        setup(pass == 123, "official pass prompt")
        prompts += 1
    end,
}
local weapons = instance("Folder")
weapons.Name, weapons.Parent = "Weapons", storage
local template = instance("Tool")
template.Name, template.Parent = "IcicleGun", weapons
local templateHandle = instance("Part")
templateHandle.Name, templateHandle.Parent = "Handle", template
local templateBarrel = instance("Attachment")
templateBarrel.Name, templateBarrel.Parent = "GunBarrel", templateHandle
local visualProjectiles, impacts, freezeVisuals = {}, {}, {}
local effects = {
    Inert = function(part, anchored)
        part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless =
            anchored, false, false, false, true
    end,
    CreateProjectile = function(at)
        local visual = instance("Part")
        visual.CFrame, visual.Parent = at, workspaceFake
        table.insert(visualProjectiles, visual)
        return visual
    end,
    Impact = function(position)
        table.insert(impacts, position)
    end,
    Freeze = function(character)
        freezeVisuals[character] = true
    end,
    ClearFreeze = function(character)
        freezeVisuals[character] = nil
    end,
}
local movement = loadModule("MovementService")
local deps = { TycoonService = tycoon, MovementService = movement, IceGunEffects = effects }
movement.Init(deps)
local function ready(p)
    movement.ApplyCharacter(p, p.Character)
end
local function guns(p)
    local total = 0
    for _, container in { p.Character, p:FindFirstChildOfClass("Backpack") } do
        for _, child in container:GetChildren() do
            if child.Name == "IcicleGun" then
                total += 1
            end
        end
    end
    return total
end
