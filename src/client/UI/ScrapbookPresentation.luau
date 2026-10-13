--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Constants.DiscoveryCatalog)
local Artwork = require(Shared.Constants.ScrapbookArtwork)
local MoneyFormat = require(Shared.MoneyFormat)
local Types = require(Shared.Types)
local Registry = require(script.Parent.UIRegistry)
local RarityStyle = require(script.Parent.IngredientPickupPromptStyle)
local Viewport = require(script.Parent.IngredientViewport)
local PreviewIds = require(Shared.Constants.ScrapbookPreviews)
local Presentation = {}
export type Binding = {
    Root: ScreenGui,
    Panel: GuiObject,
    Scroll: ScrollingFrame,
    Template: Frame,
    Title: TextLabel,
    Fields: { Instance },
}
export type View = {
    RenderState: (Types.DiscoveryState) -> (),
    UpdateDiscovery: (Types.DiscoveryEvent) -> (),
    Destroy: () -> (),
}

function Presentation.FormatValue(value: number): string
    return MoneyFormat.Announcement(value)
end

local function child(parent: Instance?, name: string, class: string): Instance?
    return Registry.Child(parent, name, { name, name .. "_txt" }, class)
end

function Presentation.Resolve(playerGui: PlayerGui): Binding?
    local selected: Instance? = nil
    local root: ScreenGui? = nil
    for _, desktop in Registry.Desktops(playerGui) do
        local active = Registry.ActiveRoot(desktop, playerGui)
        if active then
            if selected then
                return nil
            end
            selected, root = desktop, active
        end
    end
    if not selected or not root then
        return nil
    end
    local panel = Registry.Child(Registry.Content(selected), "Panel:Index", { "Index", "Index_panel" }, "GuiObject")
    local scroll =
        Registry.Child(panel, "CardsViewport", { "CardsViewport", "CardsViewport_scroll_grid" }, "ScrollingFrame")
    local template = child(scroll, "IndexCardTemplate", "Frame")
    local title = child(child(panel, "Header", "GuiObject"), "INDEX", "TextLabel")
    if not panel or not scroll or not template or not title then
        return nil
    end
    local fields: { [string]: string } = {
        FruitImage = "ImageLabel",
        IngredientLabel = "TextLabel",
        IngredientValue = "TextLabel",
        RarityLabel = "TextLabel",
    }
    local controls: { Instance } = {}
    for name, class in fields do
        local control = child(template, name, class)
        if not control then
            return nil
        end
        table.insert(controls, control)
    end
    table.sort(controls, function(a, b)
        return a.Name < b.Name
    end)
    return {
        Root = root,
        Panel = panel :: GuiObject,
        Scroll = scroll :: ScrollingFrame,
        Template = template :: Frame,
        Title = title :: TextLabel,
        Fields = controls,
    }
end

-- Pixel cell heights preserve the authored card aspect ratio without a canvas
-- feedback loop. Four cells plus three gaps fit the padded viewport exactly.
function Presentation.CellSize(width: number, aspect: number): UDim2
    local cell = math.max(1, (width - 16 - 3 * 8) / 4)
    return UDim2.fromOffset(cell, math.max(1, cell * aspect))
end

-- Both registries can use the authored card fields; category controls are
-- intentionally absent until Figma supplies them.
function Presentation.RenderCard(
    card: Frame,
    discovered: boolean,
    metadata: { DisplayName: string, Rarity: string?, Value: number?, Image: string }
)
    local image = child(card, "FruitImage", "ImageLabel") :: ImageLabel
    local name = child(card, "IngredientLabel", "TextLabel") :: TextLabel
    local rarity = child(card, "RarityLabel", "TextLabel") :: TextLabel
    local value = child(card, "IngredientValue", "TextLabel") :: TextLabel
    local asset = if discovered then metadata.Image else ""
    image.Image = asset
    image.Visible = asset ~= ""
    name.Text = if discovered then metadata.DisplayName else "???"
    local tier = metadata.Rarity or "Common"
    rarity.Text = string.upper(tier)
    local palette = (RarityStyle.RarityStyles :: any)[tier] or RarityStyle.RarityStyles.Common
    rarity.TextColor3 = palette.TextColor
    value.Text = if discovered and metadata.Value ~= nil then Presentation.FormatValue(metadata.Value) else ""
    value.Visible = discovered and metadata.Value ~= nil
end

function Presentation.Create(binding: Binding, state: Types.DiscoveryState): View
    local scroll, template = binding.Scroll, binding.Template
    local grid = scroll:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout?
    local ownsGrid = grid == nil
    if not grid then
        local created = Instance.new("UIGridLayout")
        created.Parent = scroll
        grid = created
    end
    local layout = grid :: UIGridLayout
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.FillDirectionMaxCells = 4
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.CellPadding = UDim2.fromOffset(8, 8)
    local padding = scroll:FindFirstChildOfClass("UIPadding") :: UIPadding?
    local ownsPadding = padding == nil
    if not padding then
        local created = Instance.new("UIPadding")
        created.Parent = scroll
        padding = created
    end
    local inset = padding :: UIPadding
    inset.PaddingLeft, inset.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
    inset.PaddingTop, inset.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
    scroll.ClipsDescendants = true
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    local originalTitle = binding.Title.Text
    local examples: { GuiObject } = {}
    local wasVisible = template.Visible
    template.Visible = false
    for _, instance in scroll:GetChildren() do
        if instance:GetAttribute("ScrapbookGenerated") == true then
            instance:Destroy()
            continue
        end
        if instance.Name == "IndexCard" and instance:IsA("GuiObject") and instance.Visible then
            instance.Visible = false
            table.insert(examples, instance)
        end
    end
    local aspect = 208 / 234 -- exported design: 234 x 208
    local function resize()
        layout.CellSize = Presentation.CellSize(scroll.AbsoluteWindowSize.X, aspect)
    end
    resize()
    local resized = scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(resize)
    local cards: { Frame } = {}
    local stopped = false
    local previews: { [Frame]: () -> () } = {}
    local previewDiscovered: { [Frame]: boolean } = {}
    local previewCards: { { Card: Frame, Image: ImageLabel, Id: string } } = {}
    local previewConnections: { RBXScriptConnection } = {}
    local pending = false
    local function refreshPreviews()
        pending = false
        if stopped then
            return
        end
        local open = binding.Root.Enabled
        local ancestor: Instance? = scroll
        while ancestor and ancestor ~= binding.Root do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then
                open = false
            end
            ancestor = ancestor.Parent
        end
        for _, item in previewCards do
            local card, image = item.Card, item.Image
            local top, bottom = scroll.AbsolutePosition.Y, scroll.AbsolutePosition.Y + scroll.AbsoluteWindowSize.Y
            local visible = open
                and card.Visible
                and card.Parent == scroll
                and card.AbsolutePosition.Y < bottom
                and card.AbsolutePosition.Y + card.AbsoluteSize.Y > top
            local discovered = state.Ingredients[item.Id] == true
            if previews[card] and (not visible or previewDiscovered[card] ~= discovered) then
                previews[card]()
                previews[card] = nil
                previewDiscovered[card] = nil
            end
            if visible and not previews[card] then
                local cleanup = Viewport.Create(image, item.Id, not discovered)
                if cleanup then
                    previews[card] = cleanup
                    previewDiscovered[card] = discovered
                end
            end
            image.Visible = state.Ingredients[item.Id] == true and image.Image ~= "" and previews[card] == nil
        end
    end
    local function schedulePreviews()
        if stopped or pending then
            return
        end
        pending = true
        task.defer(refreshPreviews)
    end
    local function watch(instance: Instance, property: string)
        table.insert(previewConnections, instance:GetPropertyChangedSignal(property):Connect(schedulePreviews))
    end
    watch(scroll, "CanvasPosition")
    watch(scroll, "AbsoluteWindowSize")
    watch(scroll, "AbsolutePosition")
    local ancestor: Instance? = scroll
    while ancestor do
        if ancestor:IsA("GuiObject") then
            watch(ancestor, "Visible")
        elseif ancestor:IsA("ScreenGui") then
            watch(ancestor, "Enabled")
        end
        ancestor = ancestor.Parent
    end
    table.insert(previewConnections, Shared.DescendantAdded:Connect(schedulePreviews))
    local updates: { [string]: (boolean) -> () } = {}
    local entries = Catalog.GetIngredients()
    local function counter()
        local count = 0
        for _, entry in entries do
            if state.Ingredients[entry.Id] then
                count += 1
            end
        end
        binding.Title.Text = string.format("INDEX %d/%d", count, #entries)
    end
    for index, entry in entries do
        local card = template:Clone()
        card.Name = "CollectionCard_" .. index -- locked instance names never identify an ingredient
        card:SetAttribute("ScrapbookGenerated", true)
        card.LayoutOrder = index
        local function render(discovered: boolean)
            if previews[card] and previewDiscovered[card] ~= discovered then
                previews[card]()
                previews[card] = nil
                previewDiscovered[card] = nil
            end
            Presentation.RenderCard(card, discovered, {
                DisplayName = entry.DisplayName,
                Rarity = entry.Rarity,
                Value = entry.Value,
                Image = if discovered then Artwork.GetIngredient(entry.Id) else "",
            })
            if previews[card] then
                (child(card, "FruitImage", "ImageLabel") :: ImageLabel).Visible = false
            end
            schedulePreviews()
        end
        updates[entry.Id] = render
        render(state.Ingredients[entry.Id] == true)
        card.Visible = true
        card.Parent = scroll
        table.insert(cards, card)
        if not (PreviewIds :: { [string]: boolean })[entry.Id] then
            continue
        end
        table.insert(previewCards, {
            Card = card,
            Image = child(card, "FruitImage", "ImageLabel") :: ImageLabel,
            Id = entry.Id,
        })
        watch(card, "Visible")
        watch(card, "AbsolutePosition")
        watch(card, "AbsoluteSize")
        table.insert(previewConnections, card.AncestryChanged:Connect(schedulePreviews))
    end
    counter()
    return {
        RenderState = function(nextState: Types.DiscoveryState)
            if stopped then
                return
            end
            state = nextState
            for id, render in updates do
                render(state.Ingredients[id] == true)
            end
            counter()
        end,
        UpdateDiscovery = function(event: Types.DiscoveryEvent)
            if stopped then
                return
            end
            if event.Kind == "Ingredient" and updates[event.Id] then
                updates[event.Id](true)
                counter()
            end
        end,
        Destroy = function()
            if stopped then
                return
            end
            stopped = true
            resized:Disconnect()
            for _, connection in previewConnections do
                connection:Disconnect()
            end
            for _, cleanup in previews do
                cleanup()
            end
            table.clear(previews)
            table.clear(previewDiscovered)
            for _, card in cards do
                card:Destroy()
            end
            if ownsGrid then
                layout:Destroy()
            end
            if ownsPadding then
                inset:Destroy()
            end
            template.Visible = wasVisible
            for _, example in examples do
                example.Visible = true
            end
            binding.Title.Text = originalTitle
        end,
    }
end

-- Coalesce imported subtrees, and ignore changes from our own cloned cards.
function Presentation.Observe(
    playerGui: PlayerGui,
    state: Types.DiscoveryState,
    changed: (View?, ScreenGui?) -> ()
): () -> ()
    local binding: Binding? = nil
    local view: View? = nil
    local stopped, queued = false, false
    local watched: { RBXScriptConnection } = {}
    local schedule: () -> ()
    local function scan()
        queued = false
        if stopped then
            return
        end
        for _, connection in watched do
            connection:Disconnect()
        end
        table.clear(watched)
        for _, desktop in Registry.Desktops(playerGui) do
            local ancestor: Instance? = desktop
            while ancestor and ancestor ~= playerGui do
                if ancestor:IsA("ScreenGui") or ancestor:IsA("GuiObject") then
                    table.insert(
                        watched,
                        ancestor
                            :GetPropertyChangedSignal(if ancestor:IsA("ScreenGui") then "Enabled" else "Visible")
                            :Connect(schedule)
                    )
                end
                ancestor = ancestor.Parent
            end
        end
        local nextBinding = Presentation.Resolve(playerGui)
        if nextBinding then
            local identifiers: { Instance } =
                { nextBinding.Panel, nextBinding.Scroll, nextBinding.Template, nextBinding.Title }
            for _, field in nextBinding.Fields do
                table.insert(identifiers, field)
            end
            for _, identifier in identifiers do
                table.insert(watched, identifier:GetPropertyChangedSignal("Name"):Connect(schedule))
                table.insert(watched, identifier:GetAttributeChangedSignal("BlenderUI"):Connect(schedule))
            end
        end
        local sameFields = binding ~= nil and nextBinding ~= nil
        if binding and nextBinding then
            for index, field in binding.Fields do
                if field ~= nextBinding.Fields[index] then
                    sameFields = false
                    break
                end
            end
        end
        if
            binding
            and nextBinding
            and binding.Root == nextBinding.Root
            and binding.Panel == nextBinding.Panel
            and binding.Scroll == nextBinding.Scroll
            and binding.Template == nextBinding.Template
            and binding.Title == nextBinding.Title
            and sameFields
        then
            return
        end
        if not binding and not nextBinding then
            return
        end
        if view then
            view.Destroy()
        end
        view, binding = nil, nextBinding
        if nextBinding then
            view = Presentation.Create(nextBinding, state)
        end
        changed(view, if nextBinding then nextBinding.Root else nil)
    end
    schedule = function()
        if stopped or queued then
            return
        end
        queued = true
        task.defer(scan)
    end
    local added = playerGui.DescendantAdded:Connect(schedule)
    local removing = playerGui.DescendantRemoving:Connect(schedule)
    scan()
    return function()
        if stopped then
            return
        end
        stopped = true
        added:Disconnect()
        removing:Disconnect()
        for _, connection in watched do
            connection:Disconnect()
        end
        if view then
            view.Destroy()
        end
        view, binding = nil, nil
        changed(nil, nil)
    end
end
return Presentation
