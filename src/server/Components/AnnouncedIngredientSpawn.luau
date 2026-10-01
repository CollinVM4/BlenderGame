--!strict
--! Server script for announcing rare ingredient spawns to clients.
local IngredientSpawn = require(script.Parent.IngredientSpawn)
local AnnouncedIngredientSpawn = {}
local started = false

function AnnouncedIngredientSpawn.Init(services: any)
    if started then
        return
    end
    started = true
    IngredientSpawn.Bind(services, "AnnouncedIngredientSpawn", function(station, id)
        services.AnnouncementService.Spawned(station, id)
    end)
end

return AnnouncedIngredientSpawn
