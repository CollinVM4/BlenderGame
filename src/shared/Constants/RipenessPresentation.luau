--!strict
-- Cosmetic stash indicators and their paired monetary label.
local Style = {
    StashMaxDistance = 36,
    IndicatorGold = Color3.fromRGB(255, 221, 48),
}

function Style.ResolveOrigin(slot: BasePart): Instance
    local origin = slot:FindFirstChild("StashRipenessOrigin")
    if origin and origin:IsA("Attachment") then
        return origin
    end
    return slot
end

function Style.ConfigureIndicator(gui: BillboardGui, slot: BasePart)
    gui.Adornee = Style.ResolveOrigin(slot)
    gui.Size = UDim2.fromOffset(120, 24)
    gui.MaxDistance = Style.StashMaxDistance
end

return Style
