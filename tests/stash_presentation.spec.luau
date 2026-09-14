local display = loadModule("StashPresentation")
local realIngredients = loadModule("IngredientService")
env.CFrame.fromMatrix = function(position, right, up, back)
    local cf = frame(position.X, position.Y, position.Z)
    cf.RightVector, cf.UpVector, cf.LookVector = right, up, back * -1
    return cf
end
do
    local pad = instance("Part")
    pad:SetAttribute("SlotIndex", 3)
    pad.Position = vec(12, 7, -20)
    pad.Size = vec(0.4, 10, 10)
    pad.CFrame = frame(12, 7, -20)
    for _, sign in { 1, -1 } do
        pad.CFrame.RightVector = vec(0, sign, 0)
        pad.CFrame.UpVector = vec(-sign, 0, 0)
        for n = 1, 5 do
            display.Refresh(pad, { IngredientId = "Strawberry", Count = n, Protected = false }, realIngredients)
            local total = vec(0, 0, 0)
            local copies = pad:FindFirstChild("StashDisplay"):GetChildren()
            check(#copies == n, "rotated pad count")
            for _, copy in copies do
                local part = copy:FindFirstChildWhichIsA("BasePart", true)
                check(
                    part.Size.X > pad.Size.X and part.Size.X < math.min(pad.Size.Y, pad.Size.Z) / 2,
                    "display uses the usable top face, not thin local X, and leaves spacing between items"
                )
                check(
                    copy.CFrame.UpVector:Dot(vec(0, 1, 0)) > 0.999,
                    "display normal points upward for either axis sign"
                )
                check(
                    copy.Position.Y - part.Size.Y / 2 >= 7.2 + 0.12 - 0.0001,
                    "proxy bottom clears actual top surface"
                )
                total += copy.Position - pad.Position
            end
            check(
                math.abs(total.X) < 0.0001 and math.abs(total.Z) < 0.0001,
                "all count layouts center over rotated pad"
            )
        end
    end
    pad:Destroy()
end
