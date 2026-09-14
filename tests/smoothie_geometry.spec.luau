-- Presentation: normalized multipart smoothie geometry.

do
    local visual = geometry.CreateVisual(smoothie("geometry"))
    check(
        visual:IsA("Model") and visual.PrimaryPart.Name == "SmoothieRoot",
        "Tool normalized to Model with explicit root"
    )
    check(visual:FindFirstChild("Details"):FindFirstChild("Straw") ~= nil, "nested geometry retained")
    local parts, welds = 0, 0
    for _, child in visual:GetDescendants() do
        if child:IsA("BasePart") then
            parts += 1
            check(not child.Anchored and not child.CanCollide and child.Massless, "all carry parts normalized")
        elseif child:IsA("WeldConstraint") then
            welds += 1
            check(
                child.Name == "SmoothieAssembly" and child.Part0 == visual.PrimaryPart,
                "old weld replaced with root weld"
            )
        end
        check(not child:IsA("ProximityPrompt"), "no cloned pickup prompt")
    end
    check(parts == 2 and welds == 1 and handle.Anchored and straw.Anchored, "one assembly, source untouched")
    visual:Destroy()
end

-- Reflow is a presentation contract; survivor usability lives in smoothie_survivors.
do
    local p = player()
    carry(p)
    grant(p, "lower")
    grant(p, "upper")
    local before = anchors(tool(p))
    local topY = before[3].C0.Position.Y
    local bottomHeight = loadModule("IngredientCarry").StackGap + 1.5
    inventory.DropHeld(p)
    local after = anchors(tool(p))
    check(
        math.abs(after[2].C0.Position.Y - (topY - bottomHeight)) < 1e-6,
        "upper visual shifts down after bottom removal"
    )
    inventory.ClearHeld(p)
end
