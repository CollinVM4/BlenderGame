local catalog = assert(loadstring(sources.Upgrades))()
local module = assert(loadstring(sources.TutorialAlertState))
setfenv(
    module,
    setmetatable({
        game = {
            GetService = function()
                return { Shared = { Constants = { Upgrades = catalog } } }
            end,
        },
        require = function(value)
            return value
        end,
    }, { __index = getfenv() })
)
local State = module()
local count = 0
local function expect(state, inputs, menu, arrow, message)
    local result = state.Evaluate(inputs)
    assert(result.MenuVisible == menu and result.PanelArrow == arrow, message)
    count += 1
end
local jumpCost, batCost = catalog.Jump[2].Cost, catalog.Bat[2].Cost
local state = State.new()
local inputs =
    { TutorialActive = true, Stage = "Order", Cash = jumpCost - 1, Levels = { Jump = 0, Bat = 0 }, PanelOpen = false }
expect(state, inputs, false, nil, "below threshold")
inputs.Cash = jumpCost
expect(state, inputs, true, nil, "exact catalog threshold shows menu")
inputs.PanelOpen = true
expect(state, inputs, false, "Jump1Alert_pulse", "open panel routes Jump arrow")
inputs.Cash = 0
expect(state, inputs, false, "Jump1Alert_pulse", "spending cannot unlatch")
inputs.PanelOpen = false
expect(state, inputs, true, nil, "closing restores latched menu arrow")
inputs.Cash = batCost
inputs.PanelOpen = true
expect(state, inputs, false, "Jump1Alert_pulse", "Jump wins when both thresholds reached")
inputs.Levels.Jump = 1
expect(state, inputs, false, "BatAlert_pulse", "purchase hands off on same evaluation")
inputs.Cash = 0
inputs.Levels.Jump = 0
expect(state, inputs, false, "BatAlert_pulse", "cleared Jump never returns; Bat remains latched")
inputs.Levels.Bat = 1
expect(state, inputs, false, nil, "Bat purchase clears final beat")
inputs.Levels.Bat = 0
expect(state, inputs, false, nil, "clears are permanent for session")

state = State.new()
inputs.Levels = { Jump = 0, Bat = 1 }
inputs.Cash = 0
expect(state, inputs, false, nil, "early Bat purchase")
inputs.Levels = { Jump = 1, Bat = 0 }
inputs.Cash = batCost
expect(state, inputs, false, nil, "Bat purchased before latching never shows")

for _, panelOpen in { false, true } do
    state = State.new()
    inputs = {
        TutorialActive = false,
        Stage = "Order",
        Cash = batCost,
        Levels = { Jump = 0, Bat = 0 },
        PanelOpen = panelOpen,
    }
    expect(state, inputs, false, nil, "inactive tutorial suppresses alerts")
    inputs.TutorialActive = true
    expect(
        state,
        inputs,
        not panelOpen,
        if panelOpen then "Jump1Alert_pulse" else nil,
        "activation reads latest attributes"
    )
    inputs.Stage = "Complete"
    expect(state, inputs, false, nil, "completion hides active beat")
    inputs.Stage = "Order"
    expect(state, inputs, false, nil, "completed tutorial cannot return this session")
end
expect(
    State.new(),
    inputs,
    not inputs.PanelOpen,
    "Jump1Alert_pulse",
    "new session has independent latches and completion"
)
print(string.format("PASS: tutorial alert state (%d contracts)", count))
