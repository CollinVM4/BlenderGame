--!strict
-- Original asset instances only. Cosmetic physics never alters character motion.
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
local Audio = require(game:GetService("ReplicatedStorage").Shared.Constants.IceShotgunPresentationConfig)
local Effects = {}
local blocks: { [Model]: BasePart } = {}

local function templates(): Instance
    return ServerStorage:WaitForChild("IceGunEffects")
end

function Effects.Inert(part: BasePart, anchored: boolean)
    part.Anchored = anchored
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
end

local function emit(part: BasePart, source: Instance, name: string, count: number)
    local template = source:FindFirstChild(name)
    if template and template:IsA("ParticleEmitter") then
        local clone = template:Clone()
        clone.Enabled = false
        clone.Parent = part
        clone:Emit(count)
    end
end

-- All audible nearby freeze/thaw voices share one budget. A listener can hear
-- only sources within MaxDistance; every such pair is within twice that range.
-- Count overlapping clips, including different casters, instead of only one AoE.
type Voice = { Clip: Sound, Root: BasePart, Volume: number }
local voices: { Voice } = {}
local function balanceVoices()
    for _, voice in voices do
        local count = 0
        for _, other in voices do
            if (voice.Root.Position - other.Root.Position).Magnitude <= Audio.SoundMaxDistance * 2 then
                count += 1
            end
        end
        voice.Clip.Volume = voice.Volume / math.max(count, 1)
    end
end
local function sound(part: BasePart, source: Instance, name: string)
    local template = source:FindFirstChild(name)
    if template and template:IsA("Sound") then
        local clone = template:Clone()
        clone.Name = if name == "IceCrack" then "IceRayFreeze" else "IceRayThaw"
        clone.RollOffMode = Enum.RollOffMode.InverseTapered
        clone.RollOffMinDistance, clone.RollOffMaxDistance = Audio.SoundMinDistance, Audio.SoundMaxDistance
        clone.Looped, clone.PlayOnRemove = false, false
        local voice: Voice = {
            Clip = clone,
            Root = part,
            Volume = if name == "IceCrack" then Audio.FreezeVolume else Audio.ThawVolume,
        }
        clone.Parent = part
        table.insert(voices, voice)
        balanceVoices()
        clone:Play()
        local function retire()
            local index = table.find(voices, voice)
            if index then
                table.remove(voices, index)
                clone:Destroy()
                balanceVoices()
            end
        end
        clone.Ended:Once(retire)
        clone.Destroying:Once(retire)
        task.delay(Audio.SoundLifetime, retire)
    end
end

function Effects.CreateProjectile(at: CFrame): BasePart
    local part = templates():FindFirstChild("Projectile") :: BasePart
    local clone = part:Clone()
    clone.Name = "IceGunProjectile"
    Effects.Inert(clone, true)
    clone.CFrame = at
    local trail = templates():FindFirstChild("SnowBullet") :: ParticleEmitter
    local snow = trail:Clone()
    snow.Enabled = true
    snow.Parent = clone
    clone.Parent = workspace
    Debris:AddItem(clone, Config.ProjectileLifetime + 0.5)
    return clone
end

function Effects.Impact(position: Vector3)
    local part = (templates():FindFirstChild("Projectile") :: BasePart):Clone()
    part.Name = "IceGunImpact"
    part.Transparency = 1
    Effects.Inert(part, true)
    part.CFrame = CFrame.new(position)
    part.Parent = workspace
    emit(part, templates(), "SnowSplosion", 100)
    sound(part, templates(), "Shatter")
    Debris:AddItem(part, 4)
end

function Effects.Freeze(character: Model)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if not torso or not torso:IsA("BasePart") then
        return
    end
    Effects.ClearFreeze(character, false)
    local block = (templates():FindFirstChild("IceBlock") :: BasePart):Clone()
    local fullSize = block.Size
    local mesh = block:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh
    local fullScale = mesh.Scale
    block.Size = fullSize * 0.1
    mesh.Scale = fullScale * 0.1
    Effects.Inert(block, false)
    block.CFrame = torso.CFrame * CFrame.Angles(-math.pi / 2, 0, 0)
    -- Keep the visual out of CharacterPhysicsService's body-part descendants.
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = torso
    weld.Part1 = block
    weld.Parent = block
    blocks[character] = block
    block.Parent = workspace
    local source = templates():FindFirstChild("FreezeEffects") :: Folder
    sound(torso, source, "IceCrack")
    emit(block, source, "Puff", 30)
    local info = TweenInfo.new(Config.FreezeGrowthSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(block, info, { Size = fullSize }):Play()
    TweenService:Create(mesh, info, { Scale = fullScale }):Play()
    -- FreezeStatusService owns lifetime, including delayed thaw and early cancellation.
end

function Effects.ClearFreeze(character: Model, shatter: boolean)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local freezeSound = torso and torso:FindFirstChild("IceRayFreeze")
    if freezeSound then
        freezeSound:Destroy()
    end
    local block = blocks[character]
    blocks[character] = nil
    if not block then
        return
    end
    local at = block.CFrame
    block:Destroy()
    if shatter then
        local residue = (templates():FindFirstChild("IceBlock") :: BasePart):Clone()
        Effects.Inert(residue, true)
        residue.CFrame = at
        residue.Transparency = 1
        residue.Parent = workspace
        local source = templates():FindFirstChild("FreezeEffects") :: Folder
        local root = character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            sound(root, source, "Shatter")
        end
        emit(residue, source, "FrostSparkles", 80)
        Debris:AddItem(residue, 4)
        -- Small inert shards reuse the original ice mesh and texture; no collision platforms.
        for i = 1, 6 do
            local shard = (templates():FindFirstChild("IceBlock") :: BasePart):Clone()
            Effects.Inert(shard, true)
            shard.Size *= 0.12
            local mesh = shard:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh
            mesh.Scale *= 0.12
            shard.CFrame = at
            shard.Parent = workspace
            local offset = Vector3.new(math.cos(i) * 3, i % 3 - 1, math.sin(i) * 3)
            TweenService:Create(shard, TweenInfo.new(0.4), { CFrame = at + offset, Transparency = 1 }):Play()
            Debris:AddItem(shard, 0.5)
        end
    end
end

return Effects
