--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Targets = require(game:GetService("ReplicatedStorage").Shared.TutorialTargets)
local Presentation = require(script.Parent.TutorialPresentationState)
local Flow = require(script.Parent.Parent.UI.TutorialBeamFlow)
local Marker = require(script.Parent.Parent.UI.TutorialObjectiveMarker)
local marker: Marker.Surface? = nil
local markerStage: string? = nil
local markerStartedAt = 0
local highlightStartedAt = 0
local currentStage: string? = nil
local beamFinish: Attachment? = nil
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
local current: { Instance } = {}
local activeClaimHintPlot: Instance? = nil
local activeClaimHintTargets: { Instance } = {}
local glassProxy: UnionOperation? = nil
local glassSource: UnionOperation? = nil
local failedGlassSource: UnionOperation? = nil
local targetConnections: { RBXScriptConnection } = {}
local stashBeam: Beam? = nil
local stashFlow: Beam? = nil
local beamStartedAt = 0
local beamAttachments: { Attachment } = {}
local function clearClaimPin()
    activeClaimHintPlot = nil
    table.clear(activeClaimHintTargets)
end
local function claimAvailable(plot: Instance?): boolean
    return plot ~= nil and plot:IsDescendantOf(workspace) and plot:GetAttribute("PlotSessionId") == nil
end
local beamTarget: Instance? = nil
local beamTargetConnections: { RBXScriptConnection } = {}
local markerTarget: Instance? = nil
local function clearMarker()
    if marker then
        marker.Destroy()
        marker = nil
    end
    markerStage, markerTarget = nil, nil
end
local function clearBeam()
    clearMarker()
    for _, connection in beamTargetConnections do
        connection:Disconnect()
    end
    table.clear(beamTargetConnections)
    beamFinish = nil
    if stashFlow then
        stashFlow:Destroy()
        stashFlow = nil
    end
    if stashBeam then
        stashBeam:Destroy()
        stashBeam = nil
    end
    for _, attachment in beamAttachments do
        attachment:Destroy()
    end
    table.clear(beamAttachments)
    beamTarget = nil
end
local function clear()
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
    currentStage = nil
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
local function beamEnd(target: BasePart | Attachment, stage: string?): Attachment
    if target:IsA("Attachment") then
        return target
    end
    local attachment = Instance.new("Attachment")
    attachment.Name = "TutorialStashBeamEnd"
    if stage == "Turbine" or stage == "FinishBatch" then
        -- Lower on a tall stationary shaft; centered on short stems.
        attachment.Position = Vector3.new(0, math.min(0, 2.5 - target.Size.Y * 0.5), 0)
    end
    attachment.Parent = target
    table.insert(beamAttachments, attachment)
    return attachment
end
local function createStashBeam(character: Model, target: BasePart | Attachment, stage: string?)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return
    end
    local start = Instance.new("Attachment")
    start.Name = "TutorialStashBeamStart"
    start.Position = Vector3.new(0, -0.5, 1.25) -- Local +Z is behind the avatar.
    start.Parent = root
    local finish = beamEnd(target, stage)
    beamTarget, beamFinish = target, finish
    local beam = Instance.new("Beam")
    beam.Name = "TutorialStashBeam"
    beam.Attachment0, beam.Attachment1 = start, finish
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 225, 0))
    beam.Transparency = NumberSequence.new(0.72) -- Let the bright traveling energy stand out.
    beam.Width0, beam.Width1 = 0.8, 0.6
    beam.CurveSize0, beam.CurveSize1 = 1.5, -1.5
    beam.Segments = 20
    beam.FaceCamera = true
    beam.LightEmission, beam.LightInfluence = 0.35, 0
    beam.Enabled = true
    beam.Parent = root
    stashBeam = beam
    local flow = Instance.new("Beam")
    flow.Name = "TutorialStashFlow"
    flow.Attachment0, flow.Attachment1 = start, finish
    flow.Color = ColorSequence.new(Color3.fromRGB(255, 248, 130))
    flow.Width0, flow.Width1 = 0.32, 0.24
    flow.CurveSize0, flow.CurveSize1 = beam.CurveSize0, beam.CurveSize1
    flow.Segments, flow.FaceCamera = 20, true
    flow.LightEmission, flow.LightInfluence = 1, 0
    flow.Transparency = Flow.Transparency(0)
    flow.Enabled = true
    flow.Parent = root
    stashFlow, beamStartedAt = flow, os.clock()
    table.insert(beamAttachments, start)
end
-- Retarget the existing effect; only locally created attachments are owned here.
local function updateBeam(character: Model?, target: (BasePart | Attachment)?, stage: string?)
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    if
        not root
        or not root:IsA("BasePart")
        or not target
        or not target:IsDescendantOf(workspace)
        or (target:IsA("Attachment") and (not target.Parent or not target.Parent:IsA("BasePart")))
    then
        clearBeam()
        return
    end
    if stashBeam and stashFlow then
        local start, finish = stashBeam.Attachment0, beamFinish
        if
            not start
            or start.Parent ~= root
            or not stashBeam:IsDescendantOf(workspace)
            or not stashFlow:IsDescendantOf(workspace)
        then
            clearBeam()
        elseif beamTarget ~= (target :: Instance) or not finish or not finish:IsDescendantOf(workspace) then
            if finish and table.find(beamAttachments, finish) then
                table.remove(beamAttachments, table.find(beamAttachments, finish) :: number)
                finish:Destroy()
            end
            for _, connection in beamTargetConnections do
                connection:Disconnect()
            end
            table.clear(beamTargetConnections)
            finish = beamEnd(target, stage)
            stashBeam.Attachment1, stashFlow.Attachment1 = finish, finish
            beamTarget, beamFinish = target, finish
        end
    end
    if not stashBeam then
        createStashBeam(character :: Model, target, stage)
    end
    if #beamTargetConnections == 0 and beamTarget then
        local function hideInvalidEndpoint()
            clearMarker()
            if stashBeam then
                stashBeam.Enabled = false
            end
            if stashFlow then
                stashFlow.Enabled = false
            end
        end
        table.insert(beamTargetConnections, beamTarget.Destroying:Connect(hideInvalidEndpoint))
        table.insert(
            beamTargetConnections,
            beamTarget.AncestryChanged:Connect(function()
                if beamTarget and not beamTarget:IsDescendantOf(workspace) then
                    hideInvalidEndpoint()
                end
            end)
        )
    end
    if stashBeam and stashFlow and beamFinish then
        stashBeam.Enabled, stashFlow.Enabled = true, true
        stashBeam.Attachment1, stashFlow.Attachment1 = beamFinish, beamFinish
        local transparency = Flow.Transparency(os.clock() - beamStartedAt)
        if stashFlow.Transparency ~= transparency then
            stashFlow.Transparency = transparency
        end
    end
end
local function refresh()
    if stopped then
        return
    end
    local _, presentationReady, presentationStage = Presentation.Read(player)
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local stage = presentationStage
    if
        stage ~= "ClaimPlot"
        or player:GetAttribute("TutorialActive") ~= true
        or player:GetAttribute("PlotSessionId") ~= nil
    then
        clearClaimPin()
    end
    local targets: { Instance } = {}
    local plot = if type(stage) == "string" then plotFor(stage) else nil
    local worldReady = player.Parent ~= nil
        and character
        and character ~= removingCharacter
        and character:IsDescendantOf(workspace)
        and humanoid
        and humanoid.Health > 0
        and Presentation.IsActive(player, stage)
        and type(stage) == "string"
        and presentationReady
    if worldReady and type(stage) == "string" then
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
    local same = #targets == #current and stage == currentStage
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
    local destination = if worldReady and type(stage) == "string"
        then Targets.ResolveBeam(plot, stage, player:GetAttribute("TutorialStashSlot"), targets[1])
        else nil
    updateBeam(character, destination, stage)
    if beamFinish and destination then
        if not marker or markerStage ~= stage or markerTarget ~= (destination :: Instance) then
            clearMarker()
            marker = Marker.Create(beamFinish, stage)
            markerStage, markerStartedAt, markerTarget = stage, os.clock(), destination
        end
        local activeMarker = marker :: Marker.Surface
        activeMarker.Update(beamFinish, targets[1], os.clock() - markerStartedAt)
        local camera = workspace.CurrentCamera
        local distance = if camera then (camera.CFrame.Position - beamFinish.WorldPosition).Magnitude else 40
        local scale = math.clamp(distance / 70, 1, 2.5)
        if stashBeam and stashFlow then
            stashBeam.Width0, stashBeam.Width1 = 0.8 * scale, 0.6 * scale
            stashFlow.Width0, stashFlow.Width1 = 0.32 * scale, 0.24 * scale
        end
    end
    if same then
        local age = os.clock() - highlightStartedAt
        local fill = if age < 0.3 then 0.12 + 0.43 * age / 0.3 else 0.55 + 0.09 * math.sin(age * 3)
        for _, highlight in highlights do
            highlight.FillTransparency = fill
        end
        return
    end
    clear()
    currentStage, highlightStartedAt = stage, os.clock()
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
        highlight.FillColor = Color3.fromRGB(255, 225, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 245, 20)
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
        highlight.FillTransparency = 0.12 -- Brief activation flash, then a subtle opacity pulse.
        table.insert(highlights, highlight)
        table.insert(current, object)
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
            "FarmTutorialStage",
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
                if attribute == "PlotMembershipRevision" or attribute == "DebugTutorialGleam" then
                    clear()
                end
                refresh()
            end)
        )
    end
    table.insert(
        connections,
        player.CharacterRemoving:Connect(function(character)
            removingCharacter = character
            if character then
                Presentation.CharacterRemoving(character)
            end
            clearBeam()
            clear()
        end)
    )
    table.insert(
        connections,
        player.CharacterAdded:Connect(function()
            removingCharacter = nil
            Presentation.CharacterAdded()
            clearBeam()
            clear()
            refresh()
        end)
    )
    -- Re-resolve streaming/recreated targets and death state without waiting for missing assets.
    local elapsed = 0
    table.insert(
        connections,
        RunService.Heartbeat:Connect(function(dt)
            elapsed += dt
            -- Active visuals update at 30 Hz; inactive streaming checks run only ten times a second.
            if elapsed >= (if marker or #current > 0 then 1 / 30 else 0.1) then
                elapsed = 0
                refresh()
            end
        end)
    )
    script.Destroying:Connect(function()
        stopped = true
        clearClaimPin()
        if spawnTargetConnection then
            spawnTargetConnection:Disconnect()
            spawnTargetConnection = nil
        end
        clearBeam()
        clear()
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
    end)
    refresh()
end
return Controller
