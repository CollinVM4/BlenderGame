--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Economy = require(Shared.Constants.Economy)
local Recipes = require(Shared.Constants.Recipes)
local Types = require(Shared.Types)
local WorldUtil = require(script.Parent.WorldUtil)
local Film = require(script.Parent.FilmingUtil)
local BlendService = {}
local deps: any
local ingredientAccepted = Instance.new("BindableEvent")
local RunService = game:GetService("RunService")
local observers: { RBXScriptConnection } = {}
local nextNotificationToken = 0
local function observerCount(): number
    for index = #observers, 1, -1 do
        if not observers[index].Connected then
            table.remove(observers, index)
        end
    end
    return #observers
end
local function diagnostic(message: string)
    if RunService:IsStudio() then
        print("[BlendService] " .. message)
    end
end

-- One canonical color calculation for both the developing liquid and final cup.
local function batchColor(ids: { string }): Color3?
    if #ids == 0 then
        return nil
    end
    local sum = Vector3.zero
    for _, id in ids do
        local color = deps.IngredientService.GetDefinition(id).BlendColor
        sum += Vector3.new(color.R, color.G, color.B)
    end
    sum /= #ids
    return Color3.new(sum.X, sum.Y, sum.Z)
end

type Batch = {
    NotificationToken: number,
    State: Types.BlendState,
    Ingredients: { string },
    Progress: number,
    Result: Types.Smoothie?,
    NextProgressPresentationAt: number,
}
local batches: { [Player]: Batch } = {}
local cups: { [Player]: { Tool: Tool, Result: Types.Smoothie } } = {}

function BlendService.ObserveIngredientAccepted(callback: (Player, string, CFrame, number) -> ()): RBXScriptConnection
    local connection = ingredientAccepted.Event:Connect(function(player, id, at, index, token)
        -- BindableEvents COPY tables. Compare a scalar token, never table identity.
        local batch = batches[player]
        if batch and batch.NotificationToken == token then
            callback(player, id, at, index)
        else
            diagnostic("accepted notify skipped stale batch ingredient=" .. id)
        end
    end)
    table.insert(observers, connection)
    diagnostic("ingredient observer connected observers=" .. tostring(observerCount()))
    return connection
end

local function publish(player: Player)
    local batch = batches[player]
    player:SetAttribute("BlendColor", if batch.Result then batch.Result.Color else batchColor(batch.Ingredients))
    player:SetAttribute("BlendState", batch.State)
    player:SetAttribute("BlendProgress", batch.Progress)
    player:SetAttribute("BlendIngredientCount", #batch.Ingredients)
end
local function copyResult(result: Types.Smoothie): Types.Smoothie
    return {
        BlendId = result.BlendId,
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
    nextNotificationToken += 1
    batches[player] = {
        NotificationToken = nextNotificationToken,
        State = "EMPTY",
        Ingredients = {},
        Progress = 0,
        Result = nil,
        NextProgressPresentationAt = 0,
    }
    publish(player)
    Film.Log("Blend", "reset")
end
function BlendService.GetSnapshot(player: Player): {
    State: Types.BlendState,
    Ingredients: { string },
    Progress: number,
    Result: Types.Smoothie?,
}?
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
        or (record.Owner ~= nil and record.Owner ~= player)
        or (record.Owner == nil and not record.Claimable)
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
    local acceptedAt = part.CFrame
    local id = deps.IngredientService.Consume(object)
    if not id then
        return false
    end
    table.insert(batch.Ingredients, id)
    Film.Log("Blend", string.format("%s accepted (%d/3)", id, #batch.Ingredients))
    batch.State = if #batch.Ingredients == Economy.MaxIngredients then "READY" else "LOADING"
    publish(player)
    Film.Log("Blend", batch.State)
    diagnostic("accepted notify ingredient=" .. id .. " observers=" .. tostring(observerCount()))
    ingredientAccepted:Fire(player, id, acceptedAt, #batch.Ingredients, batch.NotificationToken)
    return true
end
function BlendService.Ready(player: Player): boolean
    local batch = batches[player]
    if not batch or #batch.Ingredients == 0 or (batch.State ~= "LOADING" and batch.State ~= "READY") then
        return false
    end
    batch.State = "READY"
    publish(player)
    Film.Log("Blend", "READY")
    return true
end
local function makeResult(ids: { string }): Types.Smoothie
    local tags = {}
    for _, id in ids do
        local definition = deps.IngredientService.GetDefinition(id)
        for _, tag in definition.Tags do
            if not table.find(tags, tag) then
                table.insert(tags, tag)
            end
        end
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
    return {
        BlendId = HttpService:GenerateGUID(false),
        Ingredients = table.clone(ids),
        Tags = tags,
        Color = batchColor(ids) :: Color3,
        Discovery = discovery,
    }
end
-- Server Heartbeat reports measured physical spin. No progress remote exists.
function BlendService.AddProgress(player: Player, wheel: BasePart, delta: number): boolean
    local batch = batches[player]
    if
        not batch
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
    if batch.State == "READY" then
        batch.State = "BLENDING"
        publish(player)
        Film.Emit(player, "BlendStarted", { IngredientIds = table.clone(batch.Ingredients) })
        Film.Log("Blend", "BLENDING")
    end
    local oldProgress = batch.Progress
    batch.Progress = math.min(Economy.RequiredProgress, batch.Progress + delta)
    local now = os.clock()
    if
        batch.Progress > oldProgress
        and (now >= batch.NextProgressPresentationAt or batch.Progress >= Economy.RequiredProgress)
    then
        batch.NextProgressPresentationAt = now + 0.1
        Film.Emit(player, "BlendProgressChanged", { Progress = batch.Progress })
    end
    if math.floor(oldProgress / 10) ~= math.floor(batch.Progress / 10) then
        Film.Log("Blend", string.format("progress %.0f", batch.Progress))
    end
    if batch.Progress >= Economy.RequiredProgress then
        batch.State = "COMPLETE"
        local result = makeResult(batch.Ingredients)
        batch.Result = result
        Film.Emit(player, "BlendCompleted", {
            BlendId = result.BlendId,
            Color = result.Color,
            IngredientIds = table.clone(result.Ingredients),
            RecipeId = result.Discovery,
        })
        Film.Log(
            "Blend",
            string.format("COMPLETE color=(%.3f,%.3f,%.3f)", result.Color.R, result.Color.G, result.Color.B)
        )
        deps.PlayerDataService.IncrementStat(player, "SmoothiesMade")
        if result.Discovery then
            deps.PlayerDataService.RecordDiscovery(player, result.Discovery)
        end
    end
    publish(player)
    return true
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
        deps.TycoonService.GetOwner(button) ~= player
        or not WorldUtil.Near(player, button, Economy.InteractionDistance)
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
    tool:SetAttribute("BlendId", batch.Result.BlendId)
    tool:SetAttribute("RecipeName", batch.Result.Discovery or "Custom Smoothie")
    tool:SetAttribute("IsFinished", true)
    cups[player] = { Tool = tool, Result = copyResult(batch.Result) }
    tool.Parent = backpack
    player:SetAttribute("HasSmoothie", true)
    player:SetAttribute("CurrentRecipeName", batch.Result.Discovery or "Custom Smoothie")
    Film.Emit(player, "SmoothieDispensed", { BlendId = batch.Result.BlendId, Color = batch.Result.Color, Cup = tool })
    Film.Log("Blend", "DISPENSED blend=" .. tostring(batch.Result.BlendId))
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
end
return require(script.Parent.StudioServices).Wrap("BlendService", BlendService)
