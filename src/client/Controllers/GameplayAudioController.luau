--!strict
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.GameplayAudio)
local Controller = {}
local started = false
local templates: { [string]: Sound } = {}
local eventAssets: { [string]: string } = {
    IngredientPickup = Config.IngredientPickupSoundId,
    IngredientPlant = Config.IngredientPlantSoundId,
    IngredientThrow = Config.IngredientThrowSoundId,
    BatSwing = Config.BatSwingSoundId,
    CustomerHurt = Config.CustomerHurtSoundId,
}

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
