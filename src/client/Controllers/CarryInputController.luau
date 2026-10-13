--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local MobileControlLayout = require(script.Parent.Parent.UI.MobileControlLayout)
local Controller = {}
local started = false

-- Read the live CAS binding; observing input never invokes the throw handler.
function Controller.GetThrowButtonLabel(): string
    local info = ContextActionService:GetBoundActionInfo("ThrowHeld")
    for _, key in (info.inputTypes or {}) do
        if key.EnumType == Enum.KeyCode and string.sub(key.Name, 1, 6) == "Button" then
            local label = UserInputService:GetStringForKeyCode(key)
            return if label ~= "" then label else key.Name
        end
    end
    return "Throw"
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local remote = ReplicatedStorage.Shared.Events:WaitForChild("GameplayRequest") :: RemoteEvent
    local attempt = 0
    local logWindow, logCount = 0, 0
    local function trace(message: string)
        if player:GetAttribute("ThrowDebug") ~= true then
            return
        end
        local now = os.clock()
        if now - logWindow >= 5 then
            logWindow, logCount = now, 0
        end
        if logCount >= 40 then
            return
        end
        logCount += 1
        print("[ThrowInput] player=" .. player.Name .. " attempt=" .. tostring(attempt) .. " " .. message)
    end
    local function observe(source: string)
        attempt += 1
        if player:GetAttribute("ThrowDebug") ~= true then
            return
        end
        local names = {}
        for _, child in (if player.Character then player.Character:GetChildren() else {}) do
            if child:IsA("Tool") then
                local kind = if child:GetAttribute("IceGunWeapon") == true
                    then "IceGun"
                    elseif typeof(child:GetAttribute("BatLevel")) == "number" then "Bat"
                    elseif child:GetAttribute("IngredientId") ~= nil then "ingredient"
                    else "other"
                table.insert(names, child.Name .. ":" .. kind)
            end
        end
        local ok, preferred = pcall(function()
            return UserInputService.PreferredInput
        end)
        trace(
            string.format(
                "input=%s mouse=%s touch=%s keyboard=%s preferred=%s tools=[%s]",
                source,
                tostring(UserInputService.MouseEnabled),
                tostring(UserInputService.TouchEnabled),
                tostring(UserInputService.KeyboardEnabled),
                if ok then tostring(preferred) else "unavailable",
                table.concat(names, ",")
            )
        )
    end
    local function throw(_action: string, state: Enum.UserInputState): Enum.ContextActionResult
        trace("handler invoked state=" .. tostring(state))
        local character = player.Character
        if character then
            for _, child in character:GetChildren() do
                if
                    child:IsA("Tool")
                    and (
                        typeof(child:GetAttribute("BatLevel")) == "number"
                        or child:GetAttribute("IceGunWeapon") == true
                    )
                then
                    -- Leave primary input available to Tool.Activated, including on touch.
                    trace("owner=weapon ignored: weapon equipped " .. child.Name)
                    return Enum.ContextActionResult.Pass
                end
            end
        end
        trace("owner=carry")
        if GuiService.MenuIsOpen or player.GameplayPaused then
            trace("ignored: menu open or gameplay paused")
            return Enum.ContextActionResult.Pass
        end
        if player:GetAttribute("Stunned") == true then
            trace("ignored: stunned")
            return Enum.ContextActionResult.Sink
        end
        if (player:GetAttribute("CarryCount") or 0) <= 0 or UserInputService:GetFocusedTextBox() then
            trace("ignored: empty carry or focused textbox")
            return Enum.ContextActionResult.Pass
        end
        if state == Enum.UserInputState.Begin then
            trace("request sent: ThrowHeld newest ingredient")
            remote:FireServer("ThrowHeld", nil, nil, if player:GetAttribute("ThrowDebug") == true then attempt else nil)
        end
        return Enum.ContextActionResult.Sink
    end
    -- The existing CAS Throw button and console trigger share this intentional path.
    -- Do not bind touch-world/primary mouse input to the mobile button's action.
    ContextActionService:BindAction(
        "ThrowHeld",
        function(action: string, state: Enum.UserInputState, input: InputObject?)
            observe(action .. ":" .. (if input then tostring(input.UserInputType) else "button"))
            return throw(action, state)
        end,
        true,
        Enum.KeyCode.ButtonR2
    )
    -- UIS exposes processed input; CAS callbacks do not have a GUI-consumed flag.
    -- TouchEnabled describes hardware capability, not the input being received.
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if input.UserInputType == Enum.UserInputType.Touch then
            observe("Touch processed=" .. tostring(processed))
            trace("ignored: world touch/UI gesture; use Throw button")
            return
        elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        observe("MouseButton1")
        trace("mouse received processed=" .. tostring(processed))
        if not UserInputService.MouseEnabled then
            trace("ignored: no mouse device (touch synthesized input)")
            return
        end
        if processed then
            trace("ignored: GUI or another action processed input")
            return
        end
        throw("ThrowHeldMouse", Enum.UserInputState.Begin)
    end)
    ContextActionService:SetTitle("ThrowHeld", "Throw")
    MobileControlLayout.Register("ThrowHeld")
end

return Controller
