--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MobileControlLayout = require(script.Parent.Parent.UI.MobileControlLayout)
local Config = require(ReplicatedStorage.Shared.Constants.BatConfig)
local Controller = {}
local SWING_ACTION = "BatSwing"
local teardown: (() -> ())? = nil

-- Temporary boundary trace: independent of attribute replication so a missing
-- server request can still be diagnosed. Remove after the Studio repro is resolved.
local function trace(message: string)
    if RunService:IsStudio() then
        print("[BatInput] " .. message)
    end
end

type Playback = {
    Tool: Tool,
    Character: Model,
    Humanoid: Humanoid?,
    Tracks: { [string]: AnimationTrack },
    Connections: { RBXScriptConnection },
    SwingTrail: Trail?,
    Phase: string,
}
local function disconnect(connections: { RBXScriptConnection })
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
end

function Controller.Destroy()
    if teardown then
        teardown()
        teardown = nil
    end
end

function Controller.Init()
    if teardown then
        return
    end
    local player = Players.LocalPlayer
    trace("BatController initialized trace=input-v1 player=" .. player.Name)
    local characterConnections: { RBXScriptConnection } = {}
    local playerConnections: { RBXScriptConnection } = {}
    local current: Playback? = nil
    local nextSwingAt = 0
    local actionBound = false
    local requestSwing: (Playback) -> ()

    local function showSwingCooldown()
        if actionBound then
            ContextActionService:SetTitle(SWING_ACTION, if os.clock() < nextSwingAt then "Wait" else "Swing")
        end
    end

    local function removeSwingAction()
        if actionBound then
            actionBound = false
            ContextActionService:UnbindAction(SWING_ACTION)
            MobileControlLayout.Unregister(SWING_ACTION)
        end
    end

    local function updateSwingAction()
        local state = current
        if
            not state
            or state.Phase == "Unequip"
            or state.Tool.Parent ~= state.Character
            or state.Character ~= player.Character
            or UserInputService.PreferredInput ~= Enum.PreferredInput.Touch
            or not player:GetAttribute("PlotSessionId")
        then
            removeSwingAction()
            return
        end
        local level = state.Tool:GetAttribute("BatLevel")
        if type(level) ~= "number" or level < 1 then
            removeSwingAction()
            return
        end
        for _, child in state.Character:GetChildren() do
            if child:IsA("Tool") and child:GetAttribute("IceGunWeapon") == true then
                removeSwingAction()
                return
            end
        end
        if not actionBound then
            actionBound = true
            ContextActionService:BindAction(SWING_ACTION, function(_, inputState)
                if inputState == Enum.UserInputState.Begin and current == state then
                    requestSwing(state)
                end
                return Enum.ContextActionResult.Sink
            end, true)
            MobileControlLayout.Register(SWING_ACTION)
        end
        showSwingCooldown()
    end

    local function clearTool()
        local state = current
        current = nil -- Invalidate completion callbacks before stopping any track.
        removeSwingAction()
        if state then
            disconnect(state.Connections)
            local trail = state.SwingTrail
            if trail then
                local inner, tip = trail.Attachment0, trail.Attachment1
                trail:Destroy()
                if inner then
                    inner:Destroy()
                end
                if tip then
                    tip:Destroy()
                end
            end
            for _, track in state.Tracks do
                track:Stop(0)
                track:Destroy()
            end
        end
    end
    local function clearCharacter()
        clearTool()
        disconnect(characterConnections)
    end
    local function stillEquipped(state: Playback): boolean
        local humanoid = state.Humanoid
        return current == state
            and state.Tool.Parent == state.Character
            and player.Character == state.Character
            and humanoid ~= nil
            and humanoid.Health > 0
    end
    local function play(state: Playback, name: string): boolean
        -- Stop callbacks from the interrupted phase cannot resume idle over the next phase.
        state.Phase = "Transition"
        for _, track in state.Tracks do
            track:Stop(0)
        end
        state.Phase = name
        local track = state.Tracks[name]
        if not track then
            return false
        end
        local ok, problem = pcall(function(): string?
            track:Play(0.05, 1, 1)
            return nil
        end)
        if not ok then
            warn("[Bat] Could not play " .. name .. "Animation: " .. tostring(problem))
        end
        return ok
    end
    local function idle(state: Playback)
        if stillEquipped(state) then
            play(state, "Idle")
        end
    end
    local function createSwingTrail(hitbox: BasePart): Trail
        local inner, tip = Instance.new("Attachment"), Instance.new("Attachment")
        inner.Parent, tip.Parent = hitbox, hitbox
        local trail = Instance.new("Trail")
        trail.Name = "BatSwingTrail"
        trail.Attachment0, trail.Attachment1 = inner, tip
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 219, 122))
        trail.Transparency = NumberSequence.new(0.35, 1)
        trail.Lifetime, trail.MinLength, trail.Enabled = 0.12, 0.1, false
        trail.Parent = hitbox
        return trail
    end
    local function showSwingTrail(state: Playback)
        local hitbox = state.Tool:FindFirstChild("Hitbox")
        local handle = state.Tool:FindFirstChild("Handle")
        if not hitbox or not hitbox:IsA("BasePart") or not handle or not handle:IsA("BasePart") then
            return
        end
        local trail = state.SwingTrail or createSwingTrail(hitbox)
        state.SwingTrail = trail
        local localZ = if hitbox.CFrame.LookVector:Dot(hitbox.Position - handle.Position) >= 0 then -1 else 1
        local inner, tip = trail.Attachment0, trail.Attachment1
        if not inner or not tip then
            return
        end
        inner.Position = Vector3.new(0, 0, localZ * hitbox.Size.Z * 0.20)
        tip.Position = Vector3.new(0, 0, localZ * hitbox.Size.Z / 2)
        task.delay(Config.HitActiveStart, function()
            if stillEquipped(state) and state.Phase == "Swing" then
                trail.Enabled = true
            end
        end)
        task.delay(Config.HitActiveEnd, function()
            if current == state then
                trail.Enabled = false
            end
        end)
    end
    local function prepare(state: Playback, humanoid: Humanoid)
        if state.Humanoid ~= humanoid then
            state.Humanoid = humanoid
            table.insert(
                state.Connections,
                humanoid.Died:Connect(function()
                    if current == state then
                        clearTool()
                    end
                end)
            )
        end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            return
        end
        for _, name in { "Idle", "Equip", "Swing", "Unequip" } do
            if state.Tracks[name] then
                continue
            end
            local animation = state.Tool:FindFirstChild(name .. "Animation")
            if not animation or not animation:IsA("Animation") or animation.AnimationId == "" then
                continue
            end
            -- Reuse the Humanoid's replicated Animator; never create a client-only Animator.
            local ok, track = pcall(function()
                return animator:LoadAnimation(animation)
            end)
            if not ok then
                warn("[Bat] Could not load " .. name .. "Animation: " .. tostring(track))
                continue
            end
            track.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Action
            track.Looped = name == "Idle"
            state.Tracks[name] = track
            if name ~= "Idle" then
                table.insert(
                    state.Connections,
                    track.Ended:Connect(function()
                        -- Ended can arrive after a stop/replay of this same track.
                        if current ~= state or state.Phase ~= name or track.IsPlaying then
                            return
                        end
                        if name == "Unequip" then
                            clearTool()
                        else
                            idle(state)
                        end
                    end)
                )
            end
        end
    end
    local function unequip(state: Playback)
        if current ~= state or state.Phase == "Unequip" then
            return
        end
        removeSwingAction()
        if state.SwingTrail then
            state.SwingTrail.Enabled = false
        end
        local humanoid = state.Humanoid
        if player.Character ~= state.Character or not humanoid or humanoid.Health <= 0 then
            clearTool()
            return
        end
        -- Retain the death/destruction listeners until this optional outro finishes.
        if not play(state, "Unequip") then
            clearTool()
        end
    end
    requestSwing = function(state: Playback)
        local child, character = state.Tool, state.Character
        local living = character:FindFirstChildOfClass("Humanoid")
        local level = child:GetAttribute("BatLevel")
        if
            current ~= state
            or state.Phase == "Unequip"
            or child.Parent ~= character
            or player.Character ~= character
            or GuiService.MenuIsOpen
            or player.GameplayPaused
            or UserInputService:GetFocusedTextBox() ~= nil
            or not living
            or living.Health <= 0
            or player:GetAttribute("Stunned") == true
            or player:GetAttribute("PlotSessionId") == nil
            or type(level) ~= "number"
            or level < 1
            or os.clock() < nextSwingAt
        then
            local reason = if current ~= state
                then "stale Tool binding"
                elseif state.Phase == "Unequip" then "unequipping"
                elseif child.Parent ~= character then "Tool not equipped"
                elseif player.Character ~= character then "stale character"
                elseif GuiService.MenuIsOpen or player.GameplayPaused then "menu or paused"
                elseif UserInputService:GetFocusedTextBox() ~= nil then "text input"
                elseif not living then "missing Humanoid"
                elseif living.Health <= 0 then "dead Humanoid"
                elseif player:GetAttribute("Stunned") == true then "attacker Stunned attribute"
                elseif player:GetAttribute("PlotSessionId") == nil then "missing PlotSessionId attribute"
                elseif type(level) ~= "number" then "missing/non-numeric Tool BatLevel"
                elseif level < 1 then "Tool BatLevel locked"
                else "local swing cooldown"
            trace("activation rejected: " .. reason)
            return
        end
        local remote = ReplicatedStorage.Shared.Events:FindFirstChild("GameplayRequest")
        if not remote or not remote:IsA("RemoteEvent") then
            trace("activation rejected: GameplayRequest " .. (if remote then "is not a RemoteEvent" else "missing"))
            return
        end
        nextSwingAt = os.clock() + Config.SwingCooldown
        showSwingCooldown()
        if UserInputService.TouchEnabled then
            task.delay(Config.SwingCooldown, showSwingCooldown)
        end
        prepare(state, living)
        if play(state, "Swing") then
            showSwingTrail(state)
        else
            idle(state)
        end
        -- Local prediction only. No pose, animation event or timing authorizes a hit.
        if RunService:IsStudio() then
            local named = 0
            for _, event in ReplicatedStorage.Shared.Events:GetChildren() do
                if event.Name == "GameplayRequest" then
                    named += 1
                end
            end
            trace(
                "sending SwingBat remote="
                    .. remote:GetFullName()
                    .. " adapter="
                    .. tostring(remote:GetAttribute("BatRequestTraceVersion"))
                    .. " namedRemotes="
                    .. tostring(named)
                    .. " debugArmed="
                    .. tostring(player:GetAttribute("BatDebugNextSwing"))
            )
        end
        remote:FireServer("SwingBat")
        trace("FireServer returned: SwingBat")
    end
    local function bind(character: Model)
        clearCharacter()
        nextSwingAt = 0
        local function equipped(child: Instance)
            if not child:IsA("Tool") then
                return
            end
            if child.Name ~= "Bat" then
                updateSwingAction()
                if current and current.Phase == "Unequip" then
                    clearTool()
                end
                return
            end
            if current and current.Tool == child and current.Phase ~= "Unequip" then
                return
            end
            clearTool()
            local state: Playback = {
                Tool = child,
                Character = character,
                Humanoid = nil,
                Tracks = {},
                Connections = {},
                Phase = "Equip",
            }
            current = state
            trace("bound Tool.Activated tool=" .. child:GetFullName())
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                prepare(state, humanoid)
            end
            table.insert(
                state.Connections,
                child.Unequipped:Connect(function()
                    unequip(state)
                end)
            )
            table.insert(
                state.Connections,
                child.Destroying:Connect(function()
                    if current == state then
                        clearTool()
                    end
                end)
            )
            table.insert(
                state.Connections,
                child.AncestryChanged:Connect(function()
                    if child.Parent ~= character then
                        unequip(state)
                    end
                end)
            )
            table.insert(
                state.Connections,
                child.Activated:Connect(function()
                    trace("Tool.Activated player=" .. player.Name .. " tool=" .. child:GetFullName())
                    if UserInputService.PreferredInput ~= Enum.PreferredInput.Touch then
                        requestSwing(state)
                    end
                end)
            )
            table.insert(state.Connections, child:GetAttributeChangedSignal("BatLevel"):Connect(updateSwingAction))
            updateSwingAction()
            if stillEquipped(state) and not play(state, "Equip") then
                idle(state)
            end
        end
        table.insert(characterConnections, character.ChildAdded:Connect(equipped))
        table.insert(characterConnections, character.ChildRemoved:Connect(updateSwingAction))
        for _, child in character:GetChildren() do
            equipped(child)
        end
    end
    teardown = function()
        clearCharacter()
        disconnect(playerConnections)
    end
    table.insert(playerConnections, player.CharacterAdded:Connect(bind))
    table.insert(playerConnections, player.CharacterRemoving:Connect(clearCharacter))
    table.insert(playerConnections, player:GetAttributeChangedSignal("PlotSessionId"):Connect(updateSwingAction))
    table.insert(
        playerConnections,
        UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateSwingAction)
    )
    if player.Character then
        bind(player.Character)
    end
end
return Controller
