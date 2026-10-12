--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.JackedNoob)
local Logic = require(script.Parent.JackedNoobLogic)
local WorldUtil = require(script.Parent.WorldUtil)
local Reaction = require(script.Parent.JackedNoobHitReaction)
local BatConfig = require(ReplicatedStorage.Shared.Constants.BatConfig)
local Knockback = require(script.Parent.BatKnockback)
local RunService = game:GetService("RunService")

local Service = {}
local deadlines: Logic.State = {}
local busy: { [Player]: boolean } = {}
local talkDeadlines: { [Player]: number } = {}
local active: Model? = nil
local template: Model? = nil
local spawn: CFrame? = nil
local response: RemoteEvent
local inventory: any
local deps: any
local hitUntil = 0
local immuneUntil = 0
local random = Random.new()

local function validRig(model: Model): (Humanoid?, BasePart?, BasePart?)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    local head = model:FindFirstChild("Head")
    if humanoid and root and root:IsA("BasePart") and head and head:IsA("BasePart") then
        return humanoid, root, head
    end
    return nil, nil, nil
end

local function disableLegacy(model: Model)
    for _, name in { "Move", "Respawn" } do
        local old = model:FindFirstChild(name, true)
        if old and (old:IsA("Script") or old:IsA("LocalScript")) then
            old.Disabled = true
        end
    end
end

local bind: (Model) -> ()
bind = function(model: Model)
    if active or model:GetAttribute("NPCId") ~= Config.NPCId then
        return
    end
    local humanoid, root, head = validRig(model)
    local zone = workspace:FindFirstChild("NoobRoam")
    if not humanoid or not root or not head or not zone or not zone:IsA("BasePart") then
        warn("[JackedNoob] Requires a tagged R6 NPC and Workspace.NoobRoam BasePart")
        return
    end
    active = model
    hitUntil, immuneUntil = 0, 0
    Reaction.Clear()
    if not template then
        spawn = model:GetPivot()
        disableLegacy(model)
        model.Archivable = true
        template = model:Clone()
    end
    disableLegacy(model)
    if root:CanSetNetworkOwnership() then
        root:SetNetworkOwner(nil)
    end

    local origin = head:FindFirstChild("JackedNoobTalkOrigin")
    if not origin or not origin:IsA("Attachment") then
        origin = Instance.new("Attachment")
        origin.Name = "JackedNoobTalkOrigin"
        origin.Position = Vector3.new(0, head.Size.Y * 0.55, 0)
        origin.Parent = head
    end
    local prompt = WorldUtil.Prompt(head, "JackedNoobTalk", "TALK")
    prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = Config.InteractionDistance
    prompt:SetAttribute("JackedNoobPrompt", true)
    prompt:SetAttribute("InteractionOrigin", origin.Name)
    prompt:SetAttribute("InteractionActionText", "TALK")
    local promptConnection = prompt.Triggered:Connect(function(player: Player)
        if busy[player] or not player:IsDescendantOf(Players) or active ~= model or humanoid.Health <= 0 then
            return
        end
        if not WorldUtil.Near(player, head, Config.InteractionDistance) then
            return
        end
        local now = workspace:GetServerTimeNow()
        if now < (talkDeadlines[player] or 0) then
            return
        end
        talkDeadlines[player] = now + 1
        busy[player] = true
        local ok, line = pcall(Logic.TryReward, deadlines, player, now, function()
            return inventory.GetCarryCount(player) < inventory.GetCarryCapacity(player)
        end, function()
            return inventory.GrantIngredient(player, Config.ProteinIngredientId)
        end)
        busy[player] = nil
        if not ok then
            warn("[JackedNoob] Reward failed: " .. tostring(line))
            line = "Can't grab it right now, buddy."
        end
        response:FireClient(player, head, line)
    end)

    local alive = true
    task.spawn(function()
        while alive and active == model and humanoid.Health > 0 do
            task.wait(random:NextNumber(Config.RoamIdleMinSeconds, Config.RoamIdleMaxSeconds))
            if not alive or active ~= model or humanoid.Health <= 0 then
                break
            end
            if os.clock() < hitUntil then
                continue
            end
            local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
            local halfX = zone.Size.X / 2
            local halfZ = zone.Size.Z / 2
            local outside = math.abs(localPosition.X) > halfX + Config.RoamEdgeMargin
                or math.abs(localPosition.Z) > halfZ + Config.RoamEdgeMargin
            local localTarget = if outside
                then Logic.ReturnTarget(localPosition, zone.Size, Config.RoamEdgeMargin)
                else Logic.LocalTarget(zone.Size, Config.RoamEdgeMargin, random)
            local worldTarget = zone.CFrame:PointToWorldSpace(localTarget)
            humanoid:MoveTo(Vector3.new(worldTarget.X, root.Position.Y, worldTarget.Z))
            humanoid.MoveToFinished:Wait()
        end
    end)

    local removalConnection = model.AncestryChanged:Connect(function()
        if active == model and not model:IsDescendantOf(workspace) then
            alive = false
            active = nil
            promptConnection:Disconnect()
            Reaction.Clear()
        end
    end)

    humanoid.Died:Connect(function()
        if active ~= model then
            return
        end
        alive = false
        removalConnection:Disconnect()
        Reaction.Clear()
        promptConnection:Disconnect()
        prompt:Destroy()
        active = nil
        task.delay(Config.RespawnSeconds, function()
            if active or not template or not spawn then
                return
            end
            model:Destroy()
            local replacement = template:Clone()
            replacement:PivotTo(spawn)
            active = replacement -- Guard DescendantAdded while parenting the clone.
            replacement.Parent = workspace
            active = nil
            bind(replacement)
        end)
    end)
end

-- Only CombatService dispatches Hit after issued-bat geometry and actor validation.
function Service.CanHit(player: Player, model: Model): boolean
    if active ~= model or not model:IsDescendantOf(workspace) or not deps.TycoonService.GetSessionId(player) then
        return false
    end
    local humanoid, root = validRig(model)
    return humanoid ~= nil
        and humanoid.Health > 0
        and root ~= nil
        and not root.Anchored
        and not model:FindFirstChildOfClass("ForceField")
        and os.clock() >= immuneUntil
end

function Service.Hit(player: Player, model: Model, context: { Direction: Vector3, Duration: number }): boolean
    if not Service.CanHit(player, model) then
        return false
    end
    local humanoid, root, head = validRig(model)
    if not humanoid or not root or not head then
        return false
    end
    hitUntil = os.clock() + context.Duration
    immuneUntil = hitUntil + BatConfig.ImmunitySeconds
    -- Authored R6 Noob has no native R15 ragdoll; preserve the existing rig policy.
    if humanoid.RigType == Enum.HumanoidRigType.R15 and deps.RagdollService.PrepareCharacter(model) then
        if deps.RagdollService.SetRagdolled(model, true) then
            RunService.Heartbeat:Once(function()
                if active == model and humanoid.Health > 0 and deps.RagdollService.IsRagdolled(model) then
                    Knockback.Apply(root, context.Direction)
                end
            end)
            task.delay(context.Duration, function()
                if active == model and humanoid.Health > 0 and model:IsDescendantOf(workspace) then
                    deps.RagdollService.SetRagdolled(model, false)
                end
            end)
        end
    end
    Reaction.Play(head)
    return true
end

function Service.Init(services: any)
    deps = services
    inventory = services.InventoryService
    response = Instance.new("RemoteEvent")
    response.Name = "JackedNoobResponse"
    response.Parent = ReplicatedStorage
    Players.PlayerRemoving:Connect(function(player)
        deadlines[player] = nil
        talkDeadlines[player] = nil
        busy[player] = nil
    end)
    workspace.DescendantAdded:Connect(function(object)
        if object:IsA("Model") and object:GetAttribute("NPCId") == Config.NPCId then
            task.defer(bind, object)
        end
    end)
    for _, object in workspace:GetDescendants() do
        if object:IsA("Model") and object:GetAttribute("NPCId") == Config.NPCId then
            bind(object)
            break
        end
    end
end

return Service
