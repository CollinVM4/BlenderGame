--!strict
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Debug = {}
local window, lines, watching = 0, 0, 0

function Debug.Enabled(player: Player): boolean
    return RunService:IsStudio() and player:GetAttribute("CashRewardDebug") == true
end

function Debug.Log(player: Player, message: string)
    if not Debug.Enabled(player) then
        return
    end
    local now = os.clock()
    if now - window >= 5 then
        window, lines = now, 0
    end
    if lines < 20 then
        lines += 1
        warn("[CashReward] " .. message)
    end
end

-- Sample one real icon per burst, with at most four pending probes. Preload's
-- status survives the short-lived icon; IsLoaded catches already cached images.
function Debug.WatchImage(player: Player, view: ImageLabel)
    if not Debug.Enabled(player) or watching >= 4 then
        return
    end
    watching += 1
    local image = view.Image
    local done = false
    local changed: RBXScriptConnection? = nil
    local function finish(loaded: boolean, detail: string)
        if done then
            return
        end
        done = true
        watching -= 1
        if changed then
            changed:Disconnect()
        end
        Debug.Log(
            player,
            string.format("asset %s: %s (%s)", if loaded then "loaded" else "failed to load", image, detail)
        )
    end
    changed = view:GetPropertyChangedSignal("IsLoaded"):Connect(function()
        if view.IsLoaded then
            finish(true, "ImageLabel.IsLoaded")
        end
    end)
    if view.IsLoaded then
        finish(true, "ImageLabel.IsLoaded")
        return
    end
    task.delay(5, function()
        finish(view.IsLoaded, "five-second timeout; check asset permissions/moderation/network")
    end)
    task.spawn(function()
        local ok = pcall(function()
            ContentProvider:PreloadAsync({ image }, function(_, status)
                finish(status == Enum.AssetFetchStatus.Success, tostring(status))
            end)
        end)
        if not ok then
            finish(false, "PreloadAsync error")
        end
    end)
end

return Debug
