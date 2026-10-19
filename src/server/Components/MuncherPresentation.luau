--!strict
local Presentation = {}

function Presentation.Marker(object: Instance?): (BasePart | Attachment)?
    if object and object:IsA("BasePart") then
        return object
    elseif object and object:IsA("Attachment") then
        return object
    end
    return nil
end

return Presentation
