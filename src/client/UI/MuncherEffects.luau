--!strict
local BillboardStyle = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Constants.Muncher)
local Style = require(Shared.Constants.DialogueTextStyle)
local Effects = {}
local RarityStyle = require(script.Parent.IngredientPickupPromptStyle)

function Effects.Pop(object: Instance)
    local flash = Instance.new("Highlight")
    flash.Name = "MuncherSpitPop"
    flash.Adornee, flash.FillColor = object, Style.White
    flash.FillTransparency, flash.OutlineTransparency = 0.3, 1
    flash.DepthMode = Enum.HighlightDepthMode.Occluded
    flash.Parent = object
    TweenService:Create(flash, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
    Debris:AddItem(flash, 0.2)
end

function Effects.Bind(model: Instance, playerGui: PlayerGui): ((number) -> (), () -> ())
    local saved: { [BasePart]: CFrame } = {}
    local sequence = -1
    local carrier: BasePart? = nil
    local glow: PointLight? = nil
    local hearts: BillboardGui? = nil
    local function restore()
        for part, at in saved do
            if part.Parent then
                part.CFrame = at
            end
        end
        table.clear(saved)
        if carrier then
            carrier:Destroy()
        end
        if hearts then
            hearts:Destroy()
        end
        carrier, glow, hearts = nil, nil, nil
    end
    local function origin(): CFrame?
        local mouth = model:FindFirstChild("MouthOrigin", true)
        if mouth and mouth:IsA("Attachment") then
            return mouth.WorldCFrame
        end
        if mouth and mouth:IsA("BasePart") then
            return mouth.CFrame
        end
        return nil
    end
    return function(now: number)
        local current = model:GetAttribute("Sequence")
        local processing = model:GetAttribute("Phase") == "Processing"
        if current ~= sequence then
            restore()
            sequence = if type(current) == "number" then current else 0
            local start = model:GetAttribute("StartedAt")
            local at = origin()
            if processing and at and type(start) == "number" and now - start < Config.ChewSeconds then
                local visual = model:FindFirstChild("Visual")
                if visual then
                    local parts = visual:GetDescendants()
                    table.insert(parts, visual)
                    for _, part in parts do
                        if part:IsA("BasePart") then
                            saved[part] = part.CFrame
                        end
                    end
                end
                local anchor = Instance.new("Part")
                anchor.Name = "MuncherLocalGlow"
                anchor.Size = Vector3.one * 0.1
                anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
                anchor.Transparency, anchor.CFrame, anchor.Parent = 1, at, workspace
                carrier = anchor
                local light = Instance.new("PointLight")
                local palette = (RarityStyle.RarityStyles :: any)[tostring(model:GetAttribute("OutputRarity"))]
                    or RarityStyle.RarityStyles.Common
                light.Color = palette.TextColor
                light.Range, light.Brightness, light.Parent = 7, 0, anchor
                glow = light
                local gui = Instance.new("BillboardGui")
                gui.Adornee = anchor
                -- Preserve this existing overlay/occlusion policy; nearby gameplay feedback must stay readable.
                BillboardStyle.ApplyBillboard(
                    gui,
                    { WidthStuds = 4, HeightStuds = 2.4, MaxDistance = 30, AlwaysOnTop = false, ResetOnSpawn = true }
                )
                gui.StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
                gui.Parent = playerGui
                hearts = gui
                for index = 1, 5 do
                    local heart = Instance.new("TextLabel")
                    heart.BackgroundTransparency = 1
                    heart.Text = utf8.char(0x2665)
                    Style.Apply(heart, 26 + index % 2 * 7)
                    heart.TextColor3 = Color3.fromRGB(255, 120, 170)
                    heart.Size = UDim2.fromScale(32 / 150, 32 / 90)
                    heart.TextScaled = true
                    heart.Position = UDim2.fromScale((14 + index * 18) / 150, 50 / 90)
                    heart.Parent = gui
                    TweenService:Create(heart, TweenInfo.new(0.6), {
                        Position = UDim2.fromScale(index * 22 / 150, 0),
                        TextTransparency = 1,
                    }):Play()
                end
                Debris:AddItem(gui, 0.7)
            end
        end
        if not processing then
            restore()
            return
        end
        local start = model:GetAttribute("StartedAt")
        if type(start) ~= "number" then
            return
        end
        local age = now - start
        local offset = math.sin(age * 25) * 0.1
        for part, at in saved do
            if part.Parent then
                part.CFrame = CFrame.new(0, offset, 0) * at
            end
        end
        if glow then
            glow.Brightness = math.clamp((age / Config.ChewSeconds - 0.55) / 0.45, 0, 1) * 3
        end
    end,
        restore
end
return Effects
