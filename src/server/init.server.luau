--!strict
local CustomerService = require(script.Services.CustomerService)
local TycoonService = require(script.Services.TycoonService)
local SprintService = require(script.Services.SprintService)
local TurbineWheel = require(script.Components.TurbineWheel)

TycoonService.Init()
CustomerService.Init()
SprintService.Init()
TurbineWheel.Init()