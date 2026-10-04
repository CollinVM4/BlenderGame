--!strict
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Presentation = require(script.Parent.MuncherPresentation)
local Component = {}

function Component.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot)
        local warned: { [string]: boolean } = {}
        local input: BasePart? = nil
        local display: (BasePart | Attachment)? = nil
        local gui: BillboardGui? = nil
        local update: ((any, boolean?) -> ())? = nil
        local elapsed = 0
        local function warning(name: string)
            if not warned[name] then
                warned[name] = true
                warn("[Muncher] " .. plot:GetFullName() .. " missing " .. name)
            end
        end
        local function refresh()
            local muncher = plot:FindFirstChild("Muncher")
            if not muncher then
                warning("Muncher")
            end
            local candidate = muncher and muncher:FindFirstChild("InputZone")
            local zone = if candidate and candidate:IsA("BasePart") then candidate else nil
            if not zone then
                warning("InputZone BasePart")
            end
            local mouth = Presentation.Marker(muncher and muncher:FindFirstChild("MouthOrigin"))
            if not mouth then
                warning("MouthOrigin")
            end
            local origin = Presentation.Marker(muncher and muncher:FindFirstChild("DisplayOrigin"))
            if not origin then
                warning("DisplayOrigin")
            end
            if origin ~= display then
                if gui then
                    gui:Destroy()
                end
                display, gui, update = origin, nil, nil
                if origin then
                    gui, update = Presentation.Display(origin)
                end
            end
            local owner = services.TycoonService.GetOwner(plot)
            local function publish(consumed: boolean?)
                if update then
                    update(if owner then services.MuncherService.GetSnapshot(owner) else nil, consumed)
                end
            end
            if zone ~= input then
                input = zone
                if zone then
                    zone.Anchored = true
                    zone.CanCollide = false
                    zone.CanTouch = false
                    zone.CanQuery = true
                    zone.Transparency = 1
                end
            end
            if zone then
                -- Remove legacy/authored intake prompts without touching Visual artwork.
                for _, child in zone:GetDescendants() do
                    if child:IsA("ProximityPrompt") then
                        child:Destroy()
                    end
                end
            end
            publish() -- Prime the display before any accepted feeds (including completion).
            if owner and zone then
                local seen: { [Instance]: boolean } = {}
                for _, part in workspace:GetPartsInPart(zone) do
                    local item = services.IngredientService.Resolve(part)
                    if item and not seen[item] then
                        seen[item] = true
                        local record = services.IngredientService.GetRecord(item)
                        local actor = if record and record.Owner then record.Owner else owner
                        local accepted, id, at = services.MuncherService.TryFeed(actor, zone, item, nil)
                        if accepted then
                            publish(true)
                            task.spawn(function()
                                local ok = pcall(Presentation.Feed, services, id, at, mouth)
                                if not ok then
                                    warning("feed feedback unavailable")
                                end
                            end)
                        end
                    end
                end
            end
            publish() -- Also clears expired buffs on server time, including idle plots.
        end
        refresh()
        local connection = RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            if elapsed >= Config.ScanInterval then
                elapsed = 0
                refresh()
            end
        end)
        return function()
            connection:Disconnect()
            if gui then
                gui:Destroy()
            end
        end
    end)
end

return Component
