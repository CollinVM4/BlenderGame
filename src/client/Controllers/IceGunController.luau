--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local REVISION = "icegun-circle-2026-10-09"
local Config = require(ReplicatedStorage.Shared.Constants.IceGunConfig)
local Controller = {}
local started = false
local lastDiagnostic: { [string]: number } = {}
local function trace(player: Player, stage: string, tool: Tool?)
    if not Config.DebugLogging or not RunService:IsStudio() then
        return
    end
    local key = tostring(player.UserId) .. ":" .. stage
    local now = os.clock()
    if now < (lastDiagnostic[key] or 0) then
        return
    end
    lastDiagnostic[key] = now + 1
    local detail = if tool
        then string.format(
            " issue=%s parent=%s weapon=%s",
            tostring(tool:GetAttribute("IceGunIssueId")),
            tostring(tool.Parent),
            tostring(tool:GetAttribute("IceGunWeapon"))
        )
        else ""
    warn("[IceGun client] " .. tostring(player.UserId) .. " " .. stage .. detail)
end

local function pointerAim(): boolean
    return UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local character: Model? = nil
    local nextShot = 0
    local tools: { [Tool]: { RBXScriptConnection } } = {}
    local containers: { [Instance]: { RBXScriptConnection } } = {}
    local characterConnections: { RBXScriptConnection } = {}
    local reticle: ScreenGui? = nil
    local crosshair: Frame? = nil
    local savedMouseEnabled: boolean? = nil
    local windowFocused = true
    local function restoreCursor()
        if savedMouseEnabled ~= nil then
            -- Restore only our own override; another controller may have taken ownership.
            if not UserInputService.MouseIconEnabled then
                UserInputService.MouseIconEnabled = savedMouseEnabled
            end
            savedMouseEnabled = nil
        end
    end
    local function gameplayInput(): boolean
        if pointerAim() then
            local gui = player:FindFirstChildOfClass("PlayerGui")
            local mouse = UserInputService:GetMouseLocation()
            if gui then
                for _, object in gui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
                    if object:IsA("GuiButton") or object:IsA("TextBox") then
                        return false
                    end
                end
            end
        end
        return windowFocused
            and not GuiService.MenuIsOpen
            and GuiService.SelectedObject == nil
            and UserInputService:GetFocusedTextBox() == nil
            and not player.GameplayPaused
    end
    local function centeredAim(): boolean
        return not pointerAim() or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
    end
    local function aimPoint(camera: Camera): Vector2
        if centeredAim() then
            return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        end
        -- Mouse coordinates are fullscreen; camera/UI coordinates are device-safe.
        -- Both inset Rects are relative to CoreUISafeInsets, so their difference
        -- removes only device cutouts, never the Roblox top bar.
        local safe = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
        local full = GuiService:GetInsetArea(Enum.ScreenInsets.None)
        local mouse = UserInputService:GetMouseLocation()
        return Vector2.new(mouse.X - safe.Min.X + full.Min.X, mouse.Y - safe.Min.Y + full.Min.Y)
    end
    local function positionReticle()
        local camera = workspace.CurrentCamera
        if crosshair and camera then
            if centeredAim() then
                crosshair.Position = UDim2.fromScale(0.5, 0.5)
            else
                local point = aimPoint(camera)
                crosshair.Position = UDim2.fromOffset(point.X, point.Y)
            end
        end
    end
    local function reconcileCursor()
        if reticle and reticle.Enabled and gameplayInput() and pointerAim() then
            if savedMouseEnabled == nil then
                savedMouseEnabled = UserInputService.MouseIconEnabled
            end
            UserInputService.MouseIconEnabled = false
        else
            restoreCursor()
        end
    end
    local function hideReticle()
        restoreCursor()
        crosshair = nil
        if reticle then
            reticle:Destroy()
            reticle = nil
        end
    end
    local function updateReticle()
        local h = character and character:FindFirstChildOfClass("Humanoid")
        local equipped = false
        for tool in tools do
            if character and tool.Parent == character and tool:GetAttribute("IceGunWeapon") == true then
                equipped = true
                break
            end
        end
        local gui = player:FindFirstChildOfClass("PlayerGui")
        if not equipped or not h or h.Health <= 0 or not gui or not gameplayInput() then
            hideReticle()
            return
        end
        if reticle and reticle.Parent == gui then
            positionReticle()
            reconcileCursor()
            return
        end
        hideReticle()
        local screen = Instance.new("ScreenGui")
        screen.Name = "IceGunReticle"
        screen.ResetOnSpawn = false
        screen.DisplayOrder = 10
        screen.IgnoreGuiInset = true
        screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
        local cross = Instance.new("Frame")
        cross.Name = "Crosshair"
        cross.AnchorPoint = Vector2.new(0.5, 0.5)
        cross.Size = UDim2.fromOffset(14, 14)
        cross.BackgroundTransparency = 1
        cross.Active = false
        cross.Selectable = false
        cross.Parent = screen
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = cross
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.new(0, 0, 0)
        outline.Thickness = 3
        outline.Parent = cross
        local ring = Instance.new("Frame")
        ring.Name = "Ring"
        ring.Size = UDim2.fromScale(1, 1)
        ring.BackgroundTransparency = 1
        ring.Active = false
        ring.Selectable = false
        ring.Parent = cross
        corner:Clone().Parent = ring
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Thickness = 1
        stroke.Parent = ring
        local dot = Instance.new("Frame")
        dot.Name = "CenterDot"
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromScale(0.5, 0.5)
        dot.Size = UDim2.fromOffset(3, 3)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.BorderSizePixel = 0
        dot.Active = false
        dot.Selectable = false
        dot.Parent = cross
        corner:Clone().Parent = dot
        local dotStroke = Instance.new("UIStroke")
        dotStroke.Color = Color3.new(0, 0, 0)
        dotStroke.Thickness = 1
        dotStroke.Parent = dot
        reticle, crosshair = screen, cross
        screen:GetPropertyChangedSignal("Enabled"):Connect(reconcileCursor)
        screen.Parent = gui
        positionReticle()
        reconcileCursor()
    end
    local function unwatch(tool: Tool)
        local list = tools[tool]
        tools[tool] = nil
        for _, connection in (list or {}) :: { RBXScriptConnection } do
            connection:Disconnect()
        end
        updateReticle()
    end
    local function watch(child: Instance)
        if not child:IsA("Tool") then
            if child:IsA("Humanoid") then
                table.insert(characterConnections, child.Died:Connect(hideReticle))
                updateReticle()
            end
            return
        end
        trace(
            player,
            if child.Parent == character then "Tool observed in Character" else "Tool observed in Backpack",
            child
        )
        if tools[child] then
            updateReticle()
            return
        end
        local list: { RBXScriptConnection } = {}
        tools[child] = list
        table.insert(
            list,
            child:GetAttributeChangedSignal("IceGunWeapon"):Connect(function()
                trace(player, "authorization attribute received", child)
                updateReticle()
            end)
        )
        table.insert(
            list,
            child.Equipped:Connect(function()
                trace(player, "Tool equipped", child)
                updateReticle()
            end)
        )
        table.insert(list, child.Unequipped:Connect(hideReticle))
        table.insert(
            list,
            child.AncestryChanged:Connect(function()
                updateReticle()
                -- Transfers can pass through nil. Retire only after the current transfer finishes.
                task.defer(function()
                    local backpack = player:FindFirstChildOfClass("Backpack")
                    if
                        tools[child] == list
                        and (not character or child.Parent ~= character)
                        and (not backpack or child.Parent ~= backpack)
                    then
                        unwatch(child)
                    end
                end)
            end)
        )
        table.insert(
            list,
            child.Destroying:Connect(function()
                unwatch(child)
            end)
        )
        table.insert(
            list,
            child.Activated:Connect(function()
                trace(player, "Tool.Activated fired", child)
                if child:GetAttribute("IceGunWeapon") ~= true then
                    trace(player, "activation rejected: weapon attribute unavailable", child)
                    return
                end
                local current = character
                local camera = workspace.CurrentCamera
                local h = current and current:FindFirstChildOfClass("Humanoid")
                if not current or child.Parent ~= current or player.Character ~= current then
                    trace(player, "activation rejected: Tool not equipped on current character", child)
                    return
                elseif not h or h.Health <= 0 then
                    trace(player, "activation rejected: missing/dead Humanoid", child)
                    return
                elseif not camera then
                    trace(player, "activation rejected: camera unavailable", child)
                    return
                elseif player:GetAttribute("Stunned") == true then
                    trace(player, "activation rejected: stunned/frozen", child)
                    return
                elseif UserInputService:GetFocusedTextBox() then
                    trace(player, "activation rejected: text input focused", child)
                    return
                elseif os.clock() < nextShot then
                    trace(player, "activation rejected: local cooldown", child)
                    return
                end
                if not gameplayInput() or (reticle and not reticle.Enabled) then
                    trace(player, "activation rejected: gameplay UI inactive", child)
                    return
                end
                local point = aimPoint(camera)
                local ray = camera:ViewportPointToRay(point.X, point.Y)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = { current }
                local length = Config.MaximumRange + Config.MaximumCameraDistance
                local hit = workspace:Raycast(ray.Origin, ray.Direction * length, params)
                local aim = if hit then hit.Position else ray.Origin + ray.Direction * length
                local event = ReplicatedStorage:FindFirstChild("IceGunFire")
                if event and event:IsA("RemoteEvent") then
                    nextShot = os.clock() + Config.ShotCooldown
                    trace(player, "Fire RemoteEvent sent", child)
                    event:FireServer(aim, ray.Origin, ray.Direction)
                else
                    trace(player, "activation rejected: fire remote unavailable", child)
                end
            end)
        )
        trace(player, "Tool.Activated listener connected", child)
        if child:GetAttribute("IceGunWeapon") == true then
            trace(player, "authorization attribute received", child)
        end
        updateReticle()
    end
    local function unwatchContainer(container: Instance)
        local list = containers[container]
        containers[container] = nil
        for _, connection in (list or {}) :: { RBXScriptConnection } do
            connection:Disconnect()
        end
    end
    local function watchContainer(container: Instance)
        if containers[container] then
            return
        end
        -- Subscribe before scanning so existing grants and concurrent transfers are both discovered.
        containers[container] = { container.ChildAdded:Connect(watch), container.ChildRemoved:Connect(updateReticle) }
        for _, child in container:GetChildren() do
            watch(child)
        end
    end
    local function clearCharacter()
        local old = character
        character = nil
        hideReticle()
        if old then
            unwatchContainer(old)
        end
        for _, connection in characterConnections do
            connection:Disconnect()
        end
        table.clear(characterConnections)
        for tool in tools do
            unwatch(tool)
        end
    end
    local function bind(current: Model)
        clearCharacter()
        character = current
        nextShot = 0
        watchContainer(current)
        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            -- A retained Backpack subscription must still reconcile its current contents after respawn.
            watchContainer(backpack)
            for _, child in backpack:GetChildren() do
                watch(child)
            end
        end
    end
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watchContainer(child)
        elseif child:IsA("PlayerGui") then
            updateReticle()
        end
    end)
    player.ChildRemoved:Connect(function(child)
        if child:IsA("Backpack") then
            unwatchContainer(child)
            for tool in tools do
                if tool.Parent == child then
                    unwatch(tool)
                end
            end
        elseif child:IsA("PlayerGui") then
            hideReticle()
        end
    end)
    player.CharacterAdded:Connect(bind)
    player.CharacterRemoving:Connect(function(old)
        if old == character then
            clearCharacter()
        end
    end)
    UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateReticle)
    UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(updateReticle)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            updateReticle()
        end
    end)
    UserInputService.TextBoxFocused:Connect(updateReticle)
    UserInputService.TextBoxFocusReleased:Connect(updateReticle)
    UserInputService.WindowFocusReleased:Connect(function()
        windowFocused = false
        updateReticle()
    end)
    UserInputService.WindowFocused:Connect(function()
        windowFocused = true
        updateReticle()
    end)
    GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(updateReticle)
    GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(updateReticle)
    GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(positionReticle)
    player:GetPropertyChangedSignal("GameplayPaused"):Connect(updateReticle)
    local viewportConnection: RBXScriptConnection? = nil
    local function bindCamera()
        if viewportConnection then
            viewportConnection:Disconnect()
            viewportConnection = nil
        end
        local camera = workspace.CurrentCamera
        if camera then
            viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(positionReticle)
        end
        positionReticle()
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
    bindCamera()
    if Config.DebugLogging and RunService:IsStudio() then
        trace(player, "controller initialized revision=" .. REVISION .. " module=" .. script:GetFullName())
    end
    if player.Character then
        bind(player.Character)
    else
        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            watchContainer(backpack)
        end
    end
end
return Controller
