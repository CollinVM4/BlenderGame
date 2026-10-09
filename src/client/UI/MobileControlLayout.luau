--!strict
-- Presentation only: CAS still owns the buttons and all action input.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Layout = {}
local OFFSETS = { SprintHeld = Vector2.new(-1.25, 0), ThrowHeld = Vector2.new(-0.95, -0.95) }
local ACTIONS = { "SprintHeld", "ThrowHeld" }
local PADDING = 8
local GAP = 2
local registered: { [string]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local guiConnections: { RBXScriptConnection } = {}
local observed: { [Instance]: { RBXScriptConnection } } = {}
local playerGui: PlayerGui? = nil
local started = false
local queued = false
local generation = 0

local function disconnect(list: { RBXScriptConnection })
    for _, connection in list do
        connection:Disconnect()
    end
    table.clear(list)
end

-- Clamp the entire square hit target, then choose the closest unoccupied position.
-- Obstacle edges provide candidates when clamping would overlap Jump or the other action.
local function place(preferred: Vector2, size: number, bounds: Rect, obstacles: { Rect }): Vector2?
    local half = size / 2
    local low = bounds.Min + Vector2.new(half + PADDING, half + PADDING)
    local high = bounds.Max - Vector2.new(half + PADDING, half + PADDING)
    if low.X > high.X or low.Y > high.Y then
        return nil
    end
    local xs = { math.clamp(preferred.X, low.X, high.X), low.X, high.X }
    local ys = { math.clamp(preferred.Y, low.Y, high.Y), low.Y, high.Y }
    for _, obstacle in obstacles do
        table.insert(xs, math.clamp(obstacle.Min.X - half - GAP, low.X, high.X))
        table.insert(xs, math.clamp(obstacle.Max.X + half + GAP, low.X, high.X))
        table.insert(ys, math.clamp(obstacle.Min.Y - half - GAP, low.Y, high.Y))
        table.insert(ys, math.clamp(obstacle.Max.Y + half + GAP, low.Y, high.Y))
    end
    local best: Vector2? = nil
    local distance = math.huge
    for _, x in xs do
        for _, y in ys do
            local clear = true
            for _, obstacle in obstacles do
                if
                    x + half + GAP > obstacle.Min.X
                    and x - half - GAP < obstacle.Max.X
                    and y + half + GAP > obstacle.Min.Y
                    and y - half - GAP < obstacle.Max.Y
                then
                    clear = false
                    break
                end
            end
            local delta = Vector2.new(x, y) - preferred
            local cost = delta:Dot(delta)
            if clear and cost < distance then
                best, distance = Vector2.new(x, y), cost
            end
        end
    end
    return best
end

local function visible(object: Instance, root: PlayerGui): boolean
    local ancestor: Instance? = object
    while ancestor and ancestor ~= root do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then
            return false
        end
        if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
            return false
        end
        ancestor = ancestor.Parent
    end
    return ancestor == root
end

local update: () -> ()
local function schedule()
    if queued or not started then
        return
    end
    queued = true
    local version = generation
    task.defer(function()
        if version ~= generation then
            return
        end
        queued = false
        update()
    end)
end

local function watch(wanted: { [Instance]: boolean }, object: Instance, properties: { string })
    wanted[object] = true
    if observed[object] then
        return
    end
    local list = { object.AncestryChanged:Connect(schedule) }
    for _, property in properties do
        table.insert(list, object:GetPropertyChangedSignal(property):Connect(schedule))
    end
    observed[object] = list
end

local function watchAncestors(wanted: { [Instance]: boolean }, object: Instance, root: PlayerGui)
    local ancestor = object.Parent
    while ancestor and ancestor ~= root do
        if ancestor:IsA("GuiObject") then
            watch(wanted, ancestor, { "AbsolutePosition", "AbsoluteSize", "Visible" })
        elseif ancestor:IsA("ScreenGui") then
            watch(wanted, ancestor, { "Enabled", "ScreenInsets", "IgnoreGuiInset" })
        end
        ancestor = ancestor.Parent
    end
end

local function clearUnused(wanted: { [Instance]: boolean })
    for object, list in observed do
        if not wanted[object] then
            disconnect(list)
            observed[object] = nil
        end
    end
end

local function relevant(object: Instance)
    -- Only a name hint for native discovery; no WaitForChild chain or CoreGui access.
    if object:IsA("GuiButton") or object:IsA("ScreenGui") or object.Name == "ContextButtonFrame" then
        schedule()
    end
end

update = function()
    local player = Players.LocalPlayer
    local root = if UserInputService.TouchEnabled then player:FindFirstChildOfClass("PlayerGui") else nil
    if root ~= playerGui then
        disconnect(guiConnections)
        clearUnused({})
        playerGui = root
        if root then
            table.insert(guiConnections, root.DescendantAdded:Connect(relevant))
            table.insert(guiConnections, root.DescendantRemoving:Connect(relevant))
        end
    end
    if not root then
        return
    end

    local wanted: { [Instance]: boolean } = {}
    local camera = workspace.CurrentCamera
    if camera then
        watch(wanted, camera, { "ViewportSize" })
    end
    local jump: GuiButton? = nil
    local touchGui = root:FindFirstChild("TouchGui")
    if touchGui then
        for _, object in touchGui:GetDescendants() do
            if object.Name == "JumpButton" and object:IsA("GuiButton") then
                watch(wanted, object, { "AbsolutePosition", "AbsoluteSize", "Visible" })
                watchAncestors(wanted, object, root)
                if visible(object, root) and object.AbsoluteSize.X > 0 and object.AbsoluteSize.Y > 0 then
                    jump = object
                    break
                end
            end
        end
    end

    -- AbsolutePosition and GetInsetArea both use CoreUISafeInsets coordinates.
    -- Subtracting the live CAS parent origin accounts for each ScreenGui's insets.
    local ok, area = pcall(function()
        return GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
    end)
    local bounds: Rect
    if ok then
        bounds = area
    elseif camera then
        local topLeft, bottomRight = GuiService:GetGuiInset()
        bounds = Rect.new(Vector2.zero, camera.ViewportSize - topLeft - bottomRight)
    else
        clearUnused(wanted)
        return
    end
    local available = bounds.Max - bounds.Min
    if available.X <= PADDING * 2 or available.Y <= PADDING * 2 then
        clearUnused(wanted)
        return
    end
    local diameter = math.clamp(math.min(available.X, available.Y) * 0.18, 70, 120)
    local jumpSize = Vector2.new(diameter, diameter)
    local center = bounds.Max - jumpSize / 2 - Vector2.new(PADDING, PADDING)
    if jump then
        jumpSize = jump.AbsoluteSize
        diameter = math.min(jumpSize.X, jumpSize.Y)
        center = jump.AbsolutePosition + jumpSize / 2
    end
    local size = math.max(44, diameter * 0.83)
    local obstacles = { Rect.new(center - jumpSize / 2, center + jumpSize / 2) }
    for _, action in ACTIONS do
        if not registered[action] then
            continue
        end
        local button = ContextActionService:GetButton(action)
        if not button or not button:IsDescendantOf(root) then
            continue
        end
        watch(wanted, button, { "AbsoluteSize", "AnchorPoint" })
        watchAncestors(wanted, button, root)
        local parent = button.Parent
        if not parent or not parent:IsA("GuiObject") then
            continue
        end
        local parentSize = parent.AbsoluteSize
        if parentSize.X <= 0 or parentSize.Y <= 0 then
            continue
        end
        local offset = OFFSETS[action]
        local position = place(center + offset * diameter, size, bounds, obstacles)
        if position then
            local half = Vector2.new(size / 2, size / 2)
            table.insert(obstacles, Rect.new(position - half, position + half))
            -- Scale ratios also handle a UIScale on the CAS parent. Preserve AnchorPoint.
            local localPosition = position
                - parent.AbsolutePosition
                + (button.AnchorPoint - Vector2.new(0.5, 0.5)) * size
            local buttonSize = UDim2.fromScale(size / parentSize.X, size / parentSize.Y)
            local buttonPosition = UDim2.fromScale(localPosition.X / parentSize.X, localPosition.Y / parentSize.Y)
            if button.Size ~= buttonSize then
                button.Size = buttonSize
            end
            if button.Position ~= buttonPosition then
                ContextActionService:SetPosition(action, buttonPosition)
            end
        end
    end
    clearUnused(wanted)
end

function Layout.Destroy()
    started = false
    queued = false
    generation += 1
    disconnect(connections)
    disconnect(guiConnections)
    clearUnused({})
    playerGui = nil
    table.clear(registered)
end

function Layout.Register(action: string)
    assert(OFFSETS[action], "Unknown mobile action")
    registered[action] = true
    if not started then
        started = true
        local player = Players.LocalPlayer
        table.insert(connections, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(schedule))
        table.insert(connections, GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(schedule))
        table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(schedule))
        table.insert(connections, player.ChildAdded:Connect(schedule))
        table.insert(connections, player.ChildRemoved:Connect(schedule))
        table.insert(connections, script.Destroying:Connect(Layout.Destroy))
    end
    schedule()
end

return Layout
