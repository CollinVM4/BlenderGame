--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.IceGunConfig)
local Service = {}
local deps: any
type State = { Character: Model, Until: number, ImmuneUntil: number, Active: boolean }
local states: { [Player]: State } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

function Service.Init(services)
    deps = services
end

function Service.Clear(player: Player)
    local state = states[player]
    states[player] = nil
    if state then
        state.Character:SetAttribute("FrozenUntil", nil)
        deps.IceGunEffects.ClearFreeze(state.Character, false)
    end
    deps.MovementService.SetFrozen(player, false)
end

function Service.Apply(player: Player): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then
        return false
    end
    local previous = states[player]
    local now = os.clock()
    if previous and previous.Character == character and (previous.Active or now < previous.ImmuneUntil) then
        return false
    end
    local state: State = {
        Character = character,
        Until = now + Config.FreezeSeconds,
        ImmuneUntil = now + Config.FreezeSeconds + Config.ImmunitySeconds,
        Active = true,
    }
    states[player] = state
    deps.MovementService.SetFrozen(player, true)
    character:SetAttribute("FrozenUntil", workspace:GetServerTimeNow() + Config.FreezeSeconds)
    deps.IceGunEffects.Freeze(character)
    task.delay(Config.FreezeSeconds, function()
        if states[player] ~= state or player.Character ~= character then
            return
        end
        state.Active = false
        -- Immunity starts at actual thaw, including a delayed server frame.
        state.ImmuneUntil = os.clock() + Config.ImmunitySeconds
        deps.MovementService.SetFrozen(player, false)
        character:SetAttribute("FrozenUntil", nil)
        deps.IceGunEffects.ClearFreeze(character, true)
    end)
    return true
end

function Service.ApplyCharacter(player: Player, character: Model)
    Service.RemovePlayer(player)
    local list: { RBXScriptConnection } = {}
    connections[player] = list
    table.insert(
        list,
        player.CharacterRemoving:Connect(function(old)
            if old == character then
                Service.Clear(player)
            end
        end)
    )
    task.spawn(function()
        local h = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if connections[player] == list and player.Character == character and h and h:IsA("Humanoid") then
            table.insert(
                list,
                h.Died:Connect(function()
                    Service.Clear(player)
                end)
            )
        end
    end)
end

function Service.RemovePlayer(player: Player)
    Service.Clear(player)
    for _, connection in (connections[player] or {}) :: { RBXScriptConnection } do
        connection:Disconnect()
    end
    connections[player] = nil
end

return Service
