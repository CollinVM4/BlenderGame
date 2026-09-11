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
        local wasComplete = false
        local heartbeat = RunService.Heartbeat:Connect(function(dt)
            local owner = services.TycoonService.GetOwner(part)
            if owner then
                services.BlendService.AddProgress(owner, part, PhysicsService.GetBlendDelta(part, dt))
            end
            local snapshot = owner and services.BlendService.GetSnapshot(owner)
            local state = snapshot and snapshot.State or "EMPTY"
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
            for _, sound in audio do
                sound:Destroy()
            end
        end
    end)
end
return TurbineWheel
