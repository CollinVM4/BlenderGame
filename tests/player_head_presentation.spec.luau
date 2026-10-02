env.Vector2 = {
    new = function(x, y)
        return { X = x, Y = y }
    end,
}
env.UDim2.new = function(xs, xo, ys, yo)
    return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
function vector:Abs()
    return vec(math.abs(self.X), math.abs(self.Y), math.abs(self.Z))
end
function vector:Min(other)
    return vec(math.min(self.X, other.X), math.min(self.Y, other.Y), math.min(self.Z, other.Z))
end
function vector:Max(other)
    return vec(math.max(self.X, other.X), math.max(self.Y, other.Y), math.max(self.Z, other.Z))
end
local modules = {}
local keys = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
local function load(name)
    if modules[name] then
        return modules[name]
    end
    local chunk = assert(loadstring(sources[name], name))
    setfenv(
        chunk,
        setmetatable({
            script = { Parent = setmetatable({ Parent = { UI = keys } }, { __index = keys }) },
            require = function(key)
                return load(key)
            end,
        }, { __index = env })
    )
    modules[name] = chunk()
    return modules[name]
end
services.ReplicatedStorage.Shared.Constants.Ingredients = "Ingredients"
services.ReplicatedStorage.Shared.MoneyFormat = "MoneyFormat"
services.ReplicatedStorage.Shared.Constants.DialogueTextStyle = "DialogueTextStyle"
services.RunService.RenderStepped = signal()
prompts.Enabled = true
local definitions = load("Ingredients")

local view = load("IngredientPickupPromptPresentation")
local object = uiInstance("Part", "PlayerHead", workspaceFake)
object.Transparency, object.Size = 0, vec(2, 2, 2)
object:SetAttribute("IngredientId", "PlayerHead")
object:SetAttribute("SourceUserId", 123)
object:SetAttribute("SourceDisplayName", "Eatandpoop")
local prompt = uiInstance("ProximityPrompt", "CarryPrompt", object)
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = { Name = "E" }, { Name = "ButtonX" }
prompt.ActionText, prompt.HoldDuration = "Pickup", 0
local cleanup, update = view.Create(prompt, object, definitions.PlayerHead, playerGui, "Keyboard")
local gui = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
check(gui:FindFirstChild("IngredientName").Text == "Eatandpoop's Head", "world name resolves head instance identity")
check(
    string.find(gui:FindFirstChild("Rarity").Text, "UNCOMMON", 1, true)
        and gui:FindFirstChild("IngredientValue").Text == load("MoneyFormat").Compact(definitions.PlayerHead.Value),
    "head uses existing rarity and value presentation"
)
cleanup()
object:SetAttribute("SourceDisplayName", nil)
cleanup, update = view.Create(prompt, object, definitions.PlayerHead, playerGui, "Keyboard")
gui = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
check(gui:FindFirstChild("IngredientName").Text == "Player Head", "missing source falls back to generic world name")
cleanup()

object:SetAttribute("SourceDisplayName", nil)
cleanup, update = view.Create(prompt, object, definitions.PlayerHead, playerGui, "Keyboard")
object:SetAttribute("SourceDisplayName", "UpdatedName")
update()
gui = playerGui:FindFirstChild("IngredientPickupPromptDisplay")
check(
    gui:FindFirstChild("IngredientName").Text == "UpdatedName's Head",
    "visible world name refreshes after metadata arrives"
)
cleanup()

print("Player head presentation checks passed")
