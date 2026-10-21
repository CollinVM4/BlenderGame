--!strict
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
-- Replicated identity is presentation only. Every action is revalidated by the server.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextStyle = require(ReplicatedStorage.Shared.Constants.DialogueTextStyle)
local Controller = {}
local player = Players.LocalPlayer
local portraits: { [number]: string } = {}
local pending: { [number]: boolean } = {}
local displays: { [Instance]: BillboardGui } = {}
local padLabels: { [Instance]: BillboardGui } = {}
local initialized = false
local function portrait(id: number): string
    if not portraits[id] and not pending[id] then
        pending[id] = true
        task.spawn(function()
            local ok, url = pcall(function()
                return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            end)
            portraits[id] = if ok then url else ""
            pending[id] = nil
        end)
    end
    return portraits[id] or ""
end
local function label(parent: Instance, text: string, y: number): TextLabel
    local result = Instance.new("TextLabel")
    result.BackgroundTransparency = 1
    result.Size = UDim2.new(1, 0, 0, 28)
    result.Position = UDim2.fromOffset(0, y)
    TextStyle.Apply(result, 17, if parent:IsA("BillboardGui") then parent else nil)
    if parent:IsA("BillboardGui") then
        local canvasHeight = if parent.Name == "PlotIdentity" then 200 else 32
        result.Size = UDim2.fromScale(1, 28 / canvasHeight)
        result.Position = UDim2.fromScale(0, y / canvasHeight)
        result.TextScaled = true
    end
    result.Text = text
    result.Parent = parent
    return result
end
local function button(parent: Instance, text: string, y: number, callback: () -> ()): TextButton
    local result = Instance.new("TextButton")
    result.Size = UDim2.new(1, -24, 0, 30)
    result.AnchorPoint = Vector2.new(0.5, 0.5)
    result.Position = UDim2.new(0.5, 0, 0, y + 15)
    if parent:IsA("BillboardGui") then
        result.Size = UDim2.fromScale(256 / 280, 30 / 200)
        result.Position = UDim2.fromScale(0.5, (y + 15) / 200)
    end
    result.BackgroundColor3 = Color3.fromRGB(35, 92, 108)
    result.BorderSizePixel = 0
    TextStyle.Apply(result, 17, if parent:IsA("BillboardGui") then parent else nil)
    result.TextScaled = parent:IsA("BillboardGui")
    result.Text = text
    result.Parent = parent
    Instance.new("UICorner", result).CornerRadius = UDim.new(0, 12)
    local border = Instance.new("UIStroke")
    border.Name = "ButtonOutline"
    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    border.Parent = result
    border.Color = TextStyle.Dark
    if parent:IsA("BillboardGui") then
        BillboardStyle.ApplyWorldStroke(result, parent, { Name = "ButtonOutline", Color = TextStyle.Dark })
    else
        border.Thickness = 3
    end
    result.Activated:Connect(callback)
    return result
end
function Controller.Init()
    if initialized then
        return
    end
    initialized = true
    local remote = ReplicatedStorage.Shared.Events:WaitForChild("GameplayRequest") :: RemoteEvent
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn = "PlotStatus", false
    gui.Parent = player:WaitForChild("PlayerGui")
    local status = label(gui, "", 70)
    local function context(plot: Instance): any
        return {
            PlotSessionId = plot:GetAttribute("PlotSessionId"),
            MembershipRevision = plot:GetAttribute("PlotMembershipRevision"),
            ClaimRevision = plot:GetAttribute("PlotClaimRevision") or 0,
        }
    end
    local function send(plot: Instance, action: string, value: any, captured: any)
        remote:FireServer(action, plot, value, captured)
    end
    local failureUntil = 0
    remote.OnClientEvent:Connect(function(action, result)
        if action == "PlotRequestResult" and not result.success then
            failureUntil = os.clock() + 4
        end
    end)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.25 then
            return
        end
        elapsed = 0
        status.Text = if os.clock() < failureUntil then "Plot action unavailable. Try again." else ""
        status.TextSize = 17
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local live: { [Instance]: boolean } = {}
        local liveLabels: { [Instance]: boolean } = {}
        for _, plot in CollectionService:GetTagged("PlayerPlot") do
            local identity = plot:FindFirstChild("PlotIdentity")
            if identity and plot:IsDescendantOf(workspace) then
                for _, role in { "Claim", "Teammate" } do
                    local labelOrigin = identity:FindFirstChild(role .. "LabelOrigin")
                    if labelOrigin and (labelOrigin:IsA("BasePart") or labelOrigin:IsA("Attachment")) then
                        liveLabels[labelOrigin] = true
                        local display = padLabels[labelOrigin]
                        if not display then
                            local created = Instance.new("BillboardGui")
                            created.Name = role .. "ZoneLabel"
                            -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
                            BillboardStyle.ApplyBillboard(
                                created,
                                { WidthStuds = 5.76, HeightStuds = 1.08, MaxDistance = 60, ResetOnSpawn = true }
                            )
                            created.Active = false
                            created.Adornee, created.Parent = labelOrigin, gui
                            label(created, if role == "Claim" then "CLAIM PLOT" else "JOIN STAND", 0)
                            padLabels[labelOrigin] = created
                            display = created
                        end
                        local occupancy = plot:GetAttribute("PlotOccupancy") or 0
                        display.Enabled = if role == "Claim" then occupancy == 0 else occupancy == 1
                    end
                end
            end
            local origin = plot:FindFirstChild("PlotIdentityOrigin", true)
            if
                not plot:IsDescendantOf(workspace)
                or not origin
                or not (origin:IsA("BasePart") or origin:IsA("Attachment"))
            then
                continue
            end
            live[plot] = true
            if not displays[plot] then
                local display = Instance.new("BillboardGui")
                display.Name = "PlotIdentity"
                BillboardStyle.ApplyBillboard(
                    display,
                    { WidthStuds = 9, HeightStuds = 6.36, MaxDistance = 60, ResetOnSpawn = true }
                )
                display.ClipsDescendants = false -- Allow proportional member columns around the existing action footprint.
                display.Active = true
                display.Parent = gui
                displays[plot] = display
            end
            local display = displays[plot]
            display.Adornee = origin
            local owner = plot:GetAttribute("OwnerUserId")
            local teammate = plot:GetAttribute("TeammateUserId")
            display.MaxDistance = 60
            local position = if origin:IsA("Attachment") then origin.WorldPosition else (origin :: BasePart).Position
            local nearby = root and root:IsA("BasePart") and (root.Position - position).Magnitude <= 32
            local action = if not nearby then nil elseif teammate == player.UserId then "LEAVE TEAM" else nil
            local signature = tostring(owner)
                .. tostring(teammate)
                .. tostring(plot:GetAttribute("PlotMembershipRevision"))
                .. tostring(plot:GetAttribute("PlotClaimRevision"))
                .. tostring(action)
                .. (if type(owner) == "number" then portrait(owner) else "")
                .. (if type(teammate) == "number" then portrait(teammate) else "")
            if display:GetAttribute("Signature") ~= signature then
                display:SetAttribute("Signature", signature)
                display:ClearAllChildren()
                if type(owner) == "number" then
                    local function member(id: number, name: string, x: number, role: string)
                        local head = Instance.new("ImageLabel")
                        head.Size, head.Position = UDim2.fromScale(64 / 280, 64 / 200), UDim2.fromScale(x / 280, 0)
                        head.Image, head.BackgroundTransparency, head.Parent = portrait(id), 1, display
                        Instance.new("UICorner", head).CornerRadius = UDim.new(1, 0)
                        local nameLabel = label(display, name, 72)
                        nameLabel.TextSize = 24
                        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                        local width = if teammate then 260 else 420
                        nameLabel.Size = UDim2.fromScale(width / 280, 32 / 200)
                        nameLabel.Position = UDim2.fromScale((x + 32 - width / 2) / 280, 72 / 200)
                        if role ~= "" then
                            local roleLabel = label(display, role, 106)
                            roleLabel.Size, roleLabel.Position =
                                UDim2.fromScale(width / 280, 24 / 200),
                                UDim2.fromScale((x + 32 - width / 2) / 280, 106 / 200)
                            roleLabel.TextSize = 14
                        end
                    end
                    member(owner, tostring(plot:GetAttribute("PlotOwnerName") or ""), if teammate then -32 else 108, "")
                    if type(teammate) == "number" then
                        member(teammate, tostring(plot:GetAttribute("PlotTeammateName") or ""), 248, "TEAMMATE")
                    end
                else
                    label(display, "AVAILABLE PLOT", 68)
                end
                if action then
                    local captured = context(plot)
                    button(display, action, 132, function()
                        send(plot, "LeaveTeam", nil, captured)
                    end)
                end
            end
        end
        for plot, display in displays do
            if not live[plot] then
                display:Destroy()
                displays[plot] = nil
            end
        end
        for origin, display in padLabels do
            if not liveLabels[origin] then
                display:Destroy()
                padLabels[origin] = nil
            end
        end
    end)
end
return Controller
