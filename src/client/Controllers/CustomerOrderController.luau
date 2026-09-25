--!strict
local Players = game:GetService("Players")
local Controller = {}
local started = false

function Controller.Init()
    if started then
        return
    end
    started = true
    local tracked: { [BillboardGui]: () -> () } = {}
    local function attach(object: Instance)
        if
            not object:IsA("BillboardGui")
            or (object.Name ~= "OrderBubble" and object.Name ~= "CustomerResult")
            or tracked[object]
        then
            return
        end
        object.Enabled = false
        local customer = object.Parent
        while customer and not customer:IsA("Model") do
            customer = customer.Parent
        end
        if not customer then
            return
        end
        local function refresh()
            object.Enabled = customer:GetAttribute("PlotSessionId") ~= nil
                and customer:GetAttribute("PlotSessionId") == Players.LocalPlayer:GetAttribute("PlotSessionId")
                and (object.Name ~= "OrderBubble" or customer:GetAttribute("OrderRevealed") == true)
        end
        local ownership = customer:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
        local membership = Players.LocalPlayer:GetAttributeChangedSignal("PlotSessionId"):Connect(refresh)
        local sessionChanged = customer:GetAttributeChangedSignal("PlotSessionId"):Connect(refresh)
        local reveal = customer:GetAttributeChangedSignal("OrderRevealed"):Connect(refresh)
        tracked[object] = function()
            ownership:Disconnect()
            sessionChanged:Disconnect()
            membership:Disconnect()
            reveal:Disconnect()
            object.Enabled = false
        end
        refresh()
    end
    workspace.DescendantAdded:Connect(attach)
    workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("BillboardGui") then
            local cleanup = tracked[object]
            if cleanup then
                tracked[object] = nil
                cleanup()
            end
        end
    end)
    for _, object in workspace:GetDescendants() do
        attach(object)
    end
end

return Controller
