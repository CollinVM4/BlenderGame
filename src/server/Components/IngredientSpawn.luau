--!strict
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local IngredientSpawn = {}
local bound: { [Instance]: boolean } = {}

-- Both marker types share the same one-item lifecycle. The callback is output only.
function IngredientSpawn.Bind(services: any, tag: string, onSpawn: ((Instance, string) -> ())?)
    WorldUtil.BindTag(tag, function(station)
        if bound[station] then
            warn("[IngredientSpawn] Use only one spawn tag: " .. station:GetFullName())
            return nil
        end
        if not station:IsA("BasePart") then
            warn("[IngredientSpawn] Tag a BasePart: " .. station:GetFullName())
            return nil
        end
        local id = station:GetAttribute("IngredientId")
        if typeof(id) ~= "string" or not services.IngredientService.GetDefinition(id) then
            warn("[IngredientSpawn] Set a valid IngredientId: " .. station:GetFullName())
            return nil
        end
        local configuredSeconds = station:GetAttribute("RespawnSeconds")
        local seconds: number = 5
        if
            typeof(configuredSeconds) == "number"
            and configuredSeconds == configuredSeconds
            and configuredSeconds > 0
            and configuredSeconds < math.huge
        then
            seconds = configuredSeconds
        end
        local minSeconds = seconds
        local maxSeconds = seconds
        if onSpawn then
            local low = station:GetAttribute("MinRespawnSeconds")
            local high = station:GetAttribute("MaxRespawnSeconds")
            if
                typeof(low) == "number"
                and typeof(high) == "number"
                and low > 0
                and high >= low
                and high < math.huge
            then
                minSeconds = low
                maxSeconds = high
            end
        end

        bound[station] = true
        local stopped = false
        local active: Instance? = nil
        local pending: thread? = nil
        local itemConnections: { RBXScriptConnection } = {}
        local function disconnectItem()
            for _, connection in itemConnections do
                connection:Disconnect()
            end
            table.clear(itemConnections)
        end
        local function spawnItem()
            pending = nil
            if stopped or active or not station:IsDescendantOf(workspace) then
                return
            end
            local item = services.IngredientService.Spawn(
                id,
                station.CFrame * CFrame.new(0, station.Size.Y / 2 + 3, 0),
                nil,
                true
            )
            if not item then
                return
            end
            active = item
            local function removed(destroying: boolean)
                if stopped or active ~= item then
                    return
                end
                active = nil
                disconnectItem()
                -- Retire a reparented item so returning it cannot duplicate station stock.
                if not destroying then
                    item:Destroy()
                end
                pending = task.delay(minSeconds + math.random() * (maxSeconds - minSeconds), spawnItem)
            end
            table.insert(
                itemConnections,
                item.Destroying:Connect(function()
                    removed(true)
                end)
            )
            if onSpawn then
                onSpawn(station, id)
            end
            table.insert(
                itemConnections,
                item.AncestryChanged:Connect(function()
                    if not item:IsDescendantOf(workspace) then
                        removed(false)
                    end
                end)
            )
        end
        local stationConnection: RBXScriptConnection? = nil
        local function cleanup()
            if stopped then
                return
            end
            stopped = true
            bound[station] = nil
            if pending then
                task.cancel(pending)
                pending = nil
            end
            if stationConnection then
                stationConnection:Disconnect()
            end
            disconnectItem()
            local item = active
            active = nil
            if item then
                item:Destroy()
            end
        end
        stationConnection = station.Destroying:Connect(cleanup)
        spawnItem()
        return cleanup
    end)
end

function IngredientSpawn.Init(services: any)
    IngredientSpawn.Bind(services, "IngredientSpawn", nil)
end

return IngredientSpawn
