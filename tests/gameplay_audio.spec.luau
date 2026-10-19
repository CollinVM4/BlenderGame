-- Render semantic events with a minimal audio boundary; no audio fidelity simulation.
local config = loadModule("GameplayAudio")
local receive
local played = {}
local preloadCount = 0
local expectedPreload = 8
local lastSound
local jobs = {}
local remote = { OnClientEvent = {
    Connect = function(_, callback)
        receive = callback
    end,
} }
local boundary = {
    ReplicatedStorage = {
        Shared = {
            Constants = { GameplayAudio = config, Muncher = loadModule("Muncher") },
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
            check(
                #assets == expectedPreload,
                "preload deduplicates ingredient sounds and includes bat swing and customer hurt"
            )
        end,
    },
    Debris = { AddItem = function() end },
}
local function sound()
    local item = { Ended = { Once = function() end } }
    function item:Clone()
        local copy = sound()
        copy.SoundId = self.SoundId
        copy.Volume = self.Volume
        copy.RollOffMinDistance = self.RollOffMinDistance
        copy.RollOffMaxDistance = self.RollOffMaxDistance
        return copy
    end
    function item:Destroy()
        self.Destroyed = true
    end
    function item:Play()
        lastSound = self
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

controller.PlayCashFeedback("Pop")
controller.PlayCashFeedback("Pop")
controller.PlayCashFeedback("Collect")
controller.PlayCashFeedback("Collect")
check(
    #played == 6 and played[5] == config.IngredientPickupSoundId and played[6] == config.IngredientThrowSoundId,
    "cash feedback reuses verified clips and throttles overlapping cues"
)

local slotConfig = loadModule("Muncher")
local before = #played
controller.PlayMuncher("ReelStop", {})()
check(#played == before, "empty tick hook is inert")
for _, kind in { "Insert", "Win", "Lose" } do
    controller.PlayMuncher(kind, { Position = "position" })()
    check(
        lastSound.SoundId == slotConfig[kind .. "SoundId"] and not lastSound.Looped,
        "supplied clip plays once: " .. kind
    )
    check(
        lastSound.Parent.Position == "position" and lastSound.Parent.Parent == getfenv(controller.PlayMuncher).workspace,
        "one shot uses mouth spatial emitter"
    )
    check(
        lastSound.Volume == config.SoundVolume
            and lastSound.RollOffMinDistance == config.SoundRollOffMinDistance
            and lastSound.RollOffMaxDistance == config.SoundRollOffMaxDistance,
        "shared spatial mix preserved"
    )
end
local cancelRoll = controller.PlayMuncher("Roll", { Position = "position" })
local roll = lastSound
check(roll.SoundId == slotConfig.RollSoundId and roll.Looped, "supplied roll clip loops")
cancelRoll()
check(roll.Destroyed, "interruption destroys loop")

-- Every missing clip is inert, including cancellable roll cleanup.
local saved = {}
for _, kind in { "Insert", "Roll", "Win", "Lose" } do
    local key = kind .. "SoundId"
    saved[key], slotConfig[key] = slotConfig[key], ""
end
expectedPreload = 4
local silent = chunk()
local jobStart = #jobs
silent.Init()
jobs[jobStart + 1]()
jobs[jobStart + 2]()
before = #played
for _, kind in { "Insert", "Roll", "ReelStop", "Win", "Lose" } do
    silent.PlayMuncher(kind, {})()
end
check(#played == before, "all empty Muncher asset IDs remain inert")
for key, id in saved do
    slotConfig[key] = id
end
