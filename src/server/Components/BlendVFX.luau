--!strict
-- Presentation only. BlendService owns acceptance, progress, color and reset.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local BlendVFX = {}
-- Legacy fallback in BlendVisualOrigin's local axes; never scales templates.
local IngredientSlotNames = { "IngredientSlot1", "IngredientSlot2", "IngredientSlot3" }
local IngredientOffsetRadius = 1.8 -- studs; fit to the jar's interior clearance
local IngredientVerticalSpread = 0.4 -- studs per local Y offset below
local IngredientArrivalDuration = 0.35 -- seconds; existing arrival timing
local IngredientOffsets = {
    Vector3.new(1, -0.4, 0.05),
    Vector3.new(-0.65, 0.15, 0.75),
    Vector3.new(-0.5, -0.2, -0.8),
    Vector3.new(0.55, -0.6, 0.7),
    Vector3.new(-0.95, 0.4, -0.1),
    Vector3.new(0.4, 0, -0.75),
}
-- Keep authored values across tag removal/re-entry; detached liquid is hidden.
-- Weak keys release the cache when a plot's liquid is destroyed and collected.
local liquidDefaults = setmetatable({} :: { [BasePart]: { Color: Color3, Transparency: number } }, { __mode = "k" })

-- Temporary lifecycle diagnostics; never print progress updates every frame.
local function diagnostic(message: string)
    if RunService:IsStudio() then
        print("[BlendVFX] " .. message)
    end
end

local function findLiquid(blender: Instance, visuals: Instance?): BasePart?
    local container = blender:FindFirstChild("Liquid")
    local nested = container and container:FindFirstChild("Liquid")
    if nested and nested:IsA("BasePart") then
        return nested
    end
    if container and container:IsA("BasePart") then
        return container
    end
    -- Imported models may nest the named liquid under Body/Glass/etc. Never
    -- select arbitrary geometry or an ingredient proxy as the smoothie surface.
    local found: BasePart? = nil
    for _, candidate in blender:GetDescendants() do
        if
            candidate:IsA("BasePart")
            and string.lower(candidate.Name) == "liquid"
            and not (visuals and candidate:IsDescendantOf(visuals))
        then
            if found then
                diagnostic("liquid ambiguous=true; multiple named Liquid parts")
                return nil
            end
            found = candidate
        end
    end
    return found
end

local function sanitize(proxy: Instance)
    local descendants = proxy:GetDescendants()
    table.insert(descendants, proxy)
    for _, child in descendants do
        for _, tag in CollectionService:GetTags(child) do
            CollectionService:RemoveTag(child, tag)
        end
        for attribute in child:GetAttributes() do
            child:SetAttribute(attribute, nil)
        end
        -- Keep geometry and appearance only, before anything enters Workspace.
        if child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            child.CanTouch = false
            child.CanQuery = false
        elseif
            not (
                child:IsA("Model")
                or child:IsA("Folder")
                or child:IsA("DataModelMesh")
                or child:IsA("Decal")
                or child:IsA("Texture")
                or child:IsA("SurfaceAppearance")
                or child:IsA("Attachment")
            )
        then
            child:Destroy()
        end
    end
end

function BlendVFX.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot)
        local blender = if plot.Name == "Blender" then plot else plot:FindFirstChild("Blender")
        if not blender then
            return nil
        end
        diagnostic("bound plot=" .. plot.Name)
        diagnostic("bound blender path=" .. blender:GetFullName())
        for _, child in blender:GetChildren() do
            diagnostic("child name=" .. child.Name .. " class=" .. child.ClassName)
        end
        local folder = blender:FindFirstChild("IngredientVisuals")
        diagnostic("IngredientVisuals found=" .. tostring(folder ~= nil and folder:IsA("Folder")))
        local createdFolder = false
        if not folder then
            local fallback = Instance.new("Folder")
            fallback.Name = "IngredientVisuals"
            fallback.Parent = blender
            folder = fallback
            createdFolder = true
        elseif not folder:IsA("Folder") then
            warn("[BlendVFX] Expected Blender.IngredientVisuals Folder; ingredient visuals skipped")
            folder = nil
        end
        local visuals = folder
        local origin = blender:FindFirstChild("BlendVisualOrigin")
        diagnostic("BlendVisualOrigin found=" .. tostring(origin ~= nil))
        local liquid: BasePart? = nil
        local originalColor = Color3.new(1, 1, 1)
        local finishedTransparency = 0
        local function discoverLiquid()
            local container = blender:FindFirstChild("Liquid")
            local nested = container and container:FindFirstChild("Liquid")
            local count = 0
            for _, candidate in blender:GetDescendants() do
                if candidate:IsA("BasePart") and string.find(string.lower(candidate.Name), "liquid", 1, true) then
                    count += 1
                end
            end
            diagnostic("liquid container direct=" .. tostring(container ~= nil))
            diagnostic("liquid nested part=" .. tostring(nested ~= nil and nested:IsA("BasePart")))
            diagnostic("liquid descendant candidates=" .. tostring(count))
            liquid = findLiquid(blender, blender:FindFirstChild("IngredientVisuals"))
            diagnostic(
                "liquid found="
                    .. tostring(liquid ~= nil)
                    .. " path="
                    .. (if liquid then liquid:GetFullName() else "<none>")
            )
            if liquid then
                diagnostic(
                    "liquid anchored=" .. tostring(liquid.Anchored) .. " archivable=" .. tostring(liquid.Archivable)
                )
                if not liquidDefaults[liquid] then
                    liquidDefaults[liquid] = { Color = liquid.Color, Transparency = liquid.Transparency }
                end
                local defaults = liquidDefaults[liquid]
                originalColor = defaults.Color
                finishedTransparency = defaults.Transparency
            end
        end
        discoverLiquid()
        if not origin or not (origin:IsA("BasePart") or origin:IsA("Attachment")) then
            warn("[BlendVFX] Expected Blender.BlendVisualOrigin BasePart or Attachment; ingredient visuals skipped")
        end
        local emitters: { ParticleEmitter } = {}
        local seen: { [Instance]: boolean } = {}
        local function isPuffEmitter(emitter: ParticleEmitter): boolean
            return string.sub(string.lower(emitter.Name), 1, 4) == "puff"
        end
        local function collectEmitters(root: Instance?)
            if not root then
                return
            end
            local candidates = root:GetDescendants()
            table.insert(candidates, root)
            for _, candidate in candidates do
                if candidate:IsA("ParticleEmitter") and isPuffEmitter(candidate) and not seen[candidate] then
                    seen[candidate] = true
                    table.insert(emitters, candidate)
                end
            end
        end
        collectEmitters(origin)
        diagnostic("emitters found=" .. tostring(#emitters))
        local owner: Player? = nil
        local ownerConnections: { RBXScriptConnection } = {}
        local tweens: { Tween } = {}
        local displayed: { [number]: boolean } = {}
        local ownedVisuals: { Instance } = {}
        local cloudActive = false
        local phase = ""
        local lastProgress = 0
        local lastIncreaseAt = 0
        local activityTimer: thread? = nil
        local activityGrace = 0.35
        local function cloud(enabled: boolean)
            cloudActive = enabled
            for _, emitter in emitters do
                emitter.Enabled = enabled
                if not enabled then
                    emitter:Clear() -- Immediate completion reveal, including long-lived particles.
                end
            end
        end
        local function stopActivity()
            if activityTimer then
                task.cancel(activityTimer)
                activityTimer = nil
            end
            cloud(false)
        end
        local function expireActivity()
            activityTimer = nil
            local remaining = activityGrace - (os.clock() - lastIncreaseAt)
            if remaining > 0 then
                activityTimer = task.delay(remaining, expireActivity)
            else
                if cloudActive then
                    diagnostic("blend visual idle")
                end
                cloud(false)
            end
        end
        local function clearIngredients()
            for _, tween in tweens do
                tween:Cancel()
            end
            table.clear(tweens)
            table.clear(displayed)
            for _, child in ownedVisuals do
                child:Destroy()
            end
            table.clear(ownedVisuals)
        end
        local function reset()
            if phase ~= "reset" then
                diagnostic("reset")
            end
            phase = "reset"
            clearIngredients()
            stopActivity()
            lastProgress = 0
            if liquid then
                liquid.Color = originalColor
                liquid.Transparency = 1
            end
        end
        local function addIngredient(id: string, index: number, from: CFrame?)
            if displayed[index] or not origin or not visuals then
                return
            end
            local at: CFrame
            if origin:IsA("BasePart") then
                at = origin.CFrame
            elseif origin:IsA("Attachment") then
                at = origin.WorldCFrame
            else
                return
            end
            local proxy = services.IngredientService.CreateVisual(id)
            diagnostic("visual source found=" .. tostring(proxy ~= nil))
            if not proxy then
                return
            end
            sanitize(proxy)
            local physical = proxy :: any
            -- Resolve the complete authored set at placement time. Exact direct
            -- Blender children take precedence; origin children are also supported.
            local slots: { Attachment } = {}
            for _, name in IngredientSlotNames do
                local candidate = blender:FindFirstChild(name) or origin:FindFirstChild(name)
                if candidate and candidate:IsA("Attachment") then
                    table.insert(slots, candidate)
                end
            end
            local target: CFrame
            if index >= 1 and index <= #IngredientSlotNames and #slots == #IngredientSlotNames then
                target = slots[index].WorldCFrame
            else
                if index > #IngredientSlotNames and RunService:IsStudio() then
                    warn(
                        string.format(
                            "[BlendVFX] Unexpected ingredient index=%d plot=%s; expected exactly 3, using presentation offset fallback",
                            index,
                            plot:GetFullName()
                        )
                    )
                end
                -- An incomplete set falls back as a whole, preserving legacy layout.
                local offset = IngredientOffsets[(index - 1) % #IngredientOffsets + 1]
                local localOffset = Vector3.new(
                    offset.X * IngredientOffsetRadius,
                    offset.Y * IngredientVerticalSpread,
                    offset.Z * IngredientOffsetRadius
                )
                target = at * CFrame.new(localOffset.X, localOffset.Y, localOffset.Z)
            end
            local start = from or target
            physical:PivotTo(start)
            proxy.Name = "BlendIngredientVisual"
            proxy.Parent = visuals
            table.insert(ownedVisuals, proxy)
            diagnostic("visual created=" .. proxy:GetFullName())
            displayed[index] = true
            local parts = proxy:GetDescendants()
            table.insert(parts, proxy)
            for _, part in parts do
                if part:IsA("BasePart") and from then
                    local tween = TweenService:Create(
                        part,
                        TweenInfo.new(IngredientArrivalDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        {
                            CFrame = target * start:ToObjectSpace(part.CFrame),
                        }
                    )
                    table.insert(tweens, tween)
                    tween:Play()
                end
            end
        end
        local function refresh()
            local player = owner
            -- Snapshot avoids observing a half-published state/progress attribute pair.
            local batch = player and services.BlendService.GetSnapshot(player)
            if not batch or batch.State == "EMPTY" or batch.State == "DISPENSED" then
                reset()
                return
            end
            local complete = batch.State == "COMPLETE"
            local active = batch.Progress > 0
            if not active and not complete then
                phase = "loaded"
                if liquid then
                    liquid.Color = originalColor
                    liquid.Transparency = 1
                end
                return
            end
            if complete then
                if phase ~= "complete" then
                    diagnostic("complete")
                end
                phase = "complete"
            else
                phase = "blending"
            end
            clearIngredients()
            if complete then
                stopActivity()
            elseif batch.Progress > lastProgress then
                lastIncreaseAt = os.clock()
                if not cloudActive then
                    diagnostic("blend active progress=" .. tostring(batch.Progress))
                end
                cloud(true)
                if not activityTimer then
                    activityTimer = task.delay(activityGrace, expireActivity)
                end
            end
            lastProgress = batch.Progress
            if liquid and player then
                local color = if batch.Result then batch.Result.Color else player:GetAttribute("BlendColor")
                if typeof(color) == "Color3" then
                    liquid.Color = color
                end
                local progress = if complete then 1 else math.clamp(batch.Progress / Economy.RequiredProgress, 0, 1)
                -- Preserve the authored endpoint; zero progress is fully hidden.
                liquid.Transparency = if progress == 1
                    then finishedTransparency
                    else 1 + (finishedTransparency - 1) * progress
            end
        end
        local function disconnectOwner()
            for _, connection in ownerConnections do
                connection:Disconnect()
            end
            table.clear(ownerConnections)
        end
        local function bindOwner()
            disconnectOwner()
            reset()
            owner = if plot:GetAttribute("OwnerUserId") ~= nil then services.TycoonService.GetOwner(plot) else nil
            local player = owner
            if player then
                for _, attribute in { "BlendProgress", "BlendState", "BlendColor" } do
                    table.insert(ownerConnections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
                end
                local batch = services.BlendService.GetSnapshot(player)
                if batch and (batch.State == "LOADING" or batch.State == "READY") and batch.Progress == 0 then
                    for index, id in batch.Ingredients do
                        addIngredient(id, index, nil)
                    end
                end
            end
            refresh()
        end
        local accepted = services.BlendService.ObserveIngredientAccepted(function(player, id, at, index)
            diagnostic("accepted ingredient=" .. id)
            if player ~= owner then
                diagnostic("accepted visual skipped owner mismatch plot=" .. plot.Name)
                return
            end
            local batch = services.BlendService.GetSnapshot(player)
            if
                batch
                and (batch.State == "LOADING" or batch.State == "READY")
                and batch.Progress == 0
                and batch.Ingredients[index] == id
            then
                addIngredient(id, index, at)
            else
                diagnostic(
                    "accepted visual skipped state="
                        .. tostring(batch and batch.State)
                        .. " progress="
                        .. tostring(batch and batch.Progress)
                )
            end
        end)
        diagnostic("ObserveIngredientAccepted connected=true")
        local alive = true
        local function liquidHierarchyChanged(object: Instance)
            if string.lower(object.Name) ~= "liquid" then
                return
            end
            diagnostic("liquid hierarchy changed path=" .. object:GetFullName())
            task.defer(function()
                if alive then
                    discoverLiquid()
                    refresh()
                end
            end)
        end
        local liquidAdded = blender.DescendantAdded:Connect(liquidHierarchyChanged)
        local liquidRemoving = blender.DescendantRemoving:Connect(liquidHierarchyChanged)
        local ownership = plot:GetAttributeChangedSignal("OwnerUserId"):Connect(bindOwner)
        local leaving = Players.PlayerRemoving:Connect(function(player)
            if player == owner then
                disconnectOwner()
                owner = nil
                reset()
            end
        end)
        bindOwner()
        return function()
            alive = false
            liquidAdded:Disconnect()
            liquidRemoving:Disconnect()
            accepted:Disconnect()
            ownership:Disconnect()
            leaving:Disconnect()
            disconnectOwner()
            owner = nil
            reset()
            if createdFolder and visuals and #visuals:GetChildren() == 0 then
                visuals:Destroy()
            end
        end
    end)
end

return BlendVFX
