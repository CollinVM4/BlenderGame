local outlines = loadModule("CharacterStatusOutlineController")
local character = localPlayer.Character
local orphan = env.Instance.new("Highlight")
orphan.Name, orphan.Parent = "CharacterStatusOutline", character
local unrelated = env.Instance.new("Highlight")
unrelated.Name, unrelated.Parent = "OtherHighlight", character
character:SetAttribute("BatStunned", true)
outlines.Init()
outlines.Init()
local function outline()
    return character:FindFirstChild("CharacterStatusOutline")
end
check(
    outline() and outline().OutlineColor == presentationConfig.White and outline().FillTransparency == 1,
    "late join reads active server bat stun as white outline only"
)
check(
    #childrenNamed(character, "CharacterStatusOutline") == 1 and unrelated.Parent == character,
    "one managed combat outline replaces leftovers without touching other highlight owners"
)
character:SetAttribute("FrozenUntil", workspaceFake:GetServerTimeNow() - 1)
character:SetAttribute("FreezeImmuneUntil", workspaceFake:GetServerTimeNow() + 2)
check(
    outline().OutlineColor == presentationConfig.Blue and outline():GetAttribute("Status") == "Freeze",
    "server-active freeze outranks bat stun even if the nominal thaw deadline passed"
)
character:SetAttribute("FrozenUntil", nil)
check(outline():GetAttribute("Status") == "BatStun", "thaw preserves higher-priority active bat stun over immunity")
character:SetAttribute("BatStunned", nil)
character:SetAttribute("BatImmuneUntil", workspaceFake:GetServerTimeNow() + 4)
check(
    outline():GetAttribute("Status") == "FreezeImmunity" and outline().OutlineColor == presentationConfig.Blue,
    "freeze recovery deterministically wins simultaneous immunity"
)
local alpha = outline().OutlineTransparency
advance(presentationConfig.ImmunityFlashSeconds)
check(outline().OutlineTransparency ~= alpha, "recovery immunity flashes using the shared server clock")
advance(2)
check(
    outline():GetAttribute("Status") == "BatImmunity" and outline().OutlineColor == presentationConfig.White,
    "expired freeze recovery reveals remaining bat recovery"
)
advance(2)
check(outline() == nil, "expired immunity removes the highlight without waiting for an attribute update")
character:SetAttribute("BatStunned", true)
workspaceFake.CurrentCamera.CFrame = frame(500, 1, 0)
advance(0.1)
check(outline() == nil, "distant status outlines release their rendering budget")
workspaceFake.CurrentCamera.CFrame = frame(0, 1, 0)
advance(0.1)
check(outline() ~= nil, "nearby active status reacquires one outline")
localH.Health = 0
localH.Died:Fire()
check(outline() == nil, "death removes the outline immediately")
character:SetAttribute("FrozenUntil", workspaceFake:GetServerTimeNow() + 9)
check(outline() == nil, "late old status replication cannot outline a dead character")
local replacement, newH = fighter("B")
local old = character
character = replacement.Character
replacement.Character = nil
localPlayer.Character = character
character:SetAttribute("BatStunned", true)
localPlayer.CharacterAdded:Fire(character)
localPlayer.CharacterRemoving:Fire(old)
old:SetAttribute("BatStunned", true)
check(
    outline() and #childrenNamed(old, "CharacterStatusOutline") == 0,
    "old removal/status callbacks cannot remove a replacement outline"
)
for _ = 1, 10 do
    character:SetAttribute("FrozenUntil", workspaceFake:GetServerTimeNow() + 3)
    character:SetAttribute("FrozenUntil", nil)
end
check(
    #childrenNamed(character, "CharacterStatusOutline") == 1,
    "status transitions never accumulate duplicate highlights"
)
local crowd = {}
for i = 1, presentationConfig.MaxOutlines + 2 do
    local p = fighter("Crowd" .. i)
    p.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 1, -i)
    p.Character:SetAttribute("BatStunned", true)
    services.Players.PlayerAdded:Fire(p)
    table.insert(crowd, p)
end
local visible = if outline() then 1 else 0
for _, p in crowd do
    visible += #childrenNamed(p.Character, "CharacterStatusOutline")
end
check(
    visible == presentationConfig.MaxOutlines and outline() ~= nil,
    "crowded scenes obey the outline budget and preserve local-player priority"
)
services.Players.PlayerRemoving:Fire(localPlayer)
check(outline() == nil, "player departure clears combat outline")
outlines.Destroy()
print("PASS: Central combat outline priority, flashing and lifecycle")
