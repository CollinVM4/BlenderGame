-- Real client visibility controller; waiting/approaching orders share the same owner contract.
local descendants, changed, bubbles = {}, {}, {}
services.Players.LocalPlayer = { UserId = 51 }
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
workspaceFake.GetDescendants = function()
    return descendants
end
for index = 1, 3 do
    local model = instance("Model")
    model:SetAttribute("OwnerUserId", 51)
    model:SetAttribute("QueuePosition", index)
    changed[index] = signal()
    model.GetAttributeChangedSignal = function()
        return changed[index]
    end
    local root = instance("Part")
    root.Parent = model
    local bubble = instance("BillboardGui")
    bubble.Name, bubble.Parent, bubble.Enabled = "OrderBubble", root, false
    table.insert(descendants, bubble)
    bubbles[index] = bubble
end
loadModule("CustomerOrderController").Init()
for index, bubble in bubbles do
    check(bubble.Enabled, "counter and both waiting orders are simultaneously visible to owner")
    local model = bubble.Parent.Parent
    model:SetAttribute("QueuePosition", index - 1)
    changed[index]:Fire()
    check(bubble.Enabled, "queue advancement keeps order visible")
    model:SetAttribute("OwnerUserId", 99)
    changed[index]:Fire()
    check(not bubble.Enabled, "other owners cannot see this order")
end
