-- Run once in the Studio SERVER Command Bar in EDIT mode after syncing Rojo.
-- This file is a setup utility, deliberately excluded from default.project.json.
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before sanitizing the imported assets")
local storage = game:GetService("ServerStorage")
assert(
    storage:FindFirstChild("Weapons") and storage.Weapons:FindFirstChild("IcicleGun"),
    "Sync the updated Rojo project first"
)
assert(storage:FindFirstChild("IceGunEffects"), "Sync the extracted original effects first")
local count = 0
for _, object in workspace:GetDescendants() do
    if object:IsA("BasePart") and object.Name == "EquipmentSpawner" then
        assert(object.Anchored, "Anchor the existing pedestal before removing its unused terrain weld")
        for _, child in object:GetDescendants() do
            if child:IsA("BaseScript") then
                child.Enabled = false
                child:Destroy()
            elseif child:IsA("ManualWeld") and not child.Part0 then
                child:Destroy()
            end
        end
        game:GetService("CollectionService"):AddTag(object, "IceGunPurchaseDisplay")
        count += 1
    end
end
for _, container in { workspace, game:GetService("StarterPack"), storage } do
    for _, object in container:GetDescendants() do
        if object:IsA("Tool") and object.Name == "IcicleGun" and object ~= storage.Weapons.IcicleGun then
            object:Destroy()
        end
    end
end
print("[IceGun] Sanitized " .. count .. " existing pedestals; their CFrames, unions and lights are unchanged.")
print("[IceGun] Play creates the original-position pedestal from the sanitized template if none exists.")
