--!strict
-- Presentation only: tween the value displayed by the authored cash label.
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.CashFeedback).Ticker
local Model = {}
export type State = { Value: number, From: number, Target: number, Start: number, Duration: number }

function Model.Digits(value: number): number
    return #string.format("%.0f", math.floor(math.max(0, value)))
end

function Model.New(value: number): State
    return { Value = value, From = value, Target = value, Start = 0, Duration = 0 }
end

function Model.Sample(state: State, now: number): boolean
    local t = if state.Duration == 0 then 1 else math.clamp((now - state.Start) / state.Duration, 0, 1)
    -- Cubic Out, equivalent to TweenService easing without an engine dependency.
    state.Value = if t == 1
        then state.Target
        else state.From + (state.Target - state.From) * (1 - (1 - t) ^ Config.EasingExponent)
    return t < 1
end

function Model.Retarget(state: State, target: number, now: number)
    if state.Duration > 0 and state.Value ~= state.Target and target == state.Target then
        return
    end
    -- Value is the last rendered sample; never restart from the old target.
    local changed = 0
    for place = 0, math.max(Model.Digits(state.Value), Model.Digits(target)) - 1 do
        if math.floor(state.Value / 10 ^ place) % 10 ~= math.floor(target / 10 ^ place) % 10 then
            changed += 1
        end
    end
    state.From, state.Target, state.Start = state.Value, target, now
    state.Duration = if state.Value == target
        then 0
        else math.clamp(
            Config.BaseDuration + Config.PerDigitDuration * changed,
            Config.MinDuration,
            Config.MaxDuration
        )
end

return Model
