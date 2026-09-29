--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local WorldUtil = require(script.Parent.WorldUtil)
local Slots = require(script.Parent.StashSlots)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local Service = {}

-- Match Farm's anchored-part reveal without depending on FarmService or its row state.
local function capture(root: Instance): { any }
    local saved: { any } = {}
    local objects = root:GetDescendants()
    table.insert(objects, root)
    for _, object in objects do
        if object:IsA("BasePart") then
            table.insert(saved, {
                Object = object,
                Frame = object.CFrame,
                Transparency = object.Transparency,
                Collide = object.CanCollide,
                Touch = object.CanTouch,
                Query = object.CanQuery,
            })
            object.Anchored = true
        elseif object:IsA("Decal") or object:IsA("Texture") then
            table.insert(saved, { Object = object, Transparency = object.Transparency })
        elseif
            object:IsA("LayerCollector")
            or object:IsA("ProximityPrompt")
            or object:IsA("ParticleEmitter")
            or object:IsA("Beam")
            or object:IsA("Trail")
            or object:IsA("Light")
        then
            table.insert(saved, { Object = object, Enabled = object.Enabled })
        end
    end
    return saved
end
local function show(saved: { any }, visible: boolean)
    for _, item in saved do
        local object = item.Object
        if item.Frame then
            object.Transparency = if visible then item.Transparency else 1
            object.CanCollide, object.CanTouch, object.CanQuery =
                visible and item.Collide, visible and item.Touch, visible and item.Query
        elseif item.Transparency then
            object.Transparency = if visible then item.Transparency else 1
        else
            object.Enabled = visible and item.Enabled
        end
    end
end

function Service.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot: Instance): (() -> ())?
        local row = Slots.Expansion(plot)
        local pad = row and row:FindFirstChild("PurchasePoint")
        if not row or not pad or not pad:IsA("BasePart") then
            return nil
        end
        local fixtures = services.TycoonService.GetFixtures(plot, "PlayerStash")
        if #fixtures ~= 1 then
            return nil
        end
        local resolved = Slots.Resolve(fixtures[1], row)
        for index = 6, 10 do
            if not resolved[index] then
                warn("[StashExpansion] Missing/ambiguous slot " .. index .. " in " .. row:GetFullName())
                return nil
            end
        end
        local base = row:FindFirstChild("base")
        if not base then
            warn("[StashExpansion] Missing base in " .. row:GetFullName())
            return nil
        end
        -- Only the purchased structure moves. PurchasePoint is a separate BasePart;
        -- unrelated decoration (such as shine) is not part of the reveal.
        local visual = capture(base)
        for index = 6, 10 do
            local object = row:FindFirstChild("Slot" .. index)
            assert(object) -- validated by the shared slot resolver above
            for _, item in capture(object) do
                table.insert(visual, item)
            end
        end
        local padAppearance = capture(pad)
        local motions: { any } = {}
        local connections: { RBXScriptConnection } = {}
        local generation, purchased, active = 0, false, true
        local session: any = nil
        local function stop()
            generation += 1
            for _, motion in motions do
                motion.Connection:Disconnect()
                motion.Tween:Cancel()
            end
            table.clear(motions)
            for _, item in visual do
                if item.Frame then
                    item.Object.CFrame = item.Frame
                end
            end
        end
        local function reset()
            stop()
            purchased = false
            row:SetAttribute("StashExpansionReady", false)
            show(visual, false)
            show(padAppearance, true)
            pad.CanTouch = true
            pad:SetAttribute("SecondStoragePad", true)
        end
        local function refresh()
            local owner = services.TycoonService.GetOwner(plot)
            local current = owner and services.TycoonService.GetSessionId(owner)
            if session ~= current then
                reset()
                session = current
            end
            local owned = owner ~= nil and services.TycoonService.GetUpgrade(owner, "SecondStorage") == 2
            if not owned then
                if purchased then
                    reset()
                end
                return
            end
            if purchased then
                return
            end
            purchased = true
            show(padAppearance, false)
            show(visual, true)
            -- Authored prompts also stay disabled until the reveal finishes.
            for _, object in row:GetDescendants() do
                if object:IsA("ProximityPrompt") then
                    object.Enabled = false
                end
            end
            local epoch, revealSession = generation, current
            local remaining = 0
            for _, item in visual do
                if item.Frame then
                    remaining += 1
                end
            end
            for _, item in visual do
                if item.Frame then
                    item.Object.CFrame = CFrame.new(0, -3.5, 0) * item.Frame
                    local tween = TweenService:Create(
                        item.Object,
                        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        { CFrame = item.Frame }
                    )
                    local connection = tween.Completed:Connect(function()
                        local currentOwner = services.TycoonService.GetOwner(plot)
                        if
                            not active
                            or epoch ~= generation
                            or not currentOwner
                            or services.TycoonService.GetSessionId(currentOwner) ~= revealSession
                        then
                            return
                        end
                        item.Object.CFrame = item.Frame
                        remaining -= 1
                        if remaining == 0 then
                            row:SetAttribute("StashExpansionReady", true)
                        end
                    end)
                    table.insert(motions, { Tween = tween, Connection = connection })
                    tween:Play()
                end
            end
        end
        reset()
        table.insert(connections, plot:GetAttributeChangedSignal("SecondStoragePurchased"):Connect(refresh))
        table.insert(connections, plot:GetAttributeChangedSignal("PlotSessionId"):Connect(refresh))
        table.insert(
            connections,
            pad.Touched:Connect(function(hit)
                if purchased or not active then
                    return
                end
                local ancestor = hit.Parent
                while ancestor and ancestor ~= workspace do
                    local player = if ancestor:IsA("Model") then Players:GetPlayerFromCharacter(ancestor) else nil
                    if player then
                        if
                            services.TycoonService.IsMember(player, plot)
                            and WorldUtil.Near(player, pad, Economy.InteractionDistance)
                        then
                            services.TycoonService.PurchaseSecondStorage(
                                player,
                                plot,
                                services.TycoonService.GetRequestContext(player)
                            )
                        end
                        return
                    end
                    ancestor = ancestor.Parent
                end
            end)
        )
        refresh()
        return function()
            active = false
            reset()
            for _, connection in connections do
                connection:Disconnect()
            end
            pad:SetAttribute("SecondStoragePad", nil)
        end
    end)
end
return Service
