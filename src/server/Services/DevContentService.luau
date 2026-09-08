--!strict
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local DevContentService = {}
local deps: any
function DevContentService.Init(services)
    deps = services
end
function DevContentService.IsEnabled(): boolean
    return RunService:IsStudio() and ServerStorage:GetAttribute("EnableDevContent") == true
end
local function allowed(player: Player): boolean
    if not DevContentService.IsEnabled() or player.Parent ~= game:GetService("Players") then
        return false
    end
    return true
end

function DevContentService.ValidatePlot(player: Player): (boolean, { string })
    if not allowed(player) then
        return false, { "Studio and EnableDevContent=true required" }
    end
    local plot = deps.TycoonService.GetPlot(player)
    local lines: { string } = {}
    local valid = true
    local function report(role: string, ok: boolean, detail: string?)
        valid = valid and ok
        table.insert(lines, (if ok then "PASS " else "FAIL ") .. role .. (if detail then " - " .. detail else ""))
    end
    if not plot then
        report("PlayerPlot", false, "No assigned plot in Workspace")
    else
        report(
            "PlayerPlot",
            CollectionService:HasTag(plot, "PlayerPlot")
                and (plot:IsA("Model") or plot:IsA("Folder"))
                and deps.TycoonService.GetOwner(plot) == player,
            "assigned " .. plot:GetFullName()
        )
        for _, other in CollectionService:GetTagged("PlayerPlot") do
            if other ~= plot and (other:IsDescendantOf(plot) or plot:IsDescendantOf(other)) then
                report("PlayerPlot", false, "Nested plot: " .. other:GetFullName())
            end
        end
        local stash: Instance? = nil
        for _, role in
            {
                "BlenderInput",
                "TurbineWheel",
                "DispenseButton",
                "StartDayButton",
                "CustomerSpawn",
                "CustomerCounter",
                "CustomerExit",
                "PlayerStash",
            }
        do
            local fixtures = deps.TycoonService.GetFixtures(plot, role)
            if #fixtures == 0 then
                report(role, false, "Missing tag inside assigned plot (tags outside this plot do not count)")
            elseif #fixtures > 1 then
                local paths = {}
                for _, fixture in fixtures do
                    table.insert(paths, fixture:GetFullName())
                end
                table.sort(paths)
                report(role, false, "Duplicate tags: " .. table.concat(paths, ", "))
            else
                local fixture = fixtures[1]
                local part = deps.TycoonService.GetReference(player, role)
                if role == "BlenderInput" and not fixture:IsA("BasePart") then
                    report(role, false, "Tag the InputZone BasePart itself: " .. fixture:GetFullName())
                elseif
                    not part
                    or not part:IsA("BasePart")
                    or not part:IsDescendantOf(plot)
                    or deps.TycoonService.GetOwner(part) ~= player
                then
                    report(role, false, "Must resolve to a BasePart in the assigned plot: " .. fixture:GetFullName())
                elseif role == "BlenderInput" and not part.CanQuery then
                    report(role, false, "CanQuery must be true: " .. part:GetFullName())
                else
                    report(role, true)
                end
                if role == "PlayerStash" then
                    stash = fixture
                end
            end
        end
        local indices: { [number]: { Instance } } = {}
        if stash then
            for _, slot in stash:GetDescendants() do
                local index = slot:GetAttribute("SlotIndex")
                if index ~= nil then
                    if
                        not slot:IsA("BasePart")
                        or type(index) ~= "number"
                        or index ~= index
                        or index % 1 ~= 0
                        or index < 1
                        or index > 10
                    then
                        report(
                            "SlotIndex",
                            false,
                            slot:GetFullName() .. " must be a BasePart with integer SlotIndex 1-10"
                        )
                    else
                        indices[index] = indices[index] or {}
                        table.insert(indices[index], slot)
                    end
                end
            end
        end
        for index = 1, 10 do
            local slots = indices[index] or {}
            if index <= 5 or #slots > 0 then
                report(
                    "SlotIndex " .. index,
                    #slots == 1,
                    if #slots == 0
                        then "Missing BasePart under tagged PlayerStash"
                        elseif #slots > 1 then "Duplicate SlotIndex"
                        else nil
                )
            end
        end
    end
    print("[Plot Validation] " .. (if plot then plot.Name else player.Name))
    for _, line in lines do
        print(line)
    end
    return valid, lines
end

local function stagingFrame(player: Player): CFrame?
    -- GetReference resolves a unique tagged BasePart inside the player's assigned plot.
    local input = deps.TycoonService.GetReference(player, "BlenderInput")
    if not input then
        return nil
    end
    return input.CFrame * CFrame.new(0, 4, 0)
end
function DevContentService.ResetBlender(player: Player): boolean
    if not allowed(player) then
        return false
    end
    deps.BlendService.Reset(player)
    return true
end
function DevContentService.SpawnIngredient(player: Player, id: string): Instance?
    if not allowed(player) then
        return nil
    end
    local at = stagingFrame(player)
    if not at then
        return nil
    end
    if not deps.IngredientService.GetDefinition(id) then
        warn("[DevContentService] Unknown ingredient: " .. tostring(id))
        return nil
    end
    return deps.IngredientService.Spawn(id, at, player)
end
function DevContentService.PrepareCombination(player: Player, ids: { string }): boolean
    if not allowed(player) or #ids < 1 or #ids > Economy.MaxIngredients then
        return false
    end
    for _, id in ids do
        if not deps.IngredientService.GetDefinition(id) then
            return false
        end
    end
    local staging = stagingFrame(player)
    if not staging then
        return false
    end
    deps.InventoryService.ClearHeld(player)
    deps.IngredientService.RemovePlayer(player)
    deps.BlendService.Reset(player)
    for index, id in ids do
        local at = staging * CFrame.new((index - (#ids + 1) / 2) * 3, 0, 0)
        if not deps.IngredientService.Spawn(id, at, player) then
            deps.IngredientService.RemovePlayer(player)
            return false
        end
    end
    return true
end
function DevContentService.SpawnCustomer(player: Player): Model?
    if not allowed(player) then
        return nil
    end
    local existing = deps.CustomerService.GetSnapshot(player)
    if existing then
        return existing.Model
    end
    local ok, reason
    if deps.GameService.IsServing(player) then
        ok = deps.GameService.ResumeDay(player)
    else
        ok, reason = deps.GameService.StartDay(player)
    end
    if not ok then
        warn("[DevContentService] " .. (reason or "Customer spawn failed; check plot markers"))
        return nil
    end
    local customer = deps.CustomerService.GetSnapshot(player)
    return customer and customer.Model
end
function DevContentService.ForceReaction(player: Player, reaction: string?): boolean
    return allowed(player) and deps.CustomerService.SetForcedReaction(player, reaction)
end
function DevContentService.ResetScene(player: Player): boolean
    if not allowed(player) then
        return false
    end
    deps.InventoryService.ClearHeld(player)
    deps.GameService.Reset(player)
    deps.BlendService.Reset(player)
    deps.BlendService.ClearCup(player)
    deps.IngredientService.RemovePlayer(player)
    return true
end
-- Keep legacy names callable; all aliases retain the same Studio/opt-in gate.
DevContentService.ClearBlender = DevContentService.ResetBlender
DevContentService.ResetPlot = DevContentService.ResetScene
return require(script.Parent.StudioServices).Wrap("DevContentService", DevContentService)
