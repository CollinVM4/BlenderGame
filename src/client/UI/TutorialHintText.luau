--!strict
local Text = {}
local function keyword(word: string): string
    return '<b><font color="#FFFFFF">' .. word .. "</font></b>"
end
local hints: { [string]: string } = {
    NextCustomer = "See what the next customer wants!",
    MarketJump = keyword("JUMP") .. " higher in the " .. keyword("MARKET") .. " for better ingredients!",
    Harvest = "Harvest your ingredients!",
    Market = "Find more ingredients at the " .. keyword("MARKET") .. "!",
    BuyRow = "Buy a farm row to grow ingredients!",
    Plant = "Plant an ingredient!",
    ClaimPlot = "Claim your smoothie stand!",
    Counter = "Head to your customer counter!",
    Order = "Take the customer's order!",
    Stash = "Take three " .. keyword("RED") .. " ingredients from Locked Slot 1!",
    Ladder = "Climb the ladder to your blender!",
    Turbine = "Drop down and Spin to blend smoothie!",
    Dispenser = "Dispense your smoothie!",
    FinishBatch = "Spin to finish the previous batch!",
    DrainBatch = "Dispense the previous batch to clear your blender!",
    Serve = "Serve customer and get MONEY!",
}
function Text.Get(stage: string, preferred: Enum.PreferredInput, button: string): string?
    if stage == "Upgrades" then
        return "Open "
            .. keyword("UPGRADES")
            .. ": buy "
            .. keyword("JUMP")
            .. " 1 and "
            .. keyword("BAT")
            .. " 1 (optional)!"
    elseif stage == "UpgradeJump" then
        return "Try " .. keyword("JUMP") .. " 1 in " .. keyword("UPGRADES") .. " (optional)!"
    elseif stage == "UpgradeBat" then
        return "Try " .. keyword("BAT") .. " 1 in " .. keyword("UPGRADES") .. " (optional)!"
    end
    if stage == "Blender" then
        if preferred == Enum.PreferredInput.Touch then
            return "Tap Throw to toss it in!"
        elseif preferred == Enum.PreferredInput.Gamepad then
            return "Press " .. button .. " to throw into the blender!"
        end
        return "Click to throw into the blender!"
    end
    return hints[stage]
end
return Text
