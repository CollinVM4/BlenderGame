-- Stash has value-only labels; each cosmetic proxy keeps its own source name.
cache.StudioServices = {
    Wrap = function(_, service)
        return service
    end,
}
local display = loadModule("StashPresentation")
local ingredients = loadModule("IngredientService")
local item = loadModule("IngredientItem")
env.CFrame.fromMatrix = function(position, right, up, back)
    local cf = frame(position.X, position.Y, position.Z)
    cf.RightVector, cf.UpVector, cf.LookVector = right, up, back * -1
    return cf
end
local first, second = item.New("PlayerHead", "first"), item.New("PlayerHead", "second")
first.SourceUserId, first.SourceDisplayName = 123, "Eatandpoop"
second.SourceUserId, second.SourceDisplayName = 456, "AnotherPlayer"
local geometry = loadModule("IngredientGeometry")
local headA, headB = instance("MeshPart"), instance("MeshPart")
headA.MeshId, headB.MeshId = "victim-A", "victim-B"
first.VisualKey, second.VisualKey = geometry.CapturePlayerHead(headA), geometry.CapturePlayerHead(headB)
local pad = instance("Part")
pad:SetAttribute("SlotIndex", 3)
local state = {
    ItemType = "Ingredient",
    IngredientId = "PlayerHead",
    Ingredients = { first, second },
    Count = 2,
    Value = item.GetIngredientValue(first, now) + item.GetIngredientValue(second, now),
}
display.Refresh(pad, state, ingredients)
local folder = pad:FindFirstChild("StashDisplay")
local identities, appearances = {}, {}
for _, model in folder:GetChildren() do
    if model:IsA("Model") then
        local proxy = model:GetChildren()[1]
        identities[proxy:GetAttribute("SourceUserId")] = proxy.Name
        appearances[proxy:GetAttribute("SourceUserId")] = proxy.MeshId
    end
end
check(
    identities[123] == "Eatandpoop's Head" and identities[456] == "AnotherPlayer's Head",
    "one stash slot presents two distinct head identities"
)
check(
    appearances[123] == "victim-A" and appearances[456] == "victim-B",
    "stash proxies preserve independent avatar heads"
)
check(
    folder:FindFirstChild("SlotValue"):FindFirstChild("Value").Text == loadModule("MoneyFormat").Compact(state.Value),
    "stash uses normal aggregated ingredient value"
)
first.SourceUserId, first.SourceDisplayName = nil, nil
state.Ingredients, state.Count = { first }, 1
display.Refresh(pad, state, ingredients)
for _, model in pad:FindFirstChild("StashDisplay"):GetChildren() do
    if model:IsA("Model") then
        check(model:GetChildren()[1].Name == "Player Head", "legacy stash head uses fallback name")
    end
end
