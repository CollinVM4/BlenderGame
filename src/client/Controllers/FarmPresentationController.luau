--!strict
local Players = game:GetService("Players")
local Prompts = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Constants = game:GetService("ReplicatedStorage").Shared.Constants
local Config = require(Constants.FarmConfig)
local Definitions = require(Constants.Ingredients)
local TextStyle = require(Constants.DialogueTextStyle)
local Style = require(script.Parent.Parent.UI.WorldBillboardStyle)
local Input = require(script.Parent.Parent.UI.InteractionPromptPresentation)
local Controller = {}
local started = false

local function label(gui: BillboardGui, y: number, text: string): TextLabel
    local result = Instance.new("TextLabel")
    result.Name = if y == 0 then "Title" else "Detail"
    Style.ApplyText(result, {})
    TextStyle.Apply(result, 24)
    result.Size = UDim2.new(1, 0, 0, 32)
    result.Position = UDim2.fromOffset(0, y)
    result.Text = text
    result.Parent = gui
    return result
end

local function billboard(origin: Instance, parent: Instance, height: number): BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.Name = "FarmDisplay"
    gui.Adornee = origin
    Style.ApplyBillboard(gui, { Width = 340, Height = height, MaxDistance = 40 })
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    gui.Parent = parent
    return gui
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    type Row = {
        Object: Instance,
        Origin: Attachment,
        Gui: BillboardGui,
        Title: TextLabel,
        Detail: TextLabel,
        PadGui: BillboardGui?,
        Pad: BasePart?,
        InputGui: BillboardGui?,
        InputTitle: TextLabel?,
        InputName: TextLabel?,
        Cleanup: (() -> ())?,
    }
    local rows: { [ProximityPrompt]: Row } = {}
    local function hide(prompt: ProximityPrompt)
        local row = rows[prompt]
        if row and row.Cleanup then
            row.Cleanup()
            row.Cleanup, row.InputGui, row.InputTitle, row.InputName = nil, nil, nil, nil
        end
    end
    local function bind(object: Instance)
        if not object:IsA("ProximityPrompt") or object.Name ~= "FarmPlantPrompt" or rows[object] then
            return
        end
        local origin = object.Parent
        local row = origin and origin.Parent and origin.Parent.Parent
        if not origin or not origin:IsA("Attachment") or not row then
            return
        end
        local gui = billboard(origin, playerGui, 64)
        gui.Enabled = false
        rows[object] = {
            Object = row,
            Origin = origin,
            Gui = gui,
            Title = label(gui, 0, ""),
            Detail = label(gui, 32, ""),
        }
    end
    local function refresh(prompt: ProximityPrompt, row: Row, now: number)
        local state = row.Object:GetAttribute("FarmState")
        row.Gui.Enabled = state == "GROWING" or state == "READY"
        row.Title.TextColor3 = if state == "READY" then TextStyle.Green else TextStyle.White
        row.Title.Text = if state == "READY"
            then "READY!"
            else "GROWING" .. string.rep(".", math.floor(now / 0.4) % 3 + 1)
        local deadline = row.Object:GetAttribute("FarmGrowEnd")
        local remaining = if typeof(deadline) == "number" then math.max(0, math.ceil(deadline - now)) else 0
        row.Detail.Text = if state == "GROWING"
            then string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
            else ""
        if state ~= "EMPTY" or not prompt.Enabled or not Prompts.Enabled then
            hide(prompt)
        end
        if row.InputTitle and row.InputName then
            -- InventoryService publishes its selected/fallback action target, including
            -- equipped smoothies. This is display metadata, never an activation payload.
            local id = player:GetAttribute("HeldIngredientId")
            local definition = if typeof(id) == "string" then Definitions[id] else nil
            local valid = definition ~= nil and definition.Farmable ~= false
            row.InputTitle.Text = if valid then "PLANT" else "HOLD AN INGREDIENT"
            row.InputTitle.TextTransparency = if valid then 0 else 0.35
            row.InputName.Text = if valid and definition then definition.DisplayName or definition.Id else ""
            row.InputName.TextColor3 = if definition then definition.BlendColor else TextStyle.White
            local action = row.InputGui and row.InputGui:FindFirstChild("Action")
            if action and action:IsA("TextButton") then
                action.TextTransparency = if valid then 0 else 1
                local outline = action:FindFirstChild("DialogueOutline")
                if outline and outline:IsA("UIStroke") then
                    outline.Transparency = if valid then 0 else 1
                end
            end
        end
        if row.PadGui and row.Pad and not row.Pad:IsDescendantOf(workspace) then
            row.PadGui:Destroy()
            row.PadGui, row.Pad = nil, nil
        end
        if not row.PadGui then
            local index = tonumber(string.match(row.Object.Name, "^Row(%d+)$"))
            local pad = index and row.Object:FindFirstChild("PurchasePoint" .. index)
            local price = index and Config.RowPrices[index]
            if pad and pad:IsA("BasePart") and price then
                row.Pad = pad
                local padGui = billboard(pad, playerGui, 64)
                padGui.MaxDistance = 28 -- Purchase signage only; growing/ready displays retain 40.
                row.PadGui = padGui
                label(padGui, 0, "FARM ROW")
                local amount = tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                label(padGui, 32, "$" .. amount).TextColor3 = TextStyle.Gold
            end
        end
        if row.PadGui and row.Pad then
            row.PadGui.Enabled = row.Pad:IsDescendantOf(workspace) and row.Pad.CanTouch and row.Pad.Transparency < 1
        end
    end
    workspace.DescendantAdded:Connect(bind)
    for _, object in workspace:GetDescendants() do
        bind(object)
    end
    Prompts.PromptShown:Connect(function(object, inputType)
        if not object:IsA("ProximityPrompt") then
            return
        end
        bind(object)
        local prompt = object :: ProximityPrompt
        local row = rows[prompt]
        if not row or row.Object:GetAttribute("FarmState") ~= "EMPTY" then
            return
        end
        hide(prompt)
        local cleanup, gui = Input.Create(prompt, row.Origin, playerGui, inputType, {
            InputOnly = true,
            Width = 340,
            Height = 100,
            TextSize = 24,
        })
        gui.Name = "FarmPlantDisplay"
        gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
        local action = gui:FindFirstChild("Action") :: TextButton
        TextStyle.Apply(action, 24)
        -- Full-canvas hit target; fixed padding places its key below the two labels.
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 64)
        padding.Parent = action
        row.Cleanup, row.InputGui = cleanup, gui
        row.InputTitle, row.InputName = label(gui, 0, ""), label(gui, 32, "")
        refresh(prompt, row, workspace:GetServerTimeNow())
    end)
    Prompts.PromptHidden:Connect(hide)

    -- Animate the existing model's pivot locally. No proxy models, pickup replacements,
    -- or server physics movement. Old streamed harvests do not replay their pop.
    type Pop = { Target: CFrame, Start: number }
    local pops: { [Instance]: Pop } = {}
    local function harvest(object: Instance)
        local time = object:GetAttribute("FarmSpawnTime")
        if
            object:GetAttribute("SpawnSource") ~= "Farm"
            or typeof(time) ~= "number"
            or workspace:GetServerTimeNow() - time > Config.HarvestPopSeconds
            or not (object:IsA("BasePart") or object:IsA("Model"))
        then
            return
        end
        pops[object] = { Target = object:GetPivot(), Start = time }
    end
    CollectionService:GetInstanceAddedSignal("IngredientWorldItem"):Connect(harvest)
    for _, object in CollectionService:GetTagged("IngredientWorldItem") do
        harvest(object)
    end
    local elapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        local now = workspace:GetServerTimeNow()
        for object, pop in pops do
            if not object:IsDescendantOf(workspace) or object:GetAttribute("FrozenUntilPickup") ~= true then
                pops[object] = nil
            elseif object:IsA("Model") or object:IsA("BasePart") then
                local alpha = math.clamp((now - pop.Start) / math.max(0.001, Config.HarvestPopSeconds), 0, 1)
                local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                object:PivotTo(pop.Target + Vector3.new(0, -Config.HarvestPopDepth * (1 - eased), 0))
                if alpha >= 1 then
                    object:PivotTo(pop.Target)
                    pops[object] = nil
                end
            end
        end
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0
        for prompt, row in rows do
            if not prompt:IsDescendantOf(workspace) then
                hide(prompt)
                row.Gui:Destroy()
                if row.PadGui then
                    row.PadGui:Destroy()
                end
                rows[prompt] = nil
            else
                refresh(prompt, row, now)
            end
        end
    end)
end

return Controller
