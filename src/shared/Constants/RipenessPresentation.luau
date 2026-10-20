--!strict
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
-- Cosmetic stash indicators and their paired monetary label.
local Style = {
    StashMaxDistance = 35,
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
    -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
    BillboardStyle.ApplyBillboard(gui, { WidthStuds = 3.84, HeightStuds = 0.72, MaxDistance = Style.StashMaxDistance })
end

return Style
