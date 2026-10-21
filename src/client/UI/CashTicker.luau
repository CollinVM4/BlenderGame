--!strict
local RunService = game:GetService("RunService")
local MoneyFormat = require(game:GetService("ReplicatedStorage").Shared.MoneyFormat)
local Model = require(script.Parent.CashTickerModel)
local Ticker = {}
type View = { Label: TextLabel, State: Model.State }
local view: View? = nil
local render: RBXScriptConnection? = nil

local function stop()
    if render then
        render:Disconnect()
        render = nil
    end
end

function Ticker.Clear()
    stop()
    view = nil
end

function Ticker.Bind(label: TextLabel?, value: number)
    Ticker.Clear()
    if not label then
        return
    end
    view = { Label = label, State = Model.New(value) }
    label.Visible = true
    label.Text = MoneyFormat.Full(value)
end

function Ticker.SetTarget(value: number)
    local current = view
    if not current or value ~= value or value < 0 or value == math.huge then
        return
    end
    local target = math.floor(value)
    if render and target == current.State.Target then
        return
    end
    stop()
    Model.Retarget(current.State, target, os.clock())
    if current.State.Duration == 0 then
        current.Label.Text = MoneyFormat.Full(target)
        return
    end
    render = RunService.RenderStepped:Connect(function()
        local ok, rolling = pcall(function()
            local active = Model.Sample(current.State, os.clock())
            current.Label.Text = MoneyFormat.Full(if active then math.floor(current.State.Value + 0.5) else target)
            return active
        end)
        if not ok or not rolling then
            stop()
            if not ok then
                -- Keep the authored renderer and settle to the correct balance if animation fails.
                current.State = Model.New(target)
                pcall(function()
                    current.Label.Text = MoneyFormat.Full(target)
                end)
            end
        end
    end)
end

function Ticker.Snap(value: number)
    stop()
    if view then
        view.State = Model.New(value)
        view.Label.Text = MoneyFormat.Full(value)
    end
end

return Ticker
