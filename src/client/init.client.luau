require(script.Controllers.InteractionPromptController).Init()
require(script.Controllers.IngredientPickupPromptController).Init()
require(script.Controllers.WorldTextController).Init()
local GameplayPresentationController = require(script.Controllers.GameplayPresentationController)
GameplayPresentationController.Init()
require(script.Controllers.BlenderStatusDistanceController).Init()
require(script.Controllers.RareIngredientPresentationController).Init()

local SprintController = require(script.Controllers.SprintController)

SprintController.Init()

require(script.Controllers.StashPromptController).Init()

require(script.Controllers.UpgradesController).Init()
