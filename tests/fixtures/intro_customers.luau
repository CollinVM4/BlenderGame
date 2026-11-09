env.Enum.HumanoidDisplayDistanceType = { None = "None" }
env.Enum.HumanoidHealthDisplayType = { AlwaysOff = "AlwaysOff" }
-- Imported avatar boundary: canonical art is authored in CustomerNPCs/Special.
local npcFolder = storage:FindFirstChild("CustomerNPCs")
if not npcFolder then
    npcFolder = instance("Folder")
    npcFolder.Name, npcFolder.Parent = "CustomerNPCs", storage
end
local specialFolder = instance("Folder")
specialFolder.Name, specialFolder.Parent = "Special", npcFolder
local caseohTemplate = instance("Model")
caseohTemplate.Name, caseohTemplate.Parent = "AuthoredCaseOhAvatar", specialFolder
caseohTemplate:SetAttribute("CustomerId", "caseoh")
local caseohHumanoid = instance("Humanoid")
caseohHumanoid.Name, caseohHumanoid.RigType, caseohHumanoid.Parent = "Humanoid", { Name = "R15" }, caseohTemplate
for _, name in { "Head", "HumanoidRootPart" } do
    local object = instance("Part")
    object.Name, object.Parent = name, caseohTemplate
end
