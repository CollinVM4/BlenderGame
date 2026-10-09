--!strict
local Spawn = {}
local deps: any
local spawnReservationByPlot: { [Instance]: Player } = {}
local spawnReservationByPlayer: { [Player]: Instance } = {}
local claimHintPlotByPlayer: { [Player]: Instance } = {}
local attempted: { [Player]: boolean } = {}
local function availableTarget(player: Player): Instance?
    for _, plot in deps.TycoonService.GetOrderedPlots() do
        local identity = plot:FindFirstChild("PlotIdentity")
        local marker = if identity then identity:FindFirstChild("PlayerSpawnOrigin") else nil
        if
            deps.TycoonService.IsPlotAvailable(plot)
            and (not spawnReservationByPlot[plot] or spawnReservationByPlot[plot] == player)
            and marker
            and marker:IsA("Attachment")
        then
            return plot
        end
    end
    return nil
end
function Spawn.Init(services: any)
    deps = services
    local elapsed = 0
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.25 then
            return
        end
        elapsed = 0
        for player, intended in claimHintPlotByPlayer do
            if
                player.Parent ~= nil
                and player:GetAttribute("TutorialActive") == true
                and player:GetAttribute("TutorialStage") == "ClaimPlot"
                and not deps.TycoonService.GetPlot(player)
                and not deps.TycoonService.IsPlotAvailable(intended)
            then
                -- Retarget help only when the intended plot becomes unavailable.
                -- No teleport, ownership, renewed timeout or additional spawn reservation.
                local nextTarget = availableTarget(player)
                local value = player:FindFirstChild("TutorialSpawnTarget")
                if value and value:IsA("ObjectValue") then
                    value.Value = nextTarget
                end
                if nextTarget then
                    claimHintPlotByPlayer[player] = nextTarget
                end
            end
        end
    end)
end
function Spawn.ClearReservation(player: Player, preserveHint: boolean?)
    local plot = spawnReservationByPlayer[player]
    if plot and spawnReservationByPlot[plot] == player then
        spawnReservationByPlot[plot] = nil
    end
    spawnReservationByPlayer[player] = nil
    if not preserveHint then
        claimHintPlotByPlayer[player] = nil
    end
    local target = player:FindFirstChild("TutorialSpawnTarget")
    if target and target:IsA("ObjectValue") and (not preserveHint or target.Value == plot) then
        target.Value = nil
    end
end
function Spawn.ApplyCharacter(player: Player, character: Model)
    local firstArrival = not attempted[player]
    attempted[player] = true -- Only unclaimed tutorial routing is limited to the first character.
    task.spawn(function()
        local root = character:WaitForChild("HumanoidRootPart", 10)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if
            not root
            or not root:IsA("BasePart")
            or not humanoid
            or humanoid.Health <= 0
            or player.Parent == nil
            or player.Character ~= character
        then
            return
        end
        -- Resolve after the root wait so a release, team change or reassignment cannot
        -- send this character to a stale session. Nothing below yields before PivotTo.
        local assignedPlot = deps.TycoonService.GetPlot(player)
        if assignedPlot then
            local identity = assignedPlot:FindFirstChild("PlotIdentity")
            local spawnOrigin = if identity then identity:FindFirstChild("PlayerSpawnOrigin") else nil
            if spawnOrigin and spawnOrigin:IsA("Attachment") then
                local spawnCFrame = spawnOrigin.WorldCFrame * CFrame.new(0, 3, 0)
                if deps.TycoonService.GetOwner(assignedPlot) ~= player then
                    spawnCFrame *= CFrame.new(4, 0, 0)
                end
                character:PivotTo(spawnCFrame)
                root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
            end
            return
        end
        if not firstArrival then
            return
        end
        for _, plot in deps.TycoonService.GetOrderedPlots() do
            local identity = plot:FindFirstChild("PlotIdentity")
            local marker = if identity then identity:FindFirstChild("PlayerSpawnOrigin") else nil
            if
                deps.TycoonService.IsPlotAvailable(plot)
                and not spawnReservationByPlot[plot]
                and marker
                and marker:IsA("Attachment")
            then
                spawnReservationByPlot[plot], spawnReservationByPlayer[player] = player, plot
                claimHintPlotByPlayer[player] = plot
                local target = Instance.new("ObjectValue")
                target.Name, target.Value, target.Parent = "TutorialSpawnTarget", plot, player
                -- Attachment specifies HRP, whereas PivotTo specifies the model pivot.
                character:PivotTo(marker.WorldCFrame * root.CFrame:ToObjectSpace(character:GetPivot()))
                root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
                task.delay(25, function()
                    if spawnReservationByPlayer[player] == plot then
                        Spawn.ClearReservation(player, true)
                    end
                end)
                return
            end
        end
    end)
end
function Spawn.RemovePlayer(player: Player)
    Spawn.ClearReservation(player)
    attempted[player] = nil
end
return Spawn
