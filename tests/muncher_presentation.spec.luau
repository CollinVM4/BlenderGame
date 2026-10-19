-- Presentation policy is independent of authoritative gameplay suites.
cache.MuncherEffects = {}
cache.InteractionPromptPresentation = {}
local controller = loadModule("MuncherPresentationController")
local config = loadModule("Muncher")
local actor = instance("Player")
actor.Character = instance("Model")
local plot = instance("Model")
local model = instance("Model")
local function feedback()
    return controller.Feedback(model, plot, actor)
end
check(feedback() == "NOT YOUR MUNCHER", "unassigned visitor has no feed action")
plot:SetAttribute("PlotSessionId", "session")
actor:SetAttribute("PlotSessionId", "session")
check(feedback() == "LOCKED", "purchase state readable")
model:SetAttribute("Purchased", true)
model:SetAttribute("Active", true)
model:SetAttribute("Phase", "Idle")
check(feedback() == "NEED INGREDIENT", "empty hands explain disabled action")
actor:SetAttribute("HeldItemType", "Smoothie")
actor:SetAttribute("HeldIngredientId", "Apple")
check(feedback() == "NEED INGREDIENT", "smoothie never offers FEED despite stale ingredient hint")
actor:SetAttribute("HeldItemType", "Ingredient")
check(feedback() == "FEED MUNCHER", "ingredient can offer feed")
local tool = instance("Tool")
tool.Parent = actor.Character
check(feedback() == "NEED INGREDIENT", "weapon blocks feed even with carried ingredients")
tool:SetAttribute("IngredientId", "Apple")
check(feedback() == "FEED MUNCHER", "ingredient tool remains valid")
for _, phase in { "Processing", "Spitting" } do
    model:SetAttribute("Phase", phase)
    check(feedback() == "MUNCHER BUSY", "transaction explains disabled feed")
end
model:SetAttribute("Phase", "Idle")
model:SetAttribute("AvailableAt", now + config.SpitSeconds)
check(feedback() == "MUNCHER BUSY", "output transition guards immediate refeed")
now += config.SpitSeconds
check(feedback() == "FEED MUNCHER", "idle prompt recovers promptly")
actor:SetAttribute("PlotSessionId", "other")
check(feedback() == "NOT YOUR MUNCHER", "membership change immediately removes action")

-- Controlled reveal handles multipart/nested artwork and excludes the pad.
do
    local model = instance("Model")
    model.Parent = workspaceFake
    local visual = instance("Model")
    visual.Name, visual.Parent = "Visual", model
    local nested = instance("Model")
    nested.Parent = visual
    local first, second = instance("Part"), instance("Part")
    first.Parent, second.Parent = visual, nested
    first.CFrame, second.CFrame = frame(3, 10, 4), frame(5, 14, 8)
    first.CanCollide, second.CanCollide = true, true
    local pad = instance("Part")
    pad.Name, pad.Parent, pad.CFrame = "PurchasePoint1", model, frame(0, 2, 0)
    local marker = instance("Attachment")
    marker.Name, marker.Parent, marker.WorldCFrame = "MouthOrigin", model, frame(0, 15, 0)
    local move, restore = loadModule("MuncherReveal").Bind(model)
    check(
        first.CFrame.Position.Y == 4 and second.CFrame.Position.Y == 8 and marker.WorldCFrame.Position.Y == 9,
        "all artwork and free markers start six studs below authored rest"
    )
    check(
        first.Anchored and second.Anchored and not first.CanCollide,
        "moving assembly is anchored with collision disabled"
    )
    local revealState = { Purchased = true, ReadyAt = now + 0.95 }
    now += 0.475
    check(
        not move(revealState) and math.abs(first.CFrame.Position.Y - 8.5) < 0.0001,
        "smooth Quad-Out midpoint does not activate intake early"
    )
    check(
        math.abs(second.CFrame.Position.Y - first.CFrame.Position.Y - 4) < 0.0001 and pad.CFrame.Position.Y == 2,
        "multipart spacing remains stable and purchase pad never moves"
    )
    now = revealState.ReadyAt
    check(
        move(revealState) and first.CFrame.Position.Y == 10 and second.CFrame.Position.Y == 14 and first.CanCollide,
        "completed reveal restores authored rest and collision"
    )
    move(nil)
    check(
        first.CFrame.Position.Y == 4 and pad.CFrame.Position.Y == 2,
        "released session returns assembly underground with pad accessible"
    )
    restore()
    check(
        first.CFrame.Position.Y == 10 and marker.WorldCFrame.Position.Y == 15,
        "component removal restores authored locations"
    )
end

-- Effects use replicated phase/time/rarity only and restore authored geometry on interruption.
cache.MuncherEffects = nil
env.Vector3.one = vec(1, 1, 1)
env.TweenInfo = {
    new = function()
        return {}
    end,
}
services.TweenService = {
    Create = function()
        return { Play = function() end }
    end,
}
local effects = loadModule("MuncherEffects")
local effectModel = instance("Model")
local visual = instance("Model")
visual.Name, visual.Parent = "Visual", effectModel
local artwork = instance("Part")
artwork.Parent, artwork.CFrame = visual, frame(0, 4, 0)
local mouth = instance("Part")
mouth.Name, mouth.Parent = "MouthOrigin", effectModel
local guiRoot = instance("PlayerGui")
effectModel:SetAttribute("Sequence", 1)
effectModel:SetAttribute("Phase", "Processing")
effectModel:SetAttribute("StartedAt", now)
effectModel:SetAttribute("OutputRarity", "Rare")
local animate, stop = effects.Bind(effectModel, guiRoot)
animate(now)
local hearts = guiRoot:FindFirstChildOfClass("BillboardGui")
check(hearts ~= nil and #hearts:GetChildren() == 5, "feed immediately acknowledges with a small heart burst")
local light = hearts.Adornee:FindFirstChildOfClass("PointLight")
local palette = loadModule("IngredientPickupPromptStyle").RarityStyles
check(light.Color == palette.Rare.TextColor, "glow uses actual output rarity and existing palette")
animate(now + config.ChewSeconds * 0.85)
check(light.Brightness > 0 and artwork.CFrame.Position.Y ~= 4, "anticipation visibly chews and intensifies glow")
effectModel:SetAttribute("Phase", "Idle")
animate(now + config.ChewSeconds)
check(
    artwork.CFrame.Position.Y == 4 and hearts.Parent == nil,
    "interruption restores artwork and removes cosmetic effects"
)
stop()
check(artwork.CFrame.Position.Y == 4, "repeated cleanup preserves authored geometry")
