-- Real component boundary; monetization authority has its separate test home.
workspaceFake = instance("Folder")
env.workspace = workspaceFake
workspaceFake.DescendantAdded, workspaceFake.DescendantRemoving = signal(), signal()
workspaceFake.Raycast = function()
    return nil
end
storage.Weapons = weapons
local added, removed = {}, {}
services.CollectionService.GetInstanceAddedSignal = function(_, tag)
    added[tag] = added[tag] or signal()
    return added[tag]
end
services.CollectionService.GetInstanceRemovedSignal = function(_, tag)
    removed[tag] = removed[tag] or signal()
    return removed[tag]
end
local addTag = services.CollectionService.AddTag
services.CollectionService.AddTag = function(self, object, tag)
    local existed = self:HasTag(object, tag)
    addTag(self, object, tag)
    if not existed and added[tag] then
        added[tag]:Fire(object)
    end
end
local frameMeta = getmetatable(frame())
frameMeta.__add = function(cf, offset)
    return frame(cf.Position + offset)
end
local oldAngles = env.CFrame.Angles
env.CFrame.Angles = function(...)
    return setmetatable(oldAngles(...), frameMeta)
end
local pad = instance("Part")
pad.Name, pad.Parent, pad.Anchored = "EquipmentSpawner", workspaceFake, true
pad.CFrame = setmetatable(frame(), frameMeta)
local light = instance("PointLight")
light.Parent, light.Enabled = pad, true
local oldTool = instance("Tool")
oldTool.Name, oldTool.Parent = "IcicleGun", workspaceFake
local originalNew = env.Instance.new
env.Instance.new = function(class)
    local object = originalNew(class)
    if class == "Attachment" then
        object.WorldPosition = vec(0, 2.5, 0)
    end
    if class == "ProximityPrompt" then
        object.Enabled = true
    end
    return object
end
env.Enum.KeyCode = { E = "E", ButtonX = "ButtonX" }
local purchases = 0
local validator = nil
deps.IceGunService = {
    GetEquipped = function()
        return nil
    end,
    RequestPurchase = function(_, validate)
        purchases += 1
        validator = validate
    end,
}
local component = loadModule("IceGunDisplayComponent")
component.Init(deps)
local display = pad:FindFirstChild("IceGunDisplay")
local prompt = pad:FindFirstChild("PurchaseAttachment"):FindFirstChild("IceGunPurchase")
local shopper, h = fighter(nil)
ready(shopper)
check(
    oldTool.Destroyed and display and not display:IsA("Tool"),
    "legacy free pickup replaced by permanent cosmetic handle"
)
check(
    display.Anchored and not display.CanTouch and not display.CanQuery and not display.CanCollide,
    "display cannot be collected or obstruct ingredient/physics queries"
)
prompt.Triggered:Fire(shopper)
check(purchases == 1 and validator(), "unassigned public shopper can interact within world distance")
check(display.Parent == pad and light.Enabled, "purchase leaves display and original light available to others")
local root = shopper.Character:FindFirstChild("HumanoidRootPart")
root.Position = vec(20, 0, 0)
prompt.Triggered:Fire(shopper)
check(purchases == 1 and not validator(), "world range checked on interaction and after async entitlement")
root.Position = vec(0, 0, 0)
movement.SetFrozen(shopper, true)
prompt.Triggered:Fire(shopper)
check(purchases == 1, "frozen shoppers cannot activate public display")
movement.SetFrozen(shopper, false)
workspaceFake.Raycast = function()
    return { Instance = pad }
end
prompt.Triggered:Fire(shopper)
check(purchases == 1, "obstructed world purchase is rejected")
workspaceFake.Raycast = function()
    return nil
end
local second = fighter(nil)
ready(second)
prompt.Triggered:Fire(second)
check(purchases == 2 and not display.Destroyed, "second shopper has independent access to unchanged public display")
removed.IceGunPurchaseDisplay:Fire(pad)
prompt.Triggered:Fire(shopper)
check(purchases == 2 and display.Destroyed, "removed display retires world interaction")
print("PASS: Ice Gun world-display contracts")
