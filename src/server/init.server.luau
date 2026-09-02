--!strict
local CustomerService = require(script.Services.CustomerService)
local TycoonService = require(script.Services.TycoonService)
local TurbineWheel = require(script.Components.TurbineWheel)

TycoonService.Init()
CustomerService.Init()
TurbineWheel.Init()