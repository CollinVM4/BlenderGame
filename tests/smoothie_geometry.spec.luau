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

do
    template.Grip = frame(1, 2, 3)
    template.Enabled, template.ManualActivationOnly = false, true
    local handTool = geometry.CreateTool(smoothie("hand-grip"))
    check(handTool:IsA("Tool") and handTool:FindFirstChild("Handle") ~= nil, "authored Tool keeps normal Handle")
    check(handTool.Grip == template.Grip and handTool.RequiresHandle, "authored grip preserved")
    check(handTool.Enabled and not handTool.ManualActivationOnly, "ordinary player click activation enabled")
    check(
        not handTool:FindFirstChild("CarryAnchor") and not handTool:FindFirstChild("SmoothieRoot"),
        "no overhead smoothie presentation"
    )
    handTool:Destroy()
end
