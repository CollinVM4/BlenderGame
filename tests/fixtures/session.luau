-- Minimal real session setup for tests which do not need authored plot geometry.
workspaceFake.FindFirstChild = workspaceFake.FindFirstChild or function()
    return nil
end
local sessionTestAuthority = loadModule("TycoonService")
sessionTestAuthority.Init({})
local function assignTestSession(p)
    if sessionTestAuthority.GetPlot(p) then
        return sessionTestAuthority.GetPlot(p)
    end
    local plot = instance("Model")
    plot.Name, plot.Parent = "Plot" .. tostring(p.UserId or #allInstances), workspaceFake
    services.CollectionService:AddTag(plot, "PlayerPlot")
    return sessionTestAuthority.AssignPlot(p)
end
local function bindTestData(data)
    data.BindRuntimeAuthority(sessionTestAuthority)
end
local function buyTestUpgrade(data, p, id, tier)
    return data.PurchaseUpgrade(p, id, tier or data.GetUpgrade(p, id) + 1, sessionTestAuthority.GetRequestContext(p))
end
