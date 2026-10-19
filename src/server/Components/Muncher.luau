--!strict
local Players = game:GetService("Players")
local Reveal = require(script.Parent.MuncherReveal)
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.Muncher)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local Vacuum = require(script.Parent.Parent.Services.MuncherVacuum)
local Component = {}

function Component.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot)
        local warned: { [string]: boolean } = {}
        local input: BasePart? = nil
        local vacuumUpdate: ((number) -> ())? = nil
        local vacuumCleanup: (() -> ())? = nil
        local elapsed = 0
        local assembly: Instance? = nil
        local reveal: ((any) -> boolean)? = nil
        local restore: (() -> ())? = nil
        local pad: BasePart? = nil
        local padConnection: RBXScriptConnection? = nil
        local padAppearance: { [Instance]: any } = {}
        local function padVisibility(purchased: boolean)
            for object, saved in padAppearance do
                if object:IsA("BasePart") then
                    object.Transparency = if purchased then 1 else saved.Transparency
                    object.CanCollide = not purchased and saved.CanCollide
                    object.CanTouch = not purchased
                elseif object:IsA("Decal") then
                    object.Transparency = if purchased then 1 else saved.Transparency
                elseif object:IsA("Texture") then
                    object.Transparency = if purchased then 1 else saved.Transparency
                elseif object:IsA("LayerCollector") then
                    object.Enabled = not purchased and saved.Enabled
                elseif object:IsA("ProximityPrompt") then
                    object.Enabled = false -- Purchase uses the authored touch pad, like farm rows.
                end
            end
        end
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
            if zone ~= input then
                if vacuumCleanup then
                    vacuumCleanup()
                end
                vacuumUpdate, vacuumCleanup = nil, nil
                input = zone
                if zone then
                    zone.Anchored = true
                    zone.CanCollide = false
                    zone.CanTouch = false
                    zone.CanQuery = true
                    zone.Transparency = 1
                    for _, child in zone:GetDescendants() do
                        if child:IsA("ProximityPrompt") then
                            child:Destroy()
                        end
                    end
                    if muncher then
                        vacuumUpdate, vacuumCleanup = Vacuum.Bind(services, zone, muncher)
                    end
                end
            end
            local owner = services.TycoonService.GetOwner(plot)
            local snapshot = if owner then services.MuncherService.GetSnapshot(owner) else nil
            if muncher ~= assembly then
                if restore then
                    restore()
                end
                assembly, reveal, restore = muncher, nil, nil
                if muncher then
                    reveal, restore = Reveal.Bind(muncher)
                end
            end
            local candidatePad = muncher and muncher:FindFirstChild("PurchasePoint1")
            local nextPad = if candidatePad and candidatePad:IsA("BasePart") then candidatePad else nil
            if nextPad ~= pad then
                if padConnection then
                    padConnection:Disconnect()
                end
                pad, padConnection, padAppearance = nextPad, nil, {}
                if nextPad then
                    local objects = nextPad:GetDescendants()
                    table.insert(objects, nextPad)
                    for _, object in objects do
                        if object:IsA("BasePart") then
                            padAppearance[object] =
                                { Transparency = object.Transparency, CanCollide = object.CanCollide }
                        elseif object:IsA("Decal") or object:IsA("Texture") then
                            padAppearance[object] = { Transparency = object.Transparency }
                        elseif object:IsA("LayerCollector") then
                            padAppearance[object] = { Enabled = object.Enabled }
                        elseif object:IsA("ProximityPrompt") then
                            padAppearance[object] = {}
                        end
                    end
                    nextPad.Anchored = true
                    nextPad:SetAttribute("PurchaseCost", Config.PurchaseCost)
                    padConnection = nextPad.Touched:Connect(function(hit)
                        local ancestor: Instance? = hit.Parent
                        while ancestor and ancestor ~= workspace do
                            local actor = if ancestor:IsA("Model")
                                then Players:GetPlayerFromCharacter(ancestor)
                                else nil
                            if actor then
                                services.MuncherService.TryPurchase(
                                    actor,
                                    nextPad,
                                    services.TycoonService.GetRequestContext(actor)
                                )
                                local currentOwner = services.TycoonService.GetOwner(plot)
                                local current = if currentOwner
                                    then services.MuncherService.GetSnapshot(currentOwner)
                                    else nil
                                padVisibility(current ~= nil and current.Purchased == true)
                                return
                            end
                            ancestor = ancestor.Parent
                        end
                    end)
                else
                    warning("PurchasePoint1 BasePart")
                end
            end
            padVisibility(snapshot ~= nil and snapshot.Purchased == true)
            if reveal and reveal(snapshot) and owner and muncher then
                services.MuncherService.CompleteReveal(owner, muncher)
                snapshot = services.MuncherService.GetSnapshot(owner)
            end
            if
                snapshot
                and snapshot.Purchased
                and not snapshot.Active
                and workspace:GetServerTimeNow() > snapshot.ReadyAt + 3
                and not warned.RevealStalled
            then
                warned.RevealStalled = true
                warn(
                    "[Muncher] Reveal stalled at " .. plot:GetFullName() .. "; inspect authored assembly and InputZone"
                )
            end
            if muncher then
                local current = if owner then services.MuncherService.GetSnapshot(owner) else nil
                -- Publish the committed result before phase/sequence can start a client roll.
                for _, name in { "OutputRarity", "InputTier", "OutputId", "ResultKind" } do
                    muncher:SetAttribute(name, if current then current[name] else nil)
                end
                local attributes: { [string]: any } = {
                    Purchased = current ~= nil and current.Purchased == true,
                    Active = current ~= nil and current.Active == true,
                    Phase = if current then current.Phase else "Idle",
                    StartedAt = if current then current.StartedAt else 0,
                    AvailableAt = if current then current.AvailableAt else 0,
                }
                for name, value in attributes do
                    if muncher:GetAttribute(name) ~= value then
                        muncher:SetAttribute(name, value)
                    end
                end
                muncher:SetAttribute("Sequence", if current then current.Sequence else 0)
                -- Retire old buff projections on existing Studio models.
                muncher:SetAttribute("ActiveBuff", nil)
                muncher:SetAttribute("BuffExpiresAt", nil)
            end
        end
        refresh()
        local connection = RunService.Heartbeat:Connect(function(dt)
            -- Move the controlled assembly every frame; intake polling remains at 10 Hz.
            if reveal then
                local owner = services.TycoonService.GetOwner(plot)
                reveal(if owner then services.MuncherService.GetSnapshot(owner) else nil)
            end
            if vacuumUpdate then
                vacuumUpdate(dt)
            end
            elapsed += dt
            if elapsed >= Config.ScanInterval then
                elapsed = 0
                refresh()
            end
        end)
        return function()
            connection:Disconnect()
            if vacuumCleanup then
                vacuumCleanup()
            end
            if padConnection then
                padConnection:Disconnect()
            end
            padVisibility(false)
            if restore then
                restore()
            end
        end
    end)
end

return Component
