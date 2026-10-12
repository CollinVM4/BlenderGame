-- Read-only Studio Play snapshot. Paste into Server and each Client Command Bar.
-- Enable logs separately on Server: player:SetAttribute("ThrowDebug", true).
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio diagnostics only")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer
local targets = if localPlayer then { localPlayer } else Players:GetPlayers()
local events = ReplicatedStorage.Shared.Events
local remotes = 0
for _, event in events:GetChildren() do
    if event.Name == "GameplayRequest" then
        remotes += 1
        print("[Throw snapshot] remote", event:GetFullName())
    end
end
print("[Throw snapshot] named GameplayRequest remotes", remotes)
for _, player in targets do
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    print(
        "[Throw snapshot]",
        player.Name,
        "debug",
        player:GetAttribute("ThrowDebug"),
        "carry",
        player:GetAttribute("CarryCount"),
        "stunned",
        player:GetAttribute("Stunned")
    )
    print(
        "[Throw snapshot] root",
        root and root.CFrame,
        "root size",
        root and root.Size,
        "health",
        humanoid and humanoid.Health
    )
    if character then
        local _, size = character:GetBoundingBox()
        print("[Throw snapshot] full bounds (includes carry/cosmetics)", size)
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") then
                print(
                    "[Throw snapshot] part",
                    part:GetFullName(),
                    part.Size,
                    part.CFrame,
                    "collide/query",
                    part.CanCollide,
                    part.CanQuery
                )
            elseif part:IsA("Tool") then
                print(
                    "[Throw snapshot] equipped",
                    part.Name,
                    "carryId",
                    part:GetAttribute("CarryItemId"),
                    "bat",
                    part:GetAttribute("BatLevel"),
                    "icegun",
                    part:GetAttribute("IceGunWeapon")
                )
            end
        end
    end
end
if localPlayer then
    local input = game:GetService("UserInputService")
    print(
        "[Throw snapshot] input touch/mouse/keyboard",
        input.TouchEnabled,
        input.MouseEnabled,
        input.KeyboardEnabled,
        "preferred",
        input.PreferredInput,
        "last",
        input:GetLastInputType(),
        "text focus",
        input:GetFocusedTextBox()
    )
    local actions = game:GetService("ContextActionService")
    for name, info in actions:GetAllBoundActionInfo() do
        print("[Throw snapshot] CAS", name, "priority", info.priorityLevel, "inputs", info.inputTypes)
    end
end
