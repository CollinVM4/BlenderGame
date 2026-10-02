require(script.Controllers.GameplayAudioController).Init()
require(script.Controllers.SmoothiePickupPromptController).Init()
require(script.Controllers.InteractionPromptController).Init()
require(script.Controllers.CustomerOrderController).Init()
require(script.Controllers.IngredientPickupPromptController).Init()
require(script.Controllers.WorldTextController).Init()
require(script.Controllers.JackedNoobResponseController).Init()
require(script.Controllers.FarmPresentationController).Init()
local GameplayPresentationController = require(script.Controllers.GameplayPresentationController)
GameplayPresentationController.Init()
require(script.Controllers.BlenderStatusDistanceController).Init()
require(script.Controllers.TurbineCameraController).Init()
require(script.Controllers.RareIngredientPresentationController).Init()

local SprintController = require(script.Controllers.SprintController)

SprintController.Init()

require(script.Controllers.StashPromptController).Init()

require(script.Controllers.UpgradesController).Init()

require(script.Controllers.CarryInputController).Init()

require(script.Controllers.SessionInteractionController).Init()

require(script.Controllers.PlotIdentityController).Init()

require(script.Controllers.BatController).Init()

require(script.Controllers.StashExpansionController).Init()
require(script.Controllers.RipenessPresentationController).Init()
require(script.Controllers.ScrapbookController).Init()
require(script.Controllers.RespawnPresentationController).Init()
