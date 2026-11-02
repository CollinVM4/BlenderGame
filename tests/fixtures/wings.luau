-- Marketplace and engine boundary, patterned after fixtures/icegun.luau.
env.Enum.HumanoidStateType = {
    Running = "Running",
    Landed = "Landed",
    RunningNoPhysics = "RunningNoPhysics",
    GettingUp = "GettingUp",
    Freefall = "Freefall",
    Jumping = "Jumping",
    Swimming = "Swimming",
    Climbing = "Climbing",
    Seated = "Seated",
    Physics = "Physics",
}
env.Enum.Material = { Air = "Air", Concrete = "Concrete" }
env.Enum.HumanoidRigType = { R6 = "R6", R15 = "R15" }
services.RunService.IsServer = function()
    return true
end
local heartbeats = {}
services.RunService.Heartbeat = {
    Connect = function(_, callback)
        table.insert(heartbeats, callback)
        return { Disconnect = function() end }
    end,
    Fire = function(_, dt)
        for _, callback in heartbeats do
            callback(dt)
        end
    end,
}
workspaceFake.Gravity = 196.2
local replicated = instance("Folder")
replicated.Shared = shared
services.ReplicatedStorage = replicated
local new = env.Instance.new
env.Instance.new = function(class)
    local item = new(class)
    item.OnServerEvent, item.Died, item.ChildAdded = signal(), signal(), signal()
    return item
end
local frameNew = env.CFrame.new
env.CFrame.new = function(...)
    local result = frameNew(...)
    result.Inverse = function()
        return frameNew()
    end
    return result
end
local template = instance("Accessory")
template.Name, template.Parent = "AngelWingsTemplate", storage
local handle = instance("Part")
handle.Name, handle.Parent = "Handle", template
local attachment = instance("Attachment")
attachment.Name, attachment.Parent, attachment.CFrame = "BodyBackAttachment", handle, env.CFrame.new()
local ownership, marketplaceCalls, prompts = {}, 0, 0
local marketplaceFailure, promptFailure = false, false
local marketplaceHook = nil
services.MarketplaceService = {
    PromptGamePassPurchaseFinished = signal(),
    UserOwnsGamePassAsync = function(_, id, pass)
        marketplaceCalls += 1
        setup(pass == 2021642550, "exact wings pass ID")
        if marketplaceHook then
            marketplaceHook()
        end
        if marketplaceFailure then
            error("marketplace offline")
        end
        return ownership[id] == true
    end,
    PromptGamePassPurchase = function(_, _, pass)
        setup(pass == 2021642550, "official wings purchase prompt")
        if promptFailure then
            error("prompt unavailable")
        end
        prompts += 1
    end,
}
local movement = {
    IsMovementLocked = function(p)
        return p.Locked == true
    end,
    IsInitialized = function()
        return true
    end,
    GetJumpPower = function(p)
        return p.JumpPower
    end,
}
local wings = loadModule("WingsService")
local fall = loadModule("FallDamageService")
local deps = { MovementService = movement, WingsService = wings }
fall.Init(deps)
wings.Init(deps)
local nextId = 0
local function subject(owned, power)
    nextId += 1
    local p = env.Instance.new("Player")
    p.Parent, p.UserId, p.JumpPower = services.Players, nextId, power or 60
    p.Character = instance("Model")
    p.Character.Parent = workspaceFake
    local h = env.Instance.new("Humanoid")
    h.Parent, h.Health = p.Character, 1000
    h.Mode, h.FloorMaterial, h.PlatformStand, h.HipHeight, h.RigType = "Freefall", "Air", false, 2, "R15"
    h.JumpPower = p.JumpPower
    h.GetState = function(self)
        return self.Mode
    end
    h.TakeDamage = function(self, damage)
        self.Health -= damage
    end
    local root = instance("Part")
    root.Name, root.Parent = "HumanoidRootPart", p.Character
    root.AssemblyLinearVelocity, root.Anchored, root.CollisionGroup = vec(7, 0, 9), false, "Default"
    root.CanSetNetworkOwnership = function()
        return true
    end
    root.GetNetworkOwnershipAuto = function(self)
        return self.Automatic ~= false
    end
    root.GetNetworkOwner = function(self)
        return self.Owner
    end
    root.SetNetworkOwner = function(self, owner)
        self.Automatic, self.Owner = false, owner
    end
    root.SetNetworkOwnershipAuto = function(self)
        self.Automatic = true
    end
    local torso = instance("Part")
    torso.Name, torso.Parent, torso.CanCollide = "UpperTorso", p.Character, true
    ownership[p.UserId] = owned
    wings.AddPlayer(p)
    fall.ApplyCharacter(p, p.Character)
    wings.ApplyCharacter(p, p.Character)
    flush()
    return p, h, root
end
local function tick(p, h, root, seconds, velocity, supported)
    if velocity ~= nil then
        root.AssemblyLinearVelocity = vec(7, velocity, 9)
    end
    h.Mode, h.FloorMaterial = if supported then "Running" else "Freefall", if supported then "Concrete" else "Air"
    now += seconds
    services.RunService.Heartbeat:Fire(seconds)
end
local function fly(p, h, root, seconds)
    for _ = 1, math.floor(seconds / 0.025 + 0.5) do
        tick(p, h, root, 0.025, 0, false)
    end
end
local function state(p)
    return p:GetAttribute("WingState")
end
