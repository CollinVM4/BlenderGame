--!strict
local TweenService = game:GetService("TweenService")
local Controller = {}
local started = false

-- Preserve the existing visibility ranges; Roblox performs camera-distance culling.
local MAX_DISTANCES: { [string]: number } = {
    IngredientCountDisplay = 60,
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
        if gui.Name == "IngredientCountDisplay" then
            -- Retain the label's existing centered layout inside the pixel canvas.
            object.AnchorPoint = Vector2.new(0.5, 0.5)
            object.Position = UDim2.fromScale(0.5, 0.5)
            object.TextScaled = false
            if not cleanups[object] then
                local scale = Instance.new("UIScale")
                scale.Scale = 1
                scale.Parent = object
                local tween: Tween? = nil
                local function complete(): boolean
                    local loaded, required = string.match(object.Text, "^(%d+)%s*/%s*(%d+)")
                    return loaded ~= nil and required ~= nil and tonumber(loaded) >= tonumber(required)
                end
                local wasComplete = complete()
                local changed = object:GetPropertyChangedSignal("Text"):Connect(function()
                    local full = complete()
                    if full ~= wasComplete then
                        if tween then
                            tween:Cancel()
                        end
                        scale.Scale = 1
                        if full then
                            local pop = TweenService:Create(
                                scale,
                                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
                                { Scale = 1.1 }
                            )
                            tween = pop
                            pop:Play()
                        end
                    end
                    wasComplete = full
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
