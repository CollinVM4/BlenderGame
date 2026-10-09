--!strict
local ProximityPromptService = game:GetService("ProximityPromptService")
local Debug = require(game:GetService("ReplicatedStorage").Shared.MobilePromptDebug)
local Targets = {}
local claimed = setmetatable({} :: { [InputObject]: boolean }, { __mode = "k" })

-- Roblox has already hit-tested this actual transparent button before InputBegan.
-- Do not compare its inset-aware InputObject.Position to a second viewport rectangle.
-- Native GUI stacking chooses the source; the finger claim prevents double dispatch.
function Targets.Register(
    prompt: ProximityPrompt,
    gui: BillboardGui,
    button: TextButton,
    begin: (InputObject) -> (),
    available: (() -> boolean)?
): () -> ()
    Debug.Log(
        prompt,
        "REGISTERED",
        "native button " .. tostring(button.Size.X.Offset) .. "x" .. tostring(button.Size.Y.Offset)
    )
    local registered = true
    local connection = button.InputBegan:Connect(function(input)
        Debug.Log(
            prompt,
            "TOUCH RECEIVED",
            tostring(input.UserInputType)
                .. " input="
                .. tostring(input.Position)
                .. " buttonPosition="
                .. tostring(button.AbsolutePosition)
                .. " buttonSize="
                .. tostring(button.AbsoluteSize)
        )
        local reason: string? = nil
        local touch = input.UserInputType == Enum.UserInputType.Touch
        local click = input.UserInputType == Enum.UserInputType.MouseButton1 and prompt.ClickablePrompt
        if not touch and not click then
            reason = "wrong input type"
        elseif claimed[input] then
            reason = "finger already claimed"
        elseif not registered or not gui.Parent or not gui.Enabled or not gui.Active then
            reason = "hidden view"
        elseif button.Parent ~= gui or not button.Visible or not button.Active then
            reason = "inactive touch button"
        elseif not prompt:IsDescendantOf(workspace) then
            reason = "invalid source: prompt outside Workspace"
        elseif not prompt.Enabled then
            reason = "disabled prompt"
        elseif not ProximityPromptService.Enabled then
            reason = "prompt service disabled"
        elseif available and not available() then
            reason = "invalid source: ingredient registration, identity or ownership changed"
        end
        if reason then
            Debug.Log(prompt, "REJECTED", reason)
            return
        end
        -- Claim before begin: a synchronous Triggered callback may retire the view.
        claimed[input] = true
        Debug.Log(prompt, "TARGET SELECTED", "native GUI hit; no coordinate re-test")
        begin(input)
    end)
    return function()
        registered = false
        connection:Disconnect()
    end
end
return Targets
