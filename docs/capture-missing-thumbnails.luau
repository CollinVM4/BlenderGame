-- Paste into the Client Command Bar during Studio Play.
-- Capture each numbered page on both backgrounds at the same window size.
local player = game:GetService("Players").LocalPlayer
assert(player, "Switch to the Client Command Bar during Play")
local playerGui = player:WaitForChild("PlayerGui")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
assert(shared:WaitForChild("ScrapbookPreviewAssets", 10), "Ingredient preview assets have not replicated")
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local renderer = require(client:WaitForChild("UI"):WaitForChild("IngredientViewport"))
assert(not playerGui:FindFirstChild("MuncherThumbnailCapture"), "Close the existing capture sheet first")

local ids = {
    "Apple",
    "Banana",
    "Cactus",
    "Chili_Sauce",
    "Cinnamon",
    "Coconut",
    "Cotton_Candy",
    "Crab",
    "Dragon_Fruit",
    "Fish",
    "French_Fries",
    "Hamburger",
    "Honey",
    "Ice",
    "Mango",
    "Melon",
    "Milk",
    "Mushrooms",
    "Noob",
    "Orange",
    "Peach",
    "Pear",
    "Pineapple",
    "Pizza",
    "Protein",
    "Rock",
    "Shell",
    "Shit",
    "Squid",
    "Starfruit",
    "Steak",
    "Strawberry",
    "Sushi",
    "Tire",
    "Watermelon",
    "Worm",
}

local columns, rows, border = 4, 3, 4
local pageSize = columns * rows
local pages = math.ceil(#ids / pageSize)
local camera = workspace.CurrentCamera
assert(camera, "No client camera found")
local view = camera.ViewportSize
local tile = math.min(256, math.floor((view.X - 32) / columns), math.floor((view.Y - 100) / rows))
assert(tile >= 128, "Enlarge the Play viewport, then run this again")
local width, height = columns * tile, rows * tile
local left = math.floor((view.X - width - 2 * border) / 2)
local top = math.floor((view.Y - height - 2 * border) / 2) + 19

local gui = Instance.new("ScreenGui")
gui.Name = "MuncherThumbnailCapture"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.ResetOnSpawn = false
gui.DisplayOrder = 100000
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
root.BorderSizePixel = 0
root.Parent = gui

local function frame(parent, x, y, w, h, color, transparency)
    local object = Instance.new("Frame")
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(w, h)
    object.BorderSizePixel = 0
    object.BackgroundColor3 = color
    object.BackgroundTransparency = transparency or 0
    object.Parent = parent
    return object
end

local outline = frame(root, left, top, width + 2 * border, height + 2 * border, Color3.fromRGB(255, 0, 255))
local plate = frame(outline, border, border, width, height, Color3.new(0, 0, 0))
local bar = frame(root, left, top - 43, width + 2 * border, 38, Color3.fromRGB(35, 40, 50))
local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(8, 0)
status.Size = UDim2.new(1, -302, 1, 0)
status.Font = Enum.Font.GothamMedium
status.TextSize = 15
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.new(1, 1, 1)
status.Parent = bar

local page = 1
local white = false
local cleanups = {}

local function updateBackground()
    plate.BackgroundColor3 = if white then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
    status.Text = ("Page %d/%d  |  %s  |  %d px tiles"):format(page, pages, if white then "WHITE" else "BLACK", tile)
end

local function clearPage()
    for _, cleanup in cleanups do
        cleanup()
    end
    table.clear(cleanups)
    plate:ClearAllChildren()
end

local function showPage()
    clearPage()
    white = false
    updateBackground()
    for index = 1, pageSize do
        local id = ids[(page - 1) * pageSize + index]
        if id then
            local x = ((index - 1) % columns) * tile
            local y = math.floor((index - 1) / columns) * tile
            local cell = frame(plate, x, y, tile, tile, Color3.new(), 1)
            cell.Name = id
            cell.ClipsDescendants = true
            local image = Instance.new("ImageLabel")
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.Position = UDim2.fromScale(0.5, 0.5)
            image.Size = UDim2.fromScale(0.92, 0.92)
            image.BackgroundTransparency = 1
            image.Parent = cell
            local cleanup = renderer.Create(image, id)
            if cleanup then
                table.insert(cleanups, cleanup)
            else
                warn("Capture sheet could not render:", id)
            end
        end
    end
end

local function button(label, offset, w, click)
    local object = Instance.new("TextButton")
    object.Size = UDim2.fromOffset(w, 30)
    object.Position = UDim2.new(1, offset, 0, 4)
    object.BackgroundColor3 = Color3.fromRGB(63, 77, 104)
    object.TextColor3 = Color3.new(1, 1, 1)
    object.Font = Enum.Font.GothamMedium
    object.TextSize = 14
    object.Text = label
    object.Parent = bar
    object.Activated:Connect(click)
end

button("Prev", -288, 53, function()
    if page > 1 then
        page -= 1
        showPage()
    end
end)
button("Next", -230, 53, function()
    if page < pages then
        page += 1
        showPage()
    end
end)
button("Black / White", -172, 106, function()
    white = not white
    updateBackground()
end)
button("Close", -61, 55, function()
    clearPage()
    gui:Destroy()
end)

showPage()
print("Muncher capture sheet ready:", #ids, "ingredients,", pages, "pages")
