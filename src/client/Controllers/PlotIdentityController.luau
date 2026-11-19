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
local PORTRAIT_BILLBOARD_WIDTH = 16.5
local PORTRAIT_BILLBOARD_HEIGHT = 8.2
local PORTRAIT_SIZE = 5.75
local HOME_PORTRAIT_PIXELS = 48
local THUMBNAIL_RETRY_SECONDS = 10
type PortraitView = { Headshot: ImageLabel, Fallback: TextLabel }
type PlotDisplay = { Available: BillboardGui, Portraits: BillboardGui, Owner: PortraitView?, Teammate: PortraitView? }
local portraits: { [number]: { Image: string, RetryAt: number } } = {}
local displays: { [Instance]: PlotDisplay } = {}
local padLabels: { [Instance]: BillboardGui } = {}
local initialized = false
local function portrait(id: number): string
    -- Studio multiplayer uses synthetic players without a Roblox account thumbnail.
    if id <= 0 then
        return ""
    end
    local entry = portraits[id]
    if not entry then
        entry = { Image = "", RetryAt = 0 }
        portraits[id] = entry
    end
    if os.clock() >= entry.RetryAt then
        entry.RetryAt = math.huge
        task.spawn(function()
            local ok, url, ready = pcall(function()
                return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            end)
            if ok and ready and url ~= "" then
                entry.Image = url
            else
                entry.RetryAt = os.clock() + THUMBNAIL_RETRY_SECONDS
            end
        end)
    end
    return entry.Image
end
local function label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
    local result = Instance.new("TextLabel")
    result.BackgroundTransparency = 1
    result.Size, result.Position = size, position
    local billboard = if parent:IsA("BillboardGui")
        then parent
        else parent:FindFirstAncestorWhichIsA("BillboardGui") :: BillboardGui?
    TextStyle.Apply(result, 17, billboard)
    result.TextScaled = billboard ~= nil
    result.Text = text
    result.Parent = parent
    return result
end
local function addPortrait(
    display: BillboardGui,
    centerX: number,
    id: number,
    name: string,
    ownBase: boolean
): PortraitView
    local badge = Instance.new("Frame")
    badge.Name = "PortraitBadge"
    badge.AnchorPoint = Vector2.new(0.5, 0)
    badge.Size = if ownBase
        then UDim2.fromOffset(HOME_PORTRAIT_PIXELS, HOME_PORTRAIT_PIXELS)
        else UDim2.fromScale(PORTRAIT_SIZE / PORTRAIT_BILLBOARD_WIDTH, PORTRAIT_SIZE / PORTRAIT_BILLBOARD_HEIGHT)
    badge.Position = if ownBase then UDim2.new(centerX, 0, 0, 4) else UDim2.fromScale(centerX, 0.04)
    badge.BackgroundColor3 = if ownBase then TextStyle.Gold else TextStyle.White
    badge.BorderSizePixel = 0
    badge.Active = false
    badge.Parent = display
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)
    BillboardStyle.ApplyWorldStroke(badge, display, { Color = TextStyle.Dark, ThicknessStuds = 0.14 })

    local head = Instance.new("ImageLabel")
    head.Name = "Headshot"
    head.Size = UDim2.fromScale(0.86, 0.86)
    head.Position = UDim2.fromScale(0.07, 0.07)
    head.BackgroundColor3 = if id % 2 == 0 then Color3.fromRGB(36, 155, 212) else Color3.fromRGB(26, 163, 141)
    head.BorderSizePixel = 0
    head.Active = false
    head.Parent = badge
    Instance.new("UICorner", head).CornerRadius = UDim.new(0.5, 0)
    local initials = if id < 0 then `P{-id}` elseif name ~= "" then string.upper(string.sub(name, 1, 1)) else "?"
    local fallback = label(head, initials, UDim2.fromScale(0.7, 0.62), UDim2.fromScale(0.15, 0.19))
    fallback.Name = "PortraitFallback"
    fallback.Active = false
    fallback.ZIndex = 2

    local nameSize = if ownBase then UDim2.new(0.48, 0, 0, 16) else UDim2.fromScale(0.48, 0.19)
    local namePosition = if ownBase then UDim2.new(centerX, 0, 0, 54) else UDim2.fromScale(centerX, 0.77)
    local nameLabel = label(display, name, nameSize, namePosition)
    nameLabel.AnchorPoint = Vector2.new(0.5, 0)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Active = false
    return { Headshot = head, Fallback = fallback }
end
local function updatePortrait(view: PortraitView, id: number)
    local image = portrait(id)
    if view.Headshot.Image ~= image then
        view.Headshot.Image = image
    end
    view.Fallback.Visible = image == "" or not view.Headshot.IsLoaded
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
                local available = Instance.new("BillboardGui")
                available.Name = "PlotIdentity"
                BillboardStyle.ApplyBillboard(
                    available,
                    { WidthStuds = 9, HeightStuds = 6.36, MaxDistance = 60, ResetOnSpawn = true }
                )
                available.Active = false
                local message =
                    label(available, "AVAILABLE PLOT", UDim2.fromScale(1, 28 / 200), UDim2.fromScale(0, 68 / 200))
                message.Active = false
                available.Parent = gui

                local marker = Instance.new("BillboardGui")
                marker.Name = "PlotPortraits"
                marker.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
                marker.Active = false
                marker.Parent = gui
                display = { Available = available, Portraits = marker }
                displays[plot] = display
            end
            local available, marker = display.Available, display.Portraits
            available.Adornee, marker.Adornee = origin, origin
            local owner = plot:GetAttribute("OwnerUserId")
            local teammate = plot:GetAttribute("TeammateUserId")
            available.Enabled = type(owner) ~= "number"
            marker.Enabled = type(owner) == "number"
            if type(owner) == "number" then
                local ownerName = tostring(plot:GetAttribute("PlotOwnerName") or "")
                local teammateName = tostring(plot:GetAttribute("PlotTeammateName") or "")
                local signature = `{owner}:{teammate}:{ownerName}:{teammateName}`
                if marker:GetAttribute("Signature") ~= signature then
                    Profile.Count("displayRebuilds", 1)
                    marker:SetAttribute("Signature", signature)
                    marker:ClearAllChildren()
                    local ownBase = owner == player.UserId or teammate == player.UserId
                    -- Only the player's base needs to keep its screen size for wayfinding.
                    BillboardStyle.ApplyBillboard(
                        marker,
                        if ownBase
                            then {
                                PixelSize = Vector2.new(152, 108),
                                MaxDistance = 360,
                                AlwaysOnTop = true,
                                ResetOnSpawn = true,
                            }
                            else {
                                WidthStuds = PORTRAIT_BILLBOARD_WIDTH,
                                HeightStuds = PORTRAIT_BILLBOARD_HEIGHT,
                                MaxDistance = 240,
                                AlwaysOnTop = true,
                                ResetOnSpawn = true,
                            }
                    )
                    marker.SizeOffset = Vector2.new(0, if ownBase then 0.25 else 0)
                    display.Owner =
                        addPortrait(marker, if type(teammate) == "number" then 0.25 else 0.5, owner, ownerName, ownBase)
                    display.Teammate = if type(teammate) == "number"
                        then addPortrait(marker, 0.75, teammate, teammateName, ownBase)
                        else nil
                end
                if display.Owner then
                    updatePortrait(display.Owner, owner)
                end
                if display.Teammate and type(teammate) == "number" then
                    updatePortrait(display.Teammate, teammate)
                end
            end
        end
        for plot, display in displays do
            if not live[plot] then
                display.Available:Destroy()
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
