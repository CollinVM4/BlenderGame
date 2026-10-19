--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.CarryPresentation)
local Controller = {}
local teardown: (() -> ())? = nil

local function disconnect(connections: { RBXScriptConnection })
    for _, connection in connections do
        connection:Disconnect()
    end
    table.clear(connections)
end

function Controller.Destroy()
    if teardown then
        teardown()
        teardown = nil
    end
end

function Controller.Init()
    if teardown or Config.IngredientHoldAnimationId == "" then
        return
    end
    local player = Players.LocalPlayer
    local playerConnections: { RBXScriptConnection } = {}
    local characterConnections: { RBXScriptConnection } = {}
    local toolConnections: { RBXScriptConnection } = {}
    local selected: Tool? = nil
    local track: AnimationTrack? = nil
    local animation = Instance.new("Animation")
    animation.AnimationId = Config.IngredientHoldAnimationId

    local function stop()
        local previous = track
        track = nil
        if previous then
            previous:Stop(0)
            previous:Destroy()
        end
    end
    local function clearTool()
        selected = nil
        stop()
        disconnect(toolConnections)
    end
    local function clearCharacter()
        clearTool()
        disconnect(characterConnections)
    end
    local function bind(character: Model)
        clearCharacter()
        local function refresh()
            local tool = selected
            if not tool or tool.Parent ~= character or player.Character ~= character then
                stop()
                return
            end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if tool:GetAttribute("ItemType") ~= "Ingredient" or not humanoid or humanoid.Health <= 0 then
                stop()
                return
            end
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if track or not animator then
                return
            end
            -- Only use the replicated Animator. Late replication retries via DescendantAdded.
            local ok, loaded = pcall(function()
                return animator:LoadAnimation(animation)
            end)
            if not ok then
                return
            end
            loaded.Priority = Enum.AnimationPriority.Action
            loaded.Looped = true
            track = loaded
            local played = pcall(function()
                loaded:Play(0.1, 1, 1)
            end)
            if not played then
                stop()
            end
        end
        local function equipped(child: Instance)
            if not child:IsA("Tool") then
                return
            end
            clearTool() -- Yield immediately to any newly equipped non-ingredient Tool.
            selected = child
            table.insert(toolConnections, child:GetAttributeChangedSignal("ItemType"):Connect(refresh))
            table.insert(toolConnections, child.Unequipped:Connect(clearTool))
            table.insert(toolConnections, child.Destroying:Connect(clearTool))
            table.insert(
                toolConnections,
                child.AncestryChanged:Connect(function()
                    if child.Parent ~= character then
                        clearTool()
                    end
                end)
            )
            refresh()
        end
        local function descendantAdded(child: Instance)
            if child:IsA("Humanoid") then
                table.insert(characterConnections, child.Died:Connect(clearTool))
                refresh()
            elseif child:IsA("Animator") then
                refresh()
            end
        end
        table.insert(characterConnections, character.ChildAdded:Connect(equipped))
        table.insert(characterConnections, character.DescendantAdded:Connect(descendantAdded))
        for _, child in character:GetDescendants() do
            if child:IsA("Humanoid") then
                descendantAdded(child)
            end
        end
        for _, child in character:GetChildren() do
            equipped(child)
        end
    end
    teardown = function()
        clearCharacter()
        disconnect(playerConnections)
        animation:Destroy()
    end
    table.insert(playerConnections, player.CharacterAdded:Connect(bind))
    table.insert(playerConnections, player.CharacterRemoving:Connect(clearCharacter))
    table.insert(
        playerConnections,
        Players.PlayerRemoving:Connect(function(leaving)
            if leaving == player then
                Controller.Destroy()
            end
        end)
    )
    if player.Character then
        bind(player.Character)
    end
end

return Controller
