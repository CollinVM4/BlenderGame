--!strict
-- Presentation adapter for the inspected Framewisp export. Never creates UI or
-- changes generated action/FX/layout behavior.
local Registry = require(script.Parent.UIRegistry)
local Gui = {}
export type Row = {
    Current: TextLabel,
    Next: TextLabel,
    Price: TextLabel,
    Purchase: GuiButton,
    BuyLabel: TextLabel,
    Title: TextLabel,
    PriceTransparency: number,
    BuyTransparency: number,
}
export type View = { Root: ScreenGui, Cash: TextLabel?, Rows: { [string]: Row } }
local transparency: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function originalTransparency(label: TextLabel): number
    if transparency[label] == nil then
        transparency[label] = label.TextTransparency
    end
    return transparency[label]
end
local cards: { [string]: string } = {
    Jump = "JumpCard",
    Bat = "BatCard",
    MovementSpeed = "MovementSpeedCard",
    CarryCapacity = "CarryCapacityCard",
    SprintStamina = "SprintStaminaCard",
}

local function child(parent: Instance?, name: string, class: string): Instance?
    return Registry.Child(parent, name, { name }, class)
end
local function importedChild(parent: Instance?, tagged: string, exported: string, class: string): Instance?
    return Registry.Child(parent, exported, { tagged, exported }, class)
end
local desktops = Registry.Desktops
local activeRoot = Registry.ActiveRoot

local function resolveDesktop(root: ScreenGui, desktop: Instance): View?
    local content = Registry.Content(desktop)
    local panel = Registry.Child(content, "Panel:Upgrades", { "Upgrades_panel", "Upgrades" }, "GuiObject")
    local scroll = importedChild(panel, "UpgradeScroll_scroll", "UpgradeScroll", "ScrollingFrame")
    local list = importedChild(scroll, "UpgradeList_list", "UpgradeList", "GuiObject")
    local top = child(content, "TOP", "GuiObject")
    local cashDisplay = child(top, "CashDisplay", "GuiObject")
    local cash = Registry.Child(cashDisplay, "Cash", { "{Coins}", "Cash" }, "TextLabel")
    if not content then
        return nil
    end
    local rows: { [string]: Row } = {}
    for id, name in cards do
        local card = Registry.Child(list, "Upgrade:" .. id, { name }, "GuiObject")
        local level = child(card, "LevelContainer", "GuiObject")
        local current = child(level, "CurrentValue", "TextLabel")
        local nextValue = child(level, "NextValue", "TextLabel")
        local price = child(card, "PurchasePrice", "TextLabel")
        local purchase = importedChild(card, "Buy_button_smooth", "Buy", "GuiButton")
        local label = child(purchase, "BuyLabel", "TextLabel")
        local title = child(card, "UpgradeTitle", "TextLabel")
        if not current or not nextValue or not price or not purchase or not label or not title then
            continue
        end
        rows[id] = {
            Current = current :: TextLabel,
            Next = nextValue :: TextLabel,
            Price = price :: TextLabel,
            Purchase = purchase :: GuiButton,
            BuyLabel = label :: TextLabel,
            Title = title :: TextLabel,
            PriceTransparency = originalTransparency(price :: TextLabel),
            BuyTransparency = originalTransparency(label :: TextLabel),
        }
    end
    return { Root = root :: ScreenGui, Cash = cash :: TextLabel?, Rows = rows }
end

function Gui.Resolve(playerGui: PlayerGui): View?
    local selected: Instance? = nil
    local selectedRoot: ScreenGui? = nil
    for _, desktop in desktops(playerGui) do
        local root = activeRoot(desktop, playerGui)
        if root then
            if selected then
                return nil -- Two visible desktops have no verified ownership/recency contract.
            end
            selected, selectedRoot = desktop, root
        end
    end
    return if selected and selectedRoot then resolveDesktop(selectedRoot, selected) else nil
end

-- Player subscriptions belong to the controller. Only instance-specific purchase
-- connections are replaced here, including when live sync replaces a card.
function Gui.Observe(playerGui: PlayerGui, changed: (View?) -> (), purchase: (string) -> ()): () -> ()
    local view: View? = nil
    local connections: { RBXScriptConnection } = {}
    local rootConnections: { RBXScriptConnection } = {}
    local stopped, queued = false, false
    local ambiguous = false
    local lastIssue = ""
    local schedule: () -> ()
    local function clear()
        for _, connection in connections do
            connection:Disconnect()
        end
        table.clear(connections)
    end
    local function same(nextView: View?): boolean
        if not view or not nextView then
            return view == nextView
        end
        if view.Root ~= nextView.Root or view.Cash ~= nextView.Cash then
            return false
        end
        for id, row in view.Rows do
            local nextRow = nextView.Rows[id]
            if not nextRow then
                return false
            end
            if
                row.Current ~= nextRow.Current
                or row.Next ~= nextRow.Next
                or row.Price ~= nextRow.Price
                or row.Purchase ~= nextRow.Purchase
                or row.BuyLabel ~= nextRow.BuyLabel
                or row.Title ~= nextRow.Title
            then
                return false
            end
        end
        for id in nextView.Rows do
            if not view.Rows[id] then
                return false
            end
        end
        return true
    end
    local function scan()
        queued = false
        if stopped then
            return
        end
        for _, connection in rootConnections do
            connection:Disconnect()
        end
        table.clear(rootConnections)
        local watched: { [Instance]: boolean } = {}
        local active = 0
        for _, desktop in desktops(playerGui) do
            if activeRoot(desktop, playerGui) then
                active += 1
            end
            local ancestor: Instance? = desktop
            while ancestor and ancestor ~= playerGui do
                if not watched[ancestor] then
                    watched[ancestor] = true
                    if ancestor:IsA("ScreenGui") or ancestor:IsA("GuiObject") then
                        local property = if ancestor:IsA("ScreenGui") then "Enabled" else "Visible"
                        table.insert(rootConnections, ancestor:GetPropertyChangedSignal(property):Connect(schedule))
                    end
                end
                ancestor = ancestor.Parent
            end
        end
        if active > 1 and not ambiguous then
            warn(
                "UpgradesGui: multiple active Be a Blender! Desktop roots in PlayerGui; binding paused until only one is active"
            )
        end
        ambiguous = active > 1
        local nextView = Gui.Resolve(playerGui)
        local issues: { string } = {}
        if nextView then
            if not nextView.Cash then
                table.insert(issues, "TOP.CashDisplay.Cash/{Coins}")
            end
            for _, id in { "Jump", "Bat", "MovementSpeed", "CarryCapacity", "SprintStamina" } do
                if not nextView.Rows[id] then
                    table.insert(issues, cards[id] .. " (card or required control)")
                end
            end
        elseif active == 1 then
            table.insert(issues, "DesktopContent (missing, wrong class or ambiguous)")
        end
        local issue = table.concat(issues, ", ")
        if issue ~= "" and issue ~= lastIssue then
            warn("UpgradesGui: missing, wrong-class or ambiguous binding in active desktop: " .. issue)
        end
        lastIssue = issue
        if same(nextView) then
            return
        end
        clear()
        view = nextView
        if nextView then
            for id, row in nextView.Rows do
                table.insert(
                    connections,
                    row.Purchase.Activated:Connect(function()
                        purchase(id)
                    end)
                )
            end
        end
        changed(nextView)
    end
    schedule = function()
        if queued or stopped then
            return
        end
        queued = true
        task.defer(scan)
    end
    local added = playerGui.DescendantAdded:Connect(schedule)
    -- Only removal of a binding or its ancestor invalidates the view. Decorative
    -- Framewisp FX instances may be added/removed without rebinding purchases.
    local removing = playerGui.DescendantRemoving:Connect(function(instance)
        local current = view
        if not current then
            schedule()
            return
        end
        local affected = instance == current.Root
            or instance == current.Cash
            or (current.Cash ~= nil and current.Cash:IsDescendantOf(instance))
        for _, row in current.Rows do
            local bindings: { Instance } = { row.Current, row.Next, row.Price, row.Purchase, row.BuyLabel, row.Title }
            for _, bound in bindings do
                if instance == bound or bound:IsDescendantOf(instance) then
                    affected = true
                    break
                end
            end
            if affected then
                break
            end
        end
        if affected then
            clear()
            view = nil
            changed(nil)
            schedule()
        end
    end)
    scan()
    return function()
        stopped = true
        clear()
        for _, connection in rootConnections do
            connection:Disconnect()
        end
        table.clear(rootConnections)
        added:Disconnect()
        removing:Disconnect()
        view = nil
        changed(nil)
    end
end

return Gui
