--!strict
local Text = {}
local hints: { [string]: string } = {
    ClaimPlot = "Claim your smoothie stand!",
    Counter = "Head to your customer counter!",
    Order = "Take the customer's order!",
    Stash = "Grab ingredients from the stash!",
    Ladder = "Climb the ladder to your blender!",
    Turbine = "Spin to Blend!",
    Dispenser = "Dispense your smoothie!",
    FinishBatch = "Spin to finish the previous batch!",
    DrainBatch = "Dispense the previous batch to clear your blender!",
    Serve = "Serve customer &amp; Earn Cash!",
}
function Text.Get(stage: string, preferred: Enum.PreferredInput, button: string): string?
    if stage == "Blender" then
        if preferred == Enum.PreferredInput.Touch then
            return "TAP THROW TO TOSS IT IN!"
        elseif preferred == Enum.PreferredInput.Gamepad then
            return "PRESS " .. button .. " TO THROW INTO THE BLENDER!"
        end
        return "CLICK TO THROW INTO THE BLENDER!"
    end
    return hints[stage]
end
-- Timers only reduce repeated text; world objectives always follow gameplay.
function Text.ShouldShow(order: number, seen: boolean, idle: number): boolean
    return order <= 1 or (order == 2 and not seen) or idle >= (if order == 2 then 6 else 8)
end
return Text
