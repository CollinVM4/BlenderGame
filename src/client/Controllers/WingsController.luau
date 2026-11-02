--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Constants.WingsConfig)
local HoldSensor = require(script.Parent.WingsHoldSensor)
local Banner = require(script.Parent.Parent.UI.AnnouncementBanner)
local Controller = {}
local started = false
local WingsOnboardingShown = false -- Session only; survives respawn.

function Controller.SetWingPose(character: Model, pose: string, time: number)
    local clone = character:FindFirstChild("AngelWings")
    local handle = clone and clone:FindFirstChild("Handle")
    local motor = handle and handle:FindFirstChild("WingMotor")
    if not motor or not motor:IsA("Motor6D") then
        return
    end
    local rest = motor:GetAttribute("WingRestC0")
    if typeof(rest) ~= "CFrame" then
        return
    end
    -- Supplied art is ONE rigid mesh, with no separate left/right joints.
    -- Pose its whole pair at the authored back attachment; narrow the silhouette
    -- at rest. No mesh splitting, replacement art or published animations.
    local angle, width = -25, 0.65
    if pose == "Grounded" then
        angle, width = -65, 0.45
    elseif pose == "Powered" then
        angle, width = math.sin(time * math.pi * 2 * Config.PoweredFlapHz) * Config.PoweredFlapAmplitudeDegrees, 1
    elseif pose == "Gliding" then
        angle, width = math.sin(time * math.pi * 2) * Config.GlideBobAmplitudeDegrees, 1
    end
    motor.C0 = rest * CFrame.Angles(math.rad(angle), 0, 0)
    local mesh = handle and handle:FindFirstChildOfClass("SpecialMesh")
    if mesh then
        local base = mesh:GetAttribute("WingBaseScale")
        if typeof(base) ~= "Vector3" then
            base = mesh.Scale
            mesh:SetAttribute("WingBaseScale", base)
        end
        mesh.Scale = (base :: Vector3) * Vector3.new(width, 1, 1)
    end
end
function Controller.Init()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
    local remote = ReplicatedStorage:WaitForChild("WingsJumpHeld") :: RemoteEvent
    local sensor = HoldSensor.Attach(playerGui, function(held)
        remote:FireServer(held)
    end)
    player.CharacterRemoving:Connect(function()
        sensor.Clear()
    end)
    local function onboard()
        local character = player.Character
        -- A confirmed grant is the registered server accessory, not Shop opening
        -- or the ownership check finishing before a character has been attached.
        if
            WingsOnboardingShown
            or player:GetAttribute("WingsOwnership") ~= "Owned"
            or not character
            or not character:FindFirstChild("AngelWings")
        then
            return
        end
        WingsOnboardingShown = true
        local surface = Banner.Create(playerGui, "WingsOnboarding")
        surface.Show("JUMP TO FLY!\n\nHold Jump in the air to flap your wings. Keep holding to glide!")
        task.delay(5, function()
            surface.Destroy()
        end)
    end
    -- Rendering every player's server state also handles streaming/respawn and
    -- fires onboarding on the first rendered grant, never again that session.
    RunService.RenderStepped:Connect(function()
        local time = os.clock()
        for _, other in Players:GetPlayers() do
            if other.Character then
                Controller.SetWingPose(
                    other.Character,
                    tostring(other:GetAttribute("WingState") or "Grounded"),
                    time + other.UserId % 997 / 997
                )
            end
        end
        onboard()
    end)
end
return Controller
