--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Targets = require(game:GetService("ReplicatedStorage").Shared.TutorialTargets)
local Controller = {}
local DEBUG_TUTORIAL_GLEAM = false
local debugSignature = ""
local spawnTarget: ObjectValue? = nil
local spawnTargetConnection: RBXScriptConnection? = nil
local player = Players.LocalPlayer
local initialized = false
local stopped = false
local removingCharacter: Model? = nil
local connections: { RBXScriptConnection } = {}
local highlights: { Highlight } = {}
local tweens: { Tween } = {}
local current: { Instance } = {}
local activeClaimHintPlot: Instance? = nil
local activeClaimHintTargets: { Instance } = {}
local glassProxy: UnionOperation? = nil
local glassSource: UnionOperation? = nil
local failedGlassSource: UnionOperation? = nil
local targetConnections: { RBXScriptConnection } = {}
local function clearClaimPin()
    activeClaimHintPlot = nil
    table.clear(activeClaimHintTargets)
end
local function claimAvailable(plot: Instance?): boolean
    return plot ~= nil and plot:IsDescendantOf(workspace) and plot:GetAttribute("PlotSessionId") == nil
end
local function clear()
    for _, tween in tweens do
        tween:Cancel()
    end
    for _, highlight in highlights do
        highlight:Destroy()
    end
    for _, connection in targetConnections do
        connection:Disconnect()
    end
    table.clear(targetConnections)
    if glassProxy then
        glassProxy:Destroy()
        glassProxy = nil
    end
    glassSource = nil
    table.clear(tweens)
    table.clear(highlights)
    table.clear(current)
end
local function plotFor(stage: string): Instance?
    if stage == "ClaimPlot" then
        local target = player:FindFirstChild("TutorialSpawnTarget")
        local intended = if target and target:IsA("ObjectValue") then target.Value else nil
        if intended and claimAvailable(intended) then
            if activeClaimHintPlot and activeClaimHintPlot ~= intended then
                clearClaimPin()
            end
            return intended
        end
        if claimAvailable(activeClaimHintPlot) then
            return activeClaimHintPlot
        end
        clearClaimPin()
        return nil
    end
    local id = player:GetAttribute("PlotSessionId")
    if id then
        for _, plot in CollectionService:GetTagged("PlayerPlot") do
            if plot:GetAttribute("PlotSessionId") == id then
                return plot
            end
        end
    end
    return nil
end
local function debugging(): boolean
    return DEBUG_TUTORIAL_GLEAM or player:GetAttribute("DebugTutorialGleam") == true
end
local function describe(object: Instance?): string
    return if object then object:GetFullName() .. " class=" .. object.ClassName else "nil"
end
local function renderDetails(object: Instance): string
    local lines = {
        "target=" .. describe(object) .. " parent=" .. describe(object.Parent) .. " inWorkspace=" .. tostring(
            object:IsDescendantOf(workspace)
        ),
    }
    local parts = object:GetDescendants()
    table.insert(parts, 1, object)
    for _, part in parts do
        if part:IsA("BasePart") then
            table.insert(
                lines,
                "part="
                    .. describe(part)
                    .. " Transparency="
                    .. tostring(part.Transparency)
                    .. " LocalTransparencyModifier="
                    .. tostring(part.LocalTransparencyModifier)
                    .. " Material="
                    .. tostring(part.Material)
                    .. " Size="
                    .. tostring(part.Size)
            )
        end
    end
    return table.concat(lines, "\n")
end
local function diagnose(stage: any, plot: Instance?, targets: { Instance })
    if not debugging() then
        debugSignature = ""
        return
    end
    local lines = {
        "stage="
            .. tostring(stage)
            .. " hintReady="
            .. tostring(player:GetAttribute("TutorialHintReady"))
            .. " active="
            .. tostring(player:GetAttribute("TutorialActive")),
        "plot=" .. describe(plot),
    }
    local slot = player:GetAttribute("TutorialStashSlot")
    local roots: { Instance } = if type(stage) == "string"
        then Targets.GetRoots(plot, stage, if type(slot) == "number" then slot else nil)
        else {}
    local keys = table.clone(lines)
    table.insert(keys, "adornableTargets=" .. tostring(#targets))
    for _, root in roots do
        table.insert(keys, describe(root))
    end
    local signature = table.concat(keys, "\n")
    if signature == debugSignature then
        return
    end
    debugSignature = signature
    for _, root in roots do
        table.insert(lines, renderDetails(root))
    end
    if #roots == 0 and type(stage) == "string" then
        table.insert(
            lines,
            if stage == "ClaimPlot" and not plot
                then "ClaimPlot: TutorialSpawnTarget=nil"
                elseif stage == "Blender" then "Blender: Glass target missing"
                else stage .. ": authored target missing"
        )
    elseif #targets == 0 then
        table.insert(
            lines,
            "No adornable target (hint inactive, character unavailable, or assembly has no visible parts)"
        )
    end
    print("[TutorialGleam] " .. table.concat(lines, "\n"))
end
-- This workaround is deliberately exclusive to the authored Blender.Glass union.
local function createGlassProxy(source: UnionOperation): UnionOperation?
    local clone = source:Clone()
    if not clone then
        return nil
    end
    for _, child in clone:GetChildren() do
        child:Destroy()
    end
    for name in clone:GetAttributes() do
        clone:SetAttribute(name, nil)
    end
    for _, tag in CollectionService:GetTags(clone) do
        CollectionService:RemoveTag(clone, tag)
    end
    clone.Name = "TutorialGlassGleamProxy"
    clone.Anchored = true
    clone.CanCollide, clone.CanTouch, clone.CanQuery = false, false, false
    clone.CastShadow = false
    clone.Transparency = 1
    clone.LocalTransparencyModifier = 0
    clone.Material = Enum.Material.Glass
    clone.CFrame, clone.Size = source.CFrame, source.Size
    clone.Parent = workspace
    return clone
end
local function refresh()
    if stopped then
        return
    end
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local stage = player:GetAttribute("TutorialStage")
    if
        stage ~= "ClaimPlot"
        or player:GetAttribute("TutorialActive") ~= true
        or player:GetAttribute("PlotSessionId") ~= nil
    then
        clearClaimPin()
    end
    local targets: { Instance } = {}
    local plot = if type(stage) == "string" then plotFor(stage) else nil
    if
        player.Parent ~= nil
        and character
        and character ~= removingCharacter
        and character:IsDescendantOf(workspace)
        and humanoid
        and humanoid.Health > 0
        and player:GetAttribute("TutorialActive") == true
        and player:GetAttribute("TutorialHintReady") == true
        and type(stage) == "string"
    then
        if stage ~= "ClaimPlot" or player:GetAttribute("PlotSessionId") == nil then
            local slot = player:GetAttribute("TutorialStashSlot")
            local customer = player:FindFirstChild("TutorialCustomerTarget")
            targets = Targets.Resolve(
                plot,
                stage,
                if type(slot) == "number" then slot else nil,
                if customer and customer:IsA("ObjectValue") then customer.Value else nil
            )
        end
        if stage == "ClaimPlot" and activeClaimHintPlot == plot and #activeClaimHintTargets > 0 then
            local valid = #targets == #activeClaimHintTargets
            for _, target in activeClaimHintTargets do
                if not target:IsDescendantOf(workspace) or not table.find(targets, target) then
                    valid = false
                    break
                end
            end
            if valid then
                targets = table.clone(activeClaimHintTargets)
            else
                table.clear(activeClaimHintTargets)
            end
        end
    end
    diagnose(stage, plot, targets)
    local same = #targets == #current
    for i, object in targets do
        if current[i] ~= object then
            same = false
            break
        end
    end
    if same and glassProxy and glassSource then
        if glassProxy.Parent ~= workspace then
            same = false
        else
            glassProxy.CFrame, glassProxy.Size = glassSource.CFrame, glassSource.Size
        end
    end
    if same then
        return
    end
    clear()
    for _, object in targets do
        local adornee = object
        if stage == "Blender" and object:IsA("UnionOperation") and Targets.GetRoots(plot, "Blender")[1] == object then
            local proxy = createGlassProxy(object)
            if not proxy then
                if debugging() and failedGlassSource ~= object then
                    failedGlassSource = object
                    warn("[TutorialGleam] Blender.Glass could not be cloned; retrying")
                end
                continue
            end
            failedGlassSource = nil
            glassProxy, glassSource = proxy, object
            adornee = proxy
        end
        table.insert(targetConnections, object.Destroying:Connect(clear))
        table.insert(
            targetConnections,
            object.AncestryChanged:Connect(function()
                if not object:IsDescendantOf(workspace) then
                    clear()
                end
            end)
        )
        local highlight = Instance.new("Highlight")
        highlight.Name = "TutorialGleam"
        highlight.Adornee = adornee
        highlight.Enabled = true
        highlight.FillColor = Color3.fromRGB(255, 224, 65)
        highlight.OutlineColor = Color3.fromRGB(255, 250, 205)
        highlight.FillTransparency, highlight.OutlineTransparency = 0.70, 0.05
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = workspace -- created locally, never replicated by server
        if debugging() then
            print(
                "[TutorialGleam] highlight created stage="
                    .. tostring(stage)
                    .. " target="
                    .. describe(object)
                    .. " highlight="
                    .. describe(highlight)
                    .. " parent="
                    .. describe(highlight.Parent)
                    .. " Adornee="
                    .. describe(highlight.Adornee)
                    .. " Enabled="
                    .. tostring(highlight.Enabled)
                    .. " DepthMode="
                    .. tostring(highlight.DepthMode)
                    .. " FillTransparency="
                    .. tostring(highlight.FillTransparency)
                    .. " OutlineTransparency="
                    .. tostring(highlight.OutlineTransparency)
            )
        end
        local tween = TweenService:Create(
            highlight,
            TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { FillTransparency = 0.35, OutlineTransparency = 0.15 }
        )
        table.insert(highlights, highlight)
        table.insert(tweens, tween)
        table.insert(current, object)
        tween:Play()
    end
    if stage == "ClaimPlot" and #current > 0 then
        activeClaimHintPlot = plot
        activeClaimHintTargets = table.clone(current)
    end
end
local function bindSpawnTarget()
    local candidate = player:FindFirstChild("TutorialSpawnTarget")
    local target = if candidate and candidate:IsA("ObjectValue") then candidate else nil
    if target == spawnTarget then
        return
    end
    if spawnTargetConnection then
        spawnTargetConnection:Disconnect()
        spawnTargetConnection = nil
    end
    spawnTarget = target
    if target then
        spawnTargetConnection = target:GetPropertyChangedSignal("Value"):Connect(function()
            if player:GetAttribute("TutorialStage") == "ClaimPlot" then
                refresh() -- nil after reservation expiry retains the active claim pin
            end
        end)
    end
    if player:GetAttribute("TutorialStage") == "ClaimPlot" then
        refresh()
    end
end
function Controller.Init()
    if initialized then
        return
    end
    initialized = true
    bindSpawnTarget()
    for _, event in { player.ChildAdded, player.ChildRemoved } do
        table.insert(
            connections,
            event:Connect(function(child)
                if child.Name == "TutorialSpawnTarget" then
                    bindSpawnTarget()
                end
            end)
        )
    end
    for _, attribute in
        {
            "TutorialStage",
            "TutorialActive",
            "TutorialHintReady",
            "TutorialStashSlot",
            "TutorialOrderIndex",
            "PlotSessionId",
            "PlotMembershipRevision",
            "DebugTutorialGleam",
        }
    do
        table.insert(
            connections,
            player:GetAttributeChangedSignal(attribute):Connect(function()
                clear() -- invalidate immediately, before resolving the next replicated target
                refresh()
            end)
        )
    end
    table.insert(
        connections,
        player.CharacterRemoving:Connect(function(character)
            removingCharacter = character
            clear()
        end)
    )
    table.insert(
        connections,
        player.CharacterAdded:Connect(function()
            removingCharacter = nil
            clear()
            refresh()
        end)
    )
    -- Re-resolve streaming/recreated targets and death state without waiting for missing assets.
    table.insert(connections, RunService.Heartbeat:Connect(refresh))
    script.Destroying:Connect(function()
        stopped = true
        clearClaimPin()
        if spawnTargetConnection then
            spawnTargetConnection:Disconnect()
            spawnTargetConnection = nil
        end
        clear()
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
    end)
    refresh()
end
return Controller
