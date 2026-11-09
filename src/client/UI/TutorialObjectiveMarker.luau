--!strict
-- One local marker follows the same stable endpoint as the navigation beam.
local Marker = {}
local YELLOW = Color3.fromRGB(255, 225, 0)
local DARK = Color3.fromRGB(47, 35, 0)
export type Surface = {
    Update: (Attachment, Instance?, number) -> (),
    Destroy: () -> (),
}
function Marker.Create(endpoint: Attachment, _stage: string?): Surface
    local top = Instance.new("Attachment")
    top.Name, top.Parent = "TutorialBeaconTop", endpoint.Parent
    local arrowOrigin = Instance.new("Attachment")
    arrowOrigin.Name, arrowOrigin.Parent = "TutorialArrowOrigin", endpoint.Parent
    local beacon = Instance.new("Beam")
    beacon.Name = "TutorialObjectiveBeacon"
    beacon.Attachment0, beacon.Attachment1 = endpoint, top
    beacon.Color = ColorSequence.new(YELLOW)
    beacon.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.18),
        NumberSequenceKeypoint.new(0.75, 0.45),
        NumberSequenceKeypoint.new(1, 1),
    })
    beacon.FaceCamera, beacon.LightEmission, beacon.LightInfluence = true, 0.6, 0
    beacon.Segments = 1
    beacon.Parent = top
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Adornee = "TutorialObjectiveArrow", arrowOrigin
    gui.Size = UDim2.fromOffset(174, 104) -- Pixels keep the arrow readable at maximum zoom.
    gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = true, 0, 0
    gui.Active = false -- Never intercept touch or gamepad interaction.
    gui.Parent = arrowOrigin
    local arrow = Instance.new("TextLabel")
    arrow.Name, arrow.BackgroundTransparency = "Arrow", 1
    arrow.Size, arrow.Position = UDim2.fromOffset(80, 68), UDim2.fromOffset(47, 30)
    arrow.Text, arrow.Font, arrow.TextSize = "▼", Enum.Font.GothamBold, 64
    arrow.TextColor3, arrow.TextStrokeColor3, arrow.TextStrokeTransparency = YELLOW, DARK, 0
    arrow.Parent = gui
    return {
        Update = function(finish: Attachment, objective: Instance?, age: number)
            local position = finish.WorldPosition
            local height = 4.5
            if objective and objective:IsA("BasePart") then
                height = math.max(height, objective.Position.Y + objective.Size.Y * 0.5 - position.Y + 3)
            elseif objective and objective:IsA("Model") then
                local bounds, size = objective:GetBoundingBox()
                height = math.max(height, bounds.Position.Y + size.Y * 0.5 - position.Y + 3)
            end
            local camera = workspace.CurrentCamera
            local distance = if camera then (camera.CFrame.Position - position).Magnitude else 40
            if camera then
                -- Keep the bottom of the pixel-sized arrow above interaction prompts, even on short screens.
                local studsPerPixel = 2
                    * distance
                    * math.tan(math.rad(camera.FieldOfView) * 0.5)
                    / math.max(320, camera.ViewportSize.Y)
                height = math.max(height, 92 * studsPerPixel)
            end
            local scale = math.clamp(distance / 70, 1, 2.5)
            local entry = math.clamp(age / 0.3, 0, 1)
            top.Parent, arrowOrigin.Parent = finish.Parent, finish.Parent
            beacon.Attachment0 = finish
            top.WorldPosition = position + Vector3.new(0, math.max(height + 4, 14 * scale) * entry, 0)
            arrowOrigin.WorldPosition = position
                + Vector3.new(0, height + 0.55 * math.sin(age * 3) + (1 - entry) * 2, 0)
            beacon.Width0, beacon.Width1 = 1.1 * scale * entry, 0.45 * scale * entry
            arrow.TextTransparency = 1 - entry
            arrow.TextStrokeTransparency = 1 - entry
        end,
        Destroy = function()
            top:Destroy()
            arrowOrigin:Destroy()
        end,
    }
end
return Marker
