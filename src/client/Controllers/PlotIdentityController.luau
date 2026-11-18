--!strict
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
-- Replicated identity is presentation only. Every action is revalidated by the server.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage.Shared.ClaimProfile)
local RunService = game:GetService("RunService")
local TextStyle = require(ReplicatedStorage.Shared.Constants.DialogueTextStyle)
local Controller = {}
local player = Players.LocalPlayer
local PORTRAIT_BILLBOARD_WIDTH = 14
local PORTRAIT_BILLBOARD_HEIGHT = 6.4
local PORTRAIT_SIZE = 4.5
local portraits: { [number]: string } = {}
local pending: { [number]: boolean } = {}
local displays: { [Instance]: { Actions: BillboardGui, Portraits: BillboardGui } } = {}
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
local function label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
    local result = Instance.new("TextLabel")
    result.BackgroundTransparency = 1
    result.Size, result.Position = size, position
    local billboard = if parent:IsA("BillboardGui") then parent else nil
    TextStyle.Apply(result, 17, billboard)
    result.TextScaled = billboard ~= nil
    result.Text = text
    result.Parent = parent
    return result
end
local function addPortrait(display: BillboardGui, centerX: number, image: string, name: string)
    local head = Instance.new("ImageLabel")
    head.AnchorPoint = Vector2.new(0.5, 0)
    head.Size = UDim2.fromScale(PORTRAIT_SIZE / PORTRAIT_BILLBOARD_WIDTH, PORTRAIT_SIZE / PORTRAIT_BILLBOARD_HEIGHT)
    head.Position = UDim2.fromScale(centerX, 0.04)
    head.Image = image
    head.BackgroundColor3 = TextStyle.Dark
    head.BackgroundTransparency = 0
    head.Active = false
    head.Parent = display
    Instance.new("UICorner", head).CornerRadius = UDim.new(0.5, 0)

    local nameLabel = label(display, name, UDim2.fromScale(0.48, 0.19), UDim2.fromScale(centerX, 0.77))
    nameLabel.AnchorPoint = Vector2.new(0.5, 0)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Active = false
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
    local status = label(gui, "", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 70))
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
    RunService.Heartbeat:Connect(Profile.Wrap("identity.poll", function(dt: number)
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
            Profile.Count("plots", 1)
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
                            label(
                                created,
                                if role == "Claim" then "CLAIM PLOT" else "JOIN STAND",
                                UDim2.fromScale(1, 28 / 32),
                                UDim2.fromScale(0, 0)
                            )
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
            local display = displays[plot]
            if not display then
                local actions = Instance.new("BillboardGui")
                actions.Name = "PlotIdentity"
                BillboardStyle.ApplyBillboard(
                    actions,
                    { WidthStuds = 9, HeightStuds = 6.36, MaxDistance = 60, ResetOnSpawn = true }
                )
                actions.Parent = gui

                local marker = Instance.new("BillboardGui")
                marker.Name = "PlotPortraits"
                BillboardStyle.ApplyBillboard(marker, {
                    WidthStuds = PORTRAIT_BILLBOARD_WIDTH,
                    HeightStuds = PORTRAIT_BILLBOARD_HEIGHT,
                    MaxDistance = 180,
                    AlwaysOnTop = true, -- Keep the base landmark readable over map geometry.
                    ResetOnSpawn = true,
                })
                marker.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
                marker.Active = false
                marker.Parent = gui
                display = { Actions = actions, Portraits = marker }
                displays[plot] = display
            end
            local actions, marker = display.Actions, display.Portraits
            actions.Adornee, marker.Adornee = origin, origin
            local owner = plot:GetAttribute("OwnerUserId")
            local teammate = plot:GetAttribute("TeammateUserId")
            marker.Enabled = type(owner) == "number"
            if type(owner) == "number" then
                local ownerName = tostring(plot:GetAttribute("PlotOwnerName") or "")
                local teammateName = tostring(plot:GetAttribute("PlotTeammateName") or "")
                local ownerImage = portrait(owner)
                local teammateImage = if type(teammate) == "number" then portrait(teammate) else ""
                local signature = `{owner}:{teammate}:{ownerName}:{teammateName}:{ownerImage}:{teammateImage}`
                if marker:GetAttribute("Signature") ~= signature then
                    Profile.Count("displayRebuilds", 1)
                    marker:SetAttribute("Signature", signature)
                    marker:ClearAllChildren()
                    addPortrait(marker, if type(teammate) == "number" then 0.25 else 0.5, ownerImage, ownerName)
                    if type(teammate) == "number" then
                        addPortrait(marker, 0.75, teammateImage, teammateName)
                    end
                end
            end

            local position = if origin:IsA("Attachment") then origin.WorldPosition else (origin :: BasePart).Position
            local nearby = root and root:IsA("BasePart") and (root.Position - position).Magnitude <= 32
            local canLeave = marker.Enabled and nearby == true and teammate == player.UserId
            actions.Active = canLeave
            actions.Enabled = canLeave or type(owner) ~= "number"
            if actions.Enabled then
                local captured = if canLeave then context(plot) else nil
                local signature = if captured
                    then `{captured.PlotSessionId}:{captured.MembershipRevision}:{captured.ClaimRevision}`
                    else "Available"
                if actions:GetAttribute("Signature") == signature then
                    continue
                end
                Profile.Count("displayRebuilds", 1)
                actions:SetAttribute("Signature", signature)
                actions:ClearAllChildren()
                if captured then
                    button(actions, "LEAVE TEAM", 132, function()
                        send(plot, "LeaveTeam", nil, captured)
                    end)
                else
                    label(actions, "AVAILABLE PLOT", UDim2.fromScale(1, 28 / 200), UDim2.fromScale(0, 68 / 200))
                end
            end
        end
        for plot, display in displays do
            if not live[plot] then
                display.Actions:Destroy()
                display.Portraits:Destroy()
                displays[plot] = nil
            end
        end
        for origin, display in padLabels do
            if not liveLabels[origin] then
                display:Destroy()
                padLabels[origin] = nil
            end
        end
    end))
end
return Controller
