--!strict
-- Observes replicated Tools only. Selection never sends gameplay requests.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Gui = require(script.Parent.Parent.UI.HotbarGui)
local IngredientViewport = require(script.Parent.Parent.UI.IngredientViewport)
local Geometry = require(Shared.IngredientPreviewGeometry)
local Registry = require(script.Parent.Parent.UI.UIRegistry)
local Controller = {}
local MIN_SLOT_WIDTH = 48
local BAR_HEIGHT, MAX_WIDTH = 96, 960
local ACTION = "HotbarSelect"
local KEYS = {
    Enum.KeyCode.One,
    Enum.KeyCode.Two,
    Enum.KeyCode.Three,
    Enum.KeyCode.Four,
    Enum.KeyCode.Five,
    Enum.KeyCode.Six,
    Enum.KeyCode.Seven,
    Enum.KeyCode.Eight,
    Enum.KeyCode.Nine,
    Enum.KeyCode.Zero,
}
type Item = { Tool: Tool, Kind: string, Label: string, Id: string?, Key: number, Sequence: number }
type Binding = {
    Slot: Gui.Slot,
    Tool: Tool?,
    Kind: string?,
    Id: string?,
    Dispose: (() -> ())?,
    Connection: RBXScriptConnection,
    OriginalParent: Instance?,
    Clone: boolean,
    Metrics: Gui.Metrics,
}
local function disconnect(list: { RBXScriptConnection })
    for _, c in list do
        c:Disconnect()
    end
    table.clear(list)
end
function Controller.Classify(tool: Tool): (string?, string?, string?, number?)
    if tool:GetAttribute("IceGunWeapon") == true then
        return "Ice", "Ice Gun", nil, 4
    end
    if typeof(tool:GetAttribute("BatLevel")) == "number" then
        return "Bat", "Bat", nil, 3
    end
    local id = tool:GetAttribute("IngredientId")
    if id ~= nil then
        local key = tool:GetAttribute("CarryItemId")
        if typeof(key) ~= "number" or key ~= key or math.abs(key) == math.huge or key % 1 ~= 0 or key < 1 then
            return "InvalidIngredient", tool.Name, nil, nil
        end
        return "Ingredient", tool.Name, if typeof(id) == "string" then id else nil, key
    end
    if tool.Name == "Smoothie" then
        return "Smoothie", "Smoothie", nil, 2
    end
    return nil, nil, nil, nil
end
local function visual(tool: Tool, icon: ImageLabel): (() -> ())?
    -- Geometry.Clone allowlists inert geometry. A Tool itself is never parented
    -- into the preview tree, and no scripts are copied into a live container.
    local model = Instance.new("Model")
    for _, child in tool:GetChildren() do
        local copy = Geometry.Clone(child)
        if copy then
            copy.Parent = model
        end
    end
    if #model:GetChildren() == 0 then
        model:Destroy()
        return nil
    end
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "HotbarToolPreview"
    viewport.BackgroundTransparency = 1
    viewport.Size, viewport.Position, viewport.AnchorPoint = UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Vector2.zero
    viewport.ZIndex = icon.ZIndex
    viewport.Ambient, viewport.LightColor = Color3.fromRGB(190, 190, 190), Color3.new(1, 1, 1)
    local world = Instance.new("WorldModel")
    world.Parent = viewport
    model.Parent = world
    local _, original = model:GetBoundingBox()
    model:ScaleTo(model:GetScale() * 4 / math.max(original.X, original.Y, original.Z, 0.001))
    local box, size = model:GetBoundingBox()
    model:PivotTo(model:GetPivot() - box.Position)
    local camera = Instance.new("Camera")
    camera.FieldOfView = 35
    camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
    camera.Parent, viewport.CurrentCamera = viewport, camera
    local function frame()
        local pixels = viewport.AbsoluteSize
        local distance = Geometry.Distance(size, if pixels.Y > 0 then pixels.X / pixels.Y else 1, 35)
        camera.CFrame = CFrame.lookAt(Vector3.new(1, 0.65, 1).Unit * distance, Vector3.zero)
    end
    viewport.Parent = icon
    frame()
    local resized = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
    local disposed = false
    local destroying: RBXScriptConnection? = nil
    local function cleanup()
        if disposed then
            return
        end
        disposed = true
        resized:Disconnect()
        if destroying then
            destroying:Disconnect()
        end
        viewport:Destroy()
    end
    destroying = viewport.Destroying:Connect(cleanup)
    return cleanup
end

function Controller.Start(player: Player, playerGui: PlayerGui): () -> ()
    local stopped, queued, enabled, bound = false, false, false, false
    local mutating = false
    local handoffAttempts = 0
    local character = player.Character
    local removing = false
    local backpack: Backpack? = nil
    local connections: { RBXScriptConnection } = {}
    local containers: { RBXScriptConnection } = {}
    local uiConnections: { RBXScriptConnection } = {}
    local controls: { [GuiButton]: boolean } = {}
    local observed: { [Tool]: { RBXScriptConnection } } = {}
    local sequence: { [Tool]: number } = setmetatable({}, { __mode = "k" }) :: any
    local serial = 0
    local warnings: { [string]: boolean } = {}
    local view: Gui.View? = nil
    local pool: { Binding } = {}
    local items: { Item } = {}
    local pristine: GuiButton? = nil
    local host: ScrollingFrame? = nil
    local ownedHost = false
    local layout: UIListLayout? = nil
    local ownedLayout = false
    local savedLayout: any = nil
    local savedBar: any = nil
    local schedule: () -> ()
    local render: () -> ()
    local function warning(key: string, message: string)
        if not warnings[key] then
            warnings[key] = true
            warn("HotbarController: " .. message)
        end
    end
    local function native()
        -- CoreGui may not have initialized. Retry restoration independently of
        -- inventory/UI signals; a new successful handoff cancels stale retries.
        enabled = false
        if bound then
            CAS:UnbindAction(ACTION)
            bound = false
        end
        local function restore(attempt: number)
            if enabled then
                return
            end
            local ok = pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
            end)
            if not ok and attempt < 8 then
                task.delay(0.25, function()
                    restore(attempt + 1)
                end)
            end
        end
        restore(1)
    end
    local function clearBinding(binding: Binding)
        if binding.Dispose then
            binding.Dispose()
            binding.Dispose = nil
        end
        binding.Tool, binding.Kind, binding.Id = nil, nil, nil
        local icon = binding.Slot.Icon
        icon.Image = ""
        -- Remove prior render sources, including legacy sibling previews. The
        -- authored ImageLabel is the sole host; constraints are not sources.
        for _, child in icon:GetChildren() do
            if child:IsA("ViewportFrame") or child:IsA("ImageLabel") then
                child:Destroy()
            end
        end
        for _, child in binding.Slot.Button:GetChildren() do
            if child.Name == "IngredientPreview" or child.Name == "HotbarToolPreview" then
                child:Destroy()
            end
        end
        binding.Slot.Selected.Visible = false
        binding.Slot.Button.Visible = false
        binding.Slot.Button.NextSelectionLeft = binding.Slot.Button
        binding.Slot.Button.NextSelectionRight = binding.Slot.Button
        if GuiService.SelectedObject == binding.Slot.Button then
            GuiService.SelectedObject = nil
        end
    end
    local function release()
        local wasMutating = mutating
        mutating = true
        native()
        disconnect(uiConnections)
        table.clear(controls)
        for _, binding in pool do
            clearBinding(binding)
            binding.Connection:Disconnect()
            if binding.Clone then
                binding.Slot.Button:Destroy()
            elseif binding.Slot.Button.Parent then
                binding.Slot.Button.Parent = binding.OriginalParent
            end
        end
        table.clear(pool)
        if pristine then
            pristine:Destroy()
            pristine = nil
        end
        if ownedLayout and layout then
            layout:Destroy()
        elseif layout and savedLayout then
            layout.FillDirection, layout.SortOrder, layout.HorizontalAlignment =
                savedLayout.FillDirection, savedLayout.SortOrder, savedLayout.HorizontalAlignment
            layout.Padding = savedLayout.Padding
            if view then
                layout.Parent = view.Bar
            end
        end
        if ownedHost and host then
            host:Destroy()
        end
        if view then
            if savedBar then
                view.Bar.AnchorPoint, view.Bar.Position, view.Bar.Size =
                    savedBar.AnchorPoint, savedBar.Position, savedBar.Size
            end
            view.Bar.Visible = false
        end
        view, host, layout, savedBar, savedLayout = nil, nil, nil, nil, nil
        ownedHost, ownedLayout = false, false
        mutating = wasMutating
    end
    local function owned(tool: Tool): boolean
        return not removing
            and character ~= nil
            and character == player.Character
            and (
                tool.Parent == character or (backpack ~= nil and tool.Parent == backpack and backpack.Parent == player)
            )
    end
    local function guarded(): boolean
        return GuiService.MenuIsOpen or player.GameplayPaused or UIS:GetFocusedTextBox() ~= nil
    end
    local function selectTool(tool: Tool?)
        if not enabled or not tool or not owned(tool) or guarded() then
            return
        end
        local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
        if not humanoid or humanoid.Health <= 0 then
            return
        end
        if tool.Parent == character then
            humanoid:UnequipTools()
        else
            humanoid:EquipTool(tool)
        end
    end
    local function bind(slot: Gui.Slot, clone: boolean, metrics: Gui.Metrics)
        local binding: Binding
        binding = {
            Slot = slot,
            Tool = nil,
            Kind = nil,
            Id = nil,
            Dispose = nil,
            OriginalParent = slot.Button.Parent,
            Clone = clone,
            Metrics = metrics,
            Connection = slot.Button.Activated:Connect(function()
                selectTool(binding.Tool)
            end),
        }
        slot.Button.Active, slot.Button.Selectable = true, true
        Gui.Aspect(slot.Button, metrics.Ratio)
        Gui.Aspect(slot.Icon, metrics.IconRatio)
        slot.Icon.ScaleType = Enum.ScaleType.Fit
        Gui.Text(slot.Label, metrics.TextMin, metrics.TextMax)
        local minimum = slot.Button:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
        minimum.Parent = slot.Button
        minimum.MinSize = Vector2.new(MIN_SLOT_WIDTH, MIN_SLOT_WIDTH)
        slot.Button.Parent = host
        table.insert(pool, binding)
        table.insert(
            uiConnections,
            slot.Button:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                if enabled and (slot.Selected.Visible or GuiService.SelectedObject == slot.Button) then
                    schedule()
                end
            end)
        )
        clearBinding(binding)
    end
    local function reveal(button: GuiButton)
        local scroll = host
        if not scroll then
            return
        end
        local left = button.AbsolutePosition.X - scroll.AbsolutePosition.X + scroll.CanvasPosition.X
        local right = left + button.AbsoluteSize.X
        local width = scroll.AbsoluteWindowSize.X
        local position = scroll.CanvasPosition.X
        if left < position then
            position = left
        elseif right > position + width then
            position = right - width
        end
        scroll.CanvasPosition =
            Vector2.new(math.clamp(position, 0, math.max(0, scroll.AbsoluteCanvasSize.X - width)), 0)
    end
    local function resize(): boolean
        local current = view
        local scroll = host
        if not current or not scroll or not layout then
            return false
        end
        local parent = current.Bar.Parent
        if not parent or not parent:IsA("GuiObject") then
            return false
        end
        local pixels = parent.AbsoluteSize
        if pixels.X < MIN_SLOT_WIDTH or pixels.Y < BAR_HEIGHT + 24 then
            return false
        end
        -- The export uses relative dimensions (0.483333 x 0.088889).
        -- Cap the authored desktop width; keep a fixed target band on phones.
        local bottom = 12
        if UIS.TouchEnabled then
            local buttons: { GuiButton } = {}
            for _, action in { "SprintHeld", "ThrowHeld", "IceShotgunFire" } do
                local button = CAS:GetButton(action)
                if button then
                    table.insert(buttons, button)
                end
            end
            local touchGui = playerGui:FindFirstChild("TouchGui")
            if touchGui then
                for _, object in touchGui:GetDescendants() do
                    if object.Name == "JumpButton" and object:IsA("GuiButton") then
                        table.insert(buttons, object)
                    end
                end
            end
            for _, button in buttons do
                if not controls[button] then
                    controls[button] = true
                    for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
                        table.insert(uiConnections, button:GetPropertyChangedSignal(property):Connect(schedule))
                    end
                end
                if button.Visible then
                    bottom = math.max(bottom, parent.AbsolutePosition.Y + pixels.Y - button.AbsolutePosition.Y + 8)
                end
            end
        end
        if pixels.Y < bottom + BAR_HEIGHT + 12 then
            return false
        end
        current.Bar.AnchorPoint = Vector2.new(0.5, 1)
        current.Bar.Position = UDim2.new(0.5, 0, 1, -bottom)
        -- The floor affects the canvas only, never the outer bar width.
        local desiredWidth = pixels.X * savedBar.Size.X.Scale + savedBar.Size.X.Offset
        current.Bar.Size =
            UDim2.fromScale(math.min(0.9, MAX_WIDTH / pixels.X, desiredWidth / pixels.X), BAR_HEIGHT / pixels.Y)
        local padding = scroll:FindFirstChildOfClass("UIPadding")
        local width = scroll.AbsoluteWindowSize.X
        local horizontalPadding = if padding
            then (padding.PaddingLeft.Scale + padding.PaddingRight.Scale) * width
                + padding.PaddingLeft.Offset
                + padding.PaddingRight.Offset
            else 0
        local gap = layout.Padding.Scale * width + layout.Padding.Offset
        local nominal = math.max(0, (width - horizontalPadding - 8 * gap) / 9)
        local bandHeight = scroll.AbsoluteSize.Y - scroll.ScrollBarThickness
        local canvas = horizontalPadding
        for _, binding in pool do
            local slot, metrics = binding.Slot, binding.Metrics
            local label = slot.Label :: TextLabel
            -- Uniform growth meets BOTH floors before constraints run. Neither
            -- constraint resolution order nor overflow can stretch one axis.
            local slotWidth =
                math.max(MIN_SLOT_WIDTH, MIN_SLOT_WIDTH * metrics.Ratio, math.min(nominal, bandHeight * metrics.Ratio))
            local labelWidth = 0.96
            local iconBottom = slot.Icon.Position.Y.Scale + slot.Icon.Size.Y.Scale * (1 - slot.Icon.AnchorPoint.Y)
            local available = math.max(0.1, 0.98 - iconBottom)
            local bounds = TextService:GetTextSize(
                slot.Label.Text,
                metrics.TextMin,
                slot.Label.Font,
                Vector2.new(slotWidth * labelWidth, math.huge)
            )
            -- A long name can grow its square/rectangle uniformly within the
            -- existing band; horizontal canvas growth absorbs the extra width.
            while bounds.Y + 1 > slotWidth / metrics.Ratio * available and slotWidth / metrics.Ratio < bandHeight do
                slotWidth = math.min(bandHeight * metrics.Ratio, slotWidth * 1.1)
                bounds = TextService:GetTextSize(
                    slot.Label.Text,
                    metrics.TextMin,
                    slot.Label.Font,
                    Vector2.new(slotWidth * labelWidth, math.huge)
                )
            end
            local height = slotWidth / metrics.Ratio
            if binding.Tool and (height > bandHeight + 0.01 or bounds.Y + 1 > height * available) then
                return false
            end
            slot.Button.Size = UDim2.fromScale(slotWidth / width, height / scroll.AbsoluteSize.Y)
            local labelHeight = math.min(
                available,
                math.max((bounds.Y + 1) / height, metrics.LabelHeight, metrics.TextMax * 1.2 / height)
            )
            label.Size = UDim2.fromScale(labelWidth, labelHeight)
            label.Position = UDim2.fromScale(
                0.5,
                math.min(1 - labelHeight / 2, math.max(metrics.LabelY, iconBottom + labelHeight / 2))
            )
            local number = slot.Button:FindFirstChild("Number")
            if number and number:IsA("TextLabel") then
                local authoredMinimum = number:GetAttribute("HotbarTextMin")
                local minimum = if typeof(authoredMinimum) == "number" then authoredMinimum else number.TextSize
                number:SetAttribute("HotbarTextMin", minimum)
                local fontSize = number:GetAttribute("FigmaFontSize")
                Gui.Text(number, minimum, math.max(minimum, if typeof(fontSize) == "number" then fontSize else minimum))
                local numberBounds =
                    TextService:GetTextSize(number.Text, minimum, number.Font, Vector2.new(math.huge, math.huge))
                number.Size = UDim2.fromScale(
                    math.max(number.Size.X.Scale, numberBounds.X / slotWidth),
                    math.max(number.Size.Y.Scale, numberBounds.Y / height)
                )
            end
            if binding.Tool then
                canvas += slotWidth + gap
            end
        end
        scroll.CanvasSize = UDim2.fromScale(math.max(0, canvas - (if #items > 0 then gap else 0)) / width, 0)
        for _, binding in pool do
            if binding.Slot.Button.Visible then
                local size = binding.Slot.Button.AbsoluteSize
                if size.X > 0 and size.Y > 0 and (size.X < 48 or size.Y < 48) then
                    return false
                end
            end
            if
                binding.Slot.Button.Visible
                and (binding.Slot.Selected.Visible or GuiService.SelectedObject == binding.Slot.Button)
            then
                reveal(binding.Slot.Button)
            end
        end
        return true
    end
    local function setup(nextView: Gui.View): boolean
        view = nextView
        local bar = nextView.Bar
        local metrics = {}
        for index, slot in nextView.Slots do
            metrics[index] = Gui.Metrics(slot, nextView.Root)
            slot.Icon.Image = ""
            slot.Button.Visible = false
        end
        pristine = nextView.Slots[1].Button:Clone()
        savedBar = { AnchorPoint = bar.AnchorPoint, Position = bar.Position, Size = bar.Size }
        if bar:IsA("ScrollingFrame") then
            host = bar
        else
            local scroll = Instance.new("ScrollingFrame")
            scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "HotbarScroll", 1, 0
            scroll.Size, scroll.ZIndex = UDim2.fromScale(1, 1), bar.ZIndex
            scroll.Parent = bar
            host, ownedHost = scroll, true
        end
        local scroll = host :: ScrollingFrame
        scroll.ScrollingDirection = Enum.ScrollingDirection.X
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
        scroll.ScrollBarThickness = 4
        local existing = bar:FindFirstChildOfClass("UIListLayout")
        if existing then
            layout = existing
            savedLayout = {
                FillDirection = existing.FillDirection,
                SortOrder = existing.SortOrder,
                HorizontalAlignment = existing.HorizontalAlignment,
                Padding = existing.Padding,
            }
            existing.Parent = scroll
        else
            local created = Instance.new("UIListLayout")
            created.Padding = UDim.new(8 / 928, 0)
            created.Parent = scroll
            layout = created
            ownedLayout = true
        end
        local list = layout :: UIListLayout
        local authoredWidth = math.max(1, bar.AbsoluteSize.X)
        list.Padding = UDim.new(list.Padding.Scale + list.Padding.Offset / authoredWidth, 0)
        list.FillDirection, list.SortOrder = Enum.FillDirection.Horizontal, Enum.SortOrder.LayoutOrder
        list.HorizontalAlignment = Enum.HorizontalAlignment.Left
        for _, child in bar:GetChildren() do
            if
                Registry.Matches(child, "Slot1", { "Slot1", "Slot1_button", "Slot1_button_smooth" })
                and child:IsA("GuiObject")
            then
                child.Visible = false
            end
        end
        for index, slot in nextView.Slots do
            bind(slot, false, metrics[index])
        end
        table.insert(uiConnections, scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule))
        table.insert(
            uiConnections,
            list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if enabled and not resize() then
                    release()
                end
            end)
        )
        return true
    end
    local function activateKeys()
        if bound then
            return
        end
        CAS:UnbindAction(ACTION)
        CAS:BindAction(ACTION, function(_, state, input)
            if not enabled or guarded() then
                return Enum.ContextActionResult.Pass
            end
            local index = table.find(KEYS, input.KeyCode)
            local item = if index then items[index] else nil
            if not item then
                return Enum.ContextActionResult.Pass
            end
            if state == Enum.UserInputState.Begin then
                selectTool(item.Tool)
            end
            return Enum.ContextActionResult.Sink
        end, false, table.unpack(KEYS))
        bound = true
    end
    local function collect(): boolean
        local found: { [Tool]: boolean } = {}
        local nextItems: { Item } = {}
        if removing or not character or character ~= player.Character then
            items = {}
            return true
        end
        for _, container in { backpack :: Instance?, character :: Instance? } do
            if not container then
                continue
            end
            for _, child in container:GetChildren() do
                if not child:IsA("Tool") or found[child] or not owned(child) then
                    continue
                end
                found[child] = true
                if not sequence[child] then
                    serial += 1
                    sequence[child] = serial
                end
                if not observed[child] then
                    local list = {
                        child.AncestryChanged:Connect(schedule),
                        child.Equipped:Connect(schedule),
                        child.Unequipped:Connect(schedule),
                        child:GetPropertyChangedSignal("Name"):Connect(schedule),
                    }
                    for _, attribute in { "IngredientId", "CarryItemId", "BatLevel", "IceGunWeapon" } do
                        table.insert(list, child:GetAttributeChangedSignal(attribute):Connect(schedule))
                    end
                    observed[child] = list
                end
                local kind, label, id, key = Controller.Classify(child)
                if kind == "InvalidIngredient" then
                    warning(
                        "carry:" .. tostring(sequence[child]),
                        child:GetFullName() .. ": missing/malformed numeric CarryItemId; custom UI paused"
                    )
                    nextItems = {}
                    items = {}
                    return false
                end
                if kind and label and key then
                    table.insert(
                        nextItems,
                        { Tool = child, Kind = kind, Label = label, Id = id, Key = key, Sequence = sequence[child] }
                    )
                end
            end
        end
        for tool, list in observed do
            if not found[tool] then
                disconnect(list)
                observed[tool] = nil
            end
        end
        local rank = { Ingredient = 1, Smoothie = 2, Bat = 3, Ice = 4 }
        table.sort(nextItems, function(a, b)
            local ar, br = rank[a.Kind], rank[b.Kind]
            if ar ~= br then
                return ar < br
            end
            if a.Kind == "Ingredient" and a.Key ~= b.Key then
                return a.Key < b.Key
            end
            return a.Sequence < b.Sequence
        end)
        items = nextItems
        return true
    end
    render = function()
        if stopped then
            return
        end
        if removing then
            release()
            return
        end
        local root, bar = Gui.Find(playerGui)
        if view and (root ~= view.Root or bar ~= view.Bar) then
            release()
        end
        if not view then
            local nextView = Gui.Resolve(playerGui)
            if not nextView then
                if bar then
                    bar.Visible = false
                end
                native()
                return
            end
            setup(nextView)
        end
        local current = view :: Gui.View
        for _, binding in pool do
            local slot = Gui.Slot(binding.Slot.Button)
            if
                not slot
                or slot.Icon ~= binding.Slot.Icon
                or slot.Label ~= binding.Slot.Label
                or slot.Selected ~= binding.Slot.Selected
                or slot.Background ~= binding.Slot.Background
                or not slot.Button:IsDescendantOf(current.Bar)
            then
                release()
                return
            end
        end
        if collect() == false then
            release()
            return
        end
        while #pool < #items do
            local copy = (pristine :: GuiButton):Clone()
            local slot = Gui.Slot(copy)
            if not slot then
                copy:Destroy()
                release()
                return
            end
            bind(slot, true, pool[1].Metrics)
        end
        -- Keep unchanged Tools in their existing bindings; order is LayoutOrder,
        -- never authored child enumeration or duplicated exported LayoutOrder.
        local assigned: { [Tool]: Binding } = {}
        local wanted: { [Tool]: boolean } = {}
        for _, item in items do
            wanted[item.Tool] = true
        end
        for _, binding in pool do
            if binding.Tool and wanted[binding.Tool] then
                assigned[binding.Tool] = binding
            else
                clearBinding(binding)
            end
        end
        local ordered: { Binding } = {}
        for index, item in items do
            local binding = assigned[item.Tool]
            if not binding then
                for _, candidate in pool do
                    if not candidate.Tool then
                        binding = candidate
                        break
                    end
                end
            end
            local target = binding :: Binding
            if target.Tool ~= item.Tool or target.Kind ~= item.Kind or target.Id ~= item.Id then
                clearBinding(target)
                target.Tool, target.Kind, target.Id = item.Tool, item.Kind, item.Id
                local dispose = if item.Kind == "Ingredient" and item.Id
                    then IngredientViewport.Create(target.Slot.Icon, item.Id)
                    else nil
                if not dispose then
                    dispose = visual(item.Tool, target.Slot.Icon)
                end
                -- IngredientViewport's shared pipeline initially creates a
                -- sibling. Move that one render into the cleared icon host.
                for _, child in target.Slot.Button:GetChildren() do
                    if child:IsA("ViewportFrame") and child.Name == "IngredientPreview" then
                        child.Size, child.Position, child.AnchorPoint =
                            UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Vector2.zero
                        child.Rotation = 0
                        child.Parent = target.Slot.Icon
                    end
                end
                for _, child in target.Slot.Icon:GetChildren() do
                    if child:IsA("ViewportFrame") then
                        Gui.Aspect(child, target.Metrics.IconRatio)
                    end
                end
                target.Dispose = dispose
                if not dispose then
                    local art = if item.Kind == "Bat"
                        then current.BatImage
                        elseif item.Kind == "Ice" then current.IceImage
                        else nil
                    if art then
                        target.Slot.Icon.Image = art
                    else
                        target.Slot.Icon.Image = current.GenericImage
                        warning(
                            "icon:" .. (item.Id or item.Kind),
                            "missing icon for "
                                .. (item.Id or item.Kind)
                                .. "; using authored Glossy Fruit Trio Sticker 1"
                        )
                    end
                end
            end
            local slot = target.Slot
            local label = slot.Label :: TextLabel
            label.Text = item.Label
            local number = slot.Button:FindFirstChild("Number")
            if number and number:IsA("TextLabel") then
                number.Text = if index <= 9 then tostring(index) elseif index == 10 then "0" else ""
            end
            slot.Button.LayoutOrder = index
            slot.Selected.Visible, slot.Button.Visible = item.Tool.Parent == character, true
            ordered[index] = target
        end
        for index, binding in ordered do
            binding.Slot.Button.NextSelectionLeft = if ordered[index - 1]
                then ordered[index - 1].Slot.Button
                else binding.Slot.Button
            binding.Slot.Button.NextSelectionRight = if ordered[index + 1]
                then ordered[index + 1].Slot.Button
                else binding.Slot.Button
        end
        current.Bar.Visible = #items > 0
        if not resize() then
            warning("layout", "insufficient safe space for accessible hotbar; native Backpack retained")
            release()
            return
        end
        -- Only hand off after input and the first render (including empty) finish.
        if not enabled then
            handoffAttempts += 1
            local ok = pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
            end)
            if ok then
                enabled = true
                activateKeys()
            else
                warning("handoff", "CoreGui handoff failed; custom bindings released")
                release()
                if handoffAttempts < 8 then
                    task.delay(0.25, function()
                        if not stopped then
                            schedule()
                        end
                    end)
                end
            end
        end
    end
    schedule = function()
        if stopped or queued then
            return
        end
        queued = true
        task.defer(function()
            queued = false
            if stopped then
                return
            end
            mutating = true
            local ok, message = pcall(render :: any)
            if not ok then
                warning("render", tostring(message))
                release()
            end
            mutating = false
        end)
    end
    local function watchContainers()
        disconnect(containers)
        backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            table.insert(containers, backpack.ChildAdded:Connect(schedule))
            table.insert(containers, backpack.ChildRemoved:Connect(schedule))
        end
        if character and not removing then
            table.insert(containers, character.ChildAdded:Connect(schedule))
            table.insert(containers, character.ChildRemoved:Connect(schedule))
        end
        schedule()
    end
    table.insert(
        connections,
        player.ChildAdded:Connect(function(child)
            if child:IsA("Backpack") then
                watchContainers()
            end
        end)
    )
    table.insert(
        connections,
        player.ChildRemoved:Connect(function(child)
            if child == backpack then
                watchContainers()
            end
        end)
    )
    table.insert(
        connections,
        player.CharacterRemoving:Connect(function()
            removing, character = true, nil
            for _, list in observed do
                disconnect(list)
            end
            table.clear(observed)
            table.clear(sequence)
            table.clear(items)
            release()
            watchContainers()
        end)
    )
    table.insert(
        connections,
        player.CharacterAdded:Connect(function(nextCharacter)
            character, removing = nextCharacter, false
            watchContainers()
        end)
    )
    -- Root visibility changes and live-sync replacement are coalesced. Do not
    -- watch Hotbar.Visible: the controller hides its own empty/invalid bar.
    local roots: { [Instance]: RBXScriptConnection } = {}
    local function uiChanged()
        if stopped or mutating then
            return
        end
        for object, connection in roots do
            if not object:IsDescendantOf(playerGui) then
                connection:Disconnect()
                roots[object] = nil
            end
        end
        for _, desktop in Registry.Desktops(playerGui) do
            local ancestor: Instance? = desktop
            while ancestor and ancestor ~= playerGui do
                if not roots[ancestor] and (ancestor:IsA("GuiObject") or ancestor:IsA("ScreenGui")) then
                    roots[ancestor] = ancestor
                        :GetPropertyChangedSignal(if ancestor:IsA("ScreenGui") then "Enabled" else "Visible")
                        :Connect(schedule)
                end
                ancestor = ancestor.Parent
            end
        end
        schedule()
    end
    table.insert(connections, playerGui.DescendantAdded:Connect(uiChanged))
    table.insert(
        connections,
        playerGui.DescendantRemoving:Connect(function()
            if not mutating then
                task.defer(uiChanged)
            end
        end)
    )
    table.insert(
        connections,
        GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
            for _, binding in pool do
                if binding.Slot.Button.Visible and GuiService.SelectedObject == binding.Slot.Button then
                    reveal(binding.Slot.Button)
                end
            end
        end)
    )
    -- Synchronous clearing before the deferred first render/data collection.
    local _, initialBar = Gui.Find(playerGui)
    if initialBar then
        initialBar.Visible = false
        for _, child in initialBar:GetChildren() do
            if Registry.Matches(child, "Slot1", { "Slot1", "Slot1_button", "Slot1_button_smooth" }) then
                if child:IsA("GuiObject") then
                    child.Visible = false
                end
                local icon = Registry.Child(child, "SlotIcon", { "SlotIcon", "SlotIcon_image" }, "ImageLabel")
                if icon and icon:IsA("ImageLabel") then
                    Gui.ClearTemplate(icon)
                end
            end
        end
    end
    uiChanged()
    watchContainers()
    local function stopSession()
        if stopped then
            return
        end
        stopped = true
        disconnect(connections)
        disconnect(containers)
        for _, list in observed do
            disconnect(list)
        end
        table.clear(observed)
        table.clear(sequence)
        table.clear(items)
        for _, connection in roots do
            connection:Disconnect()
        end
        table.clear(roots)
        release()
    end
    table.insert(connections, playerGui.Destroying:Connect(stopSession))
    return stopSession
end
local stop: (() -> ())? = nil
local destroying: RBXScriptConnection? = nil
function Controller.Init()
    if stop then
        return
    end
    local player = Players.LocalPlayer
    stop = Controller.Start(player, player:WaitForChild("PlayerGui") :: PlayerGui)
    destroying = script.Destroying:Connect(Controller.Destroy)
end
function Controller.Destroy()
    if destroying then
        destroying:Disconnect()
        destroying = nil
    end
    if stop then
        stop()
        stop = nil
    end
end
return Controller
