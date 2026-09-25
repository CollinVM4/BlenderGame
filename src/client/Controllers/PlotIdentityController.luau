--!strict
-- Replicated identity is presentation only. Every action is revalidated by the server.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextStyle = require(ReplicatedStorage.Shared.Constants.DialogueTextStyle)
local Controller = {}
local player = Players.LocalPlayer
local portraits: { [number]: string } = {}
local pending: { [number]: boolean } = {}
local displays: { [Instance]: BillboardGui } = {}
local initialized = false
local friends: { [number]: boolean } = {}
local checkingFriends: { [number]: boolean } = {}
local nextFriendCheck: { [number]: number } = {}
local function isFriend(id: number): boolean
    if os.clock() >= (nextFriendCheck[id] or 0) and not checkingFriends[id] then
        checkingFriends[id] = true
        task.spawn(function()
            local ok, result = pcall(function()
                return player:IsFriendsWithAsync(id)
            end)
            friends[id] = ok and result == true
            nextFriendCheck[id] = os.clock() + 30
            checkingFriends[id] = nil
        end)
    end
    return friends[id] == true
end
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
    TextStyle.Apply(result, 17)
    result.Text = text
    result.Parent = parent
    return result
end
local function button(parent: Instance, text: string, y: number, callback: () -> ()): TextButton
    local result = Instance.new("TextButton")
    result.Size = UDim2.new(1, -24, 0, 30)
    result.AnchorPoint = Vector2.new(0.5, 0.5)
    result.Position = UDim2.new(0.5, 0, 0, y + 15)
    result.BackgroundColor3 = Color3.fromRGB(35, 92, 108)
    result.BorderSizePixel = 0
    TextStyle.Apply(result, 17)
    result.Text = text
    result.Parent = parent
    Instance.new("UICorner", result).CornerRadius = UDim.new(0, 12)
    local border = Instance.new("UIStroke")
    border.Name = "ButtonOutline"
    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    border.Color, border.Thickness = TextStyle.Dark, 3
    border.Parent = result
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
    gui.Name, gui.ResetOnSpawn = "PlotManagement", false
    gui.Parent = player:WaitForChild("PlayerGui")
    local status = label(gui, "", 70)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(280, 300)
    panel.Position = UDim2.new(0.5, -140, 0.5, -150)
    panel.BackgroundColor3 = Color3.fromRGB(23, 30, 40)
    panel.Visible = false
    panel.Parent = gui
    Instance.new("UICorner", panel)
    local managed: Instance? = nil
    local managedRevision: any = nil
    local modeRows: { [string]: TextButton } = {}
    local selectionTweens: { Tween } = {}
    local selectedMode: any = nil
    local modeTitles = { Open = "PUBLIC", FriendsOnly = "FRIENDS", Closed = "PRIVATE" }
    local function updateSelection(mode: any, animate: boolean)
        for _, tween in selectionTweens do
            tween:Cancel()
        end
        table.clear(selectionTweens)
        selectedMode = mode
        for value, row in modeRows do
            local selected = value == mode
            row.Text = (if selected then "SELECTED: " else "") .. modeTitles[value]
            row.TextColor3 = if selected then TextStyle.White else Color3.fromRGB(205, 215, 226)
            local fill = if selected then Color3.fromRGB(45, 159, 123) else Color3.fromRGB(43, 56, 70)
            local scale = row:FindFirstChild("SelectionScale") :: UIScale
            local border = row:FindFirstChild("ButtonOutline") :: UIStroke
            border.Color = if selected then TextStyle.Gold else TextStyle.Dark
            border.Thickness = if selected then 3.5 else 2
            local size = if selected then 1.1 else 1
            if animate then
                for _, tween in
                    {
                        TweenService:Create(
                            scale,
                            TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Scale = size }
                        ),
                        TweenService:Create(row, TweenInfo.new(0.16), { BackgroundColor3 = fill }),
                    }
                do
                    table.insert(selectionTweens, tween)
                    tween:Play()
                end
            else
                scale.Scale = size
                row.BackgroundColor3 = fill
            end
        end
    end
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
    local function openManage(plot: Instance)
        local previousMode = if managed == plot and panel.Visible then selectedMode else nil
        for _, tween in selectionTweens do
            tween:Cancel()
        end
        table.clear(selectionTweens)
        table.clear(modeRows)
        panel:ClearAllChildren()
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
        managed = plot
        local captured = context(plot)
        managedRevision = captured.MembershipRevision
        label(panel, "MANAGE PLOT", 8)
        label(panel, tostring(plot:GetAttribute("PlotTeammateName") or "Empty Slot"), 38)
        local teammate = plot:GetAttribute("TeammateUserId")
        if type(teammate) == "number" then
            local head = Instance.new("ImageLabel")
            head.Size, head.Position = UDim2.fromOffset(36, 36), UDim2.fromOffset(8, 32)
            head.Image, head.BackgroundTransparency, head.Parent = portrait(teammate), 1, panel
            Instance.new("UICorner", head).CornerRadius = UDim.new(1, 0)
        end
        for index, mode in { "Open", "FriendsOnly", "Closed" } do
            local row = button(panel, modeTitles[mode], 74 + (index - 1) * 36, function()
                send(plot, "SetJoinMode", mode, captured)
            end)
            row.Size = UDim2.new(1, -32, 0, 28) -- Leave space for the selected scale and outline.
            row.AutoButtonColor = false
            local scale = Instance.new("UIScale")
            scale.Name, scale.Scale, scale.Parent = "SelectionScale", 1, row
            modeRows[mode] = row
        end
        local mode = plot:GetAttribute("JoinMode")
        updateSelection(if previousMode ~= nil then previousMode else mode, false)
        if previousMode ~= nil and previousMode ~= mode then
            updateSelection(mode, true)
        end
        if teammate then
            button(panel, "KICK TEAMMATE", 186, function()
                send(plot, "KickTeammate", teammate, captured)
            end)
        end
        button(panel, "CLOSE", 252, function()
            managed = nil
            panel.Visible = false
        end)
        panel.Visible = true
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
        local assigned = player:GetAttribute("PlotSessionId") ~= nil
        status.Text = if os.clock() < failureUntil
            then "Plot action unavailable. Move closer or try again."
            elseif not assigned then "UNASSIGNED - Walk to a plot to claim or join"
            else ""
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local live: { [Instance]: boolean } = {}
        for _, plot in CollectionService:GetTagged("PlayerPlot") do
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
                display.Size = UDim2.fromOffset(280, 200)
                display.ClipsDescendants = false -- Allow fixed-width member columns around the existing action footprint.
                display.AlwaysOnTop, display.MaxDistance, display.Active = true, 160, true
                display.Parent = gui
                displays[plot] = display
            end
            local display = displays[plot]
            display.Adornee = origin
            local owner = plot:GetAttribute("OwnerUserId")
            local teammate = plot:GetAttribute("TeammateUserId")
            local position = if origin:IsA("Attachment") then origin.WorldPosition else (origin :: BasePart).Position
            local nearby = root and root:IsA("BasePart") and (root.Position - position).Magnitude <= 32
            local action = if not nearby
                then nil
                elseif owner == player.UserId then "MANAGE PLOT"
                elseif teammate == player.UserId then "LEAVE TEAM"
                elseif not assigned and not owner then "CLAIM PLOT"
                elseif
                    not assigned
                    and not teammate
                    and type(owner) == "number"
                    and (
                        plot:GetAttribute("JoinMode") == "Open"
                        or (plot:GetAttribute("JoinMode") == "FriendsOnly" and isFriend(owner))
                    )
                then "JOIN TEAM"
                else nil
            -- Local friendship only controls visibility; the server checks independently.
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
                        head.Size, head.Position = UDim2.fromOffset(64, 64), UDim2.fromOffset(x, 0)
                        head.Image, head.BackgroundTransparency, head.Parent = portrait(id), 1, display
                        Instance.new("UICorner", head).CornerRadius = UDim.new(1, 0)
                        local nameLabel = label(display, name, 72)
                        nameLabel.TextSize = 24
                        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                        local width = if teammate then 260 else 420
                        nameLabel.Size = UDim2.fromOffset(width, 32)
                        nameLabel.Position = UDim2.fromOffset(x + 32 - width / 2, 72)
                        if role ~= "" then
                            local roleLabel = label(display, role, 106)
                            roleLabel.Size, roleLabel.Position =
                                UDim2.fromOffset(width, 24), UDim2.fromOffset(x + 32 - width / 2, 106)
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
                        if action == "MANAGE PLOT" then
                            openManage(plot)
                        else
                            send(
                                plot,
                                if action == "CLAIM PLOT"
                                    then "ClaimPlot"
                                    elseif action == "JOIN TEAM" then "JoinTeam"
                                    else "LeaveTeam",
                                nil,
                                captured
                            )
                        end
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
        if managed then
            if not live[managed] or managed:GetAttribute("OwnerUserId") ~= player.UserId then
                managed = nil
                panel.Visible = false
            elseif managed:GetAttribute("PlotMembershipRevision") ~= managedRevision then
                openManage(managed)
            elseif managed:GetAttribute("JoinMode") ~= selectedMode then
                updateSelection(managed:GetAttribute("JoinMode"), true)
            end
        end
    end)
end
return Controller
