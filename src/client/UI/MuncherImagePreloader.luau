--!strict
local ContentProvider = game:GetService("ContentProvider")
local Artwork = require(game:GetService("ReplicatedStorage").Shared.Constants.MuncherArtwork)
local started = false
local Preloader = {}

-- Called during binding, never from a reel update. Failed/slow requests cannot
-- block animation. Each image is attempted once per client; labels remain usable.
function Preloader.Start()
    if started then
        return
    end
    started = true
    task.defer(function()
        local uris = {}
        local seen: { [string]: boolean } = {}
        for id in Artwork.Images do
            local uri = Artwork.GetMuncherIngredient(id)
            if uri ~= "" and not seen[uri] then
                seen[uri] = true
                table.insert(uris, uri)
            end
        end
        table.sort(uris)
        for first = 1, #uris, 4 do
            local batch = {}
            for index = first, math.min(first + 3, #uris) do
                table.insert(batch, uris[index])
            end
            -- Yielding requests are isolated so one unavailable batch cannot
            -- prevent subsequent batches from starting.
            task.spawn(function()
                pcall(function()
                    ContentProvider:PreloadAsync(batch)
                end)
            end)
            task.wait(0.1)
        end
    end)
end

return Preloader
