--!strict
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
local Component = {}
local bindings: { [Instance]: { RBXScriptConnection } } = {}

function Component.Init(services: any)
    local unbind: (Instance) -> ()
    local function bind(pedestal: Instance)
        if bindings[pedestal] or not pedestal:IsA("BasePart") or not pedestal:IsDescendantOf(workspace) then
            return
        end
        local list: { RBXScriptConnection } = {}
        bindings[pedestal] = list
        table.insert(
            list,
            pedestal.AncestryChanged:Connect(function()
                if not pedestal:IsDescendantOf(workspace) then
                    unbind(pedestal)
                end
            end)
        )
        -- Defense for existing imports. Disable/remove these in Edit mode before any Play.
        for _, child in pedestal:GetDescendants() do
            if child:IsA("BaseScript") then
                child.Enabled = false
                child:Destroy()
            elseif child:IsA("ManualWeld") and not child.Part0 and pedestal.Anchored then
                child:Destroy()
            end
        end
        local previous = pedestal:FindFirstChild("IceGunDisplay")
        if previous then
            previous:Destroy()
        end
        local weapons = ServerStorage:FindFirstChild("Weapons")
        local template = weapons and weapons:FindFirstChild("IcicleGun")
        local handle = template and template:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then
            warn("[IceGun] Missing authored Handle; cannot bind display")
            for _, connection in list do
                connection:Disconnect()
            end
            bindings[pedestal] = nil
            return
        end
        local display = handle:Clone()
        display.Name = "IceGunDisplay"
        for _, child in display:GetDescendants() do
            if
                child:IsA("BaseScript")
                or child:IsA("RemoteEvent")
                or child:IsA("RemoteFunction")
                or child:IsA("Sound")
            then
                child:Destroy()
            elseif child:IsA("ParticleEmitter") then
                child.Enabled = false
            end
        end
        services.IceGunEffects.Inert(display, true)
        display.CFrame = (pedestal.CFrame + Vector3.new(0, handle.Size.Z / 2 + 1, 0))
            * CFrame.Angles(-math.pi / 2, 0, 0)
        display.Parent = pedestal
        display:SetAttribute("IceGunDisplayBase", display.CFrame)
        CollectionService:AddTag(display, "IceGunCosmeticDisplay")
        local existingAttachment = pedestal:FindFirstChild("PurchaseAttachment")
        local marker: Attachment
        if existingAttachment then
            if not existingAttachment:IsA("Attachment") then
                warn("[IceGun] PurchaseAttachment must be an Attachment")
                return
            end
            marker = existingAttachment
        else
            marker = Instance.new("Attachment")
            marker.Name = "PurchaseAttachment"
            marker.Position = Vector3.new(0, 2.5, 0)
            marker.Parent = pedestal
        end
        local prompt = marker:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
        prompt.Name = "IceGunPurchase"
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt.ActionText = "LOADING"
        prompt.ObjectText = "ICE GUN"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = Config.PurchaseDistance
        prompt.RequiresLineOfSight = true
        prompt.ClickablePrompt = true
        prompt:SetAttribute("IceGunPurchase", true)
        prompt.Parent = marker
        local function eligible(player: Player): boolean
            local character = player.Character
            local h = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if
                not root
                or not root:IsA("BasePart")
                or not h
                or h.Health <= 0
                or not services.MovementService.CanPerformGameplayAction(player)
                or not pedestal:IsDescendantOf(workspace)
                or not prompt.Enabled
                or (root.Position - marker.WorldPosition).Magnitude > Config.PurchaseDistance
            then
                return false
            end
            local ray = RaycastParams.new()
            ray.FilterType = Enum.RaycastFilterType.Exclude
            ray.FilterDescendantsInstances = { character :: Model, pedestal }
            return workspace:Raycast(root.Position, marker.WorldPosition - root.Position, ray) == nil
        end
        table.insert(
            list,
            prompt.Triggered:Connect(function(player)
                if eligible(player) then
                    services.IceGunService.RequestPurchase(player, function()
                        return eligible(player)
                    end)
                end
            end)
        )
    end
    unbind = function(pedestal: Instance)
        for _, connection in (bindings[pedestal] or {}) :: { RBXScriptConnection } do
            connection:Disconnect()
        end
        bindings[pedestal] = nil
        local display = pedestal:FindFirstChild("IceGunDisplay")
        if display then
            display:Destroy()
        end
        local attachment = pedestal:FindFirstChild("PurchaseAttachment")
        if attachment then
            local prompt = attachment:FindFirstChild("IceGunPurchase")
            if prompt then
                prompt:Destroy()
            end
        end
    end
    local function authorizedTool(object: Instance): boolean
        local parent = object.Parent
        if not parent or not parent:IsA("Model") then
            return false
        end
        local player = game:GetService("Players"):GetPlayerFromCharacter(parent)
        return player ~= nil and services.IceGunService.GetEquipped(player) == object
    end
    local found = false
    for _, object in workspace:GetDescendants() do
        if object:IsA("BasePart") and object.Name == "EquipmentSpawner" then
            found = true
            CollectionService:AddTag(object, "IceGunPurchaseDisplay")
        elseif object:IsA("Tool") and object.Name == "IcicleGun" and not authorizedTool(object) then
            -- Never retain legacy free pickups from the imported display.
            object:Destroy()
        end
    end
    if not found and #CollectionService:GetTagged("IceGunPurchaseDisplay") == 0 then
        local template = ServerStorage:FindFirstChild("IceGunPedestalTemplate")
        if template and template:IsA("BasePart") then
            local pedestal = template:Clone()
            pedestal.Name = "EquipmentSpawner"
            pedestal.Parent = workspace
            CollectionService:AddTag(pedestal, "IceGunPurchaseDisplay")
        end
    end
    for _, pedestal in CollectionService:GetTagged("IceGunPurchaseDisplay") do
        bind(pedestal)
    end
    CollectionService:GetInstanceAddedSignal("IceGunPurchaseDisplay"):Connect(bind)
    CollectionService:GetInstanceRemovedSignal("IceGunPurchaseDisplay"):Connect(unbind)
    workspace.DescendantAdded:Connect(function(object: Instance)
        if object:IsA("Tool") and object.Name == "IcicleGun" and not authorizedTool(object) then
            object:Destroy()
        elseif object:IsA("BasePart") and object.Name == "EquipmentSpawner" then
            CollectionService:AddTag(object, "IceGunPurchaseDisplay")
        end
    end)
end

return Component
