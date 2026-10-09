--!strict
-- Original asset instances only. Cosmetic physics never alters character motion.
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
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

local function sound(part: BasePart, source: Instance, name: string)
    local template = source:FindFirstChild(name)
    if template and template:IsA("Sound") then
        local clone = template:Clone()
        clone.RollOffMaxDistance = 100
        clone.Parent = part
        clone:Play()
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
    sound(block, source, "IceCrack")
    emit(block, source, "Puff", 30)
    local info = TweenInfo.new(Config.FreezeGrowthSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(block, info, { Size = fullSize }):Play()
    TweenService:Create(mesh, info, { Scale = fullScale }):Play()
    Debris:AddItem(block, Config.FreezeSeconds + 1)
end

function Effects.ClearFreeze(character: Model, shatter: boolean)
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
        sound(residue, source, "Shatter")
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
