--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local MobileControlLayout = require(script.Parent.Parent.UI.MobileControlLayout)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local remote = ReplicatedStorage.Shared.Events:WaitForChild("GameplayRequest") :: RemoteEvent
    local function trace(message: string)
        if player:GetAttribute("ThrowDebug") == true then
            print("[ThrowInput] player=" .. player.Name .. " " .. message)
        end
    end
    local function throw(_action: string, state: Enum.UserInputState): Enum.ContextActionResult
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
                    trace("ignored: weapon equipped " .. child.Name)
                    return Enum.ContextActionResult.Pass
                end
            end
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
            remote:FireServer("ThrowHeld")
        end
        return Enum.ContextActionResult.Sink
    end
    -- The existing CAS Throw button and console trigger share this intentional path.
    -- Do not bind touch-world/primary mouse input to the mobile button's action.
    ContextActionService:BindAction("ThrowHeld", throw, true, Enum.KeyCode.ButtonR2)
    -- UIS exposes processed input; CAS callbacks do not have a GUI-consumed flag.
    -- TouchEnabled describes hardware capability, not the input being received.
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
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
