--!strict
local RunService = game:GetService("RunService")
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local PhysicsService = require(script.Parent.Parent.Services.PhysicsService)
local TurbineWheel = {}
function TurbineWheel.Init(services: any)
    WorldUtil.BindTag("TurbineWheel", function(object)
        local part = WorldUtil.Part(object)
        if not part then
            warn("[TurbineWheel] Requires a blade/stem BasePart")
            return nil
        end
        -- if part:CanSetNetworkOwnership() then
        --     part:SetNetworkOwner(nil)
        -- end
        local audio = AudioService.CreateBlendGroup(part)
        audio.blendSound:Play()
        local particles = Instance.new("ParticleEmitter")
        particles.Rate = 0
        particles.Speed = NumberRange.new(5, 10)
        particles.Parent = part
        local gui = Instance.new("BillboardGui")
        gui.Name = "BlendProgress"
        gui.Size = UDim2.fromOffset(200, 28)
        gui.StudsOffset = Vector3.new(0, 4, 0)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 80
        gui.Parent = part
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.Parent = gui
        local wasComplete = false
        local heartbeat = RunService.Heartbeat:Connect(function(dt)
            local owner = services.TycoonService.GetOwner(part)
            if owner then
                services.BlendService.AddProgress(owner, part, PhysicsService.GetBlendDelta(part, dt))
            end
            local snapshot = owner and services.BlendService.GetSnapshot(owner)
            local progress = snapshot and snapshot.Progress or 0
            local state = snapshot and snapshot.State or "EMPTY"
            label.Text = if state == "COMPLETE"
                then "READY TO DISPENSE!"
                else string.format("%s | %.0f%%", state, progress)
            local strength = if state == "BLENDING" then PhysicsService.GetSpinStrength(part) else 0
            AudioService.UpdateBlendGroup(audio, strength)
            particles.Rate = strength * 2
            if snapshot and snapshot.Result then
                particles.Color = ColorSequence.new(snapshot.Result.Color)
            end
            if state == "COMPLETE" and not wasComplete then
                audio.dingSound:Play()
            end
            wasComplete = state == "COMPLETE"
        end)
        return function()
            heartbeat:Disconnect()
            particles:Destroy()
            gui:Destroy()
            for _, sound in audio do
                sound:Destroy()
            end
        end
    end)
end
return TurbineWheel
