-- Render semantic events with a minimal audio boundary; no audio fidelity simulation.
local config = loadModule("GameplayAudio")
local receive
local played = {}
local preloadCount = 0
local jobs = {}
local remote = { OnClientEvent = {
    Connect = function(_, callback)
        receive = callback
    end,
} }
local boundary = {
    ReplicatedStorage = {
        Shared = {
            Constants = { GameplayAudio = config },
            Events = {
                WaitForChild = function(_, name)
                    assert(name == "GameplaySfx")
                    return remote
                end,
            },
        },
    },
    ContentProvider = {
        PreloadAsync = function(_, assets)
            preloadCount += 1
            check(#assets == 4, "preload deduplicates ingredient sounds and includes bat swing and customer hurt")
        end,
    },
    Debris = { AddItem = function() end },
}
local function sound()
    local item = { Ended = { Once = function() end } }
    function item:Clone()
        local copy = sound()
        copy.SoundId = self.SoundId
        return copy
    end
    function item:Play()
        table.insert(played, self.SoundId)
    end
    return item
end
local chunk = assert(loadstring(sources.GameplayAudioController))
setfenv(
    chunk,
    setmetatable({
        game = {
            GetService = function(_, name)
                return boundary[name]
            end,
        },
        require = function(value)
            return value
        end,
        Instance = {
            new = function(class)
                return if class == "Sound" then sound() else {}
            end,
        },
        workspace = {},
        typeof = function(value)
            return if value == "position" then "Vector3" else type(value)
        end,
        task = {
            spawn = function(callback)
                table.insert(jobs, callback)
            end,
        },
    }, { __index = env })
)
local controller = chunk()
controller.Init()
controller.Init()
jobs[1]()
receive("IngredientPickup", "position")
check(#played == 0, "early event waits for preload")
jobs[2]()
receive("IngredientPlant", "position")
receive("IngredientThrow", "position")
receive("BatSwing", "position")
check(
    preloadCount == 1
        and #played == 4
        and played[1] == config.IngredientPickupSoundId
        and played[2] == config.IngredientPlantSoundId
        and played[3] == config.IngredientThrowSoundId
        and played[4] == config.BatSwingSoundId,
    "known semantic events map to the configured clips after one preload"
)
receive("FarmHarvest", "position")
receive(config.IngredientThrowSoundId, "position")
receive("IngredientPickup", false)
check(#played == 4, "unknown events, raw asset IDs and invalid positions are ignored")
