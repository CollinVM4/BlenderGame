-- Run from Studio's CLIENT Command Bar during Play after Rojo sync.
-- Native-engine contracts only. This is NOT a filmed sample or smoothness sign-off.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Path = require(Shared.FilmCamPath)
local client = Players.LocalPlayer.PlayerScripts:WaitForChild("Client")
local Takes = require(client.UI.FilmCamTakes)
local start = CFrame.new(12, 8, -25) * CFrame.fromOrientation(0.6, -2.8, 0.3)
local finish = CFrame.new(21, 12, -12) * CFrame.fromOrientation(-0.2, 2.9, -0.4)
local take = {
    Version = 1,
    Name = 'Native JSON "quote" \\ newline\ncheck',
    Duration = 2,
    Keys = { Takes.Capture(0, start, 65), Takes.Capture(2, finish, 85) },
}
local decoded, message = Takes.Decode(Takes.Encode(take))
assert(decoded, message)
assert(decoded.Name == take.Name, "native JSON string round-trip")
local compiled = Path.Compile(decoded)
for _, endpoint in { { 0, start, 65 }, { 2, finish, 85 } } do
    local x, y, z, qx, qy, qz, qw, fov = Path.Evaluate(compiled, endpoint[1])
    local actual = CFrame.new(x, y, z, qx, qy, qz, qw)
    local expected = endpoint[2]
    assert((actual.Position - expected.Position).Magnitude < 0.0001)
    local _, angle = actual:ToObjectSpace(expected):ToAxisAngle()
    assert(math.abs(angle) < 0.0001, "pitched/rolled quaternion round-trip")
    assert(math.abs(fov - endpoint[3]) < 0.0001)
end
local center = start.Position + start.LookVector * 20
for _, kind in { "Push-in", "Pull-out", "Orbit" } do
    local preset = Takes.Preset(kind, start, 70, center)
    assert(Path.Validate(preset))
    if kind == "Orbit" then
        for _, key in preset.Keys do
            local p, q = key.Position, key.Rotation
            local actual = CFrame.new(p[1], p[2], p[3], q[1], q[2], q[3], q[4])
            assert(math.abs((actual.Position - center).Magnitude - 20) < 0.0001)
            assert(actual.LookVector:Dot((center - actual.Position).Unit) > 0.99999)
        end
    else
        local p = preset.Keys[#preset.Keys].Position
        local expected = start.Position + start.LookVector * (if kind == "Push-in" then 10 else -10)
        assert((Vector3.new(p[1], p[2], p[3]) - expected).Magnitude < 0.0001)
    end
end
print("PASS: FilmCam native CFrame, JSON and preset contracts; filmed acceptance still required")
