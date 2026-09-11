--!strict
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Constants.Economy)
local WorldUtil = require(script.Parent.Parent.Services.WorldUtil)
local BlendProgressLights = {}

type Light = {
    Bulb: BasePart,
    Point: PointLight,
    Insert: BasePart?,
    OffMaterial: Enum.Material,
    Brightness: number,
    Mode: string,
}

local function playClick(light: Light)
    local sound = Instance.new("Sound")
    sound.Name = "BlendThresholdClick"
    sound.SoundId = "rbxassetid://113416294133952"
    sound.Volume = 0.5
    sound.RollOffMaxDistance = 60
    sound.Parent = light.Bulb
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    Debris:AddItem(sound, 10)
    sound:Play()
end

local function setMode(light: Light, mode: string)
    if light.Mode == mode then
        return
    end
    light.Mode = mode
    light.Bulb.Material = if mode == "solid" then Enum.Material.Neon else light.OffMaterial
    if light.Insert then
        light.Insert.Transparency = if mode == "off" then 1 else 0
    end
    light.Point.Enabled = mode ~= "off"
    light.Point.Brightness = if mode == "off" then 0 else light.Brightness
end

function BlendProgressLights.Init(services: any)
    WorldUtil.BindTag("PlayerPlot", function(plot)
        local blender = if plot.Name == "Blender" then plot else plot:FindFirstChild("Blender")
        local folder = blender and blender:FindFirstChild("BlendProgressLights")
        if not folder then
            return nil
        end
        -- Group physical bulbs by milestone; banks never own progress or clicks.
        local lights: { { Light } } = { {}, {}, {}, {}, {} }
        local clicked: { [number]: boolean } = {}
        local banks: { Instance } = {}
        if folder:FindFirstChild("Light1") then
            -- Preserve the original single-bank hierarchy during Studio migration.
            table.insert(banks, folder)
        else
            for _, bank in folder:GetChildren() do
                if bank:IsA("Folder") or bank:IsA("Model") then
                    table.insert(banks, bank)
                end
            end
        end
        table.sort(banks, function(a, b)
            return a.Name < b.Name
        end)
        for _, bank in banks do
            local bankContext = bank:GetFullName()
            for index = 1, 5 do
                local model = bank:FindFirstChild("Light" .. index)
                local bulb = if model and model:IsA("Model") then model:FindFirstChild("Bulb") else nil
                local point = bulb and bulb:FindFirstChild("PointLight")
                local insert = if model then model:FindFirstChild("Light") else nil
                if bulb and bulb:IsA("BasePart") and point and point:IsA("PointLight") then
                    if not insert or not insert:IsA("BasePart") then
                        warn("[BlendProgressLights] Expected " .. bankContext .. ".Light" .. index .. ".Light BasePart")
                    end
                    table.insert(lights[index], {
                        Bulb = bulb,
                        Point = point,
                        Insert = if insert and insert:IsA("BasePart") then insert else nil,
                        OffMaterial = if bulb.Material == Enum.Material.Neon
                            then Enum.Material.SmoothPlastic
                            else bulb.Material,
                        -- An authored zero is an off setting; use a visible solid fallback.
                        Brightness = if point.Brightness > 0 then point.Brightness else 1.5,
                        Mode = "",
                    })
                else
                    warn("[BlendProgressLights] Expected " .. bankContext .. ".Light" .. index .. ".Bulb.PointLight")
                end
            end
        end

        local owner: Player? = nil
        local ownerConnections: { RBXScriptConnection } = {}
        local function refresh(playThresholdClicks: boolean?)
            local player = owner
            local state = player and player:GetAttribute("BlendState") or "EMPTY"
            local progress = player and player:GetAttribute("BlendProgress") or 0
            -- BlendService publishes DISPENSED after a successful dispense, then
            -- Reset publishes EMPTY. Stopping progress production is not a reset.
            local reset = state == "EMPTY" or state == "DISPENSED"
            local completed = if reset
                then 0
                else math.clamp(math.floor((progress :: number) / Economy.RequiredProgress * 5), 0, 5)
            for index, milestoneLights in lights do
                for _, light in milestoneLights do
                    setMode(light, if index <= completed then "solid" else "off")
                end
                if reset then
                    clicked[index] = nil
                elseif index <= completed and index <= 4 and not clicked[index] then
                    clicked[index] = true
                    local soundSource = milestoneLights[1]
                    if playThresholdClicks ~= false and soundSource then
                        playClick(soundSource)
                    end
                end
            end
        end
        local function bindOwner()
            for _, connection in ownerConnections do
                connection:Disconnect()
            end
            table.clear(ownerConnections)
            table.clear(clicked)
            owner = if plot:GetAttribute("OwnerUserId") ~= nil then services.TycoonService.GetOwner(plot) else nil
            local player = owner
            if player then
                for _, attribute in { "BlendProgress", "BlendState" } do
                    table.insert(ownerConnections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
                end
            end
            -- Binding an already-progressed batch restores visuals silently;
            -- only subsequent authoritative threshold crossings play clicks.
            refresh(false)
        end
        local ownership = plot:GetAttributeChangedSignal("OwnerUserId"):Connect(bindOwner)
        local leaving = Players.PlayerRemoving:Connect(function(player)
            if player == owner then
                owner = nil
                refresh()
            end
        end)
        bindOwner()
        return function()
            ownership:Disconnect()
            leaving:Disconnect()
            for _, connection in ownerConnections do
                connection:Disconnect()
            end
            for _, milestoneLights in lights do
                for _, light in milestoneLights do
                    setMode(light, "off")
                end
            end
        end
    end)
end

return BlendProgressLights
