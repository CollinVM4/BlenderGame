--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Presentation = require(script.Parent.Parent.UI.InteractionPromptPresentation)
local Controller = {}
local started = false

-- Never recursively search a plot/workspace and accidentally bind another interactable.
local function findOrigin(prompt: ProximityPrompt): (Attachment?, string?)
    local name = prompt:GetAttribute("InteractionOrigin")
    if typeof(name) ~= "string" or name == "" then
        return nil, "InteractionOrigin must be a nonempty string"
    end
    local ancestor = prompt.Parent
    while ancestor and ancestor ~= workspace do
        local marker = ancestor:FindFirstChild(name)
        if marker and marker:IsA("Attachment") then
            return marker
        end
        if marker then
            return nil, marker:GetFullName() .. " is " .. marker.ClassName .. "; expected Attachment"
        end
        if ancestor:IsA("Model") then
            local found: Attachment? = nil
            for _, descendant in ancestor:GetDescendants() do
                if descendant.Name == name and descendant:IsA("Attachment") then
                    if found then
                        return nil, "Ambiguous InteractionOrigin beneath " .. ancestor:GetFullName()
                    end
                    found = descendant
                end
            end
            if found then
                return found
            end
            return nil, "Attachment " .. name .. " not found beneath containing Model " .. ancestor:GetFullName()
        end
        ancestor = ancestor.Parent
    end
    return nil, "Attachment " .. name .. " not found beneath prompt's containing interactable"
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    -- ServerStorage's debug flag does not replicate. Use the same Studio-only
    -- convention on local PlayerGui, without introducing a server bridge.
    local function debugging(): boolean
        return RunService:IsStudio() and playerGui:GetAttribute("DebugFilmLoop") == true
    end
    local function log(prompt: ProximityPrompt, message: string)
        if debugging() then
            print("[InteractionPrompt] " .. prompt:GetFullName() .. " | " .. message)
        end
    end
    local shownCounts = setmetatable({} :: { [ProximityPrompt]: number }, { __mode = "k" })
    local function snapshot(prompt: ProximityPrompt)
        if not debugging() then
            return
        end
        local parent = prompt.Parent
        local placement = "Invalid: parent must be BasePart, Attachment, or Model with PrimaryPart"
        if parent then
            if parent:IsA("Model") then
                placement = if parent.PrimaryPart
                    then "Model PrimaryPart=" .. parent.PrimaryPart:GetFullName()
                    else "Invalid: Model.PrimaryPart is nil; engine cannot show this prompt"
            elseif parent:IsA("BasePart") then
                placement = "BasePart=" .. parent:GetFullName()
            elseif parent:IsA("Attachment") then
                placement = "Attachment=" .. parent:GetFullName() .. "; parent=" .. tostring(parent.Parent)
            end
        end
        local origin, reason = findOrigin(prompt)
        log(
            prompt,
            string.format(
                "snapshot | PromptShownCount=%d | InteractionOrigin=%s | InteractionActionText=%s | ResolvedOrigin=%s | OriginReason=%s | MaxActivationDistance=%s | RequiresLineOfSight=%s | HoldDuration=%s | Style=%s | Enabled=%s | ParentClass=%s | Placement=%s | InWorkspace=%s | Exclusivity=%s | ServiceEnabled=%s | MaxPromptsVisible=%s",
                shownCounts[prompt] or 0,
                tostring(prompt:GetAttribute("InteractionOrigin")),
                tostring(prompt:GetAttribute("InteractionActionText")),
                if origin then origin:GetFullName() else "nil",
                reason or "resolved",
                tostring(prompt.MaxActivationDistance),
                tostring(prompt.RequiresLineOfSight),
                tostring(prompt.HoldDuration),
                tostring(prompt.Style),
                tostring(prompt.Enabled),
                if parent then parent.ClassName else "nil",
                placement,
                tostring(prompt:IsDescendantOf(workspace)),
                tostring(prompt.Exclusivity),
                tostring(ProximityPromptService.Enabled),
                tostring(ProximityPromptService.MaxPromptsVisible)
            )
        )
    end
    local function dump()
        if not debugging() then
            return
        end
        for _, object in workspace:GetDescendants() do
            if object:IsA("ProximityPrompt") and object:GetAttribute("InteractionOrigin") ~= nil then
                snapshot(object)
            end
        end
    end
    playerGui:GetAttributeChangedSignal("DebugFilmLoop"):Connect(dump)
    type Visible = {
        InputType: Enum.ProximityPromptInputType,
        Origin: Attachment?,
        Cleanup: (() -> ())?,
        Connections: { RBXScriptConnection },
    }
    local visible: { [ProximityPrompt]: Visible } = {}
    local function clearView(entry: Visible)
        local cleanup = entry.Cleanup
        entry.Cleanup = nil
        entry.Origin = nil
        if cleanup then
            cleanup()
        end
    end
    local function hide(prompt: ProximityPrompt)
        local entry = visible[prompt]
        if not entry then
            return
        end
        visible[prompt] = nil
        for _, connection in entry.Connections do
            connection:Disconnect()
        end
        clearView(entry)
    end
    local function refresh(prompt: ProximityPrompt, entry: Visible)
        if not prompt:IsDescendantOf(workspace) or not prompt.Enabled then
            log(prompt, "Rejected: " .. (if not prompt.Enabled then "Enabled=false" else "prompt is outside Workspace"))
            hide(prompt)
            return
        end
        local origin, reason = findOrigin(prompt)
        if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
            origin = nil
            reason = "Style is not Custom"
        end
        local customerAction = prompt:GetAttribute("InteractionCustomerAction")
        if customerAction and prompt:GetAttribute("InteractionOwnerUserId") ~= Players.LocalPlayer.UserId then
            origin = nil
            reason = "Customer prompt belongs to another player"
        end
        if not origin then
            log(prompt, "Rejected: " .. (reason or "origin unavailable"))
        end
        if origin == entry.Origin then
            return
        end
        clearView(entry)
        if origin then
            local action = prompt:GetAttribute("InteractionActionText")
            local key = prompt:GetAttribute("InteractionKeyText")
            local distance = prompt:GetAttribute("InteractionMaxDistance")
            entry.Origin = origin
            log(
                prompt,
                "Presentation.Create | origin="
                    .. origin:GetFullName()
                    .. " | InteractionActionText="
                    .. tostring(action)
            )
            local cleanup, gui = Presentation.Create(prompt, origin, playerGui, entry.InputType, {
                CustomerAction = if typeof(customerAction) == "string" then customerAction else nil,
                ActionText = if typeof(action) == "string" then action else nil,
                KeyText = if typeof(key) == "string" then key else nil,
                MaxDistance = if typeof(distance) == "number" and distance > 0 then distance else nil,
            })
            entry.Cleanup = cleanup
            log(prompt, "BillboardGui created=" .. gui:GetFullName() .. " | Adornee=" .. origin:GetFullName())
        end
    end
    ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        shownCounts[prompt] = (shownCounts[prompt] or 0) + 1
        log(prompt, "PromptShown received by controller | InputType=" .. tostring(inputType))
        snapshot(prompt)
        hide(prompt)
        local entry: Visible = { InputType = inputType, Connections = {} }
        visible[prompt] = entry
        table.insert(
            entry.Connections,
            prompt.AncestryChanged:Connect(function()
                refresh(prompt, entry)
            end)
        )
        table.insert(
            entry.Connections,
            prompt.Changed:Connect(function(property)
                if property == "Enabled" or property == "Style" then
                    refresh(prompt, entry)
                end
            end)
        )
        table.insert(
            entry.Connections,
            prompt.AttributeChanged:Connect(function(attribute)
                if string.sub(attribute, 1, 11) == "Interaction" then
                    clearView(entry)
                    refresh(prompt, entry)
                end
            end)
        )
        refresh(prompt, entry)
    end)
    ProximityPromptService.PromptHidden:Connect(function(prompt)
        log(prompt, "PromptHidden received by controller")
        hide(prompt)
    end)
    dump()
    -- Replication/streaming may deliver a marker after its already-visible prompt.
    workspace.DescendantAdded:Connect(function(object)
        if object:IsA("ProximityPrompt") then
            snapshot(object)
        end
        if object:IsA("Attachment") then
            for prompt, entry in visible do
                refresh(prompt, entry)
            end
        end
    end)
    workspace.DescendantRemoving:Connect(function(object: Instance)
        for prompt, entry in visible do
            if object == prompt then
                hide(prompt)
            elseif object == entry.Origin then
                clearView(entry)
            end
        end
    end)
end

return Controller
