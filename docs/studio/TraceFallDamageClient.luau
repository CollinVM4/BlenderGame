--!strict
-- Paste into the Studio CLIENT Command Bar after spawning. Observation only:
-- no remotes, no physics/property writes, and no damage decisions.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsClient(), "Use the Studio Client Command Bar")
local player = game:GetService("Players").LocalPlayer
local character = assert(player.Character, "Spawn first")
local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "Missing Humanoid")
local part = character:FindFirstChild("HumanoidRootPart")
assert(part and part:IsA("BasePart"), "Missing root")
local root = part :: BasePart
local connections: { RBXScriptConnection } = {}
local elapsed, nextSample, records = 0, 0, 0
local deadline = os.clock() + 30
local function stop()
    for _, connection in connections do
        connection:Disconnect()
    end
end
local function record(event: string, detail: string)
    if records >= 240 or elapsed >= 30 or os.clock() >= deadline then
        stop()
        return
    end
    records += 1
    warn(
        string.format(
            "[FallDamageClient] serverTime=%.6f event=%s %s mode=%s floor=%s jump=%s velocityY=%.3f positionY=%.3f platformStand=%s record=%d",
            workspace:GetServerTimeNow(),
            event,
            detail,
            tostring(humanoid:GetState()),
            tostring(humanoid.FloorMaterial),
            tostring(humanoid.Jump),
            root.AssemblyLinearVelocity.Y,
            root.Position.Y,
            tostring(humanoid.PlatformStand),
            records
        )
    )
end
table.insert(
    connections,
    humanoid.StateChanged:Connect(function(old, new)
        record("state-change", "from=" .. tostring(old) .. " to=" .. tostring(new))
    end)
)
table.insert(
    connections,
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if
            player.Character ~= character
            or not root:IsDescendantOf(workspace)
            or elapsed >= 30
            or os.clock() >= deadline
            or records >= 240
        then
            stop()
        elseif elapsed >= nextSample then
            nextSample = elapsed + 0.1
            record("sample", "dt=" .. tostring(dt))
        end
    end)
)
record("enabled", "")
