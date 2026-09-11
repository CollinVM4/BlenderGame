--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local WorldUtil = require(script.Parent.WorldUtil)
local CombatService = {}
local deps: any
local attackAt: { [Player]: number } = {}
local dropAt: { [Player]: number } = {}
local stunAt: { [Player]: number } = {}
local hands: { [Player]: Tool } = {}
function CombatService.Init(services)
    deps = services
end
function CombatService.Slap(player: Player, victim: Player): boolean
    local now = os.clock()
    local hand = hands[player]
    local target = victim.Character
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
    local humanoid = target and target:FindFirstChildOfClass("Humanoid")
    if
        player == victim
        or not hand
        or hand.Parent ~= player.Character
        or not root
        or not root:IsA("BasePart")
        or not targetRoot
        or not targetRoot:IsA("BasePart")
        or not humanoid
        or humanoid.Health <= 0
        or not WorldUtil.Near(player, targetRoot, Economy.SlapRange)
        or now < (attackAt[player] or 0)
        or now < (tonumber(player:GetAttribute("StunnedUntil")) or 0)
    then
        return false
    end
    local direction = targetRoot.Position - root.Position
    if direction.Magnitude < 0.01 or root.CFrame.LookVector:Dot(direction.Unit) < 0 then
        return false
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character :: Model }
    local obstruction = workspace:Raycast(root.Position, direction, params)
    if obstruction and not obstruction.Instance:IsDescendantOf(target :: Model) then
        return false
    end
    attackAt[player] = now + Economy.SlapCooldown
    local level = Upgrades.Hand[deps.PlayerDataService.GetUpgrade(player, "Hand")]
    local handle = hand:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        handle.Size = Vector3.new(2, 2, 0.5) * level.Size
    end
    humanoid:TakeDamage(level.Damage)
    targetRoot:ApplyImpulse((direction.Unit * level.Knockback + Vector3.new(0, 8, 0)) * targetRoot.AssemblyMass)
    if now >= (stunAt[victim] or 0) then
        victim:SetAttribute("StunnedUntil", now + Economy.StunSeconds)
        stunAt[victim] = now + Economy.StunSeconds + 1
    end
    if now >= (dropAt[victim] or 0) then
        deps.InventoryService.DropOne(victim)
        dropAt[victim] = now + Economy.DropProtection
    end
    deps.PlayerDataService.IncrementStat(player, "PlayersSlapped")
    return true
end
-- Optional server-issued placeholder weapon. No arbitrary Tool name grants attack rights.
function CombatService.GrantHand(player: Player): Tool?
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return nil
    end
    if hands[player] then
        hands[player]:Destroy()
    end
    local tool = Instance.new("Tool")
    tool.Name = "SlapHand"
    tool.CanBeDropped = false
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(2, 2, 0.5)
    handle.Color = Color3.fromRGB(255, 210, 140)
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool
    hands[player] = tool
    tool.Activated:Connect(function()
        local closest: Player? = nil
        local distance = Economy.SlapRange
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then
            return
        end
        for _, victim in Players:GetPlayers() do
            local target = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
            if victim ~= player and target and target:IsA("BasePart") then
                local separation = (target.Position - root.Position).Magnitude
                if separation < distance then
                    distance = separation
                    closest = victim
                end
            end
        end
        if closest then
            CombatService.Slap(player, closest)
        end
    end)
    tool.Parent = backpack
    return tool
end
function CombatService.RemovePlayer(player: Player)
    if hands[player] then
        hands[player]:Destroy()
    end
    hands[player] = nil
    attackAt[player] = nil
    dropAt[player] = nil
    stunAt[player] = nil
end
return require(script.Parent.StudioServices).Wrap("CombatService", CombatService)
