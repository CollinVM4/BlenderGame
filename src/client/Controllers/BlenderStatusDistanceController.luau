--!strict
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
        end
        -- Canvas size, font, opacity, world origin and state text stay authored.
    end
    -- Late replication and streaming use the same idempotent configuration.
    workspace.DescendantAdded:Connect(register)
    for _, object in workspace:GetDescendants() do
        register(object)
    end
end

return Controller
