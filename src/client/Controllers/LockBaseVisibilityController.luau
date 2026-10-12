--!strict
local Players = game:GetService("Players")
local Controller = {}
local started = false
local SHOW_DISTANCE = 6
local HIDE_DISTANCE = 7
local CHECK_INTERVAL = 0.2

function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local displays: { [BillboardGui]: boolean } = {}
    local lastCharacter: Model? = nil
    local function hideAll()
        for gui in displays do
            displays[gui] = false
            gui.Enabled = false
        end
    end
    local function register(object: Instance)
        if object:IsA("BillboardGui") and object.Name == "LockBaseDisplay" then
            displays[object] = false
            object.Enabled = false
        end
    end
    workspace.DescendantAdded:Connect(register)
    workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("BillboardGui") and displays[object] ~= nil then
            displays[object] = nil
            object.Enabled = false
        end
    end)
    player.CharacterRemoving:Connect(hideAll)
    for _, object in workspace:GetDescendants() do
        register(object)
    end
    task.spawn(function()
        while true do
            local character = player.Character
            if character ~= lastCharacter then
                hideAll()
                lastCharacter = character
            end
            local root = character and character:FindFirstChild("HumanoidRootPart")
            for gui, showing in displays do
                local attachment = gui.Adornee
                local visible = false
                if
                    root
                    and root:IsA("BasePart")
                    and root:IsDescendantOf(workspace)
                    and attachment
                    and attachment:IsA("Attachment")
                    and attachment:IsDescendantOf(workspace)
                    and gui:GetAttribute("LockBaseOccupied") == true
                then
                    local distance = (root.Position - attachment.WorldPosition).Magnitude
                    visible = distance <= (if showing then HIDE_DISTANCE else SHOW_DISTANCE)
                end
                displays[gui] = visible
                if gui.Enabled ~= visible then
                    gui.Enabled = visible
                end
            end
            task.wait(CHECK_INTERVAL)
        end
    end)
end

return Controller
