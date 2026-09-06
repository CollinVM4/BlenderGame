--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Economy = require(Shared.Constants.Economy)
local Upgrades = require(Shared.Constants.Upgrades)
local Recipes = require(Shared.Constants.Recipes)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local BlendService = {}
local deps: any
type Batch = { State: Types.BlendState, Ingredients: { string }, Progress: number, Result: Types.Smoothie? }
local batches: { [Player]: Batch } = {}
local cups: { [Player]: { Tool: Tool, Result: Types.Smoothie } } = {}
local nextInteraction: { [Player]: number } = {}

local function publish(player: Player)
    local batch = batches[player]
    player:SetAttribute("BlendState", batch.State)
    player:SetAttribute("BlendProgress", batch.Progress)
    player:SetAttribute("BlendIngredientCount", #batch.Ingredients)
end
local function copyResult(result: Types.Smoothie): Types.Smoothie
    return {
        Ingredients = table.clone(result.Ingredients),
        Tags = table.clone(result.Tags),
        Color = result.Color,
        Discovery = result.Discovery,
    }
end
function BlendService.Init(services)
    deps = services
end
function BlendService.Reset(player: Player)
    batches[player] = { State = "EMPTY", Ingredients = {}, Progress = 0, Result = nil }
    nextInteraction[player] = nil
    publish(player)
end
function BlendService.GetSnapshot(player: Player): Batch?
    local batch = batches[player]
    if not batch then
        return nil
    end
    return {
        State = batch.State,
        Ingredients = table.clone(batch.Ingredients),
        Progress = batch.Progress,
        Result = if batch.Result then copyResult(batch.Result) else nil,
    }
end
function BlendService.TryInput(player: Player, object: Instance, input: BasePart): boolean
    local batch = batches[player]
    local record = deps.IngredientService.GetRecord(object)
    local part = WorldUtil.Part(object)
    if
        not batch
        or (batch.State ~= "EMPTY" and batch.State ~= "LOADING" and batch.State ~= "READY")
        or #batch.Ingredients >= Economy.MaxIngredients
        or not record
        or record.Owner ~= player
        or not part
        or deps.TycoonService.GetOwner(input) ~= player
        or deps.TycoonService.GetReference(player, "BlenderInput") ~= input
    then
        return false
    end
    -- Check actual overlap on the server, not only a client-influenced Touched signal.
    local overlaps = false
    for _, touching in workspace:GetPartsInPart(input) do
        if deps.IngredientService.Resolve(touching) == object then
            overlaps = true
            break
        end
    end
    if not overlaps then
        return false
    end
    local id = deps.IngredientService.Consume(object)
    if not id then
        return false
    end
    table.insert(batch.Ingredients, id)
    batch.State = if #batch.Ingredients == Economy.MaxIngredients then "READY" else "LOADING"
    publish(player)
    return true
end
function BlendService.Ready(player: Player): boolean
    local batch = batches[player]
    if not batch or #batch.Ingredients == 0 or (batch.State ~= "LOADING" and batch.State ~= "READY") then
        return false
    end
    batch.State = "READY"
    publish(player)
    return true
end
local function makeResult(ids: { string }): Types.Smoothie
    local tags = {}
    local sum = Vector3.zero
    for _, id in ids do
        local definition = deps.IngredientService.GetDefinition(id)
        for _, tag in definition.Tags do
            if not table.find(tags, tag) then
                table.insert(tags, tag)
            end
        end
        local color = definition.BlendColor
        sum += Vector3.new(color.R, color.G, color.B)
    end
    local sorted = table.clone(ids)
    table.sort(sorted)
    local discovery: string? = nil
    for name, recipe in Recipes do
        local combination = table.clone(recipe.Ingredients)
        table.sort(combination)
        if table.concat(sorted, "|") == table.concat(combination, "|") then
            discovery = name
            break
        end
    end
    sum /= #ids
    return {
        Ingredients = table.clone(ids),
        Tags = tags,
        Color = Color3.new(sum.X, sum.Y, sum.Z),
        Discovery = discovery,
    }
end
-- Server components report physical spin or a fixed prompt interaction. No progress remote exists.
function BlendService.AddProgress(player: Player, wheel: BasePart, delta: number): boolean
    local batch = batches[player]
    if
        not batch
        or not WorldUtil.Near(player, wheel, Economy.InteractionDistance)
        or deps.TycoonService.GetOwner(wheel) ~= player
        or delta ~= delta
        or delta <= 0
        or delta == math.huge
    then
        return false
    end
    if batch.State == "LOADING" then
        BlendService.Ready(player)
    end
    if batch.State ~= "READY" and batch.State ~= "BLENDING" then
        return false
    end
    batch.State = "BLENDING"
    local speed = Upgrades.BlendSpeed[deps.PlayerDataService.GetUpgrade(player, "BlendSpeed")].Value
    batch.Progress = math.min(Economy.RequiredProgress, batch.Progress + math.min(delta, 10) * speed)
    if batch.Progress >= Economy.RequiredProgress then
        batch.State = "COMPLETE"
        local result = makeResult(batch.Ingredients)
        batch.Result = result
        deps.PlayerDataService.IncrementStat(player, "SmoothiesMade")
        if result.Discovery then
            deps.PlayerDataService.RecordDiscovery(player, result.Discovery)
        end
    end
    publish(player)
    return true
end
function BlendService.Interact(player: Player, wheel: BasePart): boolean
    local now = os.clock()
    if now < (nextInteraction[player] or 0) then
        return false
    end
    nextInteraction[player] = now + 0.25
    return BlendService.AddProgress(player, wheel, 10)
end
function BlendService.GetCup(player: Player, requested: Instance?): Types.Smoothie?
    local cup = cups[player]
    if not cup then
        return nil
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if
        (requested and requested ~= cup.Tool)
        or not cup.Tool.Parent
        or (cup.Tool.Parent ~= backpack and cup.Tool.Parent ~= player.Character)
    then
        return nil
    end
    return copyResult(cup.Result)
end
function BlendService.ClearCup(player: Player)
    local cup = cups[player]
    cups[player] = nil
    if cup then
        cup.Tool:Destroy()
    end
    player:SetAttribute("HasSmoothie", false)
    player:SetAttribute("CurrentRecipeName", "")
end
function BlendService.ConsumeCup(player: Player): Types.Smoothie?
    local result = BlendService.GetCup(player)
    if result then
        BlendService.ClearCup(player)
    end
    return result
end
function BlendService.Dispense(player: Player, button: BasePart): (boolean, string?)
    local batch = batches[player]
    if not batch or batch.State ~= "COMPLETE" or not batch.Result then
        return false, "Not ready"
    end
    if
        deps.TycoonService.GetOwner(button) ~= player or not WorldUtil.Near(player, button, Economy.InteractionDistance)
    then
        return false, "Not your blender or too far"
    end
    if BlendService.GetCup(player) then
        return false, "Serve your existing cup first"
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return false, "No backpack"
    end
    BlendService.ClearCup(player)
    local template = ServerStorage:FindFirstChild("Smoothie")
    local tool: Tool
    if template and template:IsA("Tool") then
        tool = template:Clone()
    else
        tool = Instance.new("Tool")
    end
    tool.Name = "Smoothie"
    tool.CanBeDropped = false
    local handle = tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        local part = Instance.new("Part")
        part.Name = "Handle"
        part.Size = Vector3.new(1, 1.5, 1)
        part.Parent = tool
        handle = part
    end
    local cupHandle = handle :: BasePart
    cupHandle.Color = batch.Result.Color
    cupHandle.CanCollide = false
    cupHandle.Anchored = false
    tool:SetAttribute("CupId", HttpService:GenerateGUID(false))
    tool:SetAttribute("RecipeName", batch.Result.Discovery or "Custom Smoothie")
    tool:SetAttribute("IsFinished", true)
    cups[player] = { Tool = tool, Result = copyResult(batch.Result) }
    tool.Parent = backpack
    player:SetAttribute("HasSmoothie", true)
    player:SetAttribute("CurrentRecipeName", batch.Result.Discovery or "Custom Smoothie")
    batch.State = "DISPENSED"
    publish(player)
    task.defer(function()
        if batches[player] == batch then
            BlendService.Reset(player)
        end
    end)
    return true
end
function BlendService.RemovePlayer(player: Player)
    BlendService.ClearCup(player)
    batches[player] = nil
    nextInteraction[player] = nil
end
return BlendService
