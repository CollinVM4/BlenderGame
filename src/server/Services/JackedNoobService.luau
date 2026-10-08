--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.JackedNoob)
local Logic = require(script.Parent.JackedNoobLogic)
local WorldUtil = require(script.Parent.WorldUtil)

local Service = {}
local deadlines: Logic.State = {}
local busy: { [Player]: boolean } = {}
local talkDeadlines: { [Player]: number } = {}
local active: Model? = nil
local template: Model? = nil
local spawn: CFrame? = nil
local response: RemoteEvent
local inventory: any
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

    humanoid.Died:Connect(function()
        if active ~= model then
            return
        end
        alive = false
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

function Service.Init(services: any)
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
