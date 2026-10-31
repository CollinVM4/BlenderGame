-- Minimal transform boundary for real shared reward cloning. No rendering/physics claims.
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
local nativeInstance = env.Instance.new
env.Instance.new = function(class)
    local object = nativeInstance(class)
    if class == "Model" then
        adaptModel(object)
    end
    return object
end
