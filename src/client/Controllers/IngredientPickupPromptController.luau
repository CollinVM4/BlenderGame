--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Constants.Ingredients)
local Presentation = require(script.Parent.Parent.UI.IngredientPickupPromptPresentation)
local Controller = {}
local started = false

-- Client mirror of IngredientService's ancestor resolution, using only its
-- replicated registration metadata. The server still validates its private record.
function Controller.Resolve(prompt: ProximityPrompt): (BasePart | Model)?
    local ancestor = prompt.Parent
    while ancestor and ancestor ~= workspace do
        if CollectionService:HasTag(ancestor, "IngredientWorldItem") then
            if ancestor:IsA("BasePart") or ancestor:IsA("Model") then
                return ancestor
            end
            return nil
        end
        ancestor = ancestor.Parent
    end
    return nil
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    type Entry = {
        InputType: Enum.ProximityPromptInputType,
        Object: Instance?,
        Id: string?,
        Cleanup: (() -> ())?,
        Update: (() -> ())?,
        Connections: { RBXScriptConnection },
    }
    local visible: { [ProximityPrompt]: Entry } = {}
    local function clear(entry: Entry)
        if entry.Cleanup then
            entry.Cleanup()
        end
        entry.Cleanup, entry.Update, entry.Object, entry.Id = nil, nil, nil, nil
    end
    local function hide(prompt: ProximityPrompt)
        local entry = visible[prompt]
        if entry then
            visible[prompt] = nil
            for _, connection in entry.Connections do
                connection:Disconnect()
            end
            clear(entry)
        end
    end
    local function refresh(prompt: ProximityPrompt, entry: Entry)
        if not prompt:IsDescendantOf(workspace) or not prompt.Enabled or not ProximityPromptService.Enabled then
            hide(prompt)
            return
        end
        local object = Controller.Resolve(prompt)
        local id = object and object:GetAttribute("IngredientId")
        local definition = if typeof(id) == "string" then Definitions[id] else nil
        if object and object:IsA("Model") and not object:FindFirstChildWhichIsA("BasePart", true) then
            clear(entry)
            return
        end
        if
            prompt.Style ~= Enum.ProximityPromptStyle.Custom
            or prompt:GetAttribute("IngredientPickupPrompt") ~= true
            or not definition
            or not object
        then
            clear(entry)
            return
        end
        if entry.Object ~= (object :: Instance) or entry.Id ~= id then
            clear(entry)
            entry.Object, entry.Id = object, definition.Id
            entry.Cleanup, entry.Update = Presentation.Create(prompt, object, definition, playerGui, entry.InputType)
        elseif entry.Update then
            entry.Update()
        end
    end
    ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
        hide(prompt)
        -- Track shown prompts only. No distance checks, pickup remotes, or scans.
        if prompt:GetAttribute("IngredientPickupPrompt") ~= true and prompt.Name ~= "CarryPrompt" then
            return
        end
        local entry: Entry = { InputType = inputType, Connections = {} }
        visible[prompt] = entry
        table.insert(
            entry.Connections,
            prompt.Destroying:Connect(function()
                hide(prompt)
            end)
        )
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
        refresh(prompt, entry)
    end)
    ProximityPromptService.PromptHidden:Connect(hide)
    -- Only engine-visible prompts: tracks rolling/dropped geometry and tolerates
    -- tags/IngredientId arriving after PromptShown during replication/streaming.
    RunService.RenderStepped:Connect(function()
        for prompt, entry in visible do
            refresh(prompt, entry)
        end
    end)
end

return Controller
