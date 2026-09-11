--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Constants.Economy)
local WorldUtil = require(script.Parent.WorldUtil)
local MarketService = {}
local CollectionService = game:GetService("CollectionService")
local deps: any
local pedestals: { [BasePart]: { Item: Instance?, RespawnAt: number, Id: string, Seconds: number } } = {}
function MarketService.Init(services)
    deps = services
end
function MarketService.Register(pedestal: BasePart)
    if
        CollectionService:HasTag(pedestal, "IngredientSpawn")
        or CollectionService:HasTag(pedestal, "AnnouncedIngredientSpawn")
    then
        warn("[MarketService] Use only one spawn tag: " .. pedestal:GetFullName())
        return
    end
    if not pedestals[pedestal] then
        local id = pedestal:GetAttribute("IngredientId")
        if typeof(id) ~= "string" or not deps.IngredientService.GetDefinition(id) then
            warn("[MarketService] Set an explicit valid IngredientId: " .. pedestal:GetFullName())
            return
        end
        local seconds = pedestal:GetAttribute("RespawnSeconds")
        if typeof(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 or seconds == math.huge then
            seconds = Economy.MarketRespawnSeconds
        end
        pedestals[pedestal] = { Item = nil, RespawnAt = 0, Id = id, Seconds = seconds :: number }
    end
end
function MarketService.Unregister(pedestal: BasePart)
    local state = pedestals[pedestal]
    pedestals[pedestal] = nil
    pedestal:SetAttribute("StockIngredientId", nil)
    if state and state.Item then
        state.Item:Destroy()
    end
end
function MarketService.Step()
    local now = os.clock()
    for pedestal, state in pedestals do
        if state.Item and not deps.IngredientService.GetRecord(state.Item) then
            -- Retire stock moved out of Workspace before allowing a replacement.
            state.Item:Destroy()
            state.Item = nil
            state.RespawnAt = now + state.Seconds
            pedestal:SetAttribute("StockIngredientId", nil)
        end
        if pedestal:IsDescendantOf(workspace) and not state.Item and now >= state.RespawnAt then
            local id = state.Id
            state.Item =
                deps.IngredientService.Spawn(id, pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2 + 1, 0), nil, true)
            if state.Item then
                pedestal:SetAttribute("StockIngredientId", id)
            else
                state.RespawnAt = now + state.Seconds
            end
        end
    end
end
function MarketService.Claim(player: Player, pedestal: BasePart): boolean
    local state = pedestals[pedestal]
    if not state or not state.Item or not WorldUtil.Near(player, pedestal, Economy.InteractionDistance) then
        return false
    end
    if not deps.InventoryService.CarryWorldItem(player, state.Item) then
        return false
    end
    state.Item = nil
    state.RespawnAt = os.clock() + state.Seconds
    pedestal:SetAttribute("StockIngredientId", nil)
    return true
end
-- Server-only drop boundary for future ant defeat handlers.
function MarketService.SpawnDrop(at: CFrame, id: string): Instance?
    return deps.IngredientService.Spawn(id, at, nil)
end
return require(script.Parent.StudioServices).Wrap("MarketService", MarketService)
