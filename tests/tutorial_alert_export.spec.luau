local modules = {}
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local module = assert(loadstring(sources[name], name))
    setfenv(
        module,
        setmetatable({
            script = { Parent = { UIRegistry = "UIRegistry" } },
            game = {
                GetService = function()
                    return { Shared = { Constants = { Upgrades = "Upgrades" } } }
                end,
            },
            require = load,
        }, { __index = getfenv() })
    )
    modules[name] = module()
    return modules[name]
end

local playerGui = instance("PlayerGui", "PlayerGui")
local objects = { [0] = playerGui }
for _, node in exportNodes do
    local object = instance(node[3], node[4], objects[node[2]])
    object.Visible = node[5]
    objects[node[1]] = object
end
local registry = load("UIRegistry")
local desktop = assert(registry.Desktops(playerGui)[1])
local content = assert(registry.Content(desktop))
local leftMenu = assert(content:FindFirstChild("LeftMenu"))
local panel = assert(content:FindFirstChild("Upgrades"))
local gui = load("UpgradesGui")
local view = assert(gui.Resolve(playerGui))
check(view.Panel == panel, "real exported Upgrades panel resolves")
check(view.MenuArrow ~= nil and view.MenuArrow == leftMenu:FindFirstChild("Alert"), "real LeftMenu/Alert resolves")
check(
    view.MenuArrow:IsA("ImageLabel") and view.MenuArrow.Visible,
    "menu arrow starts with real exported class and visibility"
)
local state = load("TutorialAlertState")
for _, beat in state.Beats do
    local arrow = view.PanelArrows[beat.ArrowName]
    check(
        arrow ~= nil and arrow == panel:FindFirstChild(beat.ArrowName),
        "beat key resolves its real direct panel child"
    )
    check(arrow:IsA("ImageLabel") and arrow.Visible, "panel arrow starts with real exported class and visibility")
    local result = state.new().Evaluate({
        TutorialActive = true,
        Stage = "Order",
        Cash = load("Upgrades")[beat.TrackId][2].Cost,
        Levels = { Jump = if beat.TrackId == "Bat" then 1 else 0, Bat = 0 },
        PanelOpen = true,
    })
    check(view.PanelArrows[result.PanelArrow] == arrow, "state output selects the resolved exported arrow")
end
check(view.PanelArrows.Jump1Alert ~= nil and view.PanelArrows.BatAlert ~= nil, "panel keys use exported names")
-- The original Figma names remain supported by importedChild without changing keys.
view.MenuArrow.Name = "Alert_pulse"
for _, beat in state.Beats do
    view.PanelArrows[beat.ArrowName].Name = beat.ArrowName .. "_pulse"
end
local tagged = assert(gui.Resolve(playerGui))
check(tagged.MenuArrow == view.MenuArrow, "tagged menu fallback remains compatible")
for _, beat in state.Beats do
    check(
        tagged.PanelArrows[beat.ArrowName] == view.PanelArrows[beat.ArrowName],
        "tagged panel fallback retains exported keys"
    )
end
print(string.format("PASS: v2 export tutorial arrow resolution (%d contracts)", count))
