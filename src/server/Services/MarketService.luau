--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Definitions = require(Shared.Constants.Ingredients)
local Economy = require(Shared.Constants.Economy)
local WorldUtil = require(script.Parent.WorldUtil)
local MarketService = {}
local deps: any
local pedestals: { [BasePart]: { Item: Instance?, RespawnAt: number } } = {}
function MarketService.Init(services)
    deps = services
end
function MarketService.SelectIngredient(): string
    local total = 0
    for _, weight in Economy.RarityWeights do
        total += weight
    end
    local roll = math.random() * total
    local rarity = "Common"
    for name, weight in Economy.RarityWeights do
        roll -= weight
        if roll <= 0 then
            rarity = name
            break
        end
    end
    local candidates = {}
    for id, definition in Definitions do
        if definition.Rarity == rarity then
            table.insert(candidates, id)
        end
    end
    return candidates[math.random(1, #candidates)]
end
function MarketService.Register(pedestal: BasePart)
    if not pedestals[pedestal] then
        pedestals[pedestal] = { Item = nil, RespawnAt = 0 }
    end
end
function MarketService.Unregister(pedestal: BasePart)
    local state = pedestals[pedestal]
    pedestals[pedestal] = nil
    if state and state.Item then
        deps.IngredientService.Consume(state.Item)
    end
end
function MarketService.Step()
    local now = os.clock()
    for pedestal, state in pedestals do
        if state.Item and not deps.IngredientService.GetRecord(state.Item) then
            state.Item = nil
            state.RespawnAt = now + Economy.MarketRespawnSeconds
            pedestal:SetAttribute("StockIngredientId", nil)
        end
        if pedestal:IsDescendantOf(workspace) and not state.Item and now >= state.RespawnAt then
            local id = MarketService.SelectIngredient()
            state.Item = deps.IngredientService.Spawn(
                id,
                pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + 1, 0),
                nil,
                false
            )
            if state.Item then
                local parts = state.Item:GetDescendants()
                table.insert(parts, state.Item)
                for _, part in parts do
                    if part:IsA("BasePart") then
                        part.Anchored = true
                    end
                end
                pedestal:SetAttribute("StockIngredientId", id)
            else
                state.RespawnAt = now + Economy.MarketRespawnSeconds
            end
        end
    end
end
function MarketService.Claim(player: Player, pedestal: BasePart): boolean
    local state = pedestals[pedestal]
    if not state or not state.Item or not WorldUtil.Near(player, pedestal, Economy.InteractionDistance) then
        return false
    end
    local record = deps.IngredientService.GetRecord(state.Item)
    if not record or not deps.InventoryService.AddUnit(player, record.Id) then
        return false
    end
    deps.IngredientService.Consume(state.Item)
    state.Item = nil
    state.RespawnAt = os.clock() + Economy.MarketRespawnSeconds
    pedestal:SetAttribute("StockIngredientId", nil)
    return true
end
-- Server-only drop boundary for future ant defeat handlers.
function MarketService.SpawnDrop(at: CFrame, id: string?): Instance?
    return deps.IngredientService.Spawn(id or MarketService.SelectIngredient(), at, nil)
end
return require(script.Parent.StudioServices).Wrap("MarketService", MarketService)
