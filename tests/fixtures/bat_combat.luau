-- Real combat, inventory, movement, shared purchases and request adapter; engine query/timers doubled.
env.OverlapParams = {
    new = function()
        return {}
    end,
}
local combat = loadModule("CombatService")
local movement = loadModule("MovementService")
local tycoon = dependency.TycoonService
local config = loadModule("BatConfig")
local gameplaySfx = loadModule("GameplaySfxService")
gameplaySfx.Init()
local sfxRemote = shared.Events:FindFirstChild("GameplaySfx")
local swingSounds = {}
sfxRemote.FireAllClients = function(_, name, position)
    table.insert(swingSounds, { Name = name, Position = position })
end
dependency.MovementService = movement
dependency.CombatService = combat
dependency.CustomerService = customer
movement.Init(dependency)
combat.Init(dependency)
-- Physical engine boundary; AJU joint restoration is covered in ragdoll.spec.
local physical = {}
local ragdollCalls = {}
local ragdollFailure = nil
local heartbeatCallbacks = {}
services.RunService.Heartbeat.Once = function(_, callback)
    table.insert(heartbeatCallbacks, callback)
end
local function heartbeat()
    local pending = heartbeatCallbacks
    heartbeatCallbacks = {}
    for _, callback in pending do
        callback()
    end
end
dependency.RagdollService = {
    SetRagdolled = function(character, enabled)
        local owner = services.Players:GetPlayerFromCharacter(character)
        table.insert(ragdollCalls, {
            Character = character,
            Enabled = enabled,
            Stunned = owner and movement.IsStunned(owner),
            CarryCount = owner and inventory.GetCarryCount(owner),
        })
        if ragdollFailure == (if enabled then "on-error" else "off-error") then
            error("injected ragdoll failure")
        elseif ragdollFailure == (if enabled then "on-false" else "off-false") then
            return false
        end
        physical[character] = enabled
        character:FindFirstChildOfClass("Humanoid").PlatformStand = enabled
        return true
    end,
    IsRagdolled = function(character)
        return physical[character] == true
    end,
}
local function impulseRoot(root)
    root.AssemblyMass = 12
    root.AssemblyLinearVelocity = vec(0, 0, 0)
    root.OwnershipAuto = true
    function root:GetNetworkOwnershipAuto()
        return self.OwnershipAuto
    end
    function root:GetNetworkOwner()
        return self.NetworkOwner
    end
    function root:SetNetworkOwner(owner)
        self.OwnershipAuto, self.NetworkOwner = false, owner
    end
    function root:SetNetworkOwnershipAuto()
        self.OwnershipAuto = true
    end
    function root:ApplyImpulse(impulse)
        check(physical[self.Parent] == true, "player impulse requires active ragdoll")
        check(not self.OwnershipAuto and self.NetworkOwner == nil, "server owns player at impulse")
        self.Impulse = impulse
        self.ImpulseCount = (self.ImpulseCount or 0) + 1
    end
end
workspaceFake.Gravity = 196.2
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
end
local template = instance("Tool")
template.Name, template.Parent = "Bat", storage
template.Grip = frame(0.1, -0.3, 0.2)
local handle = part("Handle", template)
handle.Size = vec(1, 2, 1)
local mesh = part("BatMesh", template)
mesh.Size = vec(1, 4, 1)
local hitbox = part("Hitbox", template)
hitbox.Size = vec(0.867, 0.597, 4.703)
hitbox.CFrame = frame(0.25, 0.1, -2.35)
local roster = {}
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
local function prepareHumanoid(humanoid)
    humanoid.MaxHealth, humanoid.HealthChanged = 100, signal()
    function humanoid:TakeDamage(amount)
        self.Health = math.max(0, self.Health - amount)
        self.HealthChanged:Fire(self.Health)
        if self.Health <= 0 then
            self.Died:Fire()
        end
    end
end
local function fighter(z)
    local p, humanoid = player()
    p.Name = "Fighter" .. tostring(#roster + 1)
    p.Character.Name = p.Name
    p.Parent, p.Neutral, p.ChildAdded = services.Players, true, signal()
    humanoid.UseJumpPower = true
    prepareHumanoid(humanoid)
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    impulseRoot(root)
    root.Position, root.CFrame = vec(0, 0, z or 0), frame(0, 0, z or 0)
    p.Character.Parent = workspaceFake
    table.insert(roster, p)
    movement.ApplyCharacter(p, p.Character)
    combat.ApplyCharacter(p, p.Character)
    flush()
    return p, humanoid
end
local function bats(p)
    local result = {}
    for _, container in { p.Character, p:FindFirstChildOfClass("Backpack") } do
        for _, object in container:GetChildren() do
            if object:IsA("Tool") and object.Name == "Bat" then
                table.insert(result, object)
            end
        end
    end
    return result
end
tycoon.Init({
    MemberChanged = function(p)
        movement.RefreshPlayer(p)
        combat.RefreshPlayer(p)
    end,
    MemberRemoved = function(p)
        combat.RefreshPlayer(p)
    end,
})
local querySize, queryFrame, queryParams, queryCount = nil, nil, nil, 0
local overlaps = {}
workspaceFake.GetPartBoundsInBox = function(_, at, size, params)
    querySize, queryCount = size, queryCount + 1
    queryFrame, queryParams = at, params
    return overlaps
end
local function equip(p)
    p.Character:FindFirstChildOfClass("Humanoid"):EquipTool(bats(p)[1])
end
