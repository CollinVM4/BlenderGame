--!strict
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
local Players = game:GetService("Players")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local TextStyle = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local BlenderStatusPresentation = {}

-- Cosmetic tuning only. Capacity comes from the same config as BlendService.
local TEXT_SIZE = 24
local MAX_DISTANCE = 40
local COUNT_SIZE = Vector2.new(7.68, 2.28)
local PROMPT_SIZE = Vector2.new(12.12, 2.52)
local COUNT_OFFSET = Vector3.new(0, 0, 0)
local PROMPT_OFFSET = Vector3.new(0, 0, 0)
local WHITE = TextStyle.White
local FULL_COLOR = TextStyle.Green

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

local function billboard(marker: Instance, name: string, size: Vector2, offset: Vector3): (BillboardGui, TextLabel)
    local gui = Instance.new("BillboardGui")
    gui.Name = name
    gui.Adornee = marker
    -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
    BillboardStyle.ApplyBillboard(
        gui,
        { WidthStuds = size.X, HeightStuds = size.Y, MaxDistance = MAX_DISTANCE, ResetOnSpawn = true }
    )
    gui.ClipsDescendants = false -- Keep the completion line and brief count pop clear of the canvas edge.
    gui.StudsOffsetWorldSpace = offset
    gui.AlwaysOnTop = true
    gui.MaxDistance = MAX_DISTANCE
    local text = Instance.new("TextLabel")
    text.Name = "Status"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.BorderSizePixel = 0
    TextStyle.Apply(text, TEXT_SIZE, gui)
    text.TextScaled = true
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
        local promptGui: BillboardGui? = nil
        if countOrigin then
            local gui, text = billboard(countOrigin, "IngredientCountDisplay", COUNT_SIZE, COUNT_OFFSET)
            table.insert(guis, gui)
            countText = text
        end
        if promptOrigin then
            local gui, text = billboard(promptOrigin, "TurbineStatusDisplay", PROMPT_SIZE, PROMPT_OFFSET)
            table.insert(guis, gui)
            promptText = text
            promptGui = gui
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
                promptText.TextColor3 = if state == "COMPLETE" then FULL_COLOR else WHITE
                promptText.Text = if state == "COMPLETE"
                    then "READY TO DISPENSE!"
                    elseif state == "BLENDING" then "BLENDING..."
                    elseif state == "READY" and full then "SPIN TO BLEND!"
                    elseif not full and owner and owner:GetAttribute("BlendNeedsItems") == true then string.format(
                        "NEEDS %d ITEMS!",
                        Economy.MaxIngredients
                    )
                    else "LOAD INGREDIENTS TO BLEND!"
                local guidance = promptText.Text == "LOAD INGREDIENTS TO BLEND!"
                promptText.TextSize = if guidance then TEXT_SIZE * 0.85 else TEXT_SIZE
                if promptGui then
                    BillboardStyle.ApplyBillboard(promptGui, {
                        WidthStuds = if guidance then 9.6 else PROMPT_SIZE.X,
                        HeightStuds = if guidance then 2.04 else PROMPT_SIZE.Y,
                        MaxDistance = MAX_DISTANCE,
                        ResetOnSpawn = true,
                    })
                    promptGui.MaxDistance = MAX_DISTANCE
                end
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
