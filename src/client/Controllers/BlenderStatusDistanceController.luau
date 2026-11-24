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
        if gui.Name == "TurbineStatusDisplay" then
            local function guidanceRange()
                gui.MaxDistance = if object.Text == "LOAD INGREDIENTS TO BLEND!" then maxDistance else 40
            end
            guidanceRange()
            if not cleanups[object] then
                local changed = object:GetPropertyChangedSignal("Text"):Connect(guidanceRange)
                cleanups[object] = function()
                    changed:Disconnect()
                end
            end
        else
            gui.MaxDistance = maxDistance
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
                    if tween then
                        tween:Cancel()
                        tween = nil
                    end
                    scale.Scale = 1
                    if loaded > previousCount then
                        local pop = TweenService:Create(
                            scale,
                            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
                            { Scale = if loaded >= required then 1.1 else 1.06 }
                        )
                        tween = pop
                        pop:Play()
                    end
                    previousCount = loaded
                end)
                cleanups[object] = function()
                    changed:Disconnect()
                    if tween then
                        tween:Cancel()
                    end
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
