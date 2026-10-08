-- Studio-only diagnostic: paste into the CLIENT Command Bar during Play.
-- Not mapped by Rojo, and never installed in production. Attribute observers
-- automatically disconnect after 60 seconds; use purchases/payouts in that window.
local Players = game:GetService("Players")
local player = assert(Players.LocalPlayer, "Run this in the client Command Bar during Play")
local playerGui = player:WaitForChild("PlayerGui")
local names = {
    ["Be a Blender! Desktop"] = true,
    TOP = true,
    CashDisplay = true,
    ["{Coins}"] = true,
    Upgrades_panel = true,
    Upgrades = true,
    UpgradeScroll_scroll = true,
    UpgradeScroll = true,
    UpgradeList_list = true,
    UpgradeList = true,
    JumpCard = true,
    BatCard = true,
    MovementSpeedCard = true,
    CarryCapacityCard = true,
    SprintStaminaCard = true,
    Buy_button_smooth = true,
    Buy = true,
}
print("PlayerGui", playerGui:GetFullName(), playerGui.ClassName)
for _, surface in { game:GetService("StarterGui"), playerGui } do
    local desktopCount = 0
    local seen = {}
    for _, instance in surface:GetDescendants() do
        if names[instance.Name] then
            seen[instance.Name] = true
            print(instance:GetFullName(), instance.ClassName)
        end
        if instance.Name == "Be a Blender! Desktop" then
            desktopCount += 1
            local root = if instance:IsA("ScreenGui") then instance else instance:FindFirstAncestorOfClass("ScreenGui")
            print(
                "Desktop candidate",
                instance:GetFullName(),
                "Visible",
                if instance:IsA("GuiObject") then instance.Visible else "n/a",
                "ScreenGui",
                if root then root:GetFullName() else "MISSING",
                "Enabled",
                if root then root.Enabled else "n/a"
            )
        end
    end
    print(surface:GetFullName(), "desktop count", desktopCount, "duplicates", desktopCount > 1)
    for _, name in
        {
            "Be a Blender! Desktop",
            "TOP",
            "CashDisplay",
            "{Coins}",
            "Upgrades_panel",
            "UpgradeScroll_scroll",
            "UpgradeList_list",
            "JumpCard",
            "BatCard",
            "MovementSpeedCard",
            "CarryCapacityCard",
            "SprintStaminaCard",
        }
    do
        print(
            surface.Name,
            name,
            if seen[name] then "FOUND (classes/paths above)" else "MISSING (check processed alias above)"
        )
    end
end
local adapter = require(player.PlayerScripts.Client.UI.UpgradesGui)
local view = adapter.Resolve(playerGui)
print(
    "Selected runtime ScreenGui",
    if view then view.Root:GetFullName() else "NONE: incomplete, inactive, or ambiguous contract"
)
print("Selected cash", if view then view.Cash:GetFullName() else "NONE")
local connections = {}
for _, name in
    {
        "playerCash",
        "JumpPurchasedLevel",
        "MovementSpeedPurchasedLevel",
        "SprintStaminaPurchasedLevel",
        "BatPurchasedLevel",
        "CarryCapacityLevel",
        "CarryCapacity",
    }
do
    print("Backend attribute", name, player:GetAttribute(name))
    table.insert(
        connections,
        player:GetAttributeChangedSignal(name):Connect(function()
            print("Backend attribute changed", name, player:GetAttribute(name))
        end)
    )
end
task.delay(60, function()
    for _, connection in connections do
        connection:Disconnect()
    end
    print("Framewisp diagnostic attribute observers disconnected")
end)
