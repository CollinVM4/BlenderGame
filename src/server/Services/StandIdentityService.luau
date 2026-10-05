--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Config = require(ReplicatedStorage.Shared.Constants.StandIdentity)
local Sanitizer = require(script.Parent.StandNameSanitizer)
local Service = {}
local authority: any
local pending: { [Player]: boolean } = {}
local nextSave: { [Player]: number } = {}

local function valid(player: Player, plot: any, context: any): boolean
    return player.Parent ~= nil
        and typeof(plot) == "Instance"
        and authority.GetPlot(player) == plot
        and authority.GetOwner(plot) == player
        and authority.ValidateActor(player, context)
        and type(context) == "table"
        and context.StandNameRevision == plot:GetAttribute("StandNameRevision")
end

function Service.RequestName(player: Player, plot: any, value: any, context: any): (boolean, string)
    local text = Config.Normalize(value)
    if not text then
        return false, string.format("Enter a name of 1–%d characters.", Config.MaxCharacters)
    end
    if not valid(player, plot, context) then
        return false, "Stand ownership changed."
    end
    if pending[player] or os.clock() < (nextSave[player] or 0) then
        return false, "Please wait before saving again."
    end
    -- Copy submitted context across the yielding filter, never repair it afterward.
    local captured = table.clone(context)
    pending[player] = true
    nextSave[player] = os.clock() + Config.SaveCooldown
    local ok, result = pcall(function()
        -- Four stars can expand a short token. Fit only after raw validation;
        -- this never lets an oversized client submission bypass the limit.
        return TextService:FilterStringAsync(
            Config.Truncate(Sanitizer.Mask(text)),
            player.UserId,
            Enum.TextFilterContext.PublicChat
        ):GetNonChatStringForBroadcastAsync()
    end)
    pending[player] = nil
    local filtered = if ok
            and type(result) == "string"
            and #result <= Config.MaxInputBytes
        then Config.Normalize(Config.Truncate(Sanitizer.BroadcastDisplay(result)))
        else nil
    if not filtered then
        return false, "Name unavailable. Try another name."
    end
    if not valid(player, plot, captured) or not authority.CommitFilteredStandName(player, plot, filtered, captured) then
        return false, "Stand ownership changed."
    end
    return true, filtered
end

function Service.Init(services: any)
    authority = services.TycoonService
    local remote = Instance.new("RemoteFunction")
    remote.Name = "SetStandName"
    remote.OnServerInvoke = Service.RequestName
    remote.Parent = ReplicatedStorage.Shared.Events
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        pending[player], nextSave[player] = nil, nil
    end)
end

return Service
