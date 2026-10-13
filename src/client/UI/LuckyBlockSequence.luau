--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Constants.LuckyBlockPresentation)
local Sequence = {}
export type View = { Show: (string, boolean) -> (), Fade: () -> (), Destroy: () -> () }
export type Schedule = (number, () -> ()) -> () -> ()

-- Explicitly cancellable timeline; no frame listener, input or reward request.
function Sequence.new(schedule: Schedule)
    local active: { [any]: () -> () } = {}
    local manager = {}
    function manager.Cancel(key: any)
        local cleanup = active[key]
        if cleanup then
            cleanup()
        end
    end
    function manager.Start(key: any, rewardId: string, full: boolean, view: View, elapsed: number?): boolean
        manager.Cancel(key)
        local age = math.max(0, elapsed or 0)
        local endAt = Config.RevealSeconds + Config.HoldSeconds + Config.FadeSeconds
        if not (Config.Rewards :: any)[rewardId] or age >= endAt then
            view.Destroy()
            return false
        end
        local cancelled = false
        local timers: { () -> () } = {}
        local function cleanup()
            if cancelled then
                return
            end
            cancelled = true
            active[key] = nil
            for _, cancel in timers do
                cancel()
            end
            view.Destroy()
        end
        active[key] = cleanup
        local function at(seconds: number, callback: () -> ())
            table.insert(
                timers,
                schedule(math.max(0, seconds - age), function()
                    if not cancelled then
                        callback()
                    end
                end)
            )
        end
        if full and age < Config.RevealSeconds then
            local ids: { string } = {}
            for id in Config.Rewards do
                table.insert(ids, id)
            end
            for index = #ids, 2, -1 do
                local other = math.random(index)
                ids[index], ids[other] = ids[other], ids[index]
            end
            local current = 1
            for index, seconds in Config.TickTimes do
                if seconds <= age then
                    current = index
                end
            end
            view.Show(ids[current], true)
            for index = current + 1, #Config.TickTimes do
                local id = ids[index]
                at(Config.TickTimes[index], function()
                    view.Show(id, true)
                end)
            end
        end
        at(Config.RevealSeconds, function()
            view.Show(rewardId, false)
        end)
        at(Config.RevealSeconds + Config.HoldSeconds, view.Fade)
        at(endAt, cleanup)
        return true
    end
    function manager.Destroy()
        local keys = {}
        for key in active do
            table.insert(keys, key)
        end
        for _, key in keys do
            manager.Cancel(key)
        end
    end
    return manager
end

return Sequence
