--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local TweenService = game:GetService("TweenService")
local Config = require(Shared.Constants.JackedNoob)
local TextStyle = require(Shared.Constants.DialogueTextStyle)
local Reaction = {}
local current: BillboardGui? = nil
local sound: Sound? = nil
local soundUntil = 0

function Reaction.Clear()
    if current then
        current:Destroy()
        current = nil
    end
    if sound then
        sound:Destroy()
        sound = nil
    end
    soundUntil = 0
end

function Reaction.Play(head: BasePart)
    if current then
        current:Destroy()
    end
    local gui = Instance.new("BillboardGui")
    gui.Name = "JackedNoobHitReaction"
    gui.Adornee = head
    gui.Size = UDim2.fromOffset(320, 58)
    gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 2.5, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 65
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "HEY STOP THAT"
    TextStyle.Apply(label, 27)
    label.Parent = gui
    local scale = Instance.new("UIScale")
    scale.Scale = 0.7
    scale.Parent = label
    gui.Parent = head
    current = gui
    TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        :Play()
    task.delay(Config.HitDialogueSeconds - 0.3, function()
        if current ~= gui or not gui:IsDescendantOf(workspace) then
            return
        end
        local outline = label:FindFirstChild("DialogueOutline") :: UIStroke
        TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
        TweenService:Create(outline, TweenInfo.new(0.3), { Transparency = 1 }):Play()
        task.delay(0.3, function()
            if current == gui then
                current = nil
            end
            gui:Destroy()
        end)
    end)
    if os.clock() >= soundUntil then
        soundUntil = os.clock() + Config.HitReactionCooldownSeconds
        if not sound then
            local created = Instance.new("Sound")
            created.Name = "JackedNoobHurt"
            created.SoundId = Config.HurtSoundId
            created.Volume = Config.HurtSoundVolume
            created.RollOffMinDistance = 10
            created.RollOffMaxDistance = 50
            created.Parent = head
            sound = created
        end
        local playing = sound :: Sound
        playing:Stop()
        playing:Play()
    end
end

return Reaction
