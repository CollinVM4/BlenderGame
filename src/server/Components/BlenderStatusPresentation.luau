--!strict
local Players = game:GetService("Players")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local BlenderStatusPresentation = {}

-- Cosmetic tuning only. Capacity comes from the same config as BlendService.
local TEXT_SIZE = 24
local MAX_DISTANCE = 80
-- Offset-only canvases keep both displays at a fixed screen-space pixel size.
local COUNT_SIZE = UDim2.fromOffset(240, 72)
local PROMPT_SIZE = UDim2.fromOffset(380, 80)
local COUNT_OFFSET = Vector3.new(0, 0, 0)
local PROMPT_OFFSET = Vector3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local FULL_COLOR = Color3.new(0.45, 1, 0.55)

-- Presentation markers accept Attachments without changing gameplay references,
-- whose TycoonService.GetReference API intentionally returns BaseParts.
local function origin(root: Instance, name: string): Instance?
    local direct = root:FindFirstChild(name)
    if direct and (direct:IsA("Attachment") or direct:IsA("BasePart")) then
        return direct
    end
    local found: Instance? = nil
    for _, child in root:GetDescendants() do
        if child.Name == name and (child:IsA("Attachment") or child:IsA("BasePart")) then
            if found then
                warn("[BlenderStatusPresentation] Duplicate " .. name .. " in " .. root:GetFullName())
                return nil
            end
            found = child
        end
    end
    if not found then
        warn("[BlenderStatusPresentation] Missing " .. name .. " in " .. root:GetFullName())
    end
    return found
end

local function billboard(marker: Instance, name: string, size: UDim2, offset: Vector3): (BillboardGui, TextLabel)
    local gui = Instance.new("BillboardGui")
    gui.Name = name
    gui.Adornee = marker
    gui.Size = size
    gui.StudsOffsetWorldSpace = offset
    gui.AlwaysOnTop = true
    gui.MaxDistance = MAX_DISTANCE
    local text = Instance.new("TextLabel")
    text.Name = "Status"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.BorderSizePixel = 0
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextStrokeTransparency = 0.25
    text.TextColor3 = WHITE
    text.Font = Enum.Font.GothamBold
    text.TextScaled = false
    text.TextSize = TEXT_SIZE
    text.TextWrapped = true
    text.Text = ""
    text.Parent = gui
    gui.Parent = marker
    return gui, text
end

function BlenderStatusPresentation.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot)
        local blender = if plot.Name == "Blender" then plot else plot:FindFirstChild("Blender")
        local countOrigin = blender and origin(blender, "IngredientCountOrigin")
        local promptOrigin = origin(plot, "TurbinePromptOrigin")
        local guis: { BillboardGui } = {}
        local countText: TextLabel? = nil
        local promptText: TextLabel? = nil
        if countOrigin then
            local gui, text = billboard(countOrigin, "IngredientCountDisplay", COUNT_SIZE, COUNT_OFFSET)
            table.insert(guis, gui)
            countText = text
        end
        if promptOrigin then
            local gui, text = billboard(promptOrigin, "TurbineStatusDisplay", PROMPT_SIZE, PROMPT_OFFSET)
            table.insert(guis, gui)
            promptText = text
        end
        local owner: Player? = nil
        local ownerConnections: { RBXScriptConnection } = {}
        local function refresh()
            local state = if owner then owner:GetAttribute("BlendState") else "EMPTY"
            local accepted = if owner then owner:GetAttribute("BlendIngredientCount") else 0
            local loaded = if state == "EMPTY" or typeof(accepted) ~= "number" then 0 else accepted :: number
            local full = loaded >= Economy.MaxIngredients
            if countText then
                countText.Text = string.format("%d / %d", loaded, Economy.MaxIngredients)
                    .. (if full then "\nLOADING COMPLETE!" else "")
                countText.TextColor3 = if full then FULL_COLOR else WHITE
            end
            if promptText then
                promptText.Text = if state == "COMPLETE"
                    then "READY TO DISPENSE!"
                    elseif state == "BLENDING" then "BLENDING..."
                    elseif state == "READY" and full then "SPIN TO BLEND!"
                    elseif not full and owner and owner:GetAttribute("BlendNeedsItems") == true
                        then string.format("NEEDS %d ITEMS!", Economy.MaxIngredients)
                    else "LOAD INGREDIENTS TO BLEND!"
            end
        end
        local function disconnectOwner()
            for _, connection in ownerConnections do
                connection:Disconnect()
            end
            table.clear(ownerConnections)
        end
        local function bindOwner()
            disconnectOwner()
            owner = if plot:GetAttribute("OwnerUserId") ~= nil then services.TycoonService.GetOwner(plot) else nil
            if owner then
                for _, attribute in { "BlendIngredientCount", "BlendState", "BlendNeedsItems" } do
                    table.insert(ownerConnections, owner:GetAttributeChangedSignal(attribute):Connect(refresh))
                end
            end
            refresh()
        end
        local ownership = plot:GetAttributeChangedSignal("OwnerUserId"):Connect(bindOwner)
        local leaving = Players.PlayerRemoving:Connect(function(player)
            if player == owner then
                disconnectOwner()
                owner = nil
                refresh()
            end
        end)
        bindOwner()
        return function()
            ownership:Disconnect()
            leaving:Disconnect()
            disconnectOwner()
            for _, gui in guis do
                gui:Destroy()
            end
        end
    end)
end

return BlenderStatusPresentation
