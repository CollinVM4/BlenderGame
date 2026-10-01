--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Constants.DiscoveryCatalog)
local Artwork = require(Shared.Constants.ScrapbookArtwork)
local MoneyFormat = require(Shared.MoneyFormat)
local Types = require(Shared.Types)
local Presentation = {}
export type Tab = "Ingredients" | "Customers"
export type View = {
    SetWindow: (boolean, Tab) -> (),
    RenderState: (Types.DiscoveryState) -> (),
    UpdateDiscovery: (Types.DiscoveryEvent) -> (),
}

function Presentation.FormatValue(value: number): string
    return MoneyFormat.Announcement(value)
end

-- Preserve the catalog's ordering, including the ordering within each section.
function Presentation.Group<T>(entries: { T }, key: (T) -> string): { { Key: string, Entries: { T } } }
    local groups: { { Key: string, Entries: { T } } } = {}
    local byKey: { [string]: { Key: string, Entries: { T } } } = {}
    for _, entry in entries do
        local id = key(entry)
        local group: { Key: string, Entries: { T } }? = byKey[id]
        if group then
            table.insert(group.Entries, entry)
        else
            local newGroup: { Key: string, Entries: { T } } = { Key = id, Entries = { entry } }
            byKey[id] = newGroup
            table.insert(groups, newGroup)
        end
    end
    return groups
end

local function required(root: Instance, path: string, className: string): Instance
    local current = root
    local fullPath = root:GetFullName()
    for part in path:gmatch("[^.]+") do
        fullPath ..= "." .. part
        local child = current:FindFirstChild(part)
        assert(child, fullPath .. " missing")
        current = child
    end
    assert(current:IsA(className), fullPath .. " must be a " .. className)
    return current
end

function Presentation.Create(
    gui: ScreenGui,
    state: Types.DiscoveryState,
    actions: { Open: () -> (), Close: () -> (), SelectTab: (Tab) -> () }
): View
    local window = required(gui, "Window", "Frame") :: Frame
    window.Visible = false
    local open = required(gui, "OpenButton", "ImageButton") :: ImageButton
    local close = required(window, "CloseButton", "ImageButton") :: ImageButton
    local ingredientsButton = required(window, "Tabs.IngredientsButton", "TextButton") :: TextButton
    local customersButton = required(window, "Tabs.CustomersButton", "TextButton") :: TextButton
    local ingredientsPage = required(window, "Pages.IngredientsPage", "Frame") :: Frame
    local customersPage = required(window, "Pages.CustomersPage", "Frame") :: Frame
    local ingredientsScroll = required(ingredientsPage, "Scroll", "ScrollingFrame") :: ScrollingFrame
    local customersScroll = required(customersPage, "Scroll", "ScrollingFrame") :: ScrollingFrame
    local rarityTemplate = required(ingredientsScroll, "RaritySectionTemplate", "Frame") :: Frame
    local jumpTemplate = required(customersScroll, "JumpSectionTemplate", "Frame") :: Frame

    -- Validate everything before cloning so setup errors cannot leave half-built pages.
    for _, config in
        {
            { Template = rarityTemplate, Card = "IngredientCardTemplate", Image = "Artwork" },
            { Template = jumpTemplate, Card = "CustomerCardTemplate", Image = "Portrait" },
        }
    do
        local template = config.Template
        local cardName = config.Card
        required(template, "Header.Title", "TextLabel")
        required(template, "Grid", "Frame")
        required(template, "Grid.UIGridLayout", "UIGridLayout")
        local card = required(template, "Grid." .. cardName, "Frame") :: Frame
        required(card, config.Image, "ImageLabel")
        required(card, "Name", "TextLabel")
        if cardName == "IngredientCardTemplate" then
            required(card, "Rarity", "TextLabel")
            required(card, "Value", "TextLabel")
        end
        template.Visible = false
        card.Visible = false
    end
    for _, scroll in { ingredientsScroll, customersScroll } do
        local list = required(scroll, "UIListLayout", "UIListLayout") :: UIListLayout
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.FillDirection = Enum.FillDirection.Vertical
        list.Padding = UDim.new(0, 12)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.fromOffset(0, 0)
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    end
    gui.ResetOnSpawn = false
    local ingredientCardsById: { [string]: (boolean) -> () } = {}
    local specialCustomerCardsById: { [string]: (boolean) -> () } = {}

    local function section(template: Frame, parent: ScrollingFrame, title: string, order: number): Frame
        local clone = template:Clone()
        clone.Name = "Section_" .. title
        clone.LayoutOrder = order
        clone.Size = UDim2.new(1, -12, 0, 0)
        clone.AutomaticSize = Enum.AutomaticSize.Y
        local header = required(clone, "Header", "Frame") :: Frame
        header.LayoutOrder = 1
        header.Size = UDim2.new(1, 0, 0, 30)
        local titleLabel = required(header, "Title", "TextLabel") :: TextLabel
        titleLabel.Text = title
        local list = clone:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.FillDirection = Enum.FillDirection.Vertical
        list.Padding = UDim.new(0, 8)
        list.Parent = clone
        local grid = required(clone, "Grid", "Frame") :: Frame
        grid.LayoutOrder = 2
        grid.AutomaticSize = Enum.AutomaticSize.None
        local layout = required(grid, "UIGridLayout", "UIGridLayout") :: UIGridLayout
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.FillDirectionMaxCells = 4
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.CellPadding = UDim2.fromOffset(6, 6)
        local function resize()
            local width = math.max(1, math.floor((grid.AbsoluteSize.X - 18) / 4))
            layout.CellSize = UDim2.fromOffset(width, math.floor(width * 1.35))
        end
        local function fitGrid()
            grid.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
        end
        -- Grid content height is engine-measured; the scroll canvas remains automatic.
        grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitGrid)
        fitGrid()
        clone.Visible = true
        clone.Parent = parent
        resize()
        return grid
    end

    local function bindCard(card: Frame, imageName: string, asset: string, displayName: string): (boolean) -> ()
        local image = required(card, imageName, "ImageLabel") :: ImageLabel
        local name = required(card, "Name", "TextLabel") :: TextLabel
        local tint = image.ImageColor3
        image.Image = asset
        image.ScaleType = Enum.ScaleType.Fit
        return function(discovered: boolean)
            image.ImageColor3 = if discovered then tint else Color3.new(0, 0, 0)
            name.Text = if discovered then displayName else "???"
        end
    end

    for order, group in
        Presentation.Group(Catalog.GetIngredients(), function(entry)
            return entry.Rarity
        end)
    do
        local grid = section(rarityTemplate, ingredientsScroll, string.upper(group.Key), order)
        local template = required(grid, "IngredientCardTemplate", "Frame") :: Frame
        for index, entry in group.Entries do
            local card = template:Clone()
            card.Name = "Ingredient_" .. entry.Id
            card.LayoutOrder = index
            local reveal = bindCard(card, "Artwork", Artwork.GetIngredient(entry.Id), entry.DisplayName)
            local rarityLabel = required(card, "Rarity", "TextLabel") :: TextLabel
            rarityLabel.Text = entry.Rarity
            local value = required(card, "Value", "TextLabel") :: TextLabel
            local function update(discovered: boolean)
                reveal(discovered)
                value.Text = if discovered then Presentation.FormatValue(entry.Value) else "$???"
            end
            ingredientCardsById[entry.Id] = update
            update(state.Ingredients[entry.Id] == true)
            card.Visible = true
            card.Parent = grid
        end
    end
    for order, group in
        Presentation.Group(Catalog.GetSpecialCustomers(), function(entry)
            return tostring(entry.MinJumpTier)
        end)
    do
        local grid = section(jumpTemplate, customersScroll, "JUMP " .. group.Key, order)
        local template = required(grid, "CustomerCardTemplate", "Frame") :: Frame
        for index, entry in group.Entries do
            local card = template:Clone()
            -- An ordinal name avoids showing a locked customer's identity in UI tooling.
            card.Name = "Customer_" .. tostring(index)
            card.LayoutOrder = index
            local update = bindCard(card, "Portrait", Artwork.GetSpecialCustomer(entry.Id), entry.DisplayName)
            specialCustomerCardsById[entry.Id] = update
            update(state.SpecialCustomers[entry.Id] == true)
            card.Visible = true
            card.Parent = grid
        end
    end
    open.Activated:Connect(actions.Open)
    close.Activated:Connect(actions.Close)
    ingredientsButton.Activated:Connect(function()
        actions.SelectTab("Ingredients")
    end)
    customersButton.Activated:Connect(function()
        actions.SelectTab("Customers")
    end)
    local ingredientsColor, customersColor = ingredientsButton.BackgroundColor3, customersButton.BackgroundColor3
    return {
        SetWindow = function(isOpen: boolean, tab: Tab)
            window.Visible = isOpen
            ingredientsPage.Visible = tab == "Ingredients"
            customersPage.Visible = tab == "Customers"
            ingredientsButton.BackgroundColor3 = if tab == "Ingredients"
                then ingredientsColor:Lerp(Color3.new(1, 1, 1), 0.25)
                else ingredientsColor
            customersButton.BackgroundColor3 = if tab == "Customers"
                then customersColor:Lerp(Color3.new(1, 1, 1), 0.25)
                else customersColor
        end,
        RenderState = function(discoveries: Types.DiscoveryState)
            for id, update in ingredientCardsById do
                update(discoveries.Ingredients[id] == true)
            end
            for id, update in specialCustomerCardsById do
                update(discoveries.SpecialCustomers[id] == true)
            end
        end,
        UpdateDiscovery = function(event: Types.DiscoveryEvent)
            local cards: { [string]: (boolean) -> () } = if event.Kind == "Ingredient"
                then ingredientCardsById
                else specialCustomerCardsById
            local update = cards[event.Id]
            if update then
                update(true)
            end
        end,
    }
end

return Presentation
