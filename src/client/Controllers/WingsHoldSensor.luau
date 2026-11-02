--!strict
-- Passive fallback: current CAS inputTypes are KeyCode/UserInputType, not
-- PlayerActions.CharacterJump. Observe standard Space/ButtonA without consuming.
-- Native touch is
-- observed separately because TouchJump does not dispatch a CAS jump action.
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Sensor = {}
function Sensor.Attach(playerGui: PlayerGui, changed: (boolean) -> ())
    local held: { [InputObject]: boolean } = {}
    local last = false
    local connections: { RBXScriptConnection } = {}
    local buttons: { [Instance]: { RBXScriptConnection } } = {}
    local function send()
        local value = next(held) ~= nil
        if value ~= last then
            last = value
            changed(value)
        end
    end
    local function clear()
        table.clear(held)
        send()
    end
    local function release(input: InputObject)
        held[input] = nil
        send()
    end
    CAS:BindActionAtPriority("WingsJumpHold", function(_, state, input: InputObject)
        if state == Enum.UserInputState.Begin then
            if not UIS:GetFocusedTextBox() and not GuiService.MenuIsOpen then
                held[input] = true
                send()
            end
        elseif state == Enum.UserInputState.End then
            release(input)
        elseif state == Enum.UserInputState.Cancel then
            clear()
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
    local function detach(button: Instance)
        local list = buttons[button]
        if list then
            for _, connection in list do
                connection:Disconnect()
            end
            buttons[button] = nil
            clear()
        end
    end
    local function attach(button: Instance)
        local touchGui = playerGui:FindFirstChild("TouchGui")
        if
            buttons[button]
            or button.Name ~= "JumpButton"
            or not button:IsA("GuiButton")
            or not touchGui
            or not button:IsDescendantOf(touchGui)
        then
            return
        end
        buttons[button] = {
            button.InputBegan:Connect(function(input)
                if
                    input.UserInputType == Enum.UserInputType.Touch
                    and input.UserInputState == Enum.UserInputState.Begin
                    and button.Visible
                    and not GuiService.MenuIsOpen
                then
                    held[input] = true
                    send()
                end
            end),
            button.InputEnded:Connect(release),
            button:GetPropertyChangedSignal("Visible"):Connect(function()
                if not button.Visible then
                    clear()
                end
            end),
        }
    end
    table.insert(connections, UIS.InputEnded:Connect(release)) -- Release outside the native button still ends hold.
    table.insert(connections, UIS.WindowFocusReleased:Connect(clear))
    table.insert(connections, UIS.TextBoxFocused:Connect(clear))
    table.insert(connections, GuiService.MenuOpened:Connect(clear))
    table.insert(connections, playerGui.DescendantAdded:Connect(attach))
    table.insert(connections, playerGui.DescendantRemoving:Connect(detach))
    for _, object in playerGui:GetDescendants() do
        attach(object)
    end
    return {
        Clear = clear,
        Destroy = function()
            clear()
            CAS:UnbindAction("WingsJumpHold")
            for button in buttons do
                detach(button)
            end
            for _, connection in connections do
                connection:Disconnect()
            end
        end,
    }
end
return Sensor
