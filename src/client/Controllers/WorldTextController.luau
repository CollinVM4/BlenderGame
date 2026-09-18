--!strict
local Presentation = require(script.Parent.Parent.UI.WorldTextPresentation)
local Controller = {}
local started = false

type Entry = {
    Connection: RBXScriptConnection?,
    Handle: Presentation.Handle?,
    MaxDistance: number?,
    TextSize: number?,
}

local function positiveNumber(value: any): number?
    return if typeof(value) == "number" and value > 0 and value < math.huge then value else nil
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local tracked: { [Attachment]: Entry } = {}
    local function clear(entry: Entry)
        local handle = entry.Handle
        entry.Handle = nil
        if handle then
            handle:Destroy()
        end
    end
    local function refresh(origin: Attachment, entry: Entry)
        local text = origin:GetAttribute("WorldText")
        if not origin:IsDescendantOf(workspace) or typeof(text) ~= "string" or text == "" then
            clear(entry)
            return
        end
        local distance = positiveNumber(origin:GetAttribute("WorldTextMaxDistance"))
        local textSize = positiveNumber(origin:GetAttribute("WorldTextTextSize"))
        if entry.MaxDistance ~= distance or entry.TextSize ~= textSize then
            clear(entry)
        end
        entry.MaxDistance, entry.TextSize = distance, textSize
        local handle = entry.Handle
        if not handle then
            local settings: Presentation.Settings = {
                Origin = origin,
                Text = text,
                MaxDistance = distance,
                TextSize = textSize,
            }
            handle = Presentation.Create(settings)
            entry.Handle = handle
        else
            handle:SetText(text)
        end
        if handle then
            handle:SetVisible(origin:GetAttribute("WorldTextVisible") ~= false)
        end
    end
    local function track(object: Instance)
        if not object:IsA("Attachment") or tracked[object] or not object:IsDescendantOf(workspace) then
            return
        end
        local entry: Entry = {}
        tracked[object] = entry
        -- Track bare Attachments too: attributes may replicate or be authored later.
        entry.Connection = object.AttributeChanged:Connect(function(attribute)
            if
                attribute == "WorldText"
                or attribute == "WorldTextVisible"
                or attribute == "WorldTextMaxDistance"
                or attribute == "WorldTextTextSize"
            then
                refresh(object, entry)
            end
        end)
        refresh(object, entry)
    end
    workspace.DescendantAdded:Connect(track)
    workspace.DescendantRemoving:Connect(function(object)
        if not object:IsA("Attachment") then
            return
        end
        local entry = tracked[object]
        if not entry then
            return
        end
        tracked[object] = nil
        if entry.Connection then
            entry.Connection:Disconnect()
        end
        clear(entry)
    end)
    -- Connect first so objects arriving during startup cannot be missed.
    for _, object in workspace:GetDescendants() do
        track(object)
    end
end

return Controller
