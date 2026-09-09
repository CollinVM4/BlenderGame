--!strict
local CollectionService = game:GetService("CollectionService")
local WorldUtil = require(script.Parent.WorldUtil)
local TycoonService = {}
local data: any
local plots: { [Player]: Instance } = {}

function TycoonService.Init(playerDataService)
    data = playerDataService
end
function TycoonService.GetPlot(player: Player): Instance?
    local plot = plots[player]
    if plot and plot:IsDescendantOf(workspace) then
        return plot
    end
    return nil
end
function TycoonService.GetOwner(object: Instance): Player?
    for player, plot in plots do
        if plot:IsDescendantOf(workspace) and (object == plot or object:IsDescendantOf(plot)) then
            return player
        end
    end
    return nil
end
function TycoonService.GetFixtures(plot: Instance, role: string): { Instance }
    local fixtures = {}
    for _, object in CollectionService:GetTagged(role) do
        if object:IsDescendantOf(plot) then
            table.insert(fixtures, object)
        end
    end
    return fixtures
end

-- Compatibility runs before binding. An explicitly tagged role always wins over old names.
function TycoonService.AutoTagLegacyPlot(plot: Instance)
    CollectionService:AddTag(plot, "PlayerPlot")
    for _, role in
        {
            "BlenderInput",
            "IngredientSpawn",
            "DispenseButton",
            "CustomerSpawn",
            "CustomerCounter",
            "CustomerExit",
            "StartDayButton",
            "PlayerStash",
            "TurbineWheel",
        }
    do
        if #TycoonService.GetFixtures(plot, role) == 0 then
            local object = plot:FindFirstChild(role, true)
            if not object and role == "TurbineWheel" then
                local turbine = plot:FindFirstChild("Turbine", true)
                object = turbine
                    and (
                        turbine:FindFirstChild("blade", true)
                        or turbine:FindFirstChild("stem", true)
                        or WorldUtil.Part(turbine)
                    )
            end
            if object then
                CollectionService:AddTag(object, role)
            end
        end
    end
end

local customerRoles = { CustomerSpawn = true, CustomerCounter = true, CustomerExit = true }

-- Customer destinations must be explicit markers, never an arbitrary part of a tagged area.
-- Prefer tagged parts over legacy tagged containers so tagging the actual marker repairs
-- an old area-level tag without making the reference ambiguous.
local function customerReference(fixtures: { Instance }, name: string): (BasePart?, string?)
    local markers: { BasePart } = {}
    for _, fixture in fixtures do
        if fixture:IsA("BasePart") then
            table.insert(markers, fixture)
        end
    end
    if #markers == 0 then
        for _, fixture in fixtures do
            local parts: { BasePart } = {}
            local named: { BasePart } = {}
            for _, child in fixture:GetDescendants() do
                if child:IsA("BasePart") then
                    table.insert(parts, child)
                    if child.Name == name then
                        table.insert(named, child)
                    end
                end
            end
            local marker = if #named == 1 then named[1] elseif #parts == 1 then parts[1] else nil
            if not marker then
                return nil,
                    "Tag the " .. name .. " marker BasePart itself; ambiguous/empty container " .. fixture:GetFullName()
            end
            if not table.find(markers, marker) then
                table.insert(markers, marker)
            end
        end
    end
    if #markers ~= 1 then
        local paths = {}
        for _, fixture in fixtures do
            table.insert(paths, fixture:GetFullName())
        end
        return nil,
            string.format(
                "%s: expected one marker, found %d; tagged objects=[%s]",
                name,
                #markers,
                table.concat(paths, ", ")
            )
    end
    local marker = markers[1]
    if
        CollectionService:HasTag(marker, "StartDayButton")
        or marker.Name == "StartDayButton"
        or marker:FindFirstChild("StartDayPrompt")
    then
        return nil,
            name .. " resolves to Start Day button " .. marker:GetFullName() .. "; tag a separate customer marker"
    end
    return marker
end

function TycoonService.GetReference(player: Player, name: string): (BasePart?, string?)
    local plot = TycoonService.GetPlot(player)
    if not plot then
        return nil, "No assigned plot"
    end
    local fixtures = TycoonService.GetFixtures(plot, name)
    if (customerRoles :: any)[name] then
        return customerReference(fixtures, name)
    end
    if #fixtures ~= 1 then
        return nil
    end
    local fixture = fixtures[1]
    if name == "BlenderInput" and not fixture:IsA("BasePart") then
        return nil
    end
    local part = WorldUtil.Part(fixture)
    if part and (part == fixture or part:IsDescendantOf(fixture)) then
        return part
    end
    return nil
end
function TycoonService.AssignPlot(player: Player): Instance?
    if TycoonService.GetPlot(player) then
        return plots[player]
    end
    local candidates = CollectionService:GetTagged("PlayerPlot")
    local folder = workspace:FindFirstChild("Plots")
    if folder then
        for _, plot in folder:GetChildren() do
            if not table.find(candidates, plot) then
                TycoonService.AutoTagLegacyPlot(plot)
                table.insert(candidates, plot)
            end
        end
    end
    table.sort(candidates, function(a, b)
        return a.Name < b.Name
    end)
    for _, plot in candidates do
        if plot:IsDescendantOf(workspace) and not TycoonService.GetOwner(plot) then
            plots[player] = plot
            plot:SetAttribute("OwnerUserId", player.UserId)
            return plot
        end
    end
    warn("[TycoonService] No free PlayerPlot / workspace.Plots child for " .. player.Name)
    return nil
end
function TycoonService.RemovePlayer(player: Player)
    local plot = plots[player]
    if plot then
        plot:SetAttribute("OwnerUserId", nil)
    end
    plots[player] = nil
end
-- Compatibility with existing server callers; PlayerDataService now owns cash.
function TycoonService.GetCash(player: Player): number
    return data.GetCash(player)
end
function TycoonService.AddCash(player: Player, amount: number): number
    return data.AddCash(player, amount)
end
function TycoonService.SetCash(player: Player, amount: number): number
    return data.SetCash(player, amount)
end
return require(script.Parent.StudioServices).Wrap("TycoonService", TycoonService)
