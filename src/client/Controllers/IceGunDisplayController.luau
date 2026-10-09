--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
local TextStyle = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local Presentation = require(script.Parent.Parent.UI.InteractionPromptPresentation)
local Adapter = require(script.Parent.IceGunShopAdapter)
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    Adapter.Init()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local displays: { [BasePart]: boolean } = {}
    type View = { Cleanup: () -> (), Text: TextLabel, Key: string, Gui: BillboardGui }
    local views: { [ProximityPrompt]: View } = {}
    local engineVisible = setmetatable({} :: { [ProximityPrompt]: boolean }, { __mode = "k" })
    local shownCounts = setmetatable({} :: { [ProximityPrompt]: number }, { __mode = "k" })
    local function debugging(): boolean
        return RunService:IsStudio() and playerGui:GetAttribute("DebugIceGunPrompt") == true
    end
    local function log(message: string)
        if debugging() then
            print("[IceGunPrompt] " .. message)
        end
    end
    local function diagnose()
        if not debugging() then
            return
        end
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local camera = workspace.CurrentCamera
        for _, object in workspace:GetDescendants() do
            if not object:IsA("ProximityPrompt") or object.Name ~= "IceGunPurchase" then
                continue
            end
            local origin = object.Parent
            local view = views[object]
            local distance = if root
                    and root:IsA("BasePart")
                    and origin
                    and origin:IsA("Attachment")
                then (root.Position - origin.WorldPosition).Magnitude
                else math.huge
            local occluded = false
            if camera and origin and origin:IsA("Attachment") then
                local ray = RaycastParams.new()
                ray.FilterType = Enum.RaycastFilterType.Exclude
                ray.FilterDescendantsInstances = if character then { character } else {}
                local hit =
                    workspace:Raycast(camera.CFrame.Position, origin.WorldPosition - camera.CFrame.Position, ray)
                occluded = hit ~= nil and hit.Instance ~= origin.Parent
            end
            local reason = if object:GetAttribute("IceGunPurchase") ~= true
                then "rejected: missing IceGunPurchase attribute"
                elseif not origin or not origin:IsA("Attachment") then "rejected: parent must be Attachment"
                elseif object.Style ~= Enum.ProximityPromptStyle.Custom then "rejected: Style is not Custom"
                elseif
                    view and (not view.Gui.Enabled or not view.Text.Visible or not view.Gui.Parent)
                then "GUI created but hidden"
                elseif view then "GUI created and enabled"
                else "no active view: engine never shown or hidden (range/occlusion/exclusivity/service limits)"
            local otherPrompts = 0
            for other in pairs(engineVisible) do
                if other ~= object then
                    otherPrompts += 1
                end
            end
            log(
                string.format(
                    "%s | %s | shown=%d | distance=%.1f/%s | enabled=%s | ownership=%s | cameraOccluded=%s | RequiresLineOfSight=%s | Exclusivity=%s | service=%s | MaxPromptsVisible=%s | otherVisiblePrompts=%d",
                    object:GetFullName(),
                    reason,
                    shownCounts[object] or 0,
                    distance,
                    tostring(object.MaxActivationDistance),
                    tostring(object.Enabled),
                    tostring(Players.LocalPlayer:GetAttribute("IceGunOwnership") or "MISSING"),
                    tostring(occluded),
                    tostring(object.RequiresLineOfSight),
                    tostring(object.Exclusivity),
                    tostring(PromptService.Enabled),
                    tostring(PromptService.MaxPromptsVisible),
                    otherPrompts
                )
            )
        end
    end
    playerGui:GetAttributeChangedSignal("DebugIceGunPrompt"):Connect(diagnose)
    local lastDiagnostic = 0
    local function add(object: Instance)
        if object:IsA("BasePart") then
            displays[object] = true
        end
    end
    for _, object in CollectionService:GetTagged("IceGunCosmeticDisplay") do
        add(object)
    end
    CollectionService:GetInstanceAddedSignal("IceGunCosmeticDisplay"):Connect(add)
    CollectionService:GetInstanceRemovedSignal("IceGunCosmeticDisplay"):Connect(function(object)
        if object:IsA("BasePart") then
            displays[object] = nil
        end
    end)
    -- One managed cosmetic animator, preserving the original local Z-axis spin.
    RunService.RenderStepped:Connect(function()
        if debugging() and os.clock() - lastDiagnostic >= 5 then
            lastDiagnostic = os.clock()
            diagnose()
        end
        for display in displays do
            local base = display:GetAttribute("IceGunDisplayBase")
            if typeof(base) == "CFrame" and display:IsDescendantOf(workspace) then
                display.CFrame = base * CFrame.Angles(0, 0, os.clock() * Config.DisplayRadiansPerSecond)
            end
        end
    end)
    local function format(key: string, _holding: boolean): string
        local snapshot = Adapter.GetSnapshot()
        local status = if snapshot.Owned
            then "OWNED"
            elseif snapshot.Ownership == "Loading" then "LOADING..."
            elseif snapshot.Ownership == "Unavailable" then "UNAVAILABLE"
            else snapshot.PriceText
        local action = if snapshot.Owned
            then (if snapshot.Equipped then "EQUIPPED" else "EQUIP")
            elseif snapshot.CanBuy then "BUY"
            else "RETRY"
        return "ICE GUN\n" .. status .. "\n[" .. key .. "] " .. action
    end
    local function refresh()
        for _, view in views do
            view.Text.Text = format(view.Key, false)
        end
    end
    local function hide(prompt: ProximityPrompt)
        local view = views[prompt]
        views[prompt] = nil
        if view then
            view.Cleanup()
        end
    end
    Adapter.Changed:Connect(refresh)
    PromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
        engineVisible[prompt] = true
        if
            prompt.Style ~= Enum.ProximityPromptStyle.Custom
            or prompt:GetAttribute("IceGunPurchase") ~= true
            or not prompt.Parent
            or not prompt.Parent:IsA("Attachment")
        then
            return
        end
        shownCounts[prompt] = (shownCounts[prompt] or 0) + 1
        log("PromptShown: " .. prompt:GetFullName())
        hide(prompt)
        local cleanup, gui = Presentation.Create(prompt, prompt.Parent, playerGui, inputType, {
            FormatText = format,
            Width = 230,
            Height = 100,
            TextSize = 24,
            -- PromptShown/Hidden controls character proximity. Billboard distance is camera-based.
            MaxDistance = math.huge,
            Available = function()
                return Players.LocalPlayer:GetAttribute("Stunned") ~= true
            end,
        })
        local text = gui:FindFirstChild("Action") :: TextLabel
        TextStyle.Apply(text, 24)
        text.TextColor3 = Color3.fromRGB(140, 235, 255)
        local key = if inputType == Enum.ProximityPromptInputType.Touch
            then "TAP"
            elseif inputType == Enum.ProximityPromptInputType.Gamepad then prompt.GamepadKeyCode.Name
            else UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
        views[prompt] = { Cleanup = cleanup, Text = text, Key = key, Gui = gui }
        log("GUI created in PlayerGui: " .. prompt:GetFullName())
        Adapter.Refresh()
        refresh()
    end)
    PromptService.PromptHidden:Connect(function(prompt)
        engineVisible[prompt] = nil
        if prompt:GetAttribute("IceGunPurchase") == true then
            log("PromptHidden: " .. prompt:GetFullName())
        end
        hide(prompt)
    end)
    playerGui:SetAttribute("IceGunPromptRendererRegistered", true)
    diagnose()
    workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("ProximityPrompt") then
            engineVisible[object] = nil
            hide(object)
        end
    end)
end

return Controller
