--!strict
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.GameplayAudio)
local MuncherConfig = require(ReplicatedStorage.Shared.Constants.Muncher)
local Controller = {}
local started = false
local lastCashCue = { Pop = -math.huge, Collect = -math.huge }
local templates: { [string]: Sound } = {}
local eventAssets: { [string]: string } = {
    IngredientPickup = Config.IngredientPickupSoundId,
    IngredientPlant = Config.IngredientPlantSoundId,
    IngredientThrow = Config.IngredientThrowSoundId,
    BatSwing = Config.BatSwingSoundId,
    CustomerHurt = Config.CustomerHurtSoundId,
}

local muncherAssets: { [string]: string } = {
    Insert = MuncherConfig.InsertSoundId,
    Roll = MuncherConfig.RollSoundId,
    ReelStop = MuncherConfig.ReelStopSoundId,
    Win = MuncherConfig.WinSoundId,
    Lose = MuncherConfig.LoseSoundId,
}

-- Reuse the authored pickup/throw assets for brief local UI cues.
function Controller.PlayCashFeedback(kind: "Pop" | "Collect")
    local now = os.clock()
    if now - lastCashCue[kind] < 0.18 then
        return
    end
    lastCashCue[kind] = now
    local id = if kind == "Pop" then Config.IngredientPickupSoundId else Config.IngredientThrowSoundId
    local template = templates[id]
    if not template then
        return
    end
    local sound = template:Clone()
    sound.Name = "CashFeedback"
    sound.Volume = 0.22
    sound.Parent = game:GetService("SoundService")
    sound:Play()
    Debris:AddItem(sound, 0.4)
end

local function play(template: Sound, position: Vector3)
    local camera = workspace.CurrentCamera
    if camera and (camera.CFrame.Position - position).Magnitude > Config.SoundRollOffMaxDistance then
        return
    end
    local emitter = Instance.new("Part")
    emitter.Name = "GameplaySfx"
    emitter.Size = Vector3.new(0.1, 0.1, 0.1)
    emitter.Anchored, emitter.Transparency = true, 1
    emitter.CanCollide, emitter.CanTouch, emitter.CanQuery = false, false, false
    emitter.Position = position
    local sound = template:Clone()
    sound.Parent = emitter
    emitter.Parent = workspace
    sound.Ended:Once(function()
        emitter:Destroy()
    end)
    Debris:AddItem(emitter, 15)
    sound:Play()
end

-- Local spatial audio. Cleanup owns loop cancellation, including interrupted rolls.
function Controller.PlayMuncher(kind: "Insert" | "Roll" | "ReelStop" | "Win" | "Lose", parent: BasePart): () -> ()
    local id = muncherAssets[kind]
    local template = if id ~= "" then templates[id] else nil
    if not template then
        return function() end
    end
    if kind ~= "Roll" then
        play(template, parent.Position)
        return function() end
    end
    local sound = template:Clone()
    sound.Name = "Muncher" .. kind
    sound.Looped = true
    sound.Parent = parent
    sound:Play()
    return function()
        sound:Destroy()
    end
end

function Controller.Init()
    if started then
        return
    end
    started = true
    local preload: { Instance } = {}
    for _, id in eventAssets do
        if not templates[id] then
            local sound = Instance.new("Sound")
            sound.SoundId = id
            sound.Volume = Config.SoundVolume
            sound.RollOffMinDistance = Config.SoundRollOffMinDistance
            sound.RollOffMaxDistance = Config.SoundRollOffMaxDistance
            templates[id] = sound
            table.insert(preload, sound)
        end
    end
    for _, id in muncherAssets do
        if id ~= "" and not templates[id] then
            local sound = Instance.new("Sound")
            sound.SoundId = id
            sound.Volume = Config.SoundVolume
            sound.RollOffMinDistance = Config.SoundRollOffMinDistance
            sound.RollOffMaxDistance = Config.SoundRollOffMaxDistance
            templates[id] = sound
            table.insert(preload, sound)
        end
    end
    local ready = false
    local pending: { { Template: Sound, Position: Vector3 } } = {}
    task.spawn(function()
        local remote = ReplicatedStorage.Shared.Events:WaitForChild("GameplaySfx") :: RemoteEvent
        remote.OnClientEvent:Connect(function(event: any, position: any)
            local id = if type(event) == "string" then eventAssets[event] else nil
            if not id or typeof(position) ~= "Vector3" then
                return
            end
            local template = templates[id]
            if ready then
                play(template, position)
            elseif #pending < 32 then
                -- Preserve early authorized events while the two assets load.
                table.insert(pending, { Template = template, Position = position })
            end
        end)
    end)
    task.spawn(function()
        local ok, message = pcall(function()
            ContentProvider:PreloadAsync(preload)
        end)
        if not ok then
            warn("[GameplayAudio] Preload failed: " .. tostring(message))
        end
        ready = true
        for _, event in pending do
            play(event.Template, event.Position)
        end
        table.clear(pending)
    end)
end

return Controller
