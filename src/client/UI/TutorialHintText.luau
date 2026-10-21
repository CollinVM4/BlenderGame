--!strict
local Text = {}
local hints: { [string]: string } = {
    Market = "Collect more from the Central Market!",
    BuyRow = "Buy a farm row!",
    Plant = "Plant an ingredient!",
    ClaimPlot = "Claim your smoothie stand!",
    Counter = "Head to your customer counter!",
    Order = "Take the customer's order!",
    Stash = "Grab ingredients from the stash!",
    Ladder = "Climb the ladder to your blender!",
    Turbine = "Spin to blend smoothie!",
    Dispenser = "Dispense your smoothie!",
    FinishBatch = "Spin to finish the previous batch!",
    DrainBatch = "Dispense the previous batch to clear your blender!",
    Serve = "Serve customer and get PAYED!",
}
function Text.Get(stage: string, preferred: Enum.PreferredInput, button: string): string?
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
