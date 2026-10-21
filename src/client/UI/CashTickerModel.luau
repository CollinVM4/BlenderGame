--!strict
-- Presentation only: one continuous value drives every wheel.
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.CashFeedback).Ticker
local Model = {}
export type State = { Value: number, From: number, Target: number, Start: number, Duration: number }

function Model.Digits(value: number): number
    return #string.format("%.0f", math.floor(math.max(0, value)))
end

function Model.Digit(value: number, place: number): number
    return (value / 10 ^ place) % 10
end

function Model.Phase(value: number, place: number, rolling: boolean): number
    local digit = Model.Digit(value, place)
    -- The repeated cycle makes carries seamless; whole digits share a baseline at rest.
    return (if rolling then digit else math.floor(digit)) + 10
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
        if math.floor(Model.Digit(state.Value, place)) ~= math.floor(Model.Digit(target, place)) then
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

function Model.Wheels(state: State, rolling: boolean): number
    return if rolling
        then math.max(Model.Digits(state.From), Model.Digits(state.Target))
        else Model.Digits(state.Target)
end

return Model
