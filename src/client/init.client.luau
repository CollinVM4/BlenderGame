local GameplayPresentationController = require(script.Controllers.GameplayPresentationController)
GameplayPresentationController.Init()

local SprintController = require(script.Controllers.SprintController)

SprintController.Init()

require(script.Controllers.StashPromptController).Init()

require(script.Controllers.UpgradesController).Init()
