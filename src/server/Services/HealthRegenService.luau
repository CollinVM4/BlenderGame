--!strict
-- Passive server regeneration. StarterCharacterScripts.Health replaces Roblox's
-- default regen script; Humanoid.Health remains the sole health authority.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.HealthRegen)
local HealthRegenService = {}

type State = {
    Humanoid: Humanoid,
    LastDamageAt: number,
    Connections: { RBXScriptConnection },
}
local states: { [Player]: State } = {}
local heartbeat: RBXScriptConnection? = nil

function HealthRegenService.RemovePlayer(player: Player)
    local state = states[player]
    if state then
        for _, connection in state.Connections do
            connection:Disconnect()
        end
        states[player] = nil
    end
end

function HealthRegenService.ApplyCharacter(player: Player, character: Model)
    HealthRegenService.RemovePlayer(player)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end
    local state: State = {
        Humanoid = humanoid,
        LastDamageAt = os.clock(),
        Connections = {},
    }
    states[player] = state
    -- Observation only: never restore this value to Health. Using the signal
    -- catches damage followed by healing between two Heartbeats.
    local previousHealth = humanoid.Health
    table.insert(
        state.Connections,
        humanoid.HealthChanged:Connect(function(health: number)
            if states[player] ~= state then
                return
            end
            if health < previousHealth then
                state.LastDamageAt = os.clock()
            end
            previousHealth = health
        end)
    )
    local function cleanup()
        if states[player] == state then
            HealthRegenService.RemovePlayer(player)
        end
    end
    table.insert(state.Connections, humanoid.Died:Connect(cleanup))
    table.insert(
        state.Connections,
        player.CharacterRemoving:Connect(function(removing: Model)
            if removing == character then
                cleanup()
            end
        end)
    )
end

function HealthRegenService.Init()
    if heartbeat then
        return
    end
    heartbeat = RunService.Heartbeat:Connect(function(dt: number)
        local now = os.clock()
        for player, state in states do
            local humanoid = state.Humanoid
            if humanoid.Health <= 0 or not humanoid.Parent then
                HealthRegenService.RemovePlayer(player)
                continue
            end
            -- Only credit the portion of this frame after the damage delay.
            local elapsed = math.min(dt, now - state.LastDamageAt - Config.HealthRegenDelaySeconds)
            if elapsed > 0 and humanoid.Health < humanoid.MaxHealth then
                humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.HealthRegenPerSecond * elapsed)
            end
        end
    end)
end

return require(script.Parent.StudioServices).Wrap("HealthRegenService", HealthRegenService)
