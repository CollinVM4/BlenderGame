local function new(class, name, parentObject)
    local object = instance(class)
    object.Name, object.Parent = name, parentObject
    local signals = {}
    function object:GetAttributeChangedSignal(attribute)
        signals[attribute] = signals[attribute] or signal()
        return signals[attribute]
    end
    function object:SetAttribute(attribute, value)
        local previous = self.Attributes[attribute]
        self.Attributes[attribute] = value
        if previous ~= value and signals[attribute] then
            signals[attribute]:Fire()
        end
    end
    return object
end
local plots, owners, cleanups, labels = {}, {}, {}, {}
for i = 1, 2 do
    local plot = new("Model", "Plot" .. i, workspaceFake)
    local blender = new("Model", "Blender", plot)
    local body = new("Part", "Body", blender)
    local countOrigin = new("Attachment", "IngredientCountOrigin", body)
    local turbine = new("Part", "TurbineSupport", plot)
    local promptOrigin = new("Attachment", "TurbinePromptOrigin", turbine)
    local owner = new("Player", "Owner" .. i)
    plot:SetAttribute("OwnerUserId", i)
    owners[plot] = owner
    plots[i] = plot
    labels[i] = { CountOrigin = countOrigin, PromptOrigin = promptOrigin }
end
cache.WorldUtil.BindTag = function(tag, attach)
    check(tag == "PlayerPlot", "presentation binds to plots")
    for i, plot in plots do
        cleanups[i] = attach(plot)
    end
end
services.Players.PlayerRemoving = signal()
local chunk = assert(loadstring(sources.BlenderStatusPresentation))
setfenv(chunk, setmetatable({ script = { Parent = { Parent = { Services = parent } } } }, { __index = env }))
chunk().Init({ TycoonService = {
    GetOwner = function(plot)
        return owners[plot]
    end,
} })
for _, refs in labels do
    refs.CountGui = refs.CountOrigin:FindFirstChild("IngredientCountDisplay")
    refs.PromptGui = refs.PromptOrigin:FindFirstChild("TurbineStatusDisplay")
    refs.Count = refs.CountGui:FindFirstChild("Status")
    refs.Prompt = refs.PromptGui:FindFirstChild("Status")
    check(refs.CountGui.Adornee == refs.CountOrigin, "Attachment is the adornee")
    check(refs.CountGui.AlwaysOnTop and refs.CountGui.MaxDistance == 80, "readable world-space settings")
    check(refs.Count.BackgroundTransparency == 1 and refs.Count.TextStrokeTransparency == 0.25, "order bubble style")
    check(refs.Count.Text == "0 / 3", "initial empty count")
end
local owner = owners[plots[1]]
local function publish(state, ingredients)
    owner:SetAttribute("BlendState", state)
    owner:SetAttribute("BlendIngredientCount", ingredients)
end
for i = 1, 2 do
    publish("LOADING", i)
    check(labels[1].Count.Text == i .. " / 3", "accepted ingredient immediately updates count")
    check(labels[1].Prompt.Text == "LOAD INGREDIENTS TO BLEND!", "partial batch asks for loading")
end
owner:SetAttribute("BlendNeedsItems", true)
check(labels[1].Prompt.Text == "NEEDS 3 ITEMS!", "rejected attempt shows required count")
check(labels[1].Count.Text == "2 / 3", "rejection preserves displayed count")
check(labels[2].Prompt.Text == "LOAD INGREDIENTS TO BLEND!", "rejection is plot-local")
owner:SetAttribute("BlendNeedsItems", false)
check(labels[1].Prompt.Text == "LOAD INGREDIENTS TO BLEND!", "expiry restores loading prompt")
owner:SetAttribute("BlendNeedsItems", true)
publish("READY", 3)
check(labels[1].Count.Text == "3 / 3\nLOADING COMPLETE!", "full count has explicit loading completion")
check(labels[1].Count.TextColor3.G == 1 and labels[1].Count.TextColor3.R < 1, "full count is green")
check(labels[1].Prompt.Text == "SPIN TO BLEND!", "ready prompt")
owner:SetAttribute("BlendNeedsItems", false)
check(labels[2].Count.Text == "0 / 3", "other plot stays independent")
publish("BLENDING", 3)
check(labels[1].Prompt.Text == "BLENDING...", "active prompt")
publish("COMPLETE", 3)
check(labels[1].Prompt.Text == "READY TO DISPENSE!", "completed prompt")
publish("DISPENSED", 3)
check(labels[1].Prompt.Text == "LOAD INGREDIENTS TO BLEND!", "dispensed no longer asks to dispense")
publish("EMPTY", 0)
check(labels[1].Count.Text == "0 / 3", "reset clears count")
check(labels[1].Prompt.Text == "LOAD INGREDIENTS TO BLEND!", "reset clears prompt")
publish("BLENDING", 1)
check(labels[1].Prompt.Text == "BLENDING...", "authoritative active state takes presentation precedence")
local replacement = owners[plots[2]]
replacement:SetAttribute("BlendIngredientCount", 3)
replacement:SetAttribute("BlendState", "COMPLETE")
owners[plots[1]] = replacement
plots[1]:SetAttribute("OwnerUserId", 2)
check(labels[1].Prompt.Text == "READY TO DISPENSE!", "reassignment restores current state")
publish("EMPTY", 0)
check(labels[1].Count.Text == "3 / 3\nLOADING COMPLETE!", "old owner disconnected")
services.Players.PlayerRemoving:Fire(replacement)
check(labels[1].Count.Text == "0 / 3" and labels[2].Count.Text == "0 / 3", "leaving clears displays")
for i, cleanup in cleanups do
    cleanup()
    check(labels[i].CountGui.Parent == nil and labels[i].PromptGui.Parent == nil, "detach destroys owned UI")
end
print(string.format("PASS: %d blender status assertions (mocked Roblox boundary).", count))
