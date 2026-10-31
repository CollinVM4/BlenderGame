--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProtectionService = {}
local PROTECTED_SESSION_LIMIT_SECONDS = 480
type State = {
    TutorialComplete: boolean,
    TutorialPlaySeconds: number,
    ProtectionForfeited: boolean,
    AccountedAt: number,
    StageConnection: RBXScriptConnection?,
}
local states: { [Player]: State } = {}

local function eligible(state: State): boolean
    return not state.TutorialComplete
        and state.TutorialPlaySeconds < PROTECTED_SESSION_LIMIT_SECONDS
        and not state.ProtectionForfeited
end

local function settle(player: Player, state: State)
    local now = os.clock()
    if player.Parent == Players and eligible(state) then
        state.TutorialPlaySeconds =
            math.min(PROTECTED_SESSION_LIMIT_SECONDS, state.TutorialPlaySeconds + math.max(0, now - state.AccountedAt))
    end
    state.AccountedAt = now
end

function ProtectionService.AddPlayer(player: Player)
    if states[player] or player.Parent ~= Players then
        return
    end
    local state: State = {
        TutorialComplete = player:GetAttribute("TutorialStage") == "Complete",
        TutorialPlaySeconds = 0,
        ProtectionForfeited = false,
        AccountedAt = os.clock(),
        StageConnection = nil,
    }
    states[player] = state
    state.StageConnection = player:GetAttributeChangedSignal("TutorialStage"):Connect(function()
        if states[player] == state and player:GetAttribute("TutorialStage") == "Complete" then
            settle(player, state)
            state.TutorialComplete = true
        end
    end)
end

function ProtectionService.IsProtected(player: Player): boolean
    local state = states[player]
    if not state or player.Parent ~= Players then
        return false
    end
    settle(player, state)
    return eligible(state)
end

function ProtectionService.Forfeit(player: Player)
    local state = states[player]
    if state and player.Parent == Players then
        settle(player, state)
        state.ProtectionForfeited = true
    end
end

function ProtectionService.RemovePlayer(player: Player)
    local state = states[player]
    states[player] = nil
    if state and state.StageConnection then
        state.StageConnection:Disconnect()
    end
end

function ProtectionService.Init()
    -- Preserve any already-published completion on activation. Bootstrap publishes
    -- new players' initial tutorial stage synchronously before AddPlayer/gates.
    for _, player in Players:GetPlayers() do
        ProtectionService.AddPlayer(player)
    end
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt: number)
        elapsed += dt
        if elapsed < 1 then
            return
        end
        elapsed = 0
        for player, state in states do
            settle(player, state)
        end
    end)
end

return ProtectionService
