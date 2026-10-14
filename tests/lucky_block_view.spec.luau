-- Real local-world renderer and sanitizer; narrow engine doubles for transforms/tweens.
env.Enum.Material = { SmoothPlastic = "SmoothPlastic" }
env.Enum.EasingStyle = { Quad = "Quad" }
env.Enum.EasingDirection = { Out = "Out" }
env.Enum.PlaybackState = { Completed = "Completed" }
env.TweenInfo = {
    new = function()
        return {}
    end,
}
local warnings = {}
env.warn = function(message)
    table.insert(warnings, message)
end
local tweens = {}
services.TweenService = {
    Create = function(_, object, info, properties)
        local tween = { Completed = signal(), Object = object, Properties = properties }
        function tween:Play()
            self.Played = true
        end
        function tween:Cancel()
            self.Cancelled = true
        end
        table.insert(tweens, tween)
        return tween
    end,
}
local function adaptModel(model)
    local factor = 1
    function model:GetScale()
        return factor
    end
    function model:GetBoundingBox()
        local low, high = vec(math.huge, math.huge, math.huge), vec(-math.huge, -math.huge, -math.huge)
        for _, part in self:GetDescendants() do
            if part:IsA("BasePart") then
                local p, half = part.CFrame.Position, part.Size / 2
                low = vec(math.min(low.X, p.X - half.X), math.min(low.Y, p.Y - half.Y), math.min(low.Z, p.Z - half.Z))
                high =
                    vec(math.max(high.X, p.X + half.X), math.max(high.Y, p.Y + half.Y), math.max(high.Z, p.Z + half.Z))
            end
        end
        return frame((low + high) / 2), high - low
    end
    function model:ScaleTo(nextFactor)
        local ratio = nextFactor / factor
        for _, part in self:GetDescendants() do
            if part:IsA("BasePart") then
                part.Size *= ratio
                part.CFrame = frame(self.CFrame.Position + (part.CFrame.Position - self.CFrame.Position) * ratio)
            end
        end
        factor = nextFactor
    end
    function model:PivotTo(at)
        local delta = at.Position - self.CFrame.Position
        for _, part in self:GetDescendants() do
            if part:IsA("BasePart") then
                part.CFrame = frame(part.CFrame.Position + delta)
            end
        end
        self.CFrame = at
    end
    function model:GetPivot()
        local cf = self.CFrame
        getmetatable(cf).__sub = function(a, b)
            return frame(a.Position - b)
        end
        return cf
    end
    return model
end
local created = {}
env.Instance.new = function(class)
    local object = instance(class)
    table.insert(created, object)
    if class == "Model" then
        adaptModel(object)
    end
    if class == "NumberValue" then
        local value = 0
        object.Changed = signal()
        setmetatable(object, {
            __index = function(_, key)
                return if key == "Value" then value else nil
            end,
            __newindex = function(self, key, nextValue)
                if key == "Value" then
                    value = nextValue
                    self.Changed:Fire(nextValue)
                else
                    rawset(self, key, nextValue)
                end
            end,
        })
    end
    function object:Stop()
        self.IsPlaying = false
    end
    function object:Play()
        self.IsPlaying = true
    end
    return object
end
local function sourcePart(name, class, at)
    local part = instance(class or "MeshPart")
    part.Name = name
    part.CFrame = frame(at or vec(0, 0, 0))
    part.Size = vec(2, 2, 2)
    part.Color = color(0.7, 0.2, 0.4)
    part.Material = "Neon"
    part.Transparency = 0.4
    part.TextureID = "authored-texture"
    part.MaterialVariant = "authored-material"
    local originalClone = part.Clone
    function part:Clone()
        local cloned = originalClone(self)
        if cloned then
            cloned.MaterialVariant = self.MaterialVariant
            cloned.LocalTransparencyModifier = self.LocalTransparencyModifier
        end
        return cloned
    end
    return part
end
local folder = instance("Folder")
folder.Name = "LuckyBlockVisuals"
services.ReplicatedStorage.FindFirstChild = function(_, name)
    return if name == folder.Name then folder else nil
end
local config = loadModule("LuckyBlockPresentation")
local sources = {}
for id, definition in config.Rewards do
    local source = sourcePart(definition.Visual)
    source.Parent = folder
    sources[id] = source
end
local old = sources.DoubleCash
old:Destroy()
local multipart = instance("Model")
multipart.Name, multipart.Parent = config.Rewards.DoubleCash.Visual, folder
sources.DoubleCash = multipart
local first, second = sourcePart("A", "Part", vec(-2, 0, 0)), sourcePart("B", "MeshPart", vec(2, 0, 0))
first.Parent, second.Parent = multipart, multipart
local union = sourcePart("Union", "UnionOperation")
union.Size, union.Parent, union.UsePartColor = vec(1, 1, 1), multipart, false
local unionIsA, unionClone = union.IsA, union.Clone
function union:IsA(class)
    return class == "BasePart" or class == "PartOperation" or unionIsA(self, class)
end
function union:Clone()
    local cloned = unionClone(self)
    cloned.IsA, cloned.UsePartColor = self.IsA, self.UsePartColor
    return cloned
end
local nested = instance("Folder")
nested.Parent, second.Parent = multipart, nested
local authored = {}
for _, class in
    {
        "SurfaceAppearance",
        "Decal",
        "Texture",
        "ParticleEmitter",
        "Trail",
        "Beam",
        "Light",
        "Attachment",
        "Script",
        "ModuleScript",
        "ProximityPrompt",
        "WeldConstraint",
    }
do
    local child = instance(class)
    child.Name, child.Parent = class, first
    table.insert(authored, child)
end
local special = instance("SpecialMesh")
special.Parent, special.TextureId, special.VertexColor = first, "authored-special-texture", vec(1, 0.3, 0.2)
-- Imported metadata can be read/native-cloned, but ordinary scripts cannot assign
-- or clear it. Enforce that boundary on roots and nested reward geometry.
multipart.Attributes.RBX_ReimportId = "imported-model"
first.Attributes.RBX_ReimportId = "imported-part"
second.Attributes.RBX_OtherMetadata = "imported-nested-part"
multipart:SetAttribute("RewardCategory", "Powerup")
first:SetAttribute("GameplayVariant", 7)
local importedClone = multipart.Clone
function multipart:Clone()
    local copy = importedClone(self)
    local objects = copy:GetDescendants()
    table.insert(objects, copy)
    for _, object in objects do
        local setAttribute = object.SetAttribute
        function object:SetAttribute(name, value)
            if string.sub(name, 1, 4) == "RBX_" then
                error("Attempt to assign attribute " .. name .. ". CoreScript permission required")
            end
            setAttribute(self, name, value)
        end
    end
    return copy
end
local renderer = loadModule("LuckyBlockView")
local position = vec(12, 6, 9)
local view = renderer.Create(position)
local function activeModels()
    local result = {}
    for _, object in allInstances do
        if object.ClassName == "Model" and object.Parent and object.Parent.Name == "LuckyBlockRoulette" then
            table.insert(result, object)
        end
    end
    return result
end
local anchor
for _, object in allInstances do
    if object.Name == "PresentationAnchor" and not object.Destroyed then
        anchor = object
    end
end
setup(anchor, "world anchor created")
check(
    (anchor.CFrame.Position - (position + vec(0, 2.5, 0))).Magnitude < 1e-6,
    "presentation is fixed 2.5 studs above server collection position"
)
local cachedCount = #created
for id in config.Rewards do
    view.Show(id, true)
    local models = activeModels()
    check(#models == 1, "each beat cleanly replaces the previous world model")
    local model = models[1]
    local _, bounds = model:GetBoundingBox()
    check(
        math.abs(math.max(bounds.X, bounds.Y, bounds.Z) - 2.6) < 1e-6,
        "every imported silhouette has the same normalized size"
    )
    check(
        (model:GetBoundingBox().Position - anchor.CFrame.Position).Magnitude < 1e-6,
        "all silhouettes share a common centered world pivot"
    )
    for _, object in model:GetDescendants() do
        if object:IsA("BasePart") then
            check(
                object.Color.R == 0
                    and object.Color.G == 0
                    and object.Color.B == 0
                    and object.Transparency == 0
                    and object.Material == "SmoothPlastic"
                    and object.MaterialVariant == ""
                    and object.LocalTransparencyModifier == 0,
                "rolling geometry is opaque pure black"
            )
            check(
                object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,
                "cloned geometry cannot affect players or ingredients"
            )
            if object:IsA("MeshPart") then
                check(object.TextureID == "", "mesh textures are suppressed")
            end
            if object:IsA("PartOperation") then
                check(object.UsePartColor, "union face colors cannot bypass the solid black treatment")
            end
        end
        check(not table.find({
            "SurfaceAppearance",
            "Decal",
            "Texture",
            "ParticleEmitter",
            "Trail",
            "Beam",
            "Light",
            "Attachment",
            "Script",
            "ModuleScript",
            "ProximityPrompt",
            "WeldConstraint",
        }, object.ClassName), "silhouettes suppress colored effects and gameplay components")
        if object.ClassName == "SpecialMesh" then
            check(
                object.TextureId == "" and object.VertexColor.Magnitude == 0,
                "special mesh color and texture are suppressed"
            )
        end
    end
    if id == "DoubleCash" then
        local a, b = model:FindFirstChild("A", true), model:FindFirstChild("B", true)
        check(
            model:FindFirstChild(config.Rewards.DoubleCash.Visual):GetAttribute("RewardCategory") == "Powerup"
                and a:GetAttribute("GameplayVariant") == 7,
            "imported silhouettes preserve legitimate model and descendant attributes"
        )
        check(
            math.abs((b.CFrame.Position - a.CFrame.Position).Magnitude / a.Size.X - 2) < 1e-6,
            "multipart relative placement survives centering and uniform scaling"
        )
    end
end
check(#created == cachedCount, "silhouette beats reuse cached geometry without constructing tick resources")
view.Show("DoubleCash", false)
local winner = activeModels()[1]
local tickSound, popSound
-- Select by configured sound IDs instead of descendant order.
for _, child in anchor:GetChildren() do
    if child.ClassName == "Sound" then
        if child.SoundId == config.TickSoundId then
            tickSound = child
        elseif child.SoundId == config.PopSoundId then
            popSound = child
        end
    end
end
setup(tickSound and popSound, "configured tick and reveal sounds exist")
check(popSound.IsPlaying and not tickSound.IsPlaying, "winner stops rolling ticks and plays the reveal sound")
local colored = winner:FindFirstChild("A", true)
check(
    winner:FindFirstChild(config.Rewards.DoubleCash.Visual):GetAttribute("RewardCategory") == "Powerup"
        and colored:GetAttribute("GameplayVariant") == 7,
    "colored reward preserves legitimate attributes without writing protected RBX_ metadata"
)
check(
    multipart:GetAttribute("RBX_ReimportId") == "imported-model"
        and first:GetAttribute("RBX_ReimportId") == "imported-part"
        and second:GetAttribute("RBX_OtherMetadata") == "imported-nested-part",
    "imported Studio template metadata is untouched"
)
check(
    colored.Color.R == first.Color.R
        and colored.Transparency == first.Transparency
        and colored.Material == first.Material
        and colored.MaterialVariant == first.MaterialVariant,
    "fresh winner clone preserves authored color, material and transparency"
)
check(
    winner:FindFirstChild("SurfaceAppearance", true) and winner:FindFirstChild("ParticleEmitter", true),
    "winner preserves original appearance and visual effects"
)
check(
    not winner:FindFirstChild("Union", true).UsePartColor and not union.UsePartColor,
    "colored clone and source retain original union-color behavior"
)
check(
    not winner:FindFirstChild("Script", true)
        and not winner:FindFirstChild("WeldConstraint", true)
        and not winner:FindFirstChild("ProximityPrompt", true),
    "fresh colored winner still excludes gameplay and constraints"
)
check(
    first.Color.R == 0.7
        and first.Transparency == 0.4
        and second.TextureID == "authored-texture"
        and special.TextureId == "authored-special-texture",
    "source art remains unchanged"
)
local sourcesIntact = true
for _, child in authored do
    sourcesIntact = sourcesIntact and child.Parent == first and not child.Destroyed
end
check(sourcesIntact, "source descendants are not destructively sanitized")
local scale = anchor.Parent:FindFirstChildOfClass("NumberValue")
local pop
for _, tween in tweens do
    if tween.Object == scale and tween.Properties.Value == 1.25 then
        pop = tween
    end
end
check(
    pop ~= nil and anchor:FindFirstChildOfClass("PointLight").Brightness > 0,
    "final reveal requests 1.25x pop and a brief glow"
)
scale.Value = 1.25
check(
    (winner:GetBoundingBox().Position - anchor.CFrame.Position).Magnitude < 1e-6,
    "pop keeps the common world center fixed"
)
check(
    math.abs(winner:GetScale() - 2.6 / 6 * 1.25) < 1e-6,
    "scale animation uniformly enlarges the complete multipart model"
)
pop.Completed:Fire("Completed")
local settle = tweens[#tweens]
check(settle.Object == scale and settle.Properties.Value == 1, "pop completion settles back to normalized size")
view.Fade()
check(tweens[#tweens - 1].Properties.Value == 0.01, "winner shrinks away at fade")
local owner = anchor.Parent
view.Destroy()
view.Destroy()
check(not tickSound.IsPlaying and not popSound.IsPlaying, "completed reveal stops both sounds")
check(
    owner.Destroyed and winner.Destroyed and #activeModels() == 0,
    "cleanup releases current world model, sounds, glow and anchor"
)
local disposed = true
for _, object in created do
    disposed = disposed and object.Destroyed == true
end
check(disposed, "cleanup also releases all hidden cached resources")
local unavailable = sources.SuperJump
unavailable.Parent = nil
local missing = renderer.Create(position)
missing.Show("SuperJump", true)
check(#activeModels() == 0 and #warnings == 1, "missing model logs a clear warning without replacement geometry")
missing.Show("SuperJump", false)
check(#activeModels() == 0 and #warnings == 1, "minimal temporary text fallback does not invent a colored powerup")
missing.Destroy()
unavailable.Parent = folder
local observer = renderer.Create(position, "IngredientMagnet")
check(#activeModels() == 0, "observer does not prepare or show silhouette beats")
observer.Show("IngredientMagnet", false)
check(
    #activeModels() == 1
        and (activeModels()[1]:GetBoundingBox().Position - (position + vec(0, 2.5, 0))).Magnitude < 1e-6,
    "nearby winner appears at the same world location"
)
observer.Destroy()
check(#activeModels() == 0, "nearby cleanup releases its fresh winner")
local noUiCamera = true
for _, object in allInstances do
    noUiCamera = noUiCamera and object.ClassName ~= "ViewportFrame" and object.ClassName ~= "Camera"
end
check(noUiCamera, "world roulette creates no viewport or UI camera")

-- A malformed native clone must use the same text fallback and complete the
-- real sequence, releasing partial art before a later healthy reveal.
local sequence = loadModule("LuckyBlockSequence")
local callbacks = {}
local manager = sequence.new(function(seconds, callback)
    local timer = { At = seconds, Callback = callback, Cancelled = false }
    table.insert(callbacks, timer)
    return function()
        timer.Cancelled = true
    end
end)
local function finish(expectModel)
    table.sort(callbacks, function(a, b)
        return a.At < b.At
    end)
    for _, timer in callbacks do
        if not timer.Cancelled then
            timer.Callback()
            if timer.At == config.RevealSeconds then
                check(
                    #activeModels() == (if expectModel then 1 else 0),
                    "sequence reaches the colored winner or text fallback before cleanup"
                )
            end
        end
    end
    callbacks = {}
end
local healthyClone = sources.IngredientMagnet.Clone
local partial
function sources.IngredientMagnet:Clone()
    partial = healthyClone(self)
    partial.Size = nil -- Simulates unusable imported geometry during normalization.
    return partial
end
local broken = renderer.Create(position)
check(manager.Start("collector", "IngredientMagnet", true, broken), "malformed art cannot abort roulette startup")
finish(false)
check(partial.Destroyed and #activeModels() == 0, "failed visual is cleaned and text-only reveal finishes")
sources.IngredientMagnet.Clone = healthyClone
local recovered = renderer.Create(position)
check(manager.Start("collector", "IngredientMagnet", true, recovered), "later valid pickup starts after malformed art")
finish(true)
check(#activeModels() == 0, "recovered reveal also finishes and cleans up")
local allReleased = true
for _, object in created do
    allReleased = allReleased and object.Destroyed == true
end
check(allReleased, "malformed and subsequent reveals leave no renderer resources behind")
