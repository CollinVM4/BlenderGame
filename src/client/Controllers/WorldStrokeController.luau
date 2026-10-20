--!strict
-- AbsoluteSize is camera-dependent. Server-authored/replicated world lettering
-- publishes stud thickness; each client owns the rendered pixel thickness.
local Style = require(game:GetService("ReplicatedStorage").Shared.WorldBillboardStyle)
local Controller = {}
local started = false
function Controller.Init()
    if started then
        return
    end
    started = true
    local tracked: { [UIStroke]: () -> () } = {}
    local function track(object: Instance)
        if not object:IsA("UIStroke") or tracked[object] then
            return
        end
        local stroke = object
        local stop: (() -> ())? = nil
        local function refresh()
            local label = stroke.Parent
            local gui = stroke:FindFirstAncestorWhichIsA("BillboardGui")
            local thickness = stroke:GetAttribute("WorldThicknessStuds")
            if stop then
                stop()
                stop = nil
            end
            if label and label:IsA("GuiObject") and gui and typeof(thickness) == "number" then
                stop = Style.ApplyWorldStroke(label, gui :: BillboardGui, {
                    Name = stroke.Name,
                    ThicknessStuds = thickness,
                    Color = stroke.Color,
                    Transparency = stroke.Transparency,
                })
            end
        end
        local attribute = stroke:GetAttributeChangedSignal("WorldThicknessStuds"):Connect(refresh)
        local ancestry = stroke.AncestryChanged:Connect(refresh)
        tracked[stroke] = function()
            attribute:Disconnect()
            ancestry:Disconnect()
            if stop then
                stop()
            end
        end
        refresh()
    end
    workspace.DescendantAdded:Connect(track)
    workspace.DescendantRemoving:Connect(function(object)
        if object:IsA("UIStroke") then
            local stop = tracked[object]
            if stop then
                stop()
                tracked[object] = nil
            end
        end
    end)
    for _, object in workspace:GetDescendants() do
        track(object)
    end
end
return Controller
