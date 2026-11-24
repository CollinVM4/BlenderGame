--!strict
local TweenService = game:GetService("TweenService")
local Controller = {}
local started = false

-- Scoped visibility ranges; Roblox performs camera-distance culling.
local MAX_DISTANCES: { [string]: number } = {
    IngredientCountDisplay = 40,
    TurbineStatusDisplay = 40,
}

function Controller.Init()
    if started then
        return
    end
    started = true
    local cleanups: { [Instance]: () -> () } = {}
    local function register(object: Instance)
        if not object:IsA("TextLabel") or object.Name ~= "Status" then
            return
        end
        local gui = object.Parent
        if not gui or not gui:IsA("BillboardGui") then
            return
        end
        local maxDistance = MAX_DISTANCES[gui.Name]
        if not maxDistance then
            return
        end
        gui.MaxDistance = maxDistance
        if gui.Name == "TurbineStatusDisplay" and not cleanups[object] then
            local tween: Tween? = nil
            local scale = Instance.new("UIScale")
            scale.Scale = 1
            scale.Parent = object
            local function resetMotion()
                if tween then
                    tween:Cancel()
                    tween = nil
                end
                scale.Scale = 1
                object.Rotation = 0
            end
            local function animateStatus()
                resetMotion()
                local animation: Tween
                if object.Text == "BLENDING..." then
                    object.Rotation = -4
                    animation = TweenService:Create(
                        object,
                        TweenInfo.new(0.23, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                        { Rotation = 4 }
                    )
                elseif object.Text == "READY TO DISPENSE!" then
                    animation = TweenService:Create(
                        scale,
                        TweenInfo.new(0.38, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                        { Scale = 1.10 }
                    )
                else
                    return
                end
                tween = animation
                animation:Play()
            end
            local changed = object:GetPropertyChangedSignal("Text"):Connect(animateStatus)
            animateStatus()
            cleanups[object] = function()
                changed:Disconnect()
                resetMotion()
                scale:Destroy()
            end
        end
        if gui.Name == "IngredientCountDisplay" then
            -- Retain the label's existing centered layout inside the stud canvas.
            object.AnchorPoint = Vector2.new(0.5, 0.5)
            object.Position = UDim2.fromScale(0.5, 0.5)
            object.TextScaled = true
            if not cleanups[object] then
                local scale = Instance.new("UIScale")
                scale.Scale = 1
                scale.Parent = object
                local tween: Tween? = nil
                local settle: Tween? = nil
                local rest = object.Position
                local function resetMotion()
                    if tween then
                        tween:Cancel()
                    end
                    if settle then
                        settle:Cancel()
                    end
                    scale.Scale = 1
                    object.Position = rest
                    object.Rotation = 0
                end
                local function readCount(): (number, number)
                    local loaded, required = string.match(object.Text, "^(%d+)%s*/%s*(%d+)")
                    return tonumber(loaded) or 0, tonumber(required) or math.huge
                end
                local previousCount = readCount()
                local changed = object:GetPropertyChangedSignal("Text"):Connect(function()
                    local loaded, required = readCount()
                    if loaded == previousCount then
                        return
                    end
                    resetMotion()
                    if loaded > previousCount then
                        local full = loaded >= required
                        object.Position = UDim2.fromScale(0.5, if full then 0.40 else 0.44)
                        object.Rotation = if loaded % 2 == 0 then 6 else -6
                        local spring = TweenService:Create(
                            object,
                            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                            { Position = rest, Rotation = 0 }
                        )
                        settle = spring
                        spring:Play()
                        local pop = TweenService:Create(
                            scale,
                            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
                            { Scale = if full then 1.16 else 1.09 }
                        )
                        tween = pop
                        pop:Play()
                    end
                    previousCount = loaded
                end)
                cleanups[object] = function()
                    changed:Disconnect()
                    resetMotion()
                    scale:Destroy()
                end
            end
        end
        -- Canvas size, font, opacity, world origin and state text stay authored.
    end
    -- Late replication and streaming use the same idempotent configuration.
    workspace.DescendantAdded:Connect(register)
    workspace.DescendantRemoving:Connect(function(object)
        local cleanup = cleanups[object]
        if cleanup then
            cleanups[object] = nil
            cleanup()
        end
    end)
    for _, object in workspace:GetDescendants() do
        register(object)
    end
end

return Controller
