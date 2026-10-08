--!strict
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local Config = require(script.Parent.AdminConfig)

local AdminService = {}
local deps: any
local initialized = false
local adminUserIds: { [number]: boolean } = {}
local lastExecution: { [Player]: number? } = {}
local chatConnections: { [Player]: RBXScriptConnection } = {}

local commands: { [string]: (Player, { string }) -> boolean } = {}
commands.addcash = function(player: Player, args: { string }): boolean
    local amount = if #args == 1 then tonumber(args[1]) else nil
    if not amount or amount ~= amount or amount <= 0 or amount > Config.MaxAddCash then
        warn("[Admin] Rejected addCash amount " .. table.concat(args, " "))
        return false
    end
    amount = math.floor(amount)
    if amount == 0 then
        warn("[Admin] addCash amount must floor to a positive integer")
        return false
    end
    if not deps.TycoonService.GetSessionId(player) then
        warn("[Admin] addCash requires an active plot/session for " .. player.Name)
        return false
    end
    local before = deps.TycoonService.GetCash(player)
    local balance = deps.TycoonService.AddCash(player, amount)
    if balance ~= before + amount then
        warn("[Admin] addCash could not commit for " .. player.Name)
        return false
    end
    print(string.format("[Admin] %s (%d) executed addCash %d -> %.0f", player.Name, player.UserId, amount, balance))
    return true
end

-- Only server chat callbacks call this dispatcher; there is no admin remote.
function AdminService.HandleCommand(player: Player, message: string): boolean
    if player.Parent ~= Players or not adminUserIds[player.UserId] then
        return false
    end
    local name, remainder = string.match(message, "^%s*;(%S+)%s*(.*)$")
    if not name then
        return false
    end
    local now = os.clock()
    local previous = lastExecution[player]
    if previous and now - previous < Config.CommandCooldownSeconds then
        return false
    end
    local command = commands[string.lower(name)]
    if not command then
        warn("[Admin] Unknown command " .. name)
        return false
    end
    local args = {}
    for argument in string.gmatch(remainder or "", "%S+") do
        table.insert(args, argument)
    end
    -- Reserve before publishing cash, which can invoke immediate server signals.
    lastExecution[player] = now
    local ok, accepted = pcall(command, player, args)
    if not ok or not accepted then
        lastExecution[player] = previous
        if not ok then
            warn("[Admin] Command failed for " .. player.Name .. ": " .. tostring(accepted))
        end
        return false
    end
    return true
end

function AdminService.RemovePlayer(player: Player)
    lastExecution[player] = nil
    local connection = chatConnections[player]
    if connection then
        connection:Disconnect()
        chatConnections[player] = nil
    end
end

function AdminService.Init(services: any)
    if initialized then
        return
    end
    initialized = true
    deps = services
    for _, userId in Config.AdminUserIds do
        adminUserIds[userId] = true
    end
    -- Each name is attempted once. Failed lookups fail closed without delaying bootstrap.
    for _, username in Config.BootstrapUsernames do
        task.spawn(function()
            local ok, userId = pcall(function()
                return Players:GetUserIdFromNameAsync(username)
            end)
            if ok and type(userId) == "number" and userId > 0 and userId < math.huge and userId % 1 == 0 then
                adminUserIds[userId] = true
                print(string.format("[Admin] %s -> %d", username, userId))
            else
                warn("[Admin] Could not resolve " .. username .. "; no bootstrap permission granted")
            end
        end)
    end

    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        for name in commands do
            local command = Instance.new("TextChatCommand")
            command.Name = "Admin_" .. name
            command.PrimaryAlias = ";" .. name
            command.AutocompleteVisible = false
            command.Triggered:Connect(function(source: TextSource, message: string)
                local player = Players:GetPlayerByUserId(source.UserId)
                if player then
                    AdminService.HandleCommand(player, message)
                end
            end)
            command.Parent = TextChatService
        end
    else
        local function bindPlayer(player: Player)
            if not chatConnections[player] then
                chatConnections[player] = player.Chatted:Connect(function(message)
                    AdminService.HandleCommand(player, message)
                end)
            end
        end
        Players.PlayerAdded:Connect(bindPlayer)
        for _, player in Players:GetPlayers() do
            bindPlayer(player)
        end
    end
    Players.PlayerRemoving:Connect(AdminService.RemovePlayer)
end

return AdminService
