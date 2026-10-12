-- Pure launch and ownership contracts; engine contacts/replication require Studio.
local knockback = loadModule("BatKnockback")
local config = loadModule("BatConfig")
local targets = { { 28, 10 }, { 48, 20 }, { 75, 32 } }
check(config.Levels[0] == nil and config.SwingCooldown == 1.1, "level zero and attack cooldown stay unchanged")
local function rootAt(x, y, z)
    local root = part("Root", workspaceFake)
    root.Position, root.CFrame = vec(x, y, z), frame(x, y, z)
    root.AssemblyMass, root.AssemblyLinearVelocity = 16, vec(0, 0, 0)
    root.AutoOwner = true
    function root:GetNetworkOwnershipAuto()
        return self.AutoOwner
    end
    function root:GetNetworkOwner()
        return self.NetworkOwner
    end
    function root:SetNetworkOwner(owner)
        self.AutoOwner, self.NetworkOwner = false, owner
    end
    function root:SetNetworkOwnershipAuto()
        self.AutoOwner = true
    end
    function root:ApplyImpulse(impulse)
        self.ImpulseCount = (self.ImpulseCount or 0) + 1
        self.AssemblyLinearVelocity += impulse / self.AssemblyMass
    end
    return root
end
for level, target in targets do
    local tuning = config.Levels[level]
    check(
        tuning.HorizontalKnockback == target[1] and tuning.VerticalKnockback == target[2],
        "exact initial launch target for level " .. level
    )
    for _, mass in { 4, 16, 25, 80 } do
        local attacker, root = rootAt(2, 100, 3), rootAt(5, 0, 7)
        root.AssemblyMass = mass
        local away = knockback.Direction(attacker, root)
        check((away - vec(0.6, 0, 0.8)).Magnitude < 0.0001, "direction uses horizontal separation from attacker")
        knockback.Apply(root, away, tuning)
        check(
            (root.AssemblyLinearVelocity - vec(target[1] * 0.6, target[2], target[1] * 0.8)).Magnitude < 0.0001,
            "velocity change is mass independent at level " .. level
        )
        check(root.ImpulseCount == 1 and root.AngularImpulse == nil, "one centered impulse adds no angular impulse")
    end
end
for _, forward in { vec(1, 0, 0), vec(0, 1, 0) } do
    local attacker, root = rootAt(0, 0, 0), rootAt(0, 5, 0)
    attacker.CFrame.LookVector = forward
    local expected = if forward.X == 1 then vec(1, 0, 0) else vec(0, 0, -1)
    check(
        (knockback.Direction(attacker, root) - expected).Magnitude < 0.0001,
        "coincident horizontal roots have a finite forward fallback"
    )
end
for _, initial in { vec(0, 70, -100), vec(150, -200, 0) } do
    local root = rootAt(0, 0, 0)
    root.AssemblyLinearVelocity = initial
    knockback.Apply(root, vec(0, 0, -1), config.Levels[3])
    local velocity = root.AssemblyLinearVelocity
    check(
        vec(velocity.X, 0, velocity.Z).Magnitude <= config.Knockback.MaxHorizontalSpeed + 0.0001
            and velocity.Y <= config.Knockback.MaxUpwardSpeed,
        "existing speed cannot accumulate an extreme launch"
    )
    if initial.Y < 0 then
        check(velocity.Y == initial.Y + 32, "launch preserves genuine descent for normal fall damage")
    end
end
for _, mass in { 0, -1, math.huge, 0 / 0 } do
    local root = rootAt(0, 0, 0)
    root.AssemblyMass = mass
    knockback.Apply(root, vec(0, 0, -1), config.Levels[3])
    check(root.ImpulseCount == nil, "invalid assembly mass cannot launch")
end
do
    local root = rootAt(0, 0, 0)
    root.Anchored = true
    knockback.Apply(root, vec(0, 0, -1), config.Levels[3])
    check(
        root.ImpulseCount == nil and knockback.TakeOwnership(root) == nil,
        "anchored target cannot launch or borrow ownership"
    )
end
for _, mode in { "automatic", "player", "server", "departed", "handoff", "removed" } do
    local root = rootAt(0, 0, 0)
    local owner = instance("Player")
    owner.Parent = services.Players
    root.AutoOwner = mode == "automatic"
    root.NetworkOwner = if mode == "server" then nil else owner
    local release = knockback.TakeOwnership(root)
    setup(release ~= nil, "acquire launch ownership")
    check(root.NetworkOwner == nil and not root.AutoOwner, "server owns the initial launch")
    if mode == "departed" then
        owner.Parent = nil
    elseif mode == "handoff" then
        root:SetNetworkOwner(owner)
    elseif mode == "removed" then
        root.Parent = nil
    end
    release()
    if mode == "automatic" or mode == "departed" then
        check(root.AutoOwner, "automatic ownership is restored, including departed owner")
    elseif mode == "player" or mode == "handoff" then
        check(root.NetworkOwner == owner and not root.AutoOwner, "manual player owner or later handoff is preserved")
    elseif mode == "server" then
        check(root.NetworkOwner == nil and not root.AutoOwner, "authored manual server ownership is preserved")
    end
    -- A stale cleanup cannot overwrite a subsequent owner's policy.
    root.AutoOwner, root.NetworkOwner = false, owner
    release()
    check(root.NetworkOwner == owner and not root.AutoOwner, "ownership release is idempotent")
end
