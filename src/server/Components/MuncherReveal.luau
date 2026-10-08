--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local Reveal = {}

-- Translate authored parts in world space without reparenting artwork/markers.
-- A single Quad-Out fraction moves all parts together, including nested Models.
function Reveal.Bind(model: Instance): ((any) -> boolean, () -> ())
    local parts: { [BasePart]: { Rest: CFrame, Collide: boolean, Anchored: boolean } } = {}
    local attachments: { [Attachment]: CFrame } = {}
    local function move(offset: number, resting: boolean)
        local pad = model:FindFirstChild("PurchasePoint1")
        for _, object in model:GetDescendants() do
            if object:IsA("BasePart") and object ~= pad and not (pad and object:IsDescendantOf(pad)) then
                local saved = parts[object]
                if not saved then
                    saved = { Rest = object.CFrame, Collide = object.CanCollide, Anchored = object.Anchored }
                    parts[object] = saved
                end
                object.Anchored = true
                object.CanCollide = resting and saved.Collide
                object.CFrame = CFrame.new(0, offset, 0) * saved.Rest
            elseif object:IsA("Attachment") and not (pad and object:IsDescendantOf(pad)) then
                -- Part-backed/nested attachments already follow their moving parent.
                local ancestor = object.Parent
                local follows = false
                while ancestor and ancestor ~= model do
                    if ancestor:IsA("BasePart") or ancestor:IsA("Attachment") then
                        follows = true
                        break
                    end
                    ancestor = ancestor.Parent
                end
                if not follows then
                    local rest = attachments[object] or object.WorldCFrame
                    attachments[object] = rest
                    object.WorldCFrame = CFrame.new(0, offset, 0) * rest
                end
            end
        end
    end
    move(-Config.RevealDepth, false)
    return function(snapshot)
        local fraction = if snapshot and snapshot.Purchased
            then math.clamp(1 - (snapshot.ReadyAt - workspace:GetServerTimeNow()) / Config.RevealSeconds, 0, 1)
            else 0
        local offset = -Config.RevealDepth * (1 - fraction) ^ 2
        move(offset, fraction == 1)
        return fraction == 1
    end, function()
        for attachment, rest in attachments do
            if attachment.Parent then
                attachment.WorldCFrame = rest
            end
        end
        for part, saved in parts do
            if part.Parent then
                part.CFrame, part.CanCollide, part.Anchored = saved.Rest, saved.Collide, saved.Anchored
            end
        end
    end
end

return Reveal
