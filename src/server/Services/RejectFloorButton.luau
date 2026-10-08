--!strict
local RunService = game:GetService("RunService")
local TextStyle = require(game:GetService("ReplicatedStorage").Shared.Constants.DialogueTextStyle)
local FloorButton = {}

-- A downward ground query verifies actual support, rather than counting limb
-- touches from someone brushing past the plate or standing beside it.
local function standing(actor: Player, button: BasePart): boolean
    local character = actor.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
        return false
    end
    if root.AssemblyLinearVelocity.Y > 2 then
        return false
    end
    local leg = character and character:FindFirstChild("Left Leg")
    local legHeight = if leg and leg:IsA("BasePart") then leg.Size.Y else 0
    local distance = root.Size.Y / 2 + humanoid.HipHeight + legHeight + 0.5
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character :: Model }
    params.RespectCanCollide = true
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params)
    return hit ~= nil and hit.Instance == button
end

function FloorButton.Bind(
    button: BasePart,
    origin: Attachment,
    getOwner: () -> Player?,
    canActivate: (Player) -> boolean,
    activate: (Player) -> boolean
): () -> ()
    local display = Instance.new("BillboardGui")
    display.Name = "RejectFloorDisplay"
    display.Adornee = origin
    display.Size = UDim2.fromOffset(220, 56)
    display.AlwaysOnTop = true
    display.MaxDistance = 20
    display.Parent = button
    local label = Instance.new("TextLabel")
    label.Name = "Action"
    label.Size = UDim2.fromOffset(260, 48)
    label.BackgroundTransparency = 1
    label.Text = "REJECT"
    TextStyle.Apply(label, 22)
    label.TextColor3 = Color3.fromRGB(255, 95, 95)
    label.Parent = display
    local line = Instance.new("Frame")
    line.Name = "Progress"
    line.Position = UDim2.fromOffset(50, 44)
    line.Size = UDim2.fromOffset(0, 6)
    line.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    line.BorderSizePixel = 0
    line.Parent = display

    local holdDuration = 2.5
    local actor: Player? = nil
    local character: Model? = nil
    local started: number? = nil
    local latched = false
    local function reset()
        started = nil
        line.Size = UDim2.fromOffset(0, 6)
        label.Text = "REJECT"
    end
    local connection = RunService.Heartbeat:Connect(function()
        local owner = getOwner()
        if owner ~= actor or (owner and owner.Character ~= character) then
            actor = owner
            character = if owner then owner.Character else nil
            latched = false
            reset()
        end
        if not button:IsDescendantOf(workspace) or not owner or not standing(owner, button) then
            latched = false
            reset()
            return
        end
        if latched then
            return
        end
        if not canActivate(owner) then
            reset()
            return
        end
        local holdStarted = started or os.clock()
        started = holdStarted
        local progress = math.clamp((os.clock() - holdStarted) / holdDuration, 0, 1)
        line.Size = UDim2.fromOffset(120 * progress, 6)
        if progress >= 1 then
            -- Latch before gameplay callbacks, which can synchronously change
            -- the queue. Staying on the plate never rejects multiple customers.
            latched = true
            if activate(owner) then
                label.Text = "STEP OFF"
            else
                latched = false
                reset()
            end
        end
    end)
    local cleaned = false
    return function()
        if cleaned then
            return
        end
        cleaned = true
        connection:Disconnect()
        display:Destroy()
    end
end

return FloorButton
