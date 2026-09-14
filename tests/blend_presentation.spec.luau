local p = player()
local input, wheel = references[p].BlenderInput, references[p].TurbineWheel
local realIngredients = ingredients
loadModule("FilmingUtil").Init()
-- Keep Heartbeat authority precise while limiting presentation traffic.
do
    blend.Reset(p)
    local ingredient = realIngredients.Spawn("Strawberry", frame(), p)
    input.Overlaps = { ingredient }
    check(blend.TryInput(p, ingredient, input), "throttle test ingests a real ingredient")
    for _ = 1, 2 do
        local extra = realIngredients.Spawn("Strawberry", frame(), p)
        input.Overlaps = { extra }
        check(blend.TryInput(p, extra, input), "throttle test fills batch")
    end
    local firstEvent = #presentation + 1
    local accepted = true
    for _ = 1, 60 do
        now += 1 / 60
        accepted = blend.AddProgress(p, wheel, 1) and accepted
    end
    check(accepted and blend.GetSnapshot(p).Progress == 60, "all 60 RPM progress updates remain authoritative")
    local updates = 0
    local previous = 0
    for index = firstEvent, #presentation do
        local event = presentation[index]
        if event.Moment == "BlendProgressChanged" then
            updates += 1
            check(event.Payload.Progress > previous, "progress notifications contain changed payloads")
            previous = event.Payload.Progress
        end
    end
    check(updates >= 8 and updates <= 10, "one second of Heartbeats produces at most ten progress notifications")
    local beforeIdle = #presentation
    check(not blend.AddProgress(p, wheel, 0) and #presentation == beforeIdle, "idle turbine sends no progress")
    check(blend.AddProgress(p, wheel, 100), "completion is accepted inside throttle window")
    check(
        presentation[#presentation - 1].Moment == "BlendProgressChanged"
            and presentation[#presentation - 1].Payload.Progress == 100
            and presentation[#presentation].Moment == "BlendCompleted",
        "final progress is delivered immediately before completion"
    )
    local afterComplete = #presentation
    check(
        not blend.AddProgress(p, wheel, 1) and #presentation == afterComplete,
        "completed turbine sends no repeated updates"
    )
end
