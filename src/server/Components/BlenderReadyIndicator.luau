--!strict
local Players = game:GetService("Players")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local BlenderReadyIndicator = {}

-- Presentation of BlendService's published state only; never authorizes dispensing.
-- READY means loaded, whereas COMPLETE means blended and dispensable.
function BlenderReadyIndicator.IsReady(state: any, progress: any): boolean
    return state == "COMPLETE" and typeof(progress) == "number" and progress >= Economy.RequiredProgress
end

function BlenderReadyIndicator.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot)
        local blender = if plot.Name == "Blender" then plot else plot:FindFirstChild("Blender")
        local marker = blender and blender:FindFirstChild("ReadyIndicatorOrigin", true)
        if not marker or not (marker:IsA("BasePart") or marker:IsA("Attachment")) then
            warn("[BlenderReadyIndicator] Missing BasePart/Attachment ReadyIndicatorOrigin in " .. plot:GetFullName())
            return nil
        end
        local disk = Instance.new("Part")
        disk.Name = "BlenderReadyFloorIndicator"
        disk.Shape = Enum.PartType.Cylinder
        disk.Size = Vector3.new(0.15, 20, 20
)
        disk.Anchored = true
        disk.CanCollide = false
        disk.CanTouch = false
        disk.CanQuery = false
        disk.CastShadow = false
        disk.Material = Enum.Material.Neon
        disk.Color = Color3.fromRGB(0, 255, 38)
        disk.Transparency = 1
        -- Cylinder length is local X. Ignore marker rotation to remain floor-flat.
        local function place()
            local position = if marker:IsA("Attachment") then marker.WorldPosition else (marker :: BasePart).Position
            disk.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
        end
        place()
        disk.Parent = marker
        local owner: Player? = nil
        local ownerConnections: { RBXScriptConnection } = {}
        local function refresh()
            local ready = owner ~= nil
                and BlenderReadyIndicator.IsReady(owner:GetAttribute("BlendState"), owner:GetAttribute("BlendProgress"))
            if ready then
                place()
            end
            disk.Transparency = if ready then 0.1 else 1
        end
        local function disconnectOwner()
            for _, connection in ownerConnections do
                connection:Disconnect()
            end
            table.clear(ownerConnections)
        end
        local function bindOwner()
            disconnectOwner()
            owner = if plot:GetAttribute("OwnerUserId") ~= nil then services.TycoonService.GetOwner(plot) else nil
            if owner then
                for _, attribute in { "BlendState", "BlendProgress" } do
                    table.insert(ownerConnections, owner:GetAttributeChangedSignal(attribute):Connect(refresh))
                end
            end
            refresh()
        end
        local ownership = plot:GetAttributeChangedSignal("OwnerUserId"):Connect(bindOwner)
        local leaving = Players.PlayerRemoving:Connect(function(player)
            if player == owner then
                disconnectOwner()
                owner = nil
                refresh()
            end
        end)
        bindOwner()
        return function()
            ownership:Disconnect()
            leaving:Disconnect()
            disconnectOwner()
            disk:Destroy()
        end
    end)
end

return BlenderReadyIndicator
