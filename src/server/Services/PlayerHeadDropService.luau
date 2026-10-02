--!strict
-- Observe actual character death; damage and ingredient ownership stay in their services.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Item = require(game:GetService("ReplicatedStorage").Shared.IngredientItem)
local Service = {}
local deps: any
local states: { [Player]: { Character: Model, Connections: { RBXScriptConnection } } } = {}
-- Retain the guard through teardown/rebinding, without keeping old characters alive.
local observed = setmetatable({} :: { [Model]: boolean }, { __mode = "k" })

function Service.Init(services: any)
    deps = services
end

function Service.RemovePlayer(player: Player)
    local state = states[player]
    if state then
        states[player] = nil
        for _, connection in state.Connections do
            connection:Disconnect()
        end
    end
end

function Service.ApplyCharacter(player: Player, character: Model)
    if player.Character ~= character or Players:GetPlayerFromCharacter(character) ~= player then
        return
    end
    if states[player] and states[player].Character == character then
        return
    end
    Service.RemovePlayer(player)
    if observed[character] then
        return
    end
    observed[character] = true
    local state = { Character = character, Connections = {} :: { RBXScriptConnection } }
    states[player] = state
    local bound, dropped = false, false
    local function bind(humanoid: Humanoid)
        if bound or states[player] ~= state then
            return
        end
        bound = true
        table.insert(
            state.Connections,
            humanoid.Died:Connect(function()
                if
                    dropped
                    or states[player] ~= state
                    or player.Character ~= character
                    or Players:GetPlayerFromCharacter(character) ~= player
                then
                    return
                end
                dropped = true -- Reserve before spawning or publishing any world item.
                local at = character:GetPivot()
                for _, name in { "Head", "UpperTorso", "HumanoidRootPart" } do
                    local part = character:FindFirstChild(name)
                    if part and part:IsA("BasePart") then
                        at = part.CFrame
                        break
                    end
                end
                local unit = Item.New("PlayerHead", HttpService:GenerateGUID(false))
                unit.SourceUserId = player.UserId
                unit.SourceDisplayName = player.DisplayName
                unit.SourceUsername = player.Name
                deps.IngredientService.Spawn(
                    "PlayerHead",
                    CFrame.new(at.Position + Vector3.new(0.75, 0.5, 0)),
                    nil,
                    true,
                    {
                        Item = unit,
                        VisualTemplate = character:FindFirstChild("Head"),
                    }
                )
            end)
        )
    end
    table.insert(
        state.Connections,
        player.CharacterRemoving:Connect(function(removing: Model)
            if removing == character and states[player] == state then
                Service.RemovePlayer(player)
            end
        end)
    )
    -- CharacterAdded may arrive before the Humanoid. Bind without blocking bootstrap.
    table.insert(
        state.Connections,
        character.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then
                bind(child)
            end
        end)
    )
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        bind(humanoid)
    end
end

return require(script.Parent.StudioServices).Wrap("PlayerHeadDropService", Service)
