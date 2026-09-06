--!strict
local CollectionService = game:GetService("CollectionService")
local WorldUtil = {}

function WorldUtil.Part(instance: Instance?): BasePart?
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") and instance.PrimaryPart then
        return instance.PrimaryPart
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function WorldUtil.Near(player: Player, target: Instance?, distance: number): boolean
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local part = WorldUtil.Part(target)
    return root ~= nil
        and root:IsA("BasePart")
        and humanoid ~= nil
        and humanoid.Health > 0
        and part ~= nil
        and part:IsDescendantOf(workspace)
        and (root.Position - part.Position).Magnitude <= distance
end

function WorldUtil.Prompt(part: BasePart, name: string, text: string): ProximityPrompt
    local old = part:FindFirstChild(name)
    if old then
        old:Destroy()
    end
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = name
    prompt.ActionText = text
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    return prompt
end

function WorldUtil.BindTag(tag: string, attach: (Instance) -> (() -> ())?)
    local cleanups: { [Instance]: () -> () } = {}
    local watches: { [Instance]: RBXScriptConnection } = {}
    local function detach(object: Instance)
        local cleanup = cleanups[object]
        cleanups[object] = nil
        if cleanup then
            cleanup()
        end
    end
    local function update(object: Instance)
        if not object:IsDescendantOf(workspace) then
            detach(object)
            return
        end
        if not cleanups[object] then
            local cleanup = attach(object)
            if cleanup then
                cleanups[object] = cleanup
            end
        end
    end
    local function add(object: Instance)
        if watches[object] then
            return
        end
        watches[object] = object.AncestryChanged:Connect(function()
            update(object)
        end)
        update(object)
    end
    local function remove(object: Instance)
        if watches[object] then
            watches[object]:Disconnect()
            watches[object] = nil
        end
        detach(object)
    end
    for _, object in CollectionService:GetTagged(tag) do
        add(object)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(add)
    CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
    if #CollectionService:GetTagged(tag) == 0 then
        warn("[MVP] No " .. tag .. " objects; add them in Studio when ready.")
    end
end

return WorldUtil
