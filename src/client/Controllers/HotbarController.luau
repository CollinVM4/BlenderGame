--!strict
-- Observes replicated Tools only. Humanoid owns selection; no gameplay remotes.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Gui = require(script.Parent.Parent.UI.HotbarGui)
local MobileLayout = require(script.Parent.Parent.UI.MobileControlLayout)
local Controller = {}
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
local sessionVersion = 0
local activeStop: (() -> ())? = nil
type Item = { Tool: Tool, Kind: string, Label: string, Id: string?, Key: number, Sequence: number }
type Binding = {
    Slot: Gui.Slot,
    Tool: Tool,
    Kind: string,
    Id: string?,
    Index: number,
    Connection: RBXScriptConnection,
    Dispose: (() -> ())?,
    PreviewAttempted: boolean,
}
local function disconnect(list: { RBXScriptConnection })
    for _, connection in list do
        connection:Disconnect()
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
    local Geometry = require(Shared.IngredientPreviewGeometry)
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
    if activeStop then
        activeStop()
    end
    sessionVersion += 1
    local session = sessionVersion
    local stopped, queued, mutating, enabled, bound = false, false, false, false, false
    local view = Gui.Create(playerGui)
    local character = player.Character
    local backpack: Backpack? = nil
    local removing = false
    local connections: { RBXScriptConnection } = {}
    local containers: { RBXScriptConnection } = {}
    local observed: { [Tool]: { RBXScriptConnection } } = {}
    local controls: { [Instance]: { RBXScriptConnection } } = {}
    local sequence: { [Tool]: number } = {}
    local bindings: { [Tool]: Binding } = {}
    local items: { Item } = {}
    local serial = 0
    local equipped: Tool? = nil
    local focused: GuiObject? = nil
    local revealTool: Tool? = nil
    local coreTarget: boolean? = nil
    local coreAttempts, coreEpoch = 0, 0
    local coreDone, retryQueued = false, false
    local reason = "waiting for first Tool"
    local inventoryTrigger: string? = "startup"
    local inventoryUpdates, inventoryAccepted = 0, 0
    local inventoryReason, inventoryAt = "not updated", os.clock()
    local writeError, readError = "", ""
    local externallyHidden = false
    local schedule: () -> ()
    local function inventoryChanged(why: string): () -> ()
        return function()
            inventoryTrigger = why
            schedule()
        end
    end
    local function coreState(): boolean?
        local ok, value = pcall(function()
            return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
        end)
        if not ok then
            readError = string.sub(tostring(value), 1, 160)
        end
        return if ok then value else nil
    end
    local function unbind()
        if bound then
            CAS:UnbindAction(ACTION)
            bound = false
        end
    end
    local function requestCore(native: boolean, transition: string)
        if native then
            enabled = false
            unbind()
            view.Bar.Visible = false
        end
        if coreTarget ~= native then
            coreTarget, coreDone, coreAttempts = native, false, 0
            coreEpoch += 1
            retryQueued = false
            reason = transition
        end
        if coreDone then
            -- Readiness can change without a new CoreGui ownership transition.
            reason = transition
            return
        end
        if retryQueued or coreAttempts >= 8 then
            return
        end
        coreAttempts += 1
        local ok, message = true, nil :: any
        if not native or coreState() ~= true then
            ok, message = pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, native)
            end)
            if not ok then
                writeError = string.sub(tostring(message), 1, 160)
            end
        end
        local readback = coreState()
        coreDone = readback == native or (ok and readback == nil)
        if coreDone then
            enabled = not native
            reason = transition
            -- Input is prepared before the API write. Visibility and ownership
            -- commit here without yielding, in the same update as that write.
            view.Bar.Visible = enabled and #items > 0
        else
            enabled = false
            unbind()
            view.Bar.Visible = false
            reason = transition .. " (CoreGui pending)"
            if coreAttempts < 8 then
                retryQueued = true
                local epoch = coreEpoch
                task.delay(0.25, function()
                    if session ~= sessionVersion or epoch ~= coreEpoch then
                        return
                    end
                    retryQueued = false
                    if stopped then
                        -- Teardown may still need its bounded native restore.
                        if native then
                            requestCore(true, transition)
                        end
                    else
                        schedule()
                    end
                end)
            end
        end
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
    local function bindKeys()
        if bound then
            return
        end
        CAS:BindAction(ACTION, function(_, state, input)
            if not enabled or guarded() then
                return Enum.ContextActionResult.Pass
            end
            local index = table.find(KEYS, input.KeyCode)
            local item = if index then items[index] else nil
            if not item or not owned(item.Tool) then
                return Enum.ContextActionResult.Pass
            end
            if state == Enum.UserInputState.Begin then
                selectTool(item.Tool)
            end
            return Enum.ContextActionResult.Sink
        end, false, table.unpack(KEYS))
        bound = true
    end
    local function clear(binding: Binding)
        if binding.Dispose then
            binding.Dispose()
        end
        if GuiService.SelectedObject == binding.Slot.Button then
            GuiService.SelectedObject = nil
        end
        binding.Connection:Disconnect()
        binding.Slot.Button:Destroy()
    end
    local function preview(binding: Binding)
        if binding.PreviewAttempted or binding.Dispose then
            return
        end
        binding.PreviewAttempted = true
        -- Optional art never gates layout, input, or CoreGui ownership. Even a
        -- suspended preview cannot suspend the controller's update path.
        task.defer(function()
            if stopped or bindings[binding.Tool] ~= binding then
                return
            end
            local ok, dispose = pcall(function(): (() -> ())?
                if binding.Kind == "Ingredient" and binding.Id then
                    local renderer = require(script.Parent.Parent.UI.IngredientViewport)
                    return renderer.Create(binding.Slot.Icon, binding.Id)
                elseif binding.Kind == "Smoothie" then
                    return visual(binding.Tool, binding.Slot.Icon)
                end
                return nil
            end)
            if not ok or not dispose then
                return
            end
            if stopped or bindings[binding.Tool] ~= binding then
                dispose()
                return
            end
            binding.Dispose = dispose
            for _, child in binding.Slot.Button:GetChildren() do
                if child:IsA("ViewportFrame") and child.Name == "IngredientPreview" then
                    child.Size, child.Position, child.AnchorPoint =
                        UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Vector2.zero
                    child.Rotation = 0
                    child.Parent = binding.Slot.Icon
                end
            end
            binding.Slot.Icon.Image = ""
        end)
    end
    local function refreshPreviews()
        for _, binding in bindings do
            if not binding.Dispose then
                binding.PreviewAttempted = false
            end
        end
        schedule()
    end
    local function collect(): boolean
        local found: { [Tool]: boolean } = {}
        local nextItems: { Item } = {}
        local valid = true
        if not removing and character and character == player.Character then
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
                            child.AncestryChanged:Connect(inventoryChanged("Tool ancestry")),
                            child.Equipped:Connect(inventoryChanged("Tool equipped")),
                            child.Unequipped:Connect(inventoryChanged("Tool unequipped")),
                            child:GetPropertyChangedSignal("Name"):Connect(inventoryChanged("Tool name")),
                            child.DescendantAdded:Connect(refreshPreviews),
                        }
                        for _, attribute in { "IngredientId", "CarryItemId", "BatLevel", "IceGunWeapon" } do
                            table.insert(
                                list,
                                child
                                    :GetAttributeChangedSignal(attribute)
                                    :Connect(inventoryChanged("Tool " .. attribute))
                            )
                        end
                        observed[child] = list
                    end
                    local kind, label, id, key = Controller.Classify(child)
                    if kind == "InvalidIngredient" then
                        valid = false
                    elseif kind and label and key then
                        table.insert(
                            nextItems,
                            { Tool = child, Kind = kind, Label = label, Id = id, Key = key, Sequence = sequence[child] }
                        )
                    end
                end
            end
        end
        for tool, list in observed do
            if not found[tool] then
                disconnect(list)
                observed[tool], sequence[tool] = nil, nil
            end
        end
        local rank = { Bat = 1, Ice = 2, Ingredient = 3, Smoothie = 4 }
        table.sort(nextItems, function(a, b)
            if rank[a.Kind] ~= rank[b.Kind] then
                return rank[a.Kind] < rank[b.Kind]
            end
            if a.Kind == "Ingredient" and a.Key ~= b.Key then
                return a.Key < b.Key
            end
            return a.Sequence < b.Sequence
        end)
        items = nextItems
        return valid
    end
    local function obstacles(): { Rect }
        local wanted: { [Instance]: boolean } = {}
        local result: { Rect } = {}
        local size, origin = view.SafeArea.AbsoluteSize, view.SafeArea.AbsolutePosition
        if UIS.TouchEnabled and size.X > 0 and size.Y > 0 then
            local objects: { Instance }
            result, objects = MobileLayout.HotbarObstacles(playerGui, Rect.new(origin, origin + size))
            for _, object in objects do
                wanted[object] = true
                if controls[object] then
                    continue
                end
                local list = { object.AncestryChanged:Connect(schedule) }
                local properties: { string } = if object:IsA("ScreenGui")
                    then { "Enabled" }
                    else { "AbsoluteSize", "AbsolutePosition", "Visible" }
                for _, property in properties do
                    table.insert(list, object:GetPropertyChangedSignal(property):Connect(schedule))
                end
                controls[object] = list
            end
        end
        for object, list in controls do
            if not wanted[object] then
                disconnect(list)
                controls[object] = nil
            end
        end
        return result
    end
    local function update()
        local valid = collect()
        inventoryUpdates += 1
        inventoryReason, inventoryAt, inventoryAccepted = inventoryTrigger or "view/input", os.clock(), #items
        inventoryTrigger = nil
        local wanted: { [Tool]: boolean } = {}
        local ordered: { Binding } = {}
        local nextEquipped: Tool? = nil
        for index, item in items do
            wanted[item.Tool] = true
            local binding: Binding? = bindings[item.Tool]
            if binding and (binding.Kind ~= item.Kind or binding.Id ~= item.Id) then
                clear(binding)
                bindings[item.Tool], binding = nil, nil
            end
            if not binding then
                local slot = Gui.NewSlot(view)
                binding = {
                    Slot = slot,
                    Tool = item.Tool,
                    Kind = item.Kind,
                    Id = item.Id,
                    Index = index,
                    Connection = slot.Button.Activated:Connect(function()
                        selectTool(item.Tool)
                    end),
                    Dispose = nil,
                    PreviewAttempted = false,
                }
                bindings[item.Tool] = binding
                slot.Icon.Image = if item.Kind == "Bat"
                    then Gui.Art.Bat
                    elseif item.Kind == "Ice" then Gui.Art.Ice
                    else Gui.Art.Generic
            end
            local target = binding :: Binding
            target.Index = index
            local slot = target.Slot
            slot.Label.Text, slot.Number.Text =
                item.Label, if index <= 9 then tostring(index) elseif index == 10 then "0" else ""
            slot.Button.LayoutOrder = index
            slot.Selected.Visible = item.Tool.Parent == character
            if slot.Selected.Visible then
                nextEquipped = item.Tool
            end
            ordered[index] = target
            preview(target)
        end
        for tool, binding in bindings do
            if not wanted[tool] then
                bindings[tool] = nil
                clear(binding)
            end
        end
        for index, binding in ordered do
            binding.Slot.Button.NextSelectionLeft = if ordered[index - 1]
                then ordered[index - 1].Slot.Button
                else binding.Slot.Button
            binding.Slot.Button.NextSelectionRight = if ordered[index + 1]
                then ordered[index + 1].Slot.Button
                else binding.Slot.Button
        end
        if equipped ~= nextEquipped then
            equipped = nextEquipped
            revealTool = nextEquipped
        end
        local mounted = view.Root.Parent == playerGui
            and view.Root.Enabled
            and view.SafeArea.Parent == view.Root
            and view.SafeArea.Visible
            and view.Bar.Parent == view.SafeArea
            and not externallyHidden
            and view.Scroll.Parent == view.Bar
            and view.Scroll.Visible
        for _, binding in ordered do
            local slot = binding.Slot
            mounted = mounted
                and slot.Button.Parent == view.Scroll
                and slot.Icon.Parent == slot.Button
                and slot.Label.Parent == slot.Button
                and slot.Background.Parent == slot.Button
                and slot.Selected.Parent == slot.Button
                and slot.Number.Parent == slot.Button
        end
        local usable = if mounted then Gui.Layout(view, #items, UIS.TouchEnabled, obstacles()) else false
        for index, binding in ordered do
            binding.Slot.Button.Size = UDim2.fromOffset(view.SlotSize, view.SlotSize)
            binding.Slot.Button.Position =
                UDim2.fromOffset(Gui.Padding + (index - 1) * (view.SlotSize + Gui.Gap), Gui.Padding)
        end
        if usable == false or not valid then
            requestCore(true, if not valid then "waiting for valid Tool attributes" else "custom view unavailable")
            return
        end
        if usable == nil then
            -- Keep ownership, slots and scroll during a brief zero-size rotation.
            -- No geometry timers, reassertions, or repeated layout gates.
            return
        end
        if revealTool and bindings[revealTool] then
            Gui.Reveal(view, bindings[revealTool].Index)
            revealTool = nil
        end
        if not enabled and #items == 0 then
            requestCore(true, "waiting for first Tool")
            return
        end
        if not enabled then
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            if removing or not humanoid or humanoid.Health <= 0 then
                requestCore(true, "waiting for selectable character")
                return
            end
            bindKeys()
            requestCore(false, "custom ready")
        end
        view.Bar.Visible = enabled and #items > 0
    end
    schedule = function()
        if stopped or queued or mutating then
            return
        end
        queued = true
        task.defer(function()
            queued = false
            if stopped or session ~= sessionVersion then
                return
            end
            mutating = true
            local ok, message = pcall(update)
            if not ok then
                requestCore(true, "custom update error")
                warn("HotbarController: " .. tostring(message))
            end
            mutating = false
        end)
    end
    local function watchContainers(why: string)
        disconnect(containers)
        backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            table.insert(containers, backpack.ChildAdded:Connect(inventoryChanged("Backpack child added")))
            table.insert(containers, backpack.ChildRemoved:Connect(inventoryChanged("Backpack child removed")))
        end
        if character and not removing then
            table.insert(containers, character.ChildAdded:Connect(inventoryChanged("Character child added")))
            table.insert(containers, character.ChildRemoved:Connect(inventoryChanged("Character child removed")))
        end
        inventoryTrigger = why
        schedule()
    end
    table.insert(
        connections,
        player.ChildAdded:Connect(function(child)
            if child:IsA("Backpack") then
                watchContainers("Backpack added")
            end
        end)
    )
    table.insert(
        connections,
        player.ChildRemoved:Connect(function(child)
            if child == backpack then
                watchContainers("Backpack removed")
            end
        end)
    )
    table.insert(
        connections,
        player.CharacterRemoving:Connect(function()
            character, removing = nil, true
            watchContainers("Character removing")
        end)
    )
    table.insert(
        connections,
        player.CharacterAdded:Connect(function(nextCharacter)
            character, removing = nextCharacter, false
            watchContainers("Character added")
        end)
    )
    local gates: { Instance } = { view.Root, view.SafeArea, view.Bar, view.Scroll }
    for _, object in gates do
        table.insert(connections, object.AncestryChanged:Connect(schedule))
        table.insert(
            connections,
            object:GetPropertyChangedSignal(if object:IsA("ScreenGui") then "Enabled" else "Visible"):Connect(function()
                if not mutating then
                    if object == view.Bar then
                        externallyHidden = not view.Bar.Visible
                    end
                    schedule()
                end
            end)
        )
    end
    table.insert(connections, view.SafeArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule))
    table.insert(connections, view.SafeArea:GetPropertyChangedSignal("AbsolutePosition"):Connect(schedule))
    table.insert(connections, playerGui.DescendantAdded:Connect(schedule))
    table.insert(
        connections,
        playerGui.DescendantRemoving:Connect(function()
            if not mutating then
                schedule()
            end
        end)
    )
    table.insert(connections, Shared.DescendantAdded:Connect(refreshPreviews))
    table.insert(
        connections,
        GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
            local nextFocus = GuiService.SelectedObject
            if nextFocus == focused then
                return
            end
            focused = nextFocus
            for tool, binding in bindings do
                if nextFocus == binding.Slot.Button then
                    revealTool = tool
                    schedule()
                    break
                end
            end
        end)
    )
    table.insert(connections, playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(schedule))
    table.insert(connections, UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(schedule))
    -- Diagnostic replication is optional and never gates the standalone view.
    -- Admin authorization remains exclusively on the existing server command.
    local debugRemote: RemoteEvent? = nil
    local debugConnection: RBXScriptConnection? = nil
    local function inventorySnapshot(): string
        -- Read the live containers before any reconciliation. Snapshot IDs are
        -- local to this report, so equal names cannot hide different instances.
        local liveBackpack = player:FindFirstChildOfClass("Backpack")
        local liveCharacter = player.Character
        local ids: { [Instance]: number } = {}
        local nextId = 0
        local function identity(object: Instance?): string
            if not object then
                return "nil"
            end
            if not ids[object] then
                nextId += 1
                ids[object] = nextId
            end
            return string.format("%s#%d", object:GetFullName(), ids[object])
        end
        local function raw(container: Instance?): { Tool }
            local result: { Tool } = {}
            if container then
                for _, child in container:GetChildren() do
                    if child:IsA("Tool") then
                        table.insert(result, child)
                    end
                end
            end
            return result
        end
        local lines = {
            string.format(
                "inventory update=%d trigger=%s accepted=%d age=%.2fs queued=%s pending=%s removing=%s",
                inventoryUpdates,
                inventoryReason,
                inventoryAccepted,
                os.clock() - inventoryAt,
                tostring(queued),
                inventoryTrigger or "none",
                tostring(removing)
            ),
        }
        local tools: { Tool } = {}
        local seen: { [Tool]: boolean } = {}
        local function containerLine(label: string, live: Instance?, watched: Instance?)
            local liveTools, watchedTools = raw(live), raw(watched)
            table.insert(
                lines,
                string.format(
                    "%s live=%s observed=%s match=%s raw=%d observedRaw=%d",
                    label,
                    identity(live),
                    identity(watched),
                    tostring(live == watched),
                    #liveTools,
                    #watchedTools
                )
            )
            for _, list in { liveTools, watchedTools } do
                for _, tool in list do
                    if not seen[tool] then
                        seen[tool] = true
                        table.insert(tools, tool)
                    end
                end
            end
        end
        containerLine("BP", liveBackpack, backpack)
        containerLine("CH", liveCharacter, character)
        local accepted: { [Tool]: boolean } = {}
        for _, item in items do
            accepted[item.Tool] = true
        end
        for _, tool in tools do
            local weapon = tool:GetAttribute("IceGunWeapon")
            local kind = Controller.Classify(tool)
            local classification = if kind == "InvalidIngredient"
                then "reject:invalid CarryItemId"
                elseif kind then kind
                else "reject:unsupported attributes/name"
            local eligibility = if removing
                then "reject:Character removing"
                elseif not character then "reject:no observed Character"
                elseif character ~= liveCharacter then "reject:stale Character"
                elseif not owned(tool) then "reject:outside observed containers"
                else "owned"
            table.insert(
                lines,
                string.format(
                    "Tool %s name=%q parent=%s IceGunWeapon=%s:%s class=%s gate=%s watched=%s lastAccepted=%s",
                    identity(tool),
                    tool.Name,
                    identity(tool.Parent),
                    tostring(weapon),
                    typeof(weapon),
                    classification,
                    eligibility,
                    tostring(observed[tool] ~= nil),
                    tostring(accepted[tool] == true)
                )
            )
        end
        return table.concat(lines, "\n")
    end
    local function report(_hide: boolean)
        local snapshot = inventorySnapshot()
        local native = coreState()
        local message = string.format(
            "[Hotbar] place v%d | %s | owner=%s | %s | safe=%.0f slots=%d visible=%s native=%s | write=%s read=%s",
            game.PlaceVersion,
            tostring(playerGui.CurrentScreenOrientation),
            if enabled then "custom" else "native",
            reason,
            view.SafeArea.AbsoluteSize.X,
            #items,
            tostring(enabled and view.Root.Enabled and view.Bar.Visible),
            tostring(native),
            if writeError == "" then "ok" else writeError,
            if readError == "" then "ok" else readError
        ) .. "\n" .. snapshot
        print(message)
        local channels = game:GetService("TextChatService"):FindFirstChild("TextChannels")
        local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
        if channel and channel:IsA("TextChannel") then
            channel:DisplaySystemMessage(message)
        end
    end
    local function attachDebug()
        if stopped then
            return
        end
        local events = Shared:FindFirstChild("Events")
        local remote = if events then events:FindFirstChild("HotbarDebug") else nil
        local nextRemote = if remote and remote:IsA("RemoteEvent") then remote else nil
        if nextRemote == debugRemote then
            return
        end
        if debugConnection then
            debugConnection:Disconnect()
            debugConnection = nil
        end
        debugRemote = nextRemote
        if nextRemote then
            debugConnection = nextRemote.OnClientEvent:Connect(report)
        end
    end
    table.insert(connections, Shared.DescendantAdded:Connect(attachDebug))
    table.insert(
        connections,
        Shared.DescendantRemoving:Connect(function()
            task.defer(attachDebug)
        end)
    )
    attachDebug()
    local function stopSession()
        if stopped then
            return
        end
        stopped = true
        mutating = true
        disconnect(connections)
        if debugConnection then
            debugConnection:Disconnect()
            debugConnection = nil
        end
        disconnect(containers)
        for _, list in observed do
            disconnect(list)
        end
        for _, list in controls do
            disconnect(list)
        end
        table.clear(observed)
        table.clear(controls)
        for _, binding in bindings do
            clear(binding)
        end
        table.clear(bindings)
        requestCore(true, "controller stopped")
        view.Template:Destroy()
        view.Root:Destroy()
    end
    activeStop = stopSession
    table.insert(connections, playerGui.Destroying:Connect(stopSession))
    requestCore(true, "waiting for first Tool")
    watchContainers("startup bind")
    return stopSession
end
local stop: (() -> ())? = nil
local lifecycle: { RBXScriptConnection } = {}
local activeGui: PlayerGui? = nil
local initialized = false
function Controller.Init()
    if initialized then
        return
    end
    initialized = true
    local player = Players.LocalPlayer
    local function reconcile()
        local root = player:FindFirstChildOfClass("PlayerGui")
        if root == activeGui then
            return
        end
        if stop then
            stop()
            stop = nil
        end
        activeGui = root
        if root then
            stop = Controller.Start(player, root)
        end
    end
    table.insert(lifecycle, player.ChildAdded:Connect(reconcile))
    table.insert(lifecycle, player.ChildRemoved:Connect(reconcile))
    table.insert(lifecycle, script.Destroying:Connect(Controller.Destroy))
    reconcile()
end
function Controller.Destroy()
    initialized = false
    disconnect(lifecycle)
    if activeStop then
        activeStop()
        activeStop = nil
    end
    stop, activeGui = nil, nil
end
return Controller
