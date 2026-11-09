--!strict
local Text = {}
Text.BodyColor = Color3.fromRGB(255, 245, 222)
local function escape(value: string): string
    return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
end
local function keyword(word: string, color: string?): string
    return '<b><font color="' .. (color or "#FFD84A") .. '">' .. escape(word) .. "</font></b>"
end
local hints: { [string]: string } = {
    NextCustomer = "See what the next customer wants!",
    MarketJump = keyword("JUMP HIGHER") .. " to reach better ingredients!",
    Harvest = "Harvest your ingredients!",
    Market = "Visit the " .. keyword("MARKET") .. " for more ingredients!",
    BuyRow = "Buy a farm row to grow ingredients!",
    Plant = "Plant an ingredient!",
    ClaimPlot = "Claim your smoothie stand!",
    Counter = "Head to your customer counter!",
    Order = "Take the customer's order!",
    Stash = "Take three " .. keyword("RED", "#FF5555") .. " ingredients from the stash!",
    Ladder = "Climb the ladder to your blender!",
    Turbine = "Climb down and " .. keyword("SPIN") .. " to blend!",
    Dispenser = "Dispense your smoothie!",
    FinishBatch = "Spin to finish the previous batch!",
    DrainBatch = "Dispense the previous batch to clear your blender!",
    Serve = "Serve customer to get " .. keyword("CASH") .. "!",
}
function Text.Get(stage: string, preferred: Enum.PreferredInput, button: string): string?
    if stage == "Upgrades" then
        return "Open " .. keyword("UPGRADES") .. ": buy " .. keyword("JUMP 1") .. " and " .. keyword("BAT 1") .. "!"
    elseif stage == "UpgradeJump" then
        return "Buy " .. keyword("JUMP 1") .. " in " .. keyword("UPGRADES") .. "!"
    elseif stage == "UpgradeBat" then
        return "Buy " .. keyword("BAT 1") .. " in " .. keyword("UPGRADES") .. "!"
    end
    if stage == "Blender" then
        if preferred == Enum.PreferredInput.Touch then
            return "Tap Throw to toss it in!"
        elseif preferred == Enum.PreferredInput.Gamepad then
            return "Press " .. escape(button) .. " to throw into the blender!"
        end
        return "Click to throw into the blender!"
    end
    return hints[stage]
end
return Text
